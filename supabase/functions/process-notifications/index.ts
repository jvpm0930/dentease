// ============================================================
// UNIFIED NOTIFICATION ENGINE
// Part 4: Edge Function - Push Notification Processor
// Deploy with: supabase functions deploy process-notifications
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Import Firebase service account
import serviceAccount from "../process_notifications/service-account.json" assert { type: "json" };

// ============================================================
// TYPES
// ============================================================

interface SystemNotification {
    id: string;
    created_at: string;
    recipient_id: string;
    recipient_role: string;
    event_type: string;
    title: string;
    body: string;
    related_entity_id: string | null;
    related_entity_type: string | null;
    metadata: Record<string, unknown>;
    push_status: string;
    priority: string;
    escalated_from: string | null;
    escalation_reason: string | null;
}

interface WebhookPayload {
    type: "INSERT";
    table: "system_notifications";
    record: SystemNotification;
    schema: "public";
}

// ============================================================
// FIREBASE ACCESS TOKEN
// ============================================================

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

// ============================================================
// SEND FCM NOTIFICATION
// ============================================================

async function sendFCMNotification(
    fcmToken: string,
    title: string,
    body: string,
    data: Record<string, string>,
    priority: string
): Promise<{ success: boolean; error?: string }> {
    try {
        const accessToken = await getFirebaseAccessToken();
        const projectId = serviceAccount.project_id;

        // Map priority to FCM priority
        const androidPriority = priority === "urgent" || priority === "high" ? "high" : "normal";
        const apnsPriority = priority === "urgent" || priority === "high" ? "10" : "5";

        const message = {
            message: {
                token: fcmToken,
                notification: {
                    title: title,
                    body: body,
                },
                data: data,
                android: {
                    priority: androidPriority,
                    notification: {
                        sound: "default",
                        channel_id: "fcm_default_channel",
                        click_action: "FLUTTER_NOTIFICATION_CLICK",
                    },
                },
                apns: {
                    headers: {
                        "apns-priority": apnsPriority,
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
            return { success: false, error: errorText };
        }

        console.log(`✅ FCM sent to ${fcmToken.substring(0, 20)}...`);
        return { success: true };
    } catch (error) {
        console.error("FCM Exception:", error);
        return { success: false, error: String(error) };
    }
}

// ============================================================
// GET FCM TOKEN FOR USER
// ============================================================

async function getFCMToken(
    supabase: ReturnType<typeof createClient>,
    userId: string,
    userRole: string
): Promise<string | null> {
    let tableName: string;
    let idColumn: string;

    switch (userRole) {
        case "dentist":
            tableName = "dentists";
            idColumn = "dentist_id";
            break;
        case "staff":
            tableName = "staffs";
            idColumn = "staff_id";
            break;
        case "patient":
            tableName = "patients";
            idColumn = "patient_id";
            break;
        case "admin":
            // Admins use topic subscription
            return null;
        default:
            return null;
    }

    const { data, error } = await supabase
        .from(tableName)
        .select("fcm_token")
        .eq(idColumn, userId)
        .single();

    if (error || !data) {
        console.log(`No FCM token found for ${userRole} ${userId}`);
        return null;
    }

    return data.fcm_token as string | null;
}

// ============================================================
// UPDATE NOTIFICATION STATUS
// ============================================================

async function updateNotificationStatus(
    supabase: ReturnType<typeof createClient>,
    notificationId: string,
    status: "sent" | "failed" | "skipped",
    error?: string
): Promise<void> {
    const updateData: Record<string, unknown> = {
        push_status: status,
    };

    if (status === "sent") {
        updateData.push_sent_at = new Date().toISOString();
    }

    if (error) {
        updateData.push_error = error;
    }

    await supabase
        .from("system_notifications")
        .update(updateData)
        .eq("id", notificationId);
}

// ============================================================
// SEND TO ADMIN TOPIC
// ============================================================

async function sendAdminTopicNotification(
    title: string,
    body: string,
    data: Record<string, string>
): Promise<{ success: boolean; error?: string }> {
    try {
        const accessToken = await getFirebaseAccessToken();
        const projectId = serviceAccount.project_id;

        const message = {
            message: {
                topic: "admin_alerts",
                notification: {
                    title: title,
                    body: body,
                },
                data: data,
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
            console.error("FCM Topic Error:", errorText);
            return { success: false, error: errorText };
        }

        console.log("✅ Admin topic notification sent");
        return { success: true };
    } catch (error) {
        console.error("FCM Topic Exception:", error);
        return { success: false, error: String(error) };
    }
}

// ============================================================
// MAIN HANDLER
// ============================================================

serve(async (req) => {
    const corsHeaders = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    };

    // Handle CORS
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        // Initialize Supabase client
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        // Parse webhook payload
        const payload: WebhookPayload = await req.json();

        // Validate payload
        if (payload.type !== "INSERT" || payload.table !== "system_notifications") {
            console.log("Ignoring non-insert or non-notification event");
            return new Response(
                JSON.stringify({ success: true, message: "Event ignored" }),
                { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const notification = payload.record;
        console.log(`\n📬 Processing notification: ${notification.id}`);
        console.log(`   Type: ${notification.event_type}`);
        console.log(`   Recipient: ${notification.recipient_role} (${notification.recipient_id})`);
        console.log(`   Priority: ${notification.priority}`);

        // Skip if already processed
        if (notification.push_status !== "pending") {
            console.log("   ⏭️ Already processed, skipping");
            return new Response(
                JSON.stringify({ success: true, message: "Already processed" }),
                { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Build data payload for FCM
        const fcmData: Record<string, string> = {
            notification_id: notification.id,
            event_type: notification.event_type,
            recipient_role: notification.recipient_role,
        };

        if (notification.related_entity_id) {
            fcmData.related_entity_id = notification.related_entity_id;
        }
        if (notification.related_entity_type) {
            fcmData.related_entity_type = notification.related_entity_type;
        }

        // Handle admin notifications via topic
        if (notification.recipient_role === "admin") {
            const result = await sendAdminTopicNotification(
                notification.title,
                notification.body,
                fcmData
            );

            await updateNotificationStatus(
                supabase,
                notification.id,
                result.success ? "sent" : "failed",
                result.error
            );

            return new Response(
                JSON.stringify({
                    success: result.success,
                    notification_id: notification.id,
                    method: "topic",
                }),
                { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Get FCM token for the recipient
        const fcmToken = await getFCMToken(supabase, notification.recipient_id, notification.recipient_role);

        if (!fcmToken) {
            console.log("   ⏭️ No FCM token, skipping push");
            await updateNotificationStatus(supabase, notification.id, "skipped", "No FCM token");

            return new Response(
                JSON.stringify({
                    success: true,
                    notification_id: notification.id,
                    message: "Skipped - no FCM token",
                }),
                { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Send FCM notification
        const result = await sendFCMNotification(
            fcmToken,
            notification.title,
            notification.body,
            fcmData,
            notification.priority
        );

        // Update status
        await updateNotificationStatus(
            supabase,
            notification.id,
            result.success ? "sent" : "failed",
            result.error
        );

        console.log(`   ${result.success ? "✅" : "❌"} Push notification ${result.success ? "sent" : "failed"}`);

        return new Response(
            JSON.stringify({
                success: result.success,
                notification_id: notification.id,
                push_status: result.success ? "sent" : "failed",
                error: result.error,
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
