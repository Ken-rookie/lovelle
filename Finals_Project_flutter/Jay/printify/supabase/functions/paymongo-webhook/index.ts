import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, paymongo-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function constantTimeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let i = 0; i < left.length; i++) {
    difference |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return difference === 0;
}

async function verifySignature(
  rawBody: string,
  signatureHeader: string | null,
  secret: string,
  mode: string,
): Promise<boolean> {
  if (!signatureHeader) return false;
  const fields = Object.fromEntries(
    signatureHeader.split(",").map((part) => {
      const separator = part.indexOf("=");
      return separator < 0
        ? [part.trim(), ""]
        : [part.slice(0, separator).trim(), part.slice(separator + 1).trim()];
    }),
  );
  const timestamp = fields.t;
  const signature = mode === "test" ? fields.te : fields.li;
  if (!timestamp || !signature) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${timestamp}.${rawBody}`),
  );
  const expected = Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return constantTimeEqual(expected, signature.toLowerCase());
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405, headers: cors });
  }

  try {
    const webhookSecret = Deno.env.get("PAYMONGO_WEBHOOK_SECRET");
    const secretKey = Deno.env.get("PAYMONGO_SECRET_KEY");
    const mode = Deno.env.get("PAYMONGO_MODE");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!webhookSecret || !secretKey || !supabaseUrl || !serviceKey) {
      throw new Error("Webhook function environment is incomplete.");
    }
    if (mode !== "test" && mode !== "live") {
      throw new Error("PAYMONGO_MODE must be test or live.");
    }

    const rawBody = await req.text();
    const signatureIsValid = await verifySignature(
      rawBody,
      req.headers.get("Paymongo-Signature"),
      webhookSecret,
      mode,
    );
    if (!signatureIsValid) {
      return Response.json({ error: "Invalid webhook signature" }, { status: 401, headers: cors });
    }

    const event = JSON.parse(rawBody);
    const eventAttributes = event?.data?.attributes;
    const eventType = eventAttributes?.type;
    const payment = eventAttributes?.data;
    if (!["payment.paid", "payment.failed", "qrph.expired"].includes(eventType)) {
      return Response.json({ received: true, ignored: true }, { headers: cors });
    }

    const paymentIntentId =
      payment?.attributes?.payment_intent_id ??
      payment?.attributes?.payment_intent?.id ??
      (typeof payment?.id === "string" && payment.id.startsWith("pi_") ? payment.id : null);
    if (typeof paymentIntentId !== "string" || !paymentIntentId) {
      return Response.json({ error: "Event has no Payment Intent reference" }, { status: 400, headers: cors });
    }

    const intentResponse = await fetch(
      `https://api.paymongo.com/v1/payment_intents/${encodeURIComponent(paymentIntentId)}`,
      {
        headers: {
          "Authorization": `Basic ${btoa(`${secretKey}:`)}`,
          "Accept": "application/json",
        },
      },
    );
    const intentBody = await intentResponse.json();
    if (!intentResponse.ok) {
      return Response.json({ error: "Could not verify payment with PayMongo" }, { status: 502, headers: cors });
    }
    const intent = intentBody?.data;
    const intentStatus = intent?.attributes?.status;
    const orderId = intent?.attributes?.metadata?.order_id;
    if (!orderId) {
      return Response.json({ error: "Payment Intent has no order metadata" }, { status: 400, headers: cors });
    }

    let nextPaymentStatus: "paid" | "failed" | "expired";
    if (eventType === "payment.paid") {
      if (intentStatus !== "succeeded") {
        return Response.json({ error: "PayMongo has not confirmed this payment" }, { status: 409, headers: cors });
      }
      nextPaymentStatus = "paid";
    } else if (eventType === "qrph.expired") {
      nextPaymentStatus = "expired";
    } else {
      nextPaymentStatus = "failed";
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: order, error: orderError } = await admin
      .from("print_orders")
      .select("id,payment_status,payment_reference")
      .eq("id", orderId)
      .single();
    if (orderError || !order || order.payment_reference !== paymentIntentId) {
      return Response.json({ error: "Payment does not match an order" }, { status: 404, headers: cors });
    }
    if (order.payment_status === "paid") {
      return Response.json({ received: true, payment_status: "paid" }, { headers: cors });
    }
    if (order.payment_status === nextPaymentStatus) {
      return Response.json(
        { received: true, payment_status: nextPaymentStatus },
        { headers: cors },
      );
    }

    const updates = nextPaymentStatus === "paid"
      ? { payment_status: "paid", status: "paid", updated_at: new Date().toISOString() }
      : { payment_status: nextPaymentStatus, updated_at: new Date().toISOString() };
    const { error: updateError } = await admin
      .from("print_orders")
      .update(updates)
      .eq("id", order.id)
      .neq("payment_status", "paid");
    if (updateError) throw updateError;

    const { error: eventError } = await admin.from("order_status_events").insert({
      order_id: order.id,
      status: nextPaymentStatus === "paid" ? "paid" : "awaiting_payment",
      message: `PayMongo QRPh payment ${nextPaymentStatus}.`,
    });
    if (eventError) throw eventError;

    return Response.json({ received: true, payment_status: nextPaymentStatus }, { headers: cors });
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : "Unable to process PayMongo webhook." },
      { status: 400, headers: cors },
    );
  }
});
