// Supabase Edge Function: notify_users
// Smart Notification Router for Messaging System
// Triggers on INSERT to messages table via Database Webhook

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Import Firebase service account (copy from process_notifications)
import serviceAccount from "../process_notifications/service-account.json" assert { type: "json" };

// ============================================
// INTERFACES
// ============================================

interface MessagePayload {
  type: "INSERT";
  table: "messages";
  record: {
    message_id: string;
    conversation_id: string;
    sender_id: string;
    sender_role: string;
    sender_name: string;
    content: string;
    message_type: string;
    created_at: string;
  };
  schema: "public";
}

interface Participant {
  user_id: string;
  role: string;
  display_name: string;
  is_active: boolean;
}

interface StaffInfo {
  staff_id: string;
  firstname: string;
  lastname: string;
  fcm_token: string | null;
  is_on_leave: boolean;
  clinic_id: string;
}

interface DentistInfo {
  dentist_id: string;
  firstname: string;
  lastname: string;
  fcm_token: string | null;
  clinic_id: string;
}

interface ClinicInfo {
  clinic_id: string;
  owner_id: string;
  clinic_name: string;
}

// ============================================
// FIREBASE ACCESS TOKEN
// ============================================

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

// ============================================
// FCM NOTIFICATION SENDER
// ============================================

interface FCMOptions {
  priority?: "high" | "normal";
  data?: Record<string, string>;
}

