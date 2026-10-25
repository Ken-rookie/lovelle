import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const qrExpirySeconds = 1800;

type PayMongoResponse = {
  data?: {
    id?: string;
    attributes?: Record<string, unknown>;
  };
  errors?: Array<{ detail?: string; code?: string }>;
};

function paymongoError(response: PayMongoResponse, status: number): Error {
  const detail = response.errors?.map((error) => error.detail ?? error.code).filter(Boolean).join("; ");
  return new Error(detail || `PayMongo request failed with status ${status}.`);
}

async function paymongoRequest(
  path: string,
  key: string,
  body?: Record<string, unknown>,
): Promise<PayMongoResponse> {
  const response = await fetch(`https://api.paymongo.com/v1${path}`, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${btoa(`${key}:`)}`,
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const result = await response.json() as PayMongoResponse;
  if (!response.ok) throw paymongoError(result, response.status);
  return result;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405, headers: cors });
  }

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const anon = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const secretKey = Deno.env.get("PAYMONGO_SECRET_KEY");
    const publicKey = Deno.env.get("PAYMONGO_PUBLIC_KEY");
    const mode = Deno.env.get("PAYMONGO_MODE");
    if (!url || !anon || !serviceKey) throw new Error("Supabase function environment is incomplete.");
    if (!secretKey || !publicKey || (mode !== "test" && mode !== "live")) {
      throw new Error("Configure PAYMONGO_SECRET_KEY, PAYMONGO_PUBLIC_KEY, and PAYMONGO_MODE.");
    }
    if (!secretKey.startsWith(mode === "test" ? "sk_test_" : "sk_live_") ||
      !publicKey.startsWith(mode === "test" ? "pk_test_" : "pk_live_")) {
      throw new Error(`PayMongo keys must match PAYMONGO_MODE=${mode}.`);
    }

    const authorization = req.headers.get("Authorization");
    if (!authorization) {
      return Response.json({ error: "Missing authorization" }, { status: 401, headers: cors });
    }

    const userClient = createClient(url, anon, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return Response.json({ error: "Unauthorized" }, { status: 401, headers: cors });
    }

    const body = await req.json();
    const orderId = String(body.order_id ?? "");
    if (!orderId) {
      return Response.json({ error: "Missing order_id" }, { status: 400, headers: cors });
    }

    const admin = createClient(url, serviceKey);
    const { data: order, error: orderError } = await admin
      .from("print_orders")
      .select("id,user_id,order_number,total,status,payment_status,payment_provider,payment_reference,qr_payload,qr_expires_at")
      .eq("id", orderId)
      .eq("user_id", user.id)
      .single();
    if (orderError || !order) {
      return Response.json({ error: "Order not found" }, { status: 404, headers: cors });
    }
    if (order.payment_status === "paid") {
      return Response.json({ error: "Order is already paid" }, { status: 409, headers: cors });
    }
    if (order.status === "cancelled" || order.status === "failed") {
      return Response.json({ error: "This order can no longer be paid." }, { status: 409, headers: cors });
    }

    const amount = Math.round(Number(order.total) * 100);
    if (!Number.isSafeInteger(amount) || amount < 100) {
      return Response.json({ error: "QRPh payments require an order total of at least PHP 1.00." }, { status: 400, headers: cors });
    }

    const qrExpiry = order.qr_expires_at ? new Date(order.qr_expires_at) : null;
    if (
      order.payment_provider === "paymongo" &&
      order.payment_status === "pending" &&
      order.payment_reference &&
      order.qr_payload &&
      qrExpiry &&
      qrExpiry.getTime() > Date.now()
    ) {
      return Response.json({
        payment_id: order.payment_reference,
        qr_code: order.qr_payload,
        expires_at: qrExpiry.toISOString(),
        order_number: order.order_number,
      }, { headers: cors });
    }

    const intent = await paymongoRequest("/payment_intents", secretKey, {
      data: {
        attributes: {
          amount,
          currency: "PHP",
          payment_method_allowed: ["qrph"],
          description: `Printify order ${order.order_number}`,
          metadata: {
            order_id: order.id,
            order_number: order.order_number,
            user_id: user.id,
          },
        },
      },
    });
    const intentId = intent.data?.id;
    const clientKey = intent.data?.attributes?.client_key;
    if (!intentId || typeof clientKey !== "string") {
      throw new Error("PayMongo did not return a Payment Intent and client key.");
    }

    const paymentMethod = await paymongoRequest("/payment_methods", publicKey, {
      data: {
        attributes: {
          type: "qrph",
          expiry_seconds: qrExpirySeconds,
        },
      },
    });
    const paymentMethodId = paymentMethod.data?.id;
    if (!paymentMethodId) throw new Error("PayMongo did not return a QRPh payment method.");

    const attached = await paymongoRequest(`/payment_intents/${intentId}/attach`, publicKey, {
      data: {
        attributes: {
          payment_method: paymentMethodId,
          client_key: clientKey,
        },
      },
    });
    const code = attached.data?.attributes?.next_action as
      | { code?: { image_url?: unknown } }
      | undefined;
    const qrImage = code?.code?.image_url;
    if (typeof qrImage !== "string" || !qrImage) {
      throw new Error("PayMongo did not return a QR image for this payment.");
    }

    const expiresAt = new Date(Date.now() + qrExpirySeconds * 1000).toISOString();
    const { error: updateError } = await admin
      .from("print_orders")
      .update({
        payment_provider: "paymongo",
        payment_status: "pending",
        payment_reference: intentId,
        qr_payload: qrImage,
        qr_expires_at: expiresAt,
        updated_at: new Date().toISOString(),
      })
      .eq("id", order.id)
      .eq("user_id", user.id);
    if (updateError) throw updateError;

    const { error: eventError } = await admin.from("order_status_events").insert({
      order_id: order.id,
      status: "awaiting_payment",
      message: "PayMongo QRPh payment created; waiting for payment confirmation.",
    });
    if (eventError) throw eventError;

    return Response.json({
      payment_id: intentId,
      qr_code: qrImage,
      expires_at: expiresAt,
      order_number: order.order_number,
    }, { headers: cors });
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : "Unable to create QRPh payment." },
      { status: 400, headers: cors },
    );
  }
});
