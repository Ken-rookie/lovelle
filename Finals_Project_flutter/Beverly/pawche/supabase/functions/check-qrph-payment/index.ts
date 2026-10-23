import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "Sign in to check this payment." }, 401);
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const paymongoSecret = Deno.env.get("PAYMONGO_SECRET_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !paymongoSecret?.startsWith("sk_live_")) {
    return json({ error: "QRPH payment checking is not fully configured." }, 503);
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser();
  if (authError || !authData.user) {
    return json({ error: "Your session expired. Sign in and try again." }, 401);
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid payment status request." }, 400);
  }
  if (!isRecord(body) || typeof body.order_id !== "string") {
    return json({ error: "A valid order ID is required." }, 400);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: order, error: orderError } = await admin
    .from("orders")
    .select(
      "id, reference_number, status, payment_status, payment_method, total_amount, paymongo_payment_intent_id, reservation_expires_at, created_at",
    )
    .eq("id", body.order_id)
    .eq("user_id", authData.user.id)
    .maybeSingle();
  if (orderError) {
    return json({ error: "Could not load this order's payment status." }, 500);
  }
  if (!order) {
    return json({ error: "No order was found for this account." }, 404);
  }
  if (order.payment_method !== "qrph") {
    return json({ error: "This order does not use QRPH." }, 400);
  }
  if (order.payment_status === "paid" || order.payment_status === "expired") {
    return json({
      order_id: order.id,
      status: order.status,
      payment_status: order.payment_status,
      expires_at: order.reservation_expires_at,
    });
  }
  if (typeof order.paymongo_payment_intent_id !== "string") {
    return json({ error: "The QRPH payment is still being prepared. Retry shortly." }, 409);
  }

  let intentResponse: Response;
  try {
    intentResponse = await fetch(
      `https://api.paymongo.com/v1/payment_intents/${encodeURIComponent(order.paymongo_payment_intent_id)}`,
      {
        headers: {
          Authorization: `Basic ${btoa(`${paymongoSecret}:`)}`,
          "Content-Type": "application/json",
        },
      },
    );
  } catch {
    return json({ error: "Could not reach PayMongo to check payment status." }, 502);
  }

  let intentPayload: unknown;
  try {
    intentPayload = await intentResponse.json();
  } catch {
    return json({ error: "PayMongo returned an unreadable payment status." }, 502);
  }
  if (!intentResponse.ok || !isRecord(intentPayload) || !isRecord(intentPayload.data)) {
    return json({ error: "PayMongo could not retrieve this payment intent." }, 502);
  }
  const intent = intentPayload.data;
  const attributes = intent.attributes;
  if (
    intent.id !== order.paymongo_payment_intent_id ||
    !isRecord(attributes) ||
    attributes.livemode !== true ||
    attributes.currency !== "PHP" ||
    attributes.amount !== Math.round(Number(order.total_amount) * 100)
  ) {
    return json({ error: "PayMongo payment details do not match this order." }, 409);
  }

  const markPaid = async () => {
    const { data: paid, error: paidError } = await admin.rpc(
      "mark_qrph_intent_paid",
      {
        p_order_id: order.id,
        p_payment_intent_id: order.paymongo_payment_intent_id,
        p_is_live: attributes.livemode,
        p_paid_amount: attributes.amount,
      },
    );
    if (paidError) {
      return json({ error: "Payment was received, but the order could not be updated. Contact support." }, 500);
    }
    if (paid !== true) {
      return json({ error: "The confirmed PayMongo payment did not match this order." }, 409);
    }
    return json({
      order_id: order.id,
      status: "confirmed",
      payment_status: "paid",
      expires_at: order.reservation_expires_at,
    });
  };

  if (attributes.status === "succeeded") {
    return await markPaid();
  }

  const expiresAt = typeof order.reservation_expires_at === "string"
    ? Date.parse(order.reservation_expires_at)
    : Date.parse(order.created_at) + 5 * 60 * 1000;
  if (!Number.isFinite(expiresAt)) {
    return json({ error: "This QR payment has no valid expiry time." }, 500);
  }
  if (Date.now() < expiresAt) {
    return json({
      order_id: order.id,
      status: order.status,
      payment_status: "awaiting_payment",
      expires_at: new Date(expiresAt).toISOString(),
    });
  }

  if (attributes.status !== "canceled") {
    let cancelResponse: Response;
    try {
      cancelResponse = await fetch(
        `https://api.paymongo.com/v1/payment_intents/${encodeURIComponent(order.paymongo_payment_intent_id)}/cancel`,
        {
          method: "POST",
          headers: {
            Authorization: `Basic ${btoa(`${paymongoSecret}:`)}`,
            "Content-Type": "application/json",
          },
        },
      );
    } catch {
      return json({ error: "QR expired, but PayMongo could not confirm cancellation. Keep this order open and retry." }, 502);
    }

    if (cancelResponse.ok) {
      let cancelledPayload: unknown;
      try {
        cancelledPayload = await cancelResponse.json();
      } catch {
        return json({ error: "PayMongo returned an unreadable cancellation result." }, 502);
      }
      if (
        isRecord(cancelledPayload) &&
        isRecord(cancelledPayload.data) &&
        isRecord(cancelledPayload.data.attributes) &&
        cancelledPayload.data.attributes.status === "succeeded"
      ) {
        return await markPaid();
      }
    } else {
      let latestResponse: Response;
      try {
        latestResponse = await fetch(
          `https://api.paymongo.com/v1/payment_intents/${encodeURIComponent(order.paymongo_payment_intent_id)}`,
          {
            headers: {
              Authorization: `Basic ${btoa(`${paymongoSecret}:`)}`,
              "Content-Type": "application/json",
            },
          },
        );
      } catch {
        return json({ error: "QR expired, but PayMongo could not confirm its final status. Retry shortly." }, 502);
      }
      let latestPayload: unknown;
      try {
        latestPayload = await latestResponse.json();
      } catch {
        return json({ error: "PayMongo returned an unreadable final payment status." }, 502);
      }
      if (
        !latestResponse.ok ||
        !isRecord(latestPayload) ||
        !isRecord(latestPayload.data) ||
        !isRecord(latestPayload.data.attributes)
      ) {
        return json({ error: "Could not confirm the final QRPH payment status." }, 502);
      }
      if (latestPayload.data.attributes.status === "succeeded") {
        return await markPaid();
      }
      if (latestPayload.data.attributes.status !== "canceled") {
        return json({ error: "PayMongo has not confirmed QR cancellation. Retry shortly." }, 502);
      }
    }
  }

  const { data: expired, error: expireError } = await admin.rpc(
    "expire_qrph_intent_order",
    {
      p_order_id: order.id,
      p_payment_intent_id: order.paymongo_payment_intent_id,
    },
  );
  if (expireError) {
    return json({ error: "Could not safely release the expired order reservation." }, 500);
  }
  if (expired !== true) {
    return json({ error: "Order status changed while the QR was expiring. Check again." }, 409);
  }
  return json({
    order_id: order.id,
    status: "cancelled",
    payment_status: "expired",
    expires_at: new Date(expiresAt).toISOString(),
  });
});
