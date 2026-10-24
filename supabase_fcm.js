import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function serviceClient() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SERVICE_ROLE_KEY") ??
    "";
  if (!url || !key) {
    throw new Error("Missing Supabase service role configuration.");
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/**
 * Sends FCM push notification if FIREBASE_SERVER_KEY is configured.
 * If not configured, notifications remain fully managed inside Supabase Realtime & DB tables.
 */
async function sendFcmNotification(fcmToken, title, body, data = {}) {
  const serverKey = Deno.env.get("FIREBASE_SERVER_KEY")?.trim();
  if (!serverKey) {
    // Graceful fallback: Pure Supabase mode (in-app notifications & realtime)
    return false;
  }

  try {
    const response = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        Authorization: `key=${serverKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        to: fcmToken,
        notification: {
          title,
          body,
          sound: "default",
        },
        data,
      }),
    });
    return response.ok;
  } catch (err) {
    console.error("FCM dispatch error:", err);
    return false;
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const admin = serviceClient();

    // 1. Fetch pending notifications from public.push_notification_logs
    const { data: logs, error: logsError } = await admin
      .from("push_notification_logs")
      .select("id, user_id, title, body, data")
      .eq("is_sent", false)
      .limit(50);

    if (logsError) throw logsError;
    if (!logs || logs.length === 0) {
      return jsonResponse({ success: true, processed: 0 });
    }

    const processedIds = [];

    for (const log of logs) {
      // Find active device tokens for recipient
      const { data: tokens } = await admin
        .from("user_fcm_tokens")
        .select("token")
        .eq("user_id", log.user_id);

      if (tokens && tokens.length > 0) {
        for (const { token } of tokens) {
          await sendFcmNotification(token, log.title, log.body, log.data);
        }
      }
      processedIds.push(log.id);
    }

    // Mark processed logs as sent
    if (processedIds.length > 0) {
      await admin
        .from("push_notification_logs")
        .update({ is_sent: true })
        .in("id", processedIds);
    }

    return jsonResponse({ success: true, processed: processedIds.length });
  } catch (error) {
    console.error("send-fcm error:", error);
    return jsonResponse({ error: error.message }, 500);
  }
});
