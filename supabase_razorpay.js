import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-razorpay-signature, x-razorpay-event-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function getEnv(name, fallbackNames = []) {
  const direct = Deno.env.get(name)?.trim();
  if (direct) return direct;
  for (const alt of fallbackNames) {
    const val = Deno.env.get(alt)?.trim();
    if (val) return val;
  }
  return "";
}

function requiredEnv(name, fallbackNames = []) {
  const value = getEnv(name, fallbackNames);
  if (!value) {
    const names = [name, ...fallbackNames].join(" or ");
    throw new Error(`Missing server configuration: ${names}`);
  }
  return value;
}

function razorpayCredentials() {
  const keyId = requiredEnv("RAZORPAY_KEY_ID", ["RAZORPAY_key_id", "RAZORPAY_KEY"]);
  const keySecret = requiredEnv("RAZORPAY_KEY_SECRET", [
    "RAZORPAY_SECRET",
    "RAZORPAY_secret",
    "RAZORPAY_key_secret",
  ]);

  if (!keyId.startsWith("rzp_test_")) {
    throw new Error("Razorpay Test Mode requires a key ID starting with rzp_test_.");
  }
  return { keyId, keySecret };
}

function razorpayAuthorization(keyId, keySecret) {
  return `Basic ${btoa(`${keyId}:${keySecret}`)}`;
}

async function authenticatedClient(request) {
  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    throw new Error("You must be signed in.");
  }
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    throw new Error("You must be signed in.");
  }

  const url = requiredEnv("SUPABASE_URL");
  const publicKey =
    Deno.env.get("SUPABASE_ANON_KEY")?.trim() ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY")?.trim() ??
    Deno.env.get("ANON_KEY")?.trim();

  if (!publicKey) {
    throw new Error("Missing server configuration: Supabase public/anon key.");
  }

  const client = createClient(url, publicKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await client.auth.getUser(token);
  if (error || !data?.user) {
    console.error("Auth session verification failed:", error?.message);
    throw new Error("Your session is invalid or expired. Please log in again.");
  }

  return { client, userId: data.user.id };
}

