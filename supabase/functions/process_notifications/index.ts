import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationPayload {
  id: number
  type: string
  recipient_id: string | null
  recipient_role: string | null  // Added: read from column directly
  message: string
  payload: any
  processed: boolean
  created_at: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log('🚀 Processing notifications...')

    // Fetch unprocessed notifications
    const { data: notifications, error: fetchError } = await supabaseClient
      .from('notification_queue')
      .select('*')
      .eq('processed', false)
      .order('created_at', { ascending: true })
      .limit(50)

    if (fetchError) {
      console.error('❌ Error fetching notifications:', fetchError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch notifications' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!notifications || notifications.length === 0) {
      console.log('✅ No unprocessed notifications found')
      return new Response(
        JSON.stringify({ message: 'No notifications to process', processed: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📋 Found ${notifications.length} unprocessed notifications`)

    let processedCount = 0
    let errorCount = 0

    // Process each notification
    for (const notification of notifications as NotificationPayload[]) {
      console.log(`🔄 Processing notification ${notification.id}: ${notification.type}`)

      let success = false
      let errorMessage = ''

      try {
        const payload = notification.payload || {}
        // Read recipient_role from column first, then fallback to payload
        const recipientRole = notification.recipient_role || payload.recipient_role || 'unknown'
        const notificationType = notification.type || ''

        // Smart type detection based on notification type
        const isAdminType = notificationType.includes('clinic_registered') || notificationType.includes('support')
        const isDentistType = notificationType.includes('booking') ||
          notificationType.includes('clinic_approved') ||
          notificationType.includes('clinic_rejected') ||
          notificationType.includes('clinic_status') ||
          notificationType === 'chat_message' && recipientRole === 'dentist'
        const isPatientType = notificationType.includes('booking_confirmed') ||
          notificationType.includes('booking_rejected') ||
          notificationType.includes('booking_cancelled') ||
          notificationType.includes('booking_completed') ||
          recipientRole === 'patient'
        const isStaffType = recipientRole === 'staff'

        // Determine notification type and handle accordingly
        if (recipientRole === 'admin' || isAdminType || notification.recipient_id === null) {
          // Admin notification - send to topic
          success = await sendAdminTopicNotification(notification)
        } else if (recipientRole === 'dentist' || isDentistType) {
          // Dentist notification - send to specific dentist(s)
          success = await sendDentistNotification(notification, supabaseClient)
        } else if (isPatientType || isStaffType || recipientRole !== 'unknown') {
          // Other user types (patient, staff)
          success = await sendUserNotification(notification, supabaseClient, recipientRole)
        } else {
          // Unknown type - log and skip
          console.log(`⚠️ Unknown notification type: ${notificationType}, role: ${recipientRole}`)
          success = true // Mark as success to avoid retries
        }

        if (success) {
          // Mark as processed successfully
          await supabaseClient
            .from('notification_queue')
            .update({
              processed: true,
              processed_at: new Date().toISOString()
            })
            .eq('id', notification.id)

          processedCount++
          console.log(`✅ Successfully processed notification ${notification.id}`)
        } else {
          errorMessage = `Failed to send ${recipientRole} notification`
        }

      } catch (error) {
        errorMessage = `Processing exception: ${String(error)}`
        console.error(`❌ Exception processing notification ${notification.id}:`, error)
      }

      // Always mark as processed to prevent infinite retries
      if (!success) {
        await supabaseClient
          .from('notification_queue')
          .update({
            processed: true,
            processed_at: new Date().toISOString(),
            error: errorMessage
          })
          .eq('id', notification.id)

        errorCount++
        console.log(`⚠️  Marked failed notification ${notification.id} as processed: ${errorMessage}`)
      }
    }

    console.log(`🎯 Processing complete: ${processedCount} successful, ${errorCount} failed`)

    return new Response(
      JSON.stringify({
        message: 'Notifications processed',
        processed: processedCount,
        errors: errorCount,
        total: notifications.length
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Fatal error in notification processor:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: String(error) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Send notification to admin topic
async function sendAdminTopicNotification(notification: NotificationPayload): Promise<boolean> {
  try {
    console.log(`📢 Sending admin topic notification: ${notification.message}`)

    const data = {
      type: notification.type,
      notification_id: notification.id.toString(),
      ...notification.payload
    }

    const success = await sendFCMToTopic(
      'admin_alerts',
      'DenteEase Admin',
      notification.message,
      data
    )

    if (success) {
      console.log(`✅ Admin topic notification sent successfully`)
    } else {
      console.log(`❌ Failed to send admin topic notification`)
    }

    return success

  } catch (error) {
    console.error('❌ Error sending admin topic notification:', error)
    return false
  }
}

// Send notification to specific dentist(s)
async function sendDentistNotification(notification: NotificationPayload, supabaseClient: any): Promise<boolean> {
  try {
    const payload = notification.payload || {}

    // First, try to send directly to recipient_id as a dentist
    if (notification.recipient_id) {
      const { data: dentist, error: dentistError } = await supabaseClient
        .from('dentists')
        .select('fcm_token, firstname, lastname, dentist_id')
        .eq('dentist_id', notification.recipient_id)
        .single()

      if (!dentistError && dentist) {
        console.log(`🦷 Sending notification directly to dentist: ${dentist.firstname} ${dentist.lastname}`)

        if (!dentist.fcm_token) {
          console.log(`⚠️  Dentist ${dentist.firstname} ${dentist.lastname} has no FCM token`)
          return true // Not an error - just no token
        }

        const sent = await sendFCMNotification(
          dentist.fcm_token,
          'DenteEase',
          notification.message,
          {
            type: notification.type,
            notification_id: notification.id.toString(),
            dentist_id: dentist.dentist_id,
            ...payload
          }
        )

        if (sent) {
          console.log(`✅ Sent notification to dentist ${dentist.firstname} ${dentist.lastname}`)
        }
        return sent
      }
    }

    // Fallback: try to find dentists by clinic_id
    const clinicId = payload.clinic_id

    if (!clinicId) {
      console.log(`⚠️  Dentist notification ${notification.id} has no clinic_id and recipient not found as dentist`)
      return true // Not an error - just nothing to send
    }

    console.log(`🦷 Sending dentist notification for clinic ${clinicId}`)

    // Fetch dentists for this clinic
    const { data: dentists, error: dentistError } = await supabaseClient
      .from('dentists')
      .select('fcm_token, firstname, lastname, dentist_id')
      .eq('clinic_id', clinicId)

    if (dentistError) {
      console.error('❌ Error fetching dentists:', dentistError)
      return false
    }

    if (!dentists || dentists.length === 0) {
      console.log(`ℹ️  No dentists found for clinic ${clinicId}`)
      return true // Not an error - just no dentists to notify
    }

    let sentCount = 0
    let tokenCount = 0

    for (const dentist of dentists) {
      if (!dentist.fcm_token) {
        console.log(`⚠️  Dentist ${dentist.firstname} ${dentist.lastname} has no FCM token`)
        continue
      }

      tokenCount++
      const sent = await sendFCMNotification(
        dentist.fcm_token,
        'DenteEase',
        notification.message,
        {
          type: notification.type,
          notification_id: notification.id.toString(),
          dentist_id: dentist.dentist_id,
          ...payload
        }
      )

      if (sent) {
        sentCount++
        console.log(`✅ Sent notification to dentist ${dentist.firstname} ${dentist.lastname}`)
      } else {
        console.log(`❌ Failed to send notification to dentist ${dentist.firstname} ${dentist.lastname}`)
      }
    }

    // Success if we sent to at least one dentist OR if no tokens exist (not an error)
    const success = sentCount > 0 || tokenCount === 0

    if (tokenCount === 0) {
      console.log(`ℹ️  No FCM tokens found for ${dentists.length} dentist(s) in clinic ${clinicId}`)
    } else {
      console.log(`📊 Sent to ${sentCount}/${tokenCount} dentists in clinic ${clinicId}`)
    }

    return success

  } catch (error) {
    console.error('❌ Error sending dentist notification:', error)
    return false
  }
}

// Send notification to other user types (patient, staff)
async function sendUserNotification(notification: NotificationPayload, supabaseClient: any, recipientRole: string = 'patient'): Promise<boolean> {
  try {
    if (!notification.recipient_id) {
      console.log(`⚠️  User notification ${notification.id} has no recipient_id`)
      return false
    }

    const payload = notification.payload || {}
    // Use passed recipientRole or fallback to payload
    const effectiveRole = recipientRole !== 'unknown' ? recipientRole : (payload.recipient_role || 'patient')

    console.log(`👤 Sending ${effectiveRole} notification to ${notification.recipient_id}`)

    // Determine table and column based on recipient role
    let tableName = 'patients'
    let idColumn = 'patient_id'

    if (effectiveRole === 'staff') {
      tableName = 'staffs'
      idColumn = 'staff_id'
    }

    // Fetch user's FCM token
    const { data: users, error: userError } = await supabaseClient
      .from(tableName)
      .select('fcm_token, firstname, lastname')
      .eq(idColumn, notification.recipient_id)

    if (userError || !users || users.length === 0) {
      console.error(`❌ Error fetching ${effectiveRole}:`, userError)
      return false
    }

    const user = users[0]
    if (!user.fcm_token) {
      console.log(`⚠️  ${effectiveRole} ${user.firstname} ${user.lastname} has no FCM token`)
      return true // Not an error - just no token to send to
    }

    const sent = await sendFCMNotification(
      user.fcm_token,
      'DenteEase',
      notification.message,
      {
        type: notification.type,
        notification_id: notification.id.toString(),
        recipient_role: effectiveRole,
        ...payload
      }
    )

    if (sent) {
      console.log(`✅ Sent notification to ${effectiveRole} ${user.firstname} ${user.lastname}`)
    } else {
      console.log(`❌ Failed to send notification to ${effectiveRole} ${user.firstname} ${user.lastname}`)
    }

    return sent

  } catch (error) {
    console.error('❌ Error sending user notification:', error)
    return false
  }
}

// Import Firebase service account for v1 API authentication
import serviceAccount from "./service-account.json" assert { type: "json" };

// Get Firebase Access Token using service account
async function getFirebaseAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const encoder = new TextEncoder();
  const headerB64 = btoa(JSON.stringify(header));
  const payloadB64 = btoa(JSON.stringify(payload));
  const signatureInput = `${headerB64}.${payloadB64}`;

  // Import private key
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = serviceAccount.private_key
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s/g, "");

  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(signatureInput)
  );

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const jwt = `${headerB64}.${payloadB64}.${signatureB64}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

// Send FCM notification to specific token using Firebase v1 API
async function sendFCMNotification(token: string, title: string, body: string, data: any): Promise<boolean> {
  try {
    const accessToken = await getFirebaseAccessToken();
    const projectId = serviceAccount.project_id;

    const message = {
      message: {
        token: token,
        notification: {
          title: title,
          body: body,
        },
        data: Object.fromEntries(
          Object.entries(data || {}).map(([k, v]) => [k, String(v)])
        ),
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channel_id: "fcm_default_channel",
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      },
    };

    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(message),
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ FCM Error for token ${token.substring(0, 20)}...:`, errorText);
      return false;
    }

    console.log(`✅ FCM sent successfully to token ${token.substring(0, 20)}...`);
    return true;
  } catch (error) {
    console.error('❌ Error sending FCM:', error)
    return false
  }
}

// Send FCM to topic using Firebase v1 API
async function sendFCMToTopic(topic: string, title: string, body: string, data: any): Promise<boolean> {
  try {
    const accessToken = await getFirebaseAccessToken();
    const projectId = serviceAccount.project_id;

    const message = {
      message: {
        topic: topic,
        notification: {
          title: title,
          body: body,
        },
        data: Object.fromEntries(
          Object.entries(data || {}).map(([k, v]) => [k, String(v)])
        ),
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channel_id: "fcm_default_channel",
          },
        },
      },
    };

    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(message),
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ FCM Topic Error:`, errorText);
      return false;
    }

    console.log(`✅ FCM sent to topic ${topic}`);
    return true;
  } catch (error) {
    console.error('❌ Error sending FCM to topic:', error)
    return false
  }
}