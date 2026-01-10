// Supabase Edge Function: push_notifications
// Unified FCM Push Notification Handler for DentEase
// Handles ALL notification events: messages, bookings, clinic status, etc.
// Triggered via Database Webhooks or direct HTTP calls

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

// Import Firebase service account from process_notifications folder
import serviceAccount from "../process_notifications/service-account.json" with { type: "json" };

// ============================================
// CORS HEADERS
// ============================================

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ============================================
// TYPES & INTERFACES
// ============================================

type NotificationType =
  | "new_message"
  | "new_booking"
  | "booking_approved"
  | "booking_rejected"
  | "booking_cancelled"
  | "booking_completed"
  | "clinic_registered"
  | "clinic_approved"
  | "clinic_rejected"
  | "clinic_resubmission"
  | "support_ticket"
  | "bill_created"
  | "chat_message"
  | "general";

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: Record<string, unknown>;
  old_record?: Record<string, unknown>;
  schema: string;
}

interface DirectNotificationPayload {
  event_type: NotificationType;
  recipient_id?: string;
  recipient_role?: string;
  clinic_id?: string;
  title?: string;
  body?: string;
  data?: Record<string, unknown>;
  send_to_admin?: boolean;
}

interface FCMOptions {
  priority?: "high" | "normal";
  data?: Record<string, string>;
  topic?: string;
}

interface NotificationResult {
  sent: number;
  skipped: number;
  errors: number;
  details: string[];
}

// ============================================
// FIREBASE ACCESS TOKEN
// ============================================

let cachedAccessToken: string | null = null;
let tokenExpiresAt = 0;

async function getFirebaseAccessToken(): Promise<string> {
  // Return cached token if still valid (with 5 min buffer)
  if (cachedAccessToken && Date.now() < tokenExpiresAt - 300000) {
    return cachedAccessToken;
  }

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
  cachedAccessToken = tokenData.access_token;
  tokenExpiresAt = Date.now() + 3600000; // 1 hour from now

  return tokenData.access_token;
}

// ============================================
// FCM NOTIFICATION SENDERS
// ============================================

async function sendFCMToToken(
  fcmToken: string,
  title: string,
  body: string,
  options: FCMOptions = {}
): Promise<boolean> {
  try {
    const accessToken = await getFirebaseAccessToken();
    const projectId = serviceAccount.project_id;
    const priority = options.priority || "high";

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

    console.log(`✅ FCM sent to token ${fcmToken.substring(0, 20)}...`);
    return true;
  } catch (error) {
    console.error("Error sending FCM:", error);
    return false;
  }
}

async function sendFCMToTopic(
  topic: string,
  title: string,
  body: string,
  options: FCMOptions = {}
): Promise<boolean> {
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
        data: options.data || {},
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
      console.error(`FCM Topic Error:`, errorText);
      return false;
    }

    console.log(`✅ FCM sent to topic: ${topic}`);
    return true;
  } catch (error) {
    console.error("Error sending FCM to topic:", error);
    return false;
  }
}

// ============================================
// HELPER FUNCTIONS
// ============================================