async function sendFCMNotification(
  fcmToken: string,
  title: string,
  body: string,
  options: FCMOptions = {}
): Promise<boolean> {
  try {
    const accessToken = await getFirebaseAccessToken();
    const projectId = serviceAccount.project_id;
    const priority = options.priority || "normal";

    const message = {
      message: {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: options.data || {},
        android: {
          priority: priority,
          notification: {
            sound: "default",
            channel_id: "fcm_default_channel",
          },
        },
        apns: {
          headers: {
            "apns-priority": priority === "high" ? "10" : "5",
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
      console.error(`FCM Error for token ${fcmToken.substring(0, 20)}...:`, errorText);
      return false;
    }

    console.log(`✅ FCM sent successfully to token ${fcmToken.substring(0, 20)}...`);
    return true;
  } catch (error) {
    console.error("Error sending FCM:", error);
    return false;
  }
}

// ============================================
// MAIN HANDLER
// ============================================

serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Initialize Supabase admin client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse webhook payload
    const payload: MessagePayload = await req.json();
    
    // Validate payload
    if (payload.type !== "INSERT" || payload.table !== "messages") {
      console.log("Ignoring non-insert or non-messages event");
      return new Response(
        JSON.stringify({ success: true, message: "Event ignored" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const message = payload.record;
    console.log(`\n📨 New message in conversation ${message.conversation_id}`);
    console.log(`   From: ${message.sender_name} (${message.sender_role})`);
    console.log(`   Content: ${message.content.substring(0, 50)}...`);

    // ============================================
    // STEP 1: Fetch all participants (excluding sender)
    // ============================================

    const { data: participants, error: participantError } = await supabase
      .from("conversation_participants")
      .select("user_id, role, display_name, is_active")
      .eq("conversation_id", message.conversation_id)
      .neq("user_id", message.sender_id)
      .eq("is_active", true);

    if (participantError) {
      console.error("Error fetching participants:", participantError);
      throw participantError;
    }

    if (!participants || participants.length === 0) {
      console.log("No other participants to notify");
      return new Response(
        JSON.stringify({ success: true, message: "No participants to notify" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Found ${participants.length} participant(s) to potentially notify`);

    // ============================================
    // STEP 2: Process each participant with smart routing
    // ============================================

    const results = {
      sent: 0,
      skipped: 0,
      escalated: 0,
      errors: 0,
    };

    for (const participant of participants as Participant[]) {
      console.log(`\n👤 Processing: ${participant.display_name} (${participant.role})`);

      try {
        switch (participant.role) {
          // ----------------------------------------
          // PATIENT: Standard FCM notification
          // ----------------------------------------
          case "patient": {
            const { data: patient, error: patientError } = await supabase
              .from("patients")
              .select("fcm_token, firstname, lastname")
              .eq("patient_id", participant.user_id)
              .single();

            if (patientError || !patient) {
              console.log(`   ⚠️ Patient not found: ${participant.user_id}`);
              results.errors++;
              break;
            }

            if (!patient.fcm_token) {
              console.log(`   ⏭️ Patient has no FCM token, skipping`);
              results.skipped++;
              break;
            }

            const sent = await sendFCMNotification(
              patient.fcm_token,
              `New message from ${message.sender_name}`,
              message.content.substring(0, 100),
              {
                data: {
                  type: "chat_message",
                  conversation_id: message.conversation_id,
                  sender_role: message.sender_role,
                },
              }
            );

            sent ? results.sent++ : results.errors++;
            break;
          }

          // ----------------------------------------
          // DENTIST: Standard FCM notification
          // ----------------------------------------
          case "dentist": {
            const { data: dentist, error: dentistError } = await supabase
              .from("dentists")
              .select("fcm_token, firstname, lastname")
              .eq("dentist_id", participant.user_id)
              .single();

            if (dentistError || !dentist) {
              console.log(`   ⚠️ Dentist not found: ${participant.user_id}`);
              results.errors++;
              break;
            }

            if (!dentist.fcm_token) {
              console.log(`   ⏭️ Dentist has no FCM token, skipping`);
              results.skipped++;
              break;
            }

            const sent = await sendFCMNotification(
              dentist.fcm_token,
              `New message from ${message.sender_name}`,
              message.content.substring(0, 100),
              {
                data: {
                  type: "chat_message",
                  conversation_id: message.conversation_id,
                  sender_role: message.sender_role,
                },
              }
            );

            sent ? results.sent++ : results.errors++;
            break;
          }

          // ----------------------------------------
          // STAFF: Smart routing with leave check
          // ----------------------------------------
          case "staff": {
            // Fetch staff details including leave status
            const { data: staff, error: staffError } = await supabase
              .from("staffs")
              .select("staff_id, firstname, lastname, fcm_token, is_on_leave, clinic_id")
              .eq("staff_id", participant.user_id)
              .single();

            if (staffError || !staff) {
              console.log(`   ⚠️ Staff not found: ${participant.user_id}`);
              results.errors++;
              break;
            }

            const staffInfo = staff as StaffInfo;
            const staffName = `${staffInfo.firstname} ${staffInfo.lastname}`.trim();

            // ========================================
            // SMART ROUTING LOGIC
            // ========================================

            if (!staffInfo.is_on_leave) {
              // ✅ Staff is WORKING - send normal notification
              console.log(`   ✅ Staff ${staffName} is working`);

              if (!staffInfo.fcm_token) {
                console.log(`   ⏭️ Staff has no FCM token, skipping`);
                results.skipped++;
                break;
              }

              const sent = await sendFCMNotification(
                staffInfo.fcm_token,
                `New message from ${message.sender_name}`,
                message.content.substring(0, 100),
                {
                  data: {
                    type: "chat_message",
                    conversation_id: message.conversation_id,
                    sender_role: message.sender_role,
                  },
                }
              );

              sent ? results.sent++ : results.errors++;
            } else {
              // 🚨 Staff is ON LEAVE - escalate to clinic owner (dentist)
              console.log(`   🏖️ Staff ${staffName} is ON LEAVE - escalating to owner`);

              // Find the clinic owner
              const { data: clinic, error: clinicError } = await supabase
                .from("clinics")
                .select("clinic_id, owner_id, clinic_name")
                .eq("clinic_id", staffInfo.clinic_id)
                .single();

              if (clinicError || !clinic) {
                console.log(`   ⚠️ Clinic not found: ${staffInfo.clinic_id}`);
                results.errors++;
                break;
              }

              const clinicInfo = clinic as ClinicInfo;

              // Get owner (dentist) details
              const { data: owner, error: ownerError } = await supabase
                .from("dentists")
                .select("dentist_id, firstname, lastname, fcm_token")
                .eq("dentist_id", clinicInfo.owner_id)
                .single();

              if (ownerError || !owner) {
                console.log(`   ⚠️ Clinic owner not found: ${clinicInfo.owner_id}`);
                results.errors++;
                break;
              }

              const ownerInfo = owner as DentistInfo;
              const ownerName = `${ownerInfo.firstname} ${ownerInfo.lastname}`.trim();

              if (!ownerInfo.fcm_token) {
                console.log(`   ⏭️ Owner ${ownerName} has no FCM token, skipping`);
                results.skipped++;
                break;
              }

              // Send HIGH PRIORITY notification to owner
              const sent = await sendFCMNotification(
                ownerInfo.fcm_token,
                `⚠️ Staff ${staffName} is on leave`,
                `New ${message.sender_role} message requires attention: "${message.content.substring(0, 60)}..."`,
                {
                  priority: "high", // High priority for escalated messages
                  data: {
                    type: "escalated_message",
                    conversation_id: message.conversation_id,
                    sender_role: message.sender_role,
                    original_recipient: staffInfo.staff_id,
                    escalation_reason: "staff_on_leave",
                  },
                }
              );

              if (sent) {
                results.escalated++;
                console.log(`   📤 Escalated to owner: ${ownerName}`);
              } else {
                results.errors++;
              }
            }
            break;
          }

          // ----------------------------------------
          // ADMIN: Send to admin topic
          // ----------------------------------------
          case "admin": {
            // Admins use topic subscription, handled separately
            console.log(`   ⏭️ Admin notifications use topic subscription`);
            results.skipped++;
            break;
          }

          default:
            console.log(`   ⚠️ Unknown role: ${participant.role}`);
            results.skipped++;
        }
      } catch (error) {
        console.error(`   ❌ Error processing ${participant.display_name}:`, error);
        results.errors++;
      }
    }

    // ============================================
    // STEP 3: Return results
    // ============================================

    console.log(`\n📊 Notification Results:`);
    console.log(`   Sent: ${results.sent}`);
    console.log(`   Escalated: ${results.escalated}`);
    console.log(`   Skipped: ${results.skipped}`);
    console.log(`   Errors: ${results.errors}`);

    return new Response(
      JSON.stringify({
        success: true,
        message_id: message.message_id,
        conversation_id: message.conversation_id,
        results,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("❌ Edge function error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