function serviceClient() {
  const url = requiredEnv("SUPABASE_URL");
  const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY", [
    "SERVICE_ROLE_KEY",
  ]);
  return createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function hmacSha256Hex(secret, message) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message),
  );
  return Array.from(new Uint8Array(signature), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

function constantTimeHexEquals(actual, expected) {
  if (
    !/^[a-fA-F0-9]{64}$/.test(actual) ||
    !/^[a-fA-F0-9]{64}$/.test(expected)
  ) {
    return false;
  }
  let difference = 0;
  for (let index = 0; index < expected.length; index++) {
    difference |= actual.toLowerCase().charCodeAt(index) ^
      expected.toLowerCase().charCodeAt(index);
  }
  return difference === 0;
}

function amountInPaise(rupees) {
  const amount = Math.round(Number(rupees) * 100);
  if (!Number.isSafeInteger(amount) || amount <= 0) {
    throw new Error("The order amount is invalid.");
  }
  return amount;
}

function validateCheckout(body) {
  if (
    !body || typeof body !== "object" ||
    !body.customer || typeof body.customer !== "object" ||
    !Array.isArray(body.items) || body.items.length === 0 ||
    body.items.length > 50
  ) {
    throw new Error("Delivery details and cart items are required.");
  }
}

async function cancelOrderReservation(client, orderId) {
  const { error } = await client.rpc("cancel_razorpay_order", {
    p_order_id: orderId,
  });
  if (error) {
    console.error("Could not release Razorpay order inventory:", error.message);
    return false;
  }
  return true;
}

async function placeCashOnDelivery(request, body) {
  const { client } = await authenticatedClient(request);
  validateCheckout(body);
  const couponCode = typeof body.coupon_code === "string" && body.coupon_code.trim() ? body.coupon_code.trim() : null;
  const { data, error } = await client.rpc("place_order", {
    p_customer: body.customer,
    p_items: body.items,
    p_payment_method: "cash_on_delivery",
    p_coupon_code: couponCode,
  });
  if (error) {
    console.error("place-order RPC failed:", error.message);
    return jsonResponse({ error: error.message }, 400);
  }
  if (typeof data !== "string") {
    throw new Error("The order service returned an invalid order ID.");
  }
  return jsonResponse({ success: true, order_id: data });
}

async function createRazorpayOrder(request, body) {
  const { client } = await authenticatedClient(request);
  const { keyId, keySecret } = razorpayCredentials();
  validateCheckout(body);
  const couponCode = typeof body.coupon_code === "string" && body.coupon_code.trim() ? body.coupon_code.trim() : null;

  const { data: orderId, error: orderError } = await client.rpc("place_order", {
    p_customer: body.customer,
    p_items: body.items,
    p_payment_method: "razorpay",
    p_coupon_code: couponCode,
  });
  if (orderError) {
    console.error("Razorpay order reservation failed:", orderError.message);
    return jsonResponse({ error: orderError.message }, 400);
  }
  if (typeof orderId !== "string") {
    throw new Error("The order service returned an invalid order ID.");
  }

  const { data: order, error: readError } = await client
    .from("orders")
    .select("id, total_price, payment_method, payment_status, status")
    .eq("id", orderId)
    .single();

  if (readError || !order) {
    console.error("Could not read reserved Razorpay order:", readError?.message);
    const cancelled = await cancelOrderReservation(client, orderId);
    return jsonResponse({
      error: cancelled
        ? "Could not read the order. Checkout was cancelled and inventory restored."
        : "Could not read or cancel the reserved order. Contact support.",
    }, 500);
  }

  if (
    order.payment_method !== "razorpay" ||
    order.payment_status !== "pending" ||
    order.status !== "pending"
  ) {
    const cancelled = await cancelOrderReservation(client, orderId);
    return jsonResponse({
      error: cancelled
        ? "The order is not awaiting payment. Checkout was cancelled and inventory restored."
        : "The order is not awaiting payment and could not be cancelled. Contact support.",
    }, 409);
  }

  let amount;
  try {
    amount = amountInPaise(order.total_price);
  } catch {
    const cancelled = await cancelOrderReservation(client, orderId);
    return jsonResponse({
      error: cancelled
        ? "The order amount is invalid. Checkout was cancelled and inventory restored."
        : "The order amount is invalid and checkout could not be cancelled. Contact support.",
    }, 400);
  }

  let providerResponse;
  try {
    providerResponse = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        Authorization: razorpayAuthorization(keyId, keySecret),
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount,
        currency: "INR",
        receipt: orderId,
        notes: { order_id: orderId },
      }),
    });
  } catch (error) {
    console.error("Could not reach Razorpay API:", error);
    const cancelled = await cancelOrderReservation(client, orderId);
    return jsonResponse({
      error: cancelled
        ? "Could not reach Razorpay. Checkout was cancelled and inventory restored."
        : "Could not reach Razorpay and checkout could not be cancelled. Contact support.",
    }, 502);
  }

  let providerData = {};
  try {
    const responseBody = await providerResponse.json();
    if (responseBody && typeof responseBody === "object") {
      providerData = responseBody;
    }
  } catch {
    console.error("Razorpay returned a non-JSON order response.");
  }

  if (
    !providerResponse.ok ||
    typeof providerData.id !== "string" ||
    providerData.amount !== amount ||
    providerData.currency !== "INR"
  ) {
    console.error("Razorpay order creation failed:", providerData);
    const cancelled = await cancelOrderReservation(client, orderId);
    const desc = providerData?.error?.description ?? "Razorpay could not start payment.";
    return jsonResponse({
      error: !cancelled
        ? `${desc} Order could not be automatically cancelled. Contact support.`
        : `${desc} The order was cancelled and inventory restored.`,
    }, 502);
  }

  const { error: attachError } = await client.rpc("attach_razorpay_order", {
    p_order_id: orderId,
    p_razorpay_order_id: providerData.id,
  });
  if (attachError) {
    console.error("Could not attach Razorpay order:", attachError.message);
    const cancelled = await cancelOrderReservation(client, orderId);
    return jsonResponse({
      error: !cancelled
        ? "Razorpay order could not be linked or cancelled. Contact support."
        : "Razorpay order could not be linked. Checkout was cancelled and inventory restored.",
    }, 500);
  }

  return jsonResponse({
    success: true,
    order_id: orderId,
    razorpay_order_id: providerData.id,
    amount,
    currency: "INR",
  });
}

