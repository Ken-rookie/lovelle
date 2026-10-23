import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  const secret = Deno.env.get("PAYMONGO_SECRET_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!secret?.startsWith("sk_live_") || !supabaseUrl || !serviceRoleKey) {
    return json({ error: "Webhook is not configured for live payments." }, 500);
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return json({ error: "Invalid webhook body." }, 400);
  }
  if (!isRecord(payload) || !isRecord(payload.data)) {
    return json({ error: "Invalid webhook body." }, 400);
  }

  const event = payload.data;
  const eventAttributes = isRecord(event.attributes) ? event.attributes : event;
  const eventType = eventAttributes.type;
  const resource = isRecord(eventAttributes.data)
    ? eventAttributes.data
    : isRecord(event.data)
      ? event.data
      : null;
  if (eventType !== "payment.paid" &&
    eventType !== "checkout_session.payment.paid") {
    return json({ received: true });
  }
  if (!resource || typeof resource.id !== "string") {
    return json({ error: "Webhook is missing its payment resource ID." }, 400);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  if (eventType === "payment.paid") {
    const paymentAttributes = resource.attributes;
    const paymentIntentId = isRecord(paymentAttributes)
      ? paymentAttributes.payment_intent_id
      : null;
    if (typeof paymentIntentId !== "string") {
      return json({ error: "Paid QRPH event is missing its payment intent ID." }, 400);
    }

    let intentResponse: Response;
    try {
      intentResponse = await fetch(
        `https://api.paymongo.com/v1/payment_intents/${encodeURIComponent(paymentIntentId)}`,
        {
          headers: {
            Authorization: `Basic ${btoa(`${secret}:`)}`,
            "Content-Type": "application/json",
          },
        },
      );
    } catch {
      return json({ error: "Could not reach PayMongo to verify the payment." }, 502);
    }

    let intentPayload: unknown;
    try {
      intentPayload = await intentResponse.json();
    } catch {
      return json({ error: "PayMongo returned an unreadable payment intent." }, 502);
    }
    if (
      !intentResponse.ok ||
      !isRecord(intentPayload) ||
      !isRecord(intentPayload.data) ||
      !isRecord(intentPayload.data.attributes)
    ) {
      return json({ error: "Could not verify the QRPH payment with PayMongo." }, 502);
    }
    const intent = intentPayload.data;
    const attributes = intent.attributes;
    const metadata = attributes.metadata;
    if (
      intent.id !== paymentIntentId ||
      attributes.status !== "succeeded" ||
      attributes.livemode !== true ||
      attributes.currency !== "PHP" ||
      typeof attributes.amount !== "number" ||
      !isRecord(metadata) ||
      typeof metadata.order_id !== "string"
    ) {
      return json({ error: "PayMongo returned an invalid live QRPH payment." }, 400);
    }

    const { data: order, error: orderError } = await admin
      .from("orders")
      .select("id")
      .eq("id", metadata.order_id)
      .eq("paymongo_payment_intent_id", paymentIntentId)
      .maybeSingle();
    if (orderError) {
      return json({ error: "Could not locate the matching QRPH order." }, 500);
    }
    if (!order) {
      return json({ error: "No order matches this payment intent." }, 404);
    }

    const { data: markedPaid, error: paymentError } = await admin.rpc(
      "mark_qrph_intent_paid",
      {
        p_order_id: order.id,
        p_payment_intent_id: paymentIntentId,
        p_is_live: attributes.livemode,
        p_paid_amount: attributes.amount,
      },
    );
    if (paymentError) {
      return json({ error: "Could not update QRPH payment status." }, 500);
    }
    if (markedPaid !== true) {
      return json({ error: "Payment did not match the saved order." }, 409);
    }
    return json({ received: true, paid: true });
  }

  let sessionResponse: Response;
  try {
    sessionResponse = await fetch(
      `https://api.paymongo.com/v2/checkout_sessions/${encodeURIComponent(resource.id)}`,
      {
        headers: { Authorization: `Basic ${btoa(`${secret}:`)}` },
      },
    );
  } catch {
    return json({ error: "Could not reach PayMongo to verify the checkout." }, 502);
  }
  let sessionPayload: unknown;
  try {
    sessionPayload = await sessionResponse.json();
  } catch {
    return json({ error: "PayMongo returned an unreadable checkout session." }, 502);
  }
  if (
    !sessionResponse.ok ||
    !isRecord(sessionPayload) ||
    !isRecord(sessionPayload.data) ||
    !isRecord(sessionPayload.data.attributes)
  ) {
    return json({ error: "Could not verify checkout with PayMongo." }, 502);
  }

  const session = sessionPayload.data;
  const attributes = session.attributes;
  const reference = attributes.reference_number;
  const payments = attributes.payments;
  if (
    attributes.livemode !== true ||
    typeof reference !== "string" ||
    !Array.isArray(payments)
  ) {
    return json({ error: "Checkout session is not a valid live payment." }, 400);
  }
  const paidPayment = payments.find((payment) =>
    isRecord(payment) &&
    isRecord(payment.attributes) &&
    payment.attributes.status === "paid"
  );
  if (!isRecord(paidPayment) || !isRecord(paidPayment.attributes)) {
    return json({ received: true, paid: false });
  }
  const paidAmount = paidPayment.attributes.amount;
  if (typeof paidAmount !== "number" || typeof session.id !== "string") {
    return json({ error: "Paid checkout is missing its amount or ID." }, 400);
  }

  const { data: order, error: orderError } = await admin
    .from("orders")
    .select("id")
    .eq("reference_number", reference)
    .maybeSingle();
  if (orderError) {
    return json({ error: "Could not locate the matching order." }, 500);
  }
  if (!order) return json({ error: "No order matches this checkout." }, 404);

  const { data: markedPaid, error: paymentError } = await admin.rpc(
    "mark_checkout_paid",
    {
      p_order_id: order.id,
      p_reference_number: reference,
      p_session_id: session.id,
      p_is_live: attributes.livemode,
      p_paid_amount: paidAmount,
    },
  );
  if (paymentError) {
    return json({ error: "Could not update payment status." }, 500);
  }
  if (markedPaid !== true) {
    return json({ error: "Payment did not match the saved order." }, 409);
  }
  return json({ received: true, paid: true });
});
