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

const paymongoRequest = (
  path: string,
  key: string,
  method: string,
  body?: unknown,
) =>
  fetch(`https://api.paymongo.com${path}`, {
    method,
    headers: {
      Authorization: `Basic ${btoa(`${key}:`)}`,
      "Content-Type": "application/json",
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });

const responseData = async (
  response: Response,
): Promise<Record<string, unknown> | null> => {
  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    return null;
  }
  return isRecord(payload) && isRecord(payload.data) ? payload.data : null;
};

const qrImage = (attributes: Record<string, unknown>) => {
  const nextAction = attributes.next_action;
  const code = isRecord(nextAction) ? nextAction.code : null;
  return isRecord(code) && typeof code.image_url === "string"
    ? code.image_url
    : null;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "Sign in before placing an order." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: "Checkout service is not fully configured." }, 500);
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
    return json({ error: "Invalid checkout request." }, 400);
  }
  if (!isRecord(body) || !Array.isArray(body.items) || !isRecord(body.delivery)) {
    return json({ error: "Invalid checkout request." }, 400);
  }

  const requestId = body.request_id;
  const paymentMethod = body.payment_method;
  if (
    typeof requestId !== "string" ||
    !/^[0-9a-f]{32}$/i.test(requestId) ||
    (paymentMethod !== "cod" && paymentMethod !== "qrph")
  ) {
    return json({ error: "Invalid checkout request." }, 400);
  }

  let paymongoSecret: string | undefined;
  let paymongoPublic: string | undefined;
  if (paymentMethod === "qrph") {
    paymongoSecret = Deno.env.get("PAYMONGO_SECRET_KEY");
    paymongoPublic = Deno.env.get("PAYMONGO_PUBLIC_KEY");
    if (!paymongoSecret?.startsWith("sk_live_")) {
      return json(
        { error: "Configure PAYMONGO_SECRET_KEY with the live secret key." },
        503,
      );
    }
    if (!paymongoPublic?.startsWith("pk_live_")) {
      return json(
        { error: "Configure PAYMONGO_PUBLIC_KEY with the live public key." },
        503,
      );
    }
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: created, error: createError } = await admin.rpc(
    "create_checkout_order",
    {
      p_user_id: authData.user.id,
      p_request_id: requestId,
      p_items: body.items,
      p_delivery: body.delivery,
      p_payment_method: paymentMethod,
    },
  );
  if (createError) {
    return json({ error: createError.message }, 409);
  }
  if (!isRecord(created)) {
    return json({ error: "Could not create the order." }, 500);
  }
  if (paymentMethod === "cod") return json(created);

  const orderId = created.order_id;
  const amount = Math.round(Number(created.total_amount) * 100);
  if (
    typeof orderId !== "string" ||
    !Number.isSafeInteger(amount) ||
    amount < 1
  ) {
    return json(
      { error: "The saved order is missing a valid server-confirmed total." },
      500,
    );
  }

  const { data: order, error: orderError } = await admin
    .from("orders")
    .select(
      "status, payment_status, paymongo_session_id, paymongo_payment_intent_id, checkout_creation_started_at, reservation_expires_at",
    )
    .eq("id", orderId)
    .eq("user_id", authData.user.id)
    .single();
  if (orderError) {
    return json({ error: "Could not load the saved order." }, 500);
  }
  if (order.paymongo_session_id) {
    return json(
      {
        error:
          "This order already has a hosted PayMongo checkout. Do not create a second payment.",
      },
      409,
    );
  }
  if (
    order.status !== "awaiting_payment" ||
    order.payment_status !== "awaiting_payment"
  ) {
    return json(
      { error: "This order is no longer awaiting payment. Check its order status before retrying." },
      409,
    );
  }

  const existingIntentId = order.paymongo_payment_intent_id;
  if (order.checkout_creation_started_at) {
    const started = Date.parse(order.checkout_creation_started_at);
    if (Number.isFinite(started) && Date.now() - started < 60_000) {
      return json(
        { error: "Your QR payment is being prepared. Wait a moment and retry." },
        409,
      );
    }
  }

  let claim = admin
    .from("orders")
    .update({ checkout_creation_started_at: new Date().toISOString() })
    .eq("id", orderId)
    .eq("payment_status", "awaiting_payment");
  if (typeof existingIntentId === "string") {
    claim = claim.eq("paymongo_payment_intent_id", existingIntentId);
  } else {
    claim = claim.is("paymongo_payment_intent_id", null);
  }
  if (order.checkout_creation_started_at) {
    const staleBefore = new Date(Date.now() - 60_000).toISOString();
    claim = claim.lte("checkout_creation_started_at", staleBefore);
  } else {
    claim = claim.is("checkout_creation_started_at", null);
  }
  const { data: claimed, error: claimError } = await claim
    .select("id")
    .maybeSingle();
  if (claimError) {
    return json({ error: "Could not prepare your QR payment." }, 500);
  }
  if (!claimed) {
    return json(
      { error: "Your QR payment is already being prepared. Retry in a moment." },
      409,
    );
  }

  let intentId = existingIntentId;
  let intentAttributes: Record<string, unknown> | null = null;
  if (typeof intentId === "string") {
    let intentResponse: Response;
    try {
      intentResponse = await paymongoRequest(
        `/v1/payment_intents/${encodeURIComponent(intentId)}`,
        paymongoSecret!,
        "GET",
      );
    } catch {
      return json(
        { error: "Could not reach PayMongo to retrieve your QR payment." },
        502,
      );
    }
    const intent = await responseData(intentResponse);
    if (
      !intentResponse.ok ||
      !intent ||
      !isRecord(intent.attributes) ||
      intent.attributes.livemode !== true
    ) {
      return json(
        { error: "PayMongo could not retrieve the saved live payment intent." },
        502,
      );
    }
    intentAttributes = intent.attributes;
    const imageUrl = qrImage(intentAttributes);
    if (typeof imageUrl === "string") {
      const qrExpiresAt = typeof order.reservation_expires_at === "string"
        ? Date.parse(order.reservation_expires_at)
        : Number.NaN;
      if (Number.isFinite(qrExpiresAt) && qrExpiresAt <= Date.now()) {
        return json(
          { error: "This QRPH code has expired. Do not pay it; place a new order." },
          409,
        );
      }
      const { error: unlockError } = await admin
        .from("orders")
        .update({ checkout_creation_started_at: null })
        .eq("id", orderId)
        .eq("paymongo_payment_intent_id", intentId);
      if (unlockError) {
        return json({ error: "Could not finish loading the QR payment." }, 500);
      }
      return json({
        ...created,
        checkout_url: null,
        paymongo_payment_intent_id: intentId,
        qr_image_url: imageUrl,
        expires_at: order.reservation_expires_at,
      });
    }
  } else {
    let intentResponse: Response;
    try {
      intentResponse = await paymongoRequest(
        "/v1/payment_intents",
        paymongoSecret!,
        "POST",
        {
          data: {
            attributes: {
              amount,
              currency: "PHP",
              payment_method_allowed: ["qrph"],
              description: `Pawche order ${created.reference_number}`,
              metadata: {
                order_id: orderId,
                reference_number: created.reference_number,
              },
            },
          },
        },
      );
    } catch {
      return json(
        { error: "Could not reach PayMongo to create the QR payment. Retry shortly." },
        502,
      );
    }
    const intent = await responseData(intentResponse);
    if (
      !intentResponse.ok ||
      !intent ||
      typeof intent.id !== "string" ||
      !isRecord(intent.attributes) ||
      intent.attributes.livemode !== true ||
      typeof intent.attributes.client_key !== "string"
    ) {
      return json(
        { error: "PayMongo could not create a live QRPH payment intent." },
        502,
      );
    }

    intentId = intent.id;
    intentAttributes = intent.attributes;
    const { error: saveIntentError } = await admin
      .from("orders")
      .update({ paymongo_payment_intent_id: intentId })
      .eq("id", orderId)
      .eq("payment_status", "awaiting_payment");
    if (saveIntentError) {
      return json(
        {
          error:
            "PayMongo created the payment intent, but the order could not save it. Contact support before retrying.",
        },
        500,
      );
    }
  }

  if (typeof intentId !== "string" || !intentAttributes) {
    return json({ error: "PayMongo returned an invalid payment intent." }, 502);
  }
  const clientKey = intentAttributes.client_key;
  if (typeof clientKey !== "string") {
    return json({ error: "PayMongo returned an invalid payment client key." }, 502);
  }

  const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
  const { error: setExpiryError } = await admin
    .from("orders")
    .update({ reservation_expires_at: expiresAt })
    .eq("id", orderId)
    .eq("paymongo_payment_intent_id", intentId);
  if (setExpiryError) {
    return json({ error: "Could not save the QR payment expiry time." }, 500);
  }

  let methodResponse: Response;
  try {
    methodResponse = await paymongoRequest(
      "/v1/payment_methods",
      paymongoPublic!,
      "POST",
      {
        data: {
          attributes: {
            type: "qrph",
            expiry_seconds: 300,
          },
        },
      },
    );
  } catch {
    return json(
      { error: "Could not reach PayMongo to generate your QR code. Retry shortly." },
      502,
    );
  }
  const paymentMethodData = await responseData(methodResponse);
  if (
    !methodResponse.ok ||
    !paymentMethodData ||
    typeof paymentMethodData.id !== "string"
  ) {
    return json(
      { error: "PayMongo could not generate a QRPH payment method." },
      502,
    );
  }

  let attachResponse: Response;
  try {
    attachResponse = await paymongoRequest(
      `/v1/payment_intents/${encodeURIComponent(intentId)}/attach`,
      paymongoPublic!,
      "POST",
      {
        data: {
          attributes: {
            payment_method: paymentMethodData.id,
            client_key: clientKey,
          },
        },
      },
    );
  } catch {
    return json(
      { error: "Could not reach PayMongo to attach your QRPH payment method." },
      502,
    );
  }

  const attached = await responseData(attachResponse);
  if (!attachResponse.ok || !attached || !isRecord(attached.attributes)) {
    return json(
      { error: "PayMongo could not attach the QRPH payment method." },
      502,
    );
  }
  const attachedAttributes = attached.attributes;
  const imageUrl = qrImage(attachedAttributes);
  if (
    attached.id !== intentId ||
    attachedAttributes.livemode !== true ||
    attachedAttributes.status !== "awaiting_next_action" ||
    typeof imageUrl !== "string"
  ) {
    return json(
      { error: "PayMongo did not return a valid live QRPH QR code." },
      502,
    );
  }

  const { error: finishError } = await admin
    .from("orders")
    .update({
      checkout_creation_started_at: null,
      reservation_expires_at: expiresAt,
    })
    .eq("id", orderId)
    .eq("paymongo_payment_intent_id", intentId);
  if (finishError) {
    return json(
      { error: "The QR is ready, but its order could not be finalized. Retry to reload it." },
      500,
    );
  }

  return json({
    ...created,
    checkout_url: null,
    paymongo_payment_intent_id: intentId,
    qr_image_url: imageUrl,
    expires_at: expiresAt,
  });
});