async function verifyRazorpayPayment(request, body) {
  const { client, userId } = await authenticatedClient(request);
  const { keyId, keySecret } = razorpayCredentials();
  const orderId = typeof body?.order_id === "string" ? body.order_id : "";
  const razorpayOrderId = typeof body?.razorpay_order_id === "string"
    ? body.razorpay_order_id
    : "";
  const paymentId = typeof body?.razorpay_payment_id === "string"
    ? body.razorpay_payment_id
    : "";
  const signature = typeof body?.razorpay_signature === "string"
    ? body.razorpay_signature
    : "";

  if (!orderId || !razorpayOrderId || !paymentId || !signature) {
    return jsonResponse({ error: "Payment verification details are incomplete." }, 400);
  }

  const { data: order, error: orderError } = await client
    .from("orders")
    .select("id, user_id, total_price, payment_method, payment_status, status, razorpay_order_id")
    .eq("id", orderId)
    .eq("user_id", userId)
    .single();

  if (orderError || !order) {
    return jsonResponse({ error: "Order not found." }, 404);
  }
  if (
    order.payment_method !== "razorpay" ||
    order.razorpay_order_id !== razorpayOrderId
  ) {
    return jsonResponse({ error: "Payment does not match this order." }, 400);
  }

  // 1. Verify HMAC SHA-256 signature
  const expectedSignature = await hmacSha256Hex(
    keySecret,
    `${razorpayOrderId}|${paymentId}`,
  );
  if (!constantTimeHexEquals(signature, expectedSignature)) {
    return jsonResponse({ error: "Razorpay signature verification failed." }, 400);
  }

  // 2. Query payment status directly from Razorpay API
  const paymentResponse = await fetch(
    `https://api.razorpay.com/v1/payments/${encodeURIComponent(paymentId)}`,
    { headers: { Authorization: razorpayAuthorization(keyId, keySecret) } },
  );
  let payment = await paymentResponse.json();
  const expectedAmount = amountInPaise(order.total_price);

  if (!paymentResponse.ok) {
    console.error("Razorpay payment fetch error:", payment);
    return jsonResponse({
      error: payment?.error?.description ?? "Could not verify payment with Razorpay.",
    }, 400);
  }

  // 3. Auto-capture if payment is authorized but not yet captured (common in test mode / manual capture setups)
  if (payment.status === "authorized") {
    try {
      const captureResponse = await fetch(
        `https://api.razorpay.com/v1/payments/${encodeURIComponent(paymentId)}/capture`,
        {
          method: "POST",
          headers: {
            Authorization: razorpayAuthorization(keyId, keySecret),
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            amount: expectedAmount,
            currency: "INR",
          }),
        },
      );
      if (captureResponse.ok) {
        payment = await captureResponse.json();
      } else {
        const captureError = await captureResponse.json();
        console.error("Razorpay payment capture failed:", captureError);
      }
    } catch (err) {
      console.error("Error attempting Razorpay auto-capture:", err);
    }
  }

  // 4. Validate payment matches order parameters
  if (
    payment.order_id !== razorpayOrderId ||
    payment.status !== "captured" ||
    payment.amount !== expectedAmount ||
    payment.currency !== "INR"
  ) {
    console.error("Razorpay payment did not match order:", payment);
    return jsonResponse({
      error: payment.status !== "captured"
        ? `Payment status is '${payment.status}'. Expected 'captured'.`
        : "Razorpay payment details do not match this order.",
    }, 400);
  }

  return confirmPayment({
    eventId: `checkout:${paymentId}`,
    orderId,
    razorpayOrderId,
    paymentId,
    payment,
    eventType: "payment.verified",
  });
}

