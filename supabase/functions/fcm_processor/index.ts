// Supabase Edge Function: fcm_processor
// Background processor for queued FCM notifications
// Should be called periodically via Supabase CRON or external scheduler
// Processes pending notifications from system_notifications table

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

// Import Firebase service account
import serviceAccount from "../process_notifications/service-account.json" with { type: "json" };

// ============================================
// CORS HEADERS
// ============================================

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ============================================
// TYPES
// ============================================

interface SystemNotification {
    id: string;
    recipient_id: string;
    recipient_role: string;
    event_type: string;
    title: string;
    body: string;
    related_entity_id: string | null;
    related_entity_type: string | null;
    metadata: Record<string, unknown>;
    priority: string;
    push_status: string;
    created_at: string;
}

interface ProcessingResult {
    processed: number;
    sent: number;
    skipped: number;
    errors: number;
    details: string[];
}

// ============================================
// FIREBASE ACCESS TOKEN (cached)
// ============================================

let cachedAccessToken: string | null = null;
let tokenExpiresAt = 0;

async function getFirebaseAccessToken(): Promise<string> {
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
    tokenExpiresAt = Date.now() + 3600000;

    return tokenData.access_token;
}

// ============================================
// FCM SENDERS
// ============================================

async function sendFCMToToken(
    fcmToken: string,
    title: string,
    body: string,
    data: Record<string, string>,
    priority: string = "high"
): Promise<boolean> {
    try {
        const accessToken = await getFirebaseAccessToken();
        const projectId = serviceAccount.project_id;

        const message = {
            message: {
                token: fcmToken,
                notification: { title, body },
                data: data,
                android: {
                    priority: priority,
                    notification: {
                        sound: "default",
                        channel_id: "fcm_default_channel",
                    },
                },
                apns: {
                    headers: { "apns-priority": priority === "high" ? "10" : "5" },
                    payload: { aps: { sound: "default", badge: 1 } },
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
            console.error(`FCM Error:`, errorText);
            return false;
        }

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
    data: Record<string, string>
): Promise<boolean> {
    try {
        const accessToken = await getFirebaseAccessToken();
        const projectId = serviceAccount.project_id;

        const message = {
            message: {
                topic: topic,
                notification: { title, body },
                data: data,
                android: {
                    priority: "high",
                    notification: { sound: "default", channel_id: "fcm_default_channel" },
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

        return true;
    } catch (error) {
        console.error("Error sending FCM to topic:", error);
        return false;
    }
}

// ============================================
// GET USER FCM TOKEN
// ============================================

async function getUserFCMToken(
    supabase: SupabaseClient,
    userId: string,
    role: string
): Promise<string | null> {
    const tableMap: Record<string, { table: string; idCol: string }> = {
        patient: { table: "patients", idCol: "patient_id" },
        dentist: { table: "dentists", idCol: "dentist_id" },
        staff: { table: "staffs", idCol: "staff_id" },
        admin: { table: "admins", idCol: "admin_id" },
    };

    const config = tableMap[role];
    if (!config) return null;

    // First try: Direct lookup by ID
    const { data, error } = await supabase
        .from(config.table)
        .select("fcm_token")
        .eq(config.idCol, userId)
        .maybeSingle();

    if (data?.fcm_token) {
        return data.fcm_token;
    }

    // Special handling for dentist role: The userId might actually be a clinic_id
    // This happens because the chat system uses clinic_id as the conversation participant
    // for dentists (so patients message the "clinic" and any dentist can respond)
    if (role === "dentist") {
        console.log(`Dentist not found by dentist_id, trying clinic_id lookup for: ${userId}`);

        // Try to find dentists by clinic_id and get the first one's FCM token
        const { data: clinicDentists, error: clinicError } = await supabase
            .from("dentists")
            .select("dentist_id, fcm_token")
            .eq("clinic_id", userId)
            .not("fcm_token", "is", null);

        if (!clinicError && clinicDentists && clinicDentists.length > 0) {
            // Return the first dentist's FCM token that has one
            const dentistWithToken = clinicDentists.find((d: { fcm_token: string | null }) => d.fcm_token);
            if (dentistWithToken) {
                console.log(`Found dentist via clinic_id: ${dentistWithToken.dentist_id}`);
                return dentistWithToken.fcm_token;
            }
        }
    }

    return null;
}

// ============================================
// PROCESS NOTIFICATIONS
// ============================================

async function processNotifications(
    supabase: SupabaseClient,
    batchSize: number = 50
): Promise<ProcessingResult> {
    const result: ProcessingResult = {
        processed: 0,
        sent: 0,
        skipped: 0,
        errors: 0,
        details: [],
    };

    // Fetch pending notifications
    const { data: notifications, error } = await supabase
        .from("system_notifications")
        .select("*")
        .eq("push_status", "pending")
        .order("created_at", { ascending: true })
        .limit(batchSize);

    if (error) {
        result.details.push(`Error fetching notifications: ${error.message}`);
        return result;
    }

    if (!notifications || notifications.length === 0) {
        result.details.push("No pending notifications");
        return result;
    }

    console.log(`📋 Processing ${notifications.length} pending notifications...`);

    for (const notification of notifications as SystemNotification[]) {
        result.processed++;

        try {
            let sent = false;
            const data: Record<string, string> = {
                type: notification.event_type,
                notification_id: notification.id,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            };

            // Add metadata to data payload
            if (notification.metadata) {
                Object.entries(notification.metadata).forEach(([key, value]) => {
                    if (typeof value === "string" || typeof value === "number") {
                        data[key] = String(value);
                    }
                });
            }

            if (notification.related_entity_id) {
                data.related_entity_id = notification.related_entity_id;
            }
            if (notification.related_entity_type) {
                data.related_entity_type = notification.related_entity_type;
            }

            // Handle admin notifications via topic
            if (notification.recipient_role === "admin") {
                sent = await sendFCMToTopic(
                    "admin_alerts",
                    notification.title,
                    notification.body || "",
                    data
                );
            } else {
                // Get user's FCM token
                const fcmToken = await getUserFCMToken(
                    supabase,
                    notification.recipient_id,
                    notification.recipient_role
                );

                if (!fcmToken) {
                    // No token - mark as skipped
                    await supabase
                        .from("system_notifications")
                        .update({
                            push_status: "skipped",
                            sent_at: new Date().toISOString(),
                        })
                        .eq("id", notification.id);

                    result.skipped++;
                    result.details.push(
                        `${notification.recipient_role} ${notification.recipient_id.substring(0, 8)}... has no FCM token`
                    );
                    continue;
                }

                // Send FCM notification
                sent = await sendFCMToToken(
                    fcmToken,
                    notification.title,
                    notification.body || "",
                    data,
                    notification.priority === "high" ? "high" : "normal"
                );
            }

            if (sent) {
                // Mark as sent
                await supabase
                    .from("system_notifications")
                    .update({
                        push_status: "sent",
                        sent_at: new Date().toISOString(),
                    })
                    .eq("id", notification.id);

                result.sent++;
                result.details.push(
                    `Sent ${notification.event_type} to ${notification.recipient_role}`
                );
            } else {
                // Mark as failed
                await supabase
                    .from("system_notifications")
                    .update({
                        push_status: "failed",
                    })
                    .eq("id", notification.id);

                result.errors++;
                result.details.push(
                    `Failed to send ${notification.event_type} to ${notification.recipient_role}`
                );
            }
        } catch (error) {
            // Mark as failed
            await supabase
                .from("system_notifications")
                .update({
                    push_status: "failed",
                })
                .eq("id", notification.id);

            result.errors++;
            result.details.push(`Error processing notification ${notification.id}: ${error}`);
        }
    }

    return result;
}

// ============================================
// MAIN HANDLER
// ============================================

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        console.log("\n🔄 ========================================");
        console.log("FCM Processor - Processing queued notifications");
        console.log("========================================");

        // Parse optional batch size from request
        let batchSize = 50;
        try {
            const body = await req.json();
            if (body.batch_size && typeof body.batch_size === "number") {
                batchSize = Math.min(body.batch_size, 100);
            }
        } catch {
            // No body or invalid JSON, use default
        }

        const result = await processNotifications(supabase, batchSize);

        console.log("\n📊 Processing Results:");
        console.log(`   Processed: ${result.processed}`);
        console.log(`   Sent: ${result.sent}`);
        console.log(`   Skipped: ${result.skipped}`);
        console.log(`   Errors: ${result.errors}`);
        console.log("========================================\n");

        return new Response(
            JSON.stringify({
                success: true,
                ...result,
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    } catch (error) {
        console.error("❌ FCM Processor error:", error);
        return new Response(
            JSON.stringify({ error: "Internal server error", details: String(error) }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
});
