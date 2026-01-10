// Supabase Edge Function: notify_dentist
// Triggers when a new booking is inserted and sends FCM notification to the dentist

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Firebase Admin SDK for sending FCM notifications
import serviceAccount from "./service-account.json" assert { type: "json" };

interface BookingRecord {
  booking_id: string;
  patient_id: string;
  clinic_id: string;
  service_id: string;
  date: string;
  status: string;
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: BookingRecord;
  schema: string;
  old_record: BookingRecord | null;
}

// Get Firebase access token using service account
async function getFirebaseAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  // Encode JWT
  const encoder = new TextEncoder();
  const headerB64 = btoa(JSON.stringify(header));
  const payloadB64 = btoa(JSON.stringify(payload));
  const signatureInput = `${headerB64}.${payloadB64}`;

  // Import the private key
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

  // Exchange JWT for access token
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

// Send FCM notification using HTTP v1 API
async function sendFCMNotification(
  fcmToken: string,
  title: string,
  body: string
): Promise<boolean> {
  try {
    const accessToken = await getFirebaseAccessToken();
    const projectId = serviceAccount.project_id;

    const message = {
      message: {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channel_id: "fcm_default_channel",
          },
        },
        apns: {
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
      console.error("FCM Error:", errorText);
      return false;
    }

    console.log("Notification sent successfully");
    return true;
  } catch (error) {
    console.error("Error sending notification:", error);
    return false;
  }
}

serve(async (req) => {
  try {
    // Verify the request method
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Parse the webhook payload
    const payload: WebhookPayload = await req.json();
    console.log("Received webhook payload:", JSON.stringify(payload));

    // Only process INSERT events on bookings table
    if (payload.type !== "INSERT" || payload.table !== "bookings") {
      return new Response(
        JSON.stringify({ message: "Ignored: Not a booking insert" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const booking = payload.record;
    const clinicId = booking.clinic_id;

    if (!clinicId) {
      return new Response(
        JSON.stringify({ error: "No clinic_id in booking" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Step B: Query dentist FCM token by clinic_id
    const { data: dentists, error: dentistError } = await supabase
      .from("dentists")
      .select("fcm_token, firstname, lastname")
      .eq("clinic_id", clinicId);

    if (dentistError) {
      console.error("Error fetching dentist:", dentistError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch dentist" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!dentists || dentists.length === 0) {
      console.log("No dentists found for clinic:", clinicId);
      return new Response(
        JSON.stringify({ message: "No dentists found for this clinic" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Step C: Send notification to each dentist with a valid FCM token
    let notificationsSent = 0;

    for (const dentist of dentists) {
      const fcmToken = dentist.fcm_token;

      // Handle null token case
      if (!fcmToken) {
        console.log(
          `Dentist ${dentist.firstname} ${dentist.lastname} has no FCM token`
        );
        continue;
      }

      const success = await sendFCMNotification(
        fcmToken,
        "New Appointment Request",
        "A new patient has booked a service."
      );

      if (success) {
        notificationsSent++;
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Notifications sent to ${notificationsSent} dentist(s)`,
        booking_id: booking.booking_id,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