async function confirmPayment({
  eventId,
  orderId,
  razorpayOrderId,
  paymentId,
  payment,
  eventType,
}) {
  const admin = serviceClient();
  const { data, error } = await admin.rpc("verify_and_confirm_payment", {
    p_event_id: eventId,
    p_order_id: orderId,
    p_razorpay_order_id: razorpayOrderId,
    p_razorpay_payment_id: paymentId,
    p_amount: payment.amount,
    p_currency: payment.currency,
    p_event_type: eventType,
    p_payload: {
      payment_id: paymentId,
      order_id: razorpayOrderId,
      status: payment.status,
    },
  });

  if (error || data?.success !== true) {
    console.error("Atomic payment confirmation failed:", error?.message);
    return jsonResponse({
      error: error?.message ?? "Payment could not be confirmed. Contact support with the payment ID.",
    }, 500);
  }
  return jsonResponse({ success: true, order_id: orderId, status: "paid" });
}

async function handleRazorpayWebhook(request) {
  const rawBody = await request.text();
  const signature = request.headers.get("x-razorpay-signature") ?? "";
  const eventId = request.headers.get("x-razorpay-event-id") ?? "";
  if (!signature || !eventId) {
    return jsonResponse({ error: "Webhook signature or event ID is missing." }, 400);
  }

  const webhookSecret = getEnv("RAZORPAY_WEBHOOK_SECRET", ["WEBHOOK_SECRET"]);
  if (!webhookSecret) {
    console.warn("RAZORPAY_WEBHOOK_SECRET is not configured on server.");
    return jsonResponse({ error: "Webhook is not configured." }, 500);
  }

  const expectedSignature = await hmacSha256Hex(webhookSecret, rawBody);
  if (!constantTimeHexEquals(signature, expectedSignature)) {
    return jsonResponse({ error: "Webhook signature is invalid." }, 400);
  }

  const event = JSON.parse(rawBody);
  if (event?.event !== "payment.captured") {
    return jsonResponse({ success: true, ignored: true });
  }
  const payment = event?.payload?.payment?.entity;
  if (
    !payment ||
    payment.status !== "captured" ||
    typeof payment.order_id !== "string" ||
    typeof payment.id !== "string" ||
    payment.currency !== "INR" ||
    !Number.isSafeInteger(payment.amount)
  ) {
    return jsonResponse({ error: "Captured-payment webhook payload is invalid." }, 400);
  }

  const admin = serviceClient();
  const { data: order, error } = await admin
    .from("orders")
    .select("id, total_price, razorpay_order_id, payment_method")
    .eq("razorpay_order_id", payment.order_id)
    .single();

  if (error || !order || order.payment_method !== "razorpay") {
    return jsonResponse({ error: "Razorpay order was not found." }, 404);
  }
  if (payment.amount !== amountInPaise(order.total_price)) {
    return jsonResponse({ error: "Webhook amount does not match this order." }, 400);
  }

  return confirmPayment({
    eventId,
    orderId: order.id,
    razorpayOrderId: payment.order_id,
    paymentId: payment.id,
    payment,
    eventType: event.event,
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    if (
      request.headers.has("x-razorpay-signature") ||
      request.headers.has("x-razorpay-event-id")
    ) {
      return await handleRazorpayWebhook(request);
    }

    const body = await request.json();
    switch (body?.action) {
      case "place-order":
        return await placeCashOnDelivery(request, body);
      case "create-razorpay-order":
        return await createRazorpayOrder(request, body);
      case "verify-razorpay-payment":
        return await verifyRazorpayPayment(request, body);
      default:
        return jsonResponse({ error: "Unknown payment action." }, 400);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Payment request failed.";
    console.error("supabase-razorpay error:", message);
    return jsonResponse({ error: message }, 400);
  }
});