async function getUserFCMToken(
  supabase: SupabaseClient,
  userId: string,
  role: string
): Promise<{ token: string | null; name: string }> {
  let tableName: string;
  let idColumn: string;

  switch (role) {
    case "patient":
      tableName = "patients";
      idColumn = "patient_id";
      break;
    case "dentist":
      tableName = "dentists";
      idColumn = "dentist_id";
      break;
    case "staff":
      tableName = "staffs";
      idColumn = "staff_id";
      break;
    case "admin":
      tableName = "admins";
      idColumn = "admin_id";
      break;
    default:
      return { token: null, name: "Unknown" };
  }

  // First try: Direct lookup by ID
  const { data, error } = await supabase
    .from(tableName)
    .select("fcm_token, firstname, lastname")
    .eq(idColumn, userId)
    .maybeSingle();

  if (data?.fcm_token) {
    const name = `${data.firstname || ""} ${data.lastname || ""}`.trim() || "User";
    return { token: data.fcm_token, name };
  }

  // Special handling for dentist role: The userId might actually be a clinic_id
  // This happens because the chat system uses clinic_id as the conversation participant
  // for dentists (so patients message the "clinic" and any dentist can respond)
  if (role === "dentist") {
    console.log(`Dentist not found by dentist_id, trying clinic_id lookup for: ${userId}`);

    // Try to find dentists by clinic_id and get the first one's FCM token
    const { data: clinicDentists, error: clinicError } = await supabase
      .from("dentists")
      .select("dentist_id, fcm_token, firstname, lastname")
      .eq("clinic_id", userId)
      .not("fcm_token", "is", null);

    if (!clinicError && clinicDentists && clinicDentists.length > 0) {
      // Return the first dentist's FCM token that has one
      const dentistWithToken = clinicDentists.find((d: { fcm_token: string | null }) => d.fcm_token);
      if (dentistWithToken) {
        const dentistName = `${dentistWithToken.firstname || ""} ${dentistWithToken.lastname || ""}`.trim() || "Dentist";
        console.log(`Found dentist via clinic_id: ${dentistWithToken.dentist_id}`);
        return { token: dentistWithToken.fcm_token, name: dentistName };
      }
    }
  }

  // User not found or has no token
  if (data) {
    const name = `${data.firstname || ""} ${data.lastname || ""}`.trim() || "User";
    return { token: null, name };
  }

  console.log(`User not found: ${role}/${userId}`);
  return { token: null, name: "Unknown" };
}

async function getClinicDentists(
  supabase: SupabaseClient,
  clinicId: string
): Promise<Array<{ dentist_id: string; fcm_token: string | null; name: string }>> {
  const { data, error } = await supabase
    .from("dentists")
    .select("dentist_id, fcm_token, firstname, lastname")
    .eq("clinic_id", clinicId);

  if (error || !data) {
    console.log(`No dentists found for clinic: ${clinicId}`);
    return [];
  }

  return data.map((d) => ({
    dentist_id: d.dentist_id,
    fcm_token: d.fcm_token,
    name: `${d.firstname || ""} ${d.lastname || ""}`.trim() || "Dentist",
  }));
}

async function getClinicStaff(
  supabase: SupabaseClient,
  clinicId: string
): Promise<Array<{ staff_id: string; fcm_token: string | null; name: string; is_on_leave: boolean }>> {
  const { data, error } = await supabase
    .from("staffs")
    .select("staff_id, fcm_token, firstname, lastname, is_on_leave")
    .eq("clinic_id", clinicId);

  if (error || !data) {
    console.log(`No staff found for clinic: ${clinicId}`);
    return [];
  }

  return data.map((s) => ({
    staff_id: s.staff_id,
    fcm_token: s.fcm_token,
    name: `${s.firstname || ""} ${s.lastname || ""}`.trim() || "Staff",
    is_on_leave: s.is_on_leave || false,
  }));
}

async function saveSystemNotification(
  supabase: SupabaseClient,
  recipientId: string,
  recipientRole: string,
  eventType: string,
  title: string,
  body: string,
  relatedEntityId?: string,
  relatedEntityType?: string,
  metadata?: Record<string, unknown>
): Promise<void> {
  try {
    await supabase.from("system_notifications").insert({
      recipient_id: recipientId,
      recipient_role: recipientRole,
      event_type: eventType,
      title: title,
      body: body,
      related_entity_id: relatedEntityId,
      related_entity_type: relatedEntityType,
      metadata: metadata || {},
      priority: eventType.includes("urgent") ? "high" : "normal",
      push_status: "pending",
    });
  } catch (error) {
    console.error("Error saving system notification:", error);
  }
}

// ============================================
// EVENT HANDLERS
// ============================================

// Handle new message notifications
async function handleNewMessage(
  supabase: SupabaseClient,
  record: Record<string, unknown>
): Promise<NotificationResult> {
  const result: NotificationResult = { sent: 0, skipped: 0, errors: 0, details: [] };

  const conversationId = record.conversation_id as string;
  const senderId = record.sender_id as string;
  const senderName = (record.sender_name as string) || "Someone";
  const senderRole = (record.sender_role as string) || "user";
  const content = (record.content || record.message || "") as string;

  console.log(`📨 New message from ${senderName} (${senderRole}) in conversation ${conversationId}`);

  // Get all participants except sender
  const { data: participants, error } = await supabase
    .from("conversation_participants")
    .select("user_id, role, display_name, is_active")
    .eq("conversation_id", conversationId)
    .neq("user_id", senderId)
    .eq("is_active", true);

  if (error || !participants || participants.length === 0) {
    result.details.push("No participants to notify");
    return result;
  }

  for (const participant of participants) {
    const { token, name } = await getUserFCMToken(
      supabase,
      participant.user_id,
      participant.role
    );

    if (!token) {
      result.skipped++;
      result.details.push(`${participant.role} ${name} has no FCM token`);
      continue;
    }

    const sent = await sendFCMToToken(
      token,
      `New message from ${senderName}`,
      content.substring(0, 100),
      {
        priority: "high",
        data: {
          type: "chat_message",
          conversation_id: conversationId,
          sender_id: senderId,
          sender_role: senderRole,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      }
    );

    if (sent) {
      result.sent++;
      result.details.push(`Sent to ${participant.role} ${name}`);

      // Save to system_notifications for in-app display
      await saveSystemNotification(
        supabase,
        participant.user_id,
        participant.role,
        "chat_message",
        `Message from ${senderName}`,
        content.substring(0, 100),
        conversationId,
        "conversation",
        { sender_id: senderId, sender_role: senderRole }
      );
    } else {
      result.errors++;
      result.details.push(`Failed to send to ${participant.role} ${name}`);
    }
  }

  return result;
}

// Handle new booking notifications
async function handleNewBooking(
  supabase: SupabaseClient,
  record: Record<string, unknown>
): Promise<NotificationResult> {
  const result: NotificationResult = { sent: 0, skipped: 0, errors: 0, details: [] };

  const bookingId = record.booking_id as string;
  const clinicId = record.clinic_id as string;
  const patientId = record.patient_id as string;
  const status = record.status as string;

  // Only notify on new pending bookings
  if (status !== "pending") {
    result.details.push(`Booking status is ${status}, not pending`);
    return result;
  }

  console.log(`📅 New booking ${bookingId} for clinic ${clinicId}`);

  // Get patient name
  const { data: patient } = await supabase
    .from("patients")
    .select("firstname, lastname")
    .eq("patient_id", patientId)
    .single();

  const patientName = patient
    ? `${patient.firstname || ""} ${patient.lastname || ""}`.trim()
    : "A patient";

  // Get service name
  const serviceId = record.service_id as string;
  let serviceName = "a service";
  if (serviceId) {
    const { data: service } = await supabase
      .from("services")
      .select("service_name")
      .eq("service_id", serviceId)
      .single();
    if (service) serviceName = service.service_name;
  }

  // Notify all dentists in the clinic
  const dentists = await getClinicDentists(supabase, clinicId);
  for (const dentist of dentists) {
    if (!dentist.fcm_token) {
      result.skipped++;
      result.details.push(`Dentist ${dentist.name} has no FCM token`);
      continue;
    }

    const sent = await sendFCMToToken(
      dentist.fcm_token,
      "🦷 New Appointment Request",
      `${patientName} has booked ${serviceName}`,
      {
        priority: "high",
        data: {
          type: "new_booking",
          booking_id: bookingId,
          clinic_id: clinicId,
          patient_id: patientId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      }
    );

    if (sent) {
      result.sent++;
      result.details.push(`Sent to dentist ${dentist.name}`);

      await saveSystemNotification(
        supabase,
        dentist.dentist_id,
        "dentist",
        "new_booking",
        "New Appointment Request",
        `${patientName} has booked ${serviceName}`,
        bookingId,
        "booking",
        { patient_id: patientId }
      );
    } else {
      result.errors++;
    }
  }

  // Notify all staff in the clinic (if not on leave)
  const staffList = await getClinicStaff(supabase, clinicId);
  for (const staff of staffList) {
    if (staff.is_on_leave) {
      result.skipped++;
      result.details.push(`Staff ${staff.name} is on leave`);
      continue;
    }

    if (!staff.fcm_token) {
      result.skipped++;
      result.details.push(`Staff ${staff.name} has no FCM token`);
      continue;
    }

    const sent = await sendFCMToToken(
      staff.fcm_token,
      "📅 New Appointment Request",
      `${patientName} has booked ${serviceName}`,
      {
        priority: "normal",
        data: {
          type: "new_booking",
          booking_id: bookingId,
          clinic_id: clinicId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      }
    );

    if (sent) {
      result.sent++;
      result.details.push(`Sent to staff ${staff.name}`);

      await saveSystemNotification(
        supabase,
        staff.staff_id,
        "staff",
        "new_booking",
        "New Appointment Request",
        `${patientName} has booked ${serviceName}`,
        bookingId,
        "booking"
      );
    } else {
      result.errors++;
    }
  }

  return result;
}

// Handle booking status change notifications
async function handleBookingStatusChange(
  supabase: SupabaseClient,
  record: Record<string, unknown>,
  oldRecord?: Record<string, unknown>
): Promise<NotificationResult> {
  const result: NotificationResult = { sent: 0, skipped: 0, errors: 0, details: [] };

  const bookingId = record.booking_id as string;
  const patientId = record.patient_id as string;
  const clinicId = record.clinic_id as string;
  const newStatus = record.status as string;
  const oldStatus = oldRecord?.status as string;

  // Only process if status actually changed
  if (!oldStatus || newStatus === oldStatus) {
    result.details.push("No status change detected");
    return result;
  }

  console.log(`📋 Booking ${bookingId} status changed: ${oldStatus} → ${newStatus}`);

  // Get clinic name
  const { data: clinic } = await supabase
    .from("clinics")
    .select("clinic_name")
    .eq("clinic_id", clinicId)
    .single();

  const clinicName = clinic?.clinic_name || "The clinic";

  // Get patient FCM token
  const { token: patientToken, name: patientName } = await getUserFCMToken(
    supabase,
    patientId,
    "patient"
  );

  let title: string;
  let body: string;
  let eventType: NotificationType;

  switch (newStatus) {
    case "approved":
      title = "✅ Appointment Confirmed!";
      body = `${clinicName} has approved your appointment`;
      eventType = "booking_approved";
      break;
    case "rejected":
      title = "❌ Appointment Declined";
      body = `${clinicName} was unable to accommodate your appointment`;
      eventType = "booking_rejected";
      break;
    case "cancelled":
      title = "🚫 Appointment Cancelled";
      body = `Your appointment at ${clinicName} has been cancelled`;
      eventType = "booking_cancelled";
      break;
    case "completed":
      title = "✨ Appointment Completed";
      body = `Thank you for visiting ${clinicName}!`;
      eventType = "booking_completed";
      break;
    default:
      result.details.push(`Unknown status: ${newStatus}`);
      return result;
  }

  // Send to patient
  if (patientToken) {
    const sent = await sendFCMToToken(patientToken, title, body, {
      priority: "high",
      data: {
        type: eventType,
        booking_id: bookingId,
        clinic_id: clinicId,
        status: newStatus,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    });

    if (sent) {
      result.sent++;
      result.details.push(`Sent to patient ${patientName}`);

      await saveSystemNotification(
        supabase,
        patientId,
        "patient",
        eventType,
        title,
        body,
        bookingId,
        "booking",
        { clinic_id: clinicId, status: newStatus }
      );
    } else {
      result.errors++;
    }
  } else {
    result.skipped++;
    result.details.push(`Patient ${patientName} has no FCM token`);
  }

  return result;
}

// Handle clinic status change notifications
async function handleClinicStatusChange(
  supabase: SupabaseClient,
  record: Record<string, unknown>,
  oldRecord?: Record<string, unknown>
): Promise<NotificationResult> {
  const result: NotificationResult = { sent: 0, skipped: 0, errors: 0, details: [] };

  const clinicId = record.clinic_id as string;
  const clinicName = (record.clinic_name as string) || "Your clinic";
  const newStatus = record.status as string;
  const oldStatus = oldRecord?.status as string;

  // Only process if status actually changed
  if (!oldStatus || newStatus === oldStatus) {
    result.details.push("No status change detected");
    return result;
  }

  console.log(`🏥 Clinic ${clinicName} status changed: ${oldStatus} → ${newStatus}`);

  // Get all dentists for this clinic
  const dentists = await getClinicDentists(supabase, clinicId);

  let title: string;
  let body: string;
  let eventType: NotificationType;

  switch (newStatus) {
    case "approved":
      title = "🎉 Clinic Approved!";
      body = `Congratulations! ${clinicName} has been approved and is now live on DentEase!`;
      eventType = "clinic_approved";
      break;
    case "rejected":
      const rejectionReason = (record.rejection_reason as string) || "Please review the requirements";
      title = "❌ Clinic Application Declined";
      body = `Your application for ${clinicName} was declined. Reason: ${rejectionReason.substring(0, 80)}`;
      eventType = "clinic_rejected";
      break;
    case "pending":
      // This might be a resubmission
      if (oldStatus === "rejected") {
        title = "📝 Application Resubmitted";
        body = `Your application for ${clinicName} has been resubmitted for review`;
        eventType = "clinic_resubmission";
      } else {
        result.details.push("Status changed to pending, no notification sent");
        return result;
      }
      break;
    default:
      result.details.push(`Unknown clinic status: ${newStatus}`);
      return result;
  }

  // Notify all dentists of this clinic
  for (const dentist of dentists) {
    if (!dentist.fcm_token) {
      result.skipped++;
      result.details.push(`Dentist ${dentist.name} has no FCM token`);
      continue;
    }

    const sent = await sendFCMToToken(dentist.fcm_token, title, body, {
      priority: "high",
      data: {
        type: eventType,
        clinic_id: clinicId,
        status: newStatus,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    });

    if (sent) {
      result.sent++;
      result.details.push(`Sent to dentist ${dentist.name}`);

      await saveSystemNotification(
        supabase,
        dentist.dentist_id,
        "dentist",
        eventType,
        title,
        body,
        clinicId,
        "clinic",
        { status: newStatus }
      );
    } else {
      result.errors++;
    }
  }

  return result;
}

// Handle new clinic registration (notify admin)
async function handleNewClinicRegistration(
  supabase: SupabaseClient,
  record: Record<string, unknown>
): Promise<NotificationResult> {
  const result: NotificationResult = { sent: 0, skipped: 0, errors: 0, details: [] };

  const clinicId = record.clinic_id as string;
  const clinicName = (record.clinic_name as string) || "A new clinic";
  const status = record.status as string;

  // Only notify on new pending clinics
  if (status !== "pending") {
    result.details.push(`Clinic status is ${status}, not pending`);
    return result;
  }

  console.log(`🏥 New clinic registration: ${clinicName}`);

  // Send to admin topic
  const sent = await sendFCMToTopic(
    "admin_alerts",
    "🏥 New Clinic Registration",
    `${clinicName} has applied to join DentEase`,
    {
      data: {
        type: "clinic_registered",
        clinic_id: clinicId,
        clinic_name: clinicName,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    }
  );

  if (sent) {
    result.sent++;
    result.details.push("Sent to admin_alerts topic");
  } else {
    result.errors++;
    result.details.push("Failed to send to admin topic");
  }

  return result;
}

// Handle bill created notification
async function handleBillCreated(
  supabase: SupabaseClient,
  record: Record<string, unknown>
): Promise<NotificationResult> {
  const result: NotificationResult = { sent: 0, skipped: 0, errors: 0, details: [] };

  const billId = record.bill_id as string;
  const patientId = record.patient_id as string;
  const clinicId = record.clinic_id as string;
  const totalAmount = record.total_amount as number;

  console.log(`💰 Bill created: ${billId} for patient ${patientId}`);

  // Get clinic name
  const { data: clinic } = await supabase
    .from("clinics")
    .select("clinic_name")
    .eq("clinic_id", clinicId)
    .single();

  const clinicName = clinic?.clinic_name || "The clinic";

  // Get patient FCM token
  const { token, name } = await getUserFCMToken(supabase, patientId, "patient");

  if (!token) {
    result.skipped++;
    result.details.push(`Patient ${name} has no FCM token`);
    return result;
  }

  const formattedAmount = new Intl.NumberFormat("en-PH", {
    style: "currency",
    currency: "PHP",
  }).format(totalAmount);

  const sent = await sendFCMToToken(
    token,
    "💳 Billing Summary",
    `Your bill from ${clinicName} is ready: ${formattedAmount}`,
    {
      priority: "normal",
      data: {
        type: "bill_created",
        bill_id: billId,
        clinic_id: clinicId,
        amount: String(totalAmount),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    }
  );

  if (sent) {
    result.sent++;
    result.details.push(`Sent to patient ${name}`);

    await saveSystemNotification(
      supabase,
      patientId,
      "patient",
      "bill_created",
      "Billing Summary",
      `Your bill from ${clinicName} is ready: ${formattedAmount}`,
      billId,
      "bill",
      { clinic_id: clinicId, amount: totalAmount }
    );
  } else {
    result.errors++;
  }

  return result;
}

// ============================================
// MAIN REQUEST HANDLER
// ============================================

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Initialize Supabase admin client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse request body
    const payload = await req.json();

    console.log("\n🔔 ========================================");
    console.log("Push Notification Handler Triggered");
    console.log("========================================");

    let result: NotificationResult = { sent: 0, skipped: 0, errors: 0, details: [] };

    // Check if this is a webhook payload or direct API call
    if (payload.type && payload.table && payload.record) {
      // Database Webhook Payload
      const webhookPayload = payload as WebhookPayload;
      const { type, table, record, old_record } = webhookPayload;

      console.log(`📡 Webhook: ${type} on ${table}`);

      // Route based on table and event type
      switch (table) {
        case "messages":
          if (type === "INSERT") {
            result = await handleNewMessage(supabase, record);
          }
          break;

        case "bookings":
          if (type === "INSERT") {
            result = await handleNewBooking(supabase, record);
          } else if (type === "UPDATE") {
            result = await handleBookingStatusChange(supabase, record, old_record);
          }
          break;

        case "clinics":
          if (type === "INSERT") {
            result = await handleNewClinicRegistration(supabase, record);
          } else if (type === "UPDATE") {
            result = await handleClinicStatusChange(supabase, record, old_record);
          }
          break;

        case "bills":
          if (type === "INSERT") {
            result = await handleBillCreated(supabase, record);
          }
          break;

        default:
          result.details.push(`Unknown table: ${table}`);
      }
    } else if (payload.event_type) {
      // Direct API call with event_type
      const directPayload = payload as DirectNotificationPayload;
      console.log(`🎯 Direct call: ${directPayload.event_type}`);

      // Handle based on event_type
      switch (directPayload.event_type) {
        case "new_message":
          if (directPayload.data) {
            result = await handleNewMessage(supabase, directPayload.data);
          }
          break;

        case "new_booking":
          if (directPayload.data) {
            result = await handleNewBooking(supabase, directPayload.data);
          }
          break;

        default:
          // Generic notification to specific recipient
          if (directPayload.recipient_id && directPayload.recipient_role) {
            const { token, name } = await getUserFCMToken(
              supabase,
              directPayload.recipient_id,
              directPayload.recipient_role
            );

            if (token) {
              const sent = await sendFCMToToken(
                token,
                directPayload.title || "DentEase Notification",
                directPayload.body || "",
                {
                  priority: "high",
                  data: {
                    type: directPayload.event_type,
                    ...(directPayload.data as Record<string, string> || {}),
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                  },
                }
              );

              if (sent) {
                result.sent++;
                result.details.push(`Sent to ${directPayload.recipient_role} ${name}`);
              } else {
                result.errors++;
              }
            } else {
              result.skipped++;
              result.details.push(`${directPayload.recipient_role} has no FCM token`);
            }
          }

          // Send to admin topic if requested
          if (directPayload.send_to_admin) {
            const sent = await sendFCMToTopic(
              "admin_alerts",
              directPayload.title || "DentEase Admin Alert",
              directPayload.body || "",
              {
                data: {
                  type: directPayload.event_type,
                  ...(directPayload.data as Record<string, string> || {}),
                },
              }
            );

            if (sent) {
              result.sent++;
              result.details.push("Sent to admin_alerts topic");
            } else {
              result.errors++;
            }
          }
      }
    } else {
      result.details.push("Invalid payload format");
    }

    // Log results
    console.log("\n📊 Results:");
    console.log(`   Sent: ${result.sent}`);
    console.log(`   Skipped: ${result.skipped}`);
    console.log(`   Errors: ${result.errors}`);
    result.details.forEach((d) => console.log(`   - ${d}`));
    console.log("========================================\n");

    return new Response(
      JSON.stringify({
        success: true,
        ...result,
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
