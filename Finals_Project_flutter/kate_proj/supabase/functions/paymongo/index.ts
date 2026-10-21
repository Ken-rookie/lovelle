import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonObject = Record<string, unknown>;

function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing server configuration: ${name}`);
  return value;
}

async function paymongoRequest(
  path: string,
  init: RequestInit = {},
  apiKey = requiredEnv("PAYMONGO_SECRET_KEY"),
) {
  const response = await fetch(`https://api.paymongo.com/v1${path}`, {
    ...init,
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      Authorization: `Basic ${btoa(`${apiKey}:`)}`,
      ...init.headers,
    },
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error("PayMongo request failed", response.status, body);
    throw new Error("PayMongo could not process the payment request.");
  }
  return body as JsonObject;
}

async function calculateCartAmount(
  admin: ReturnType<typeof createClient>,
  customerId: string,
  fulfillment: string,
  wrapping: boolean,
  greetingCard: boolean,
): Promise<number> {
  if (fulfillment !== "delivery" && fulfillment !== "pickup") {
    throw new Error("Invalid fulfillment selection.");
  }

  const { data: cart, error } = await admin
    .from("cart_items")
    .select("quantity, products(price, stock_quantity, is_available)")
    .eq("customer_id", customerId);
  if (error) throw new Error("Could not verify your cart.");
  if (!cart?.length) throw new Error("Your cart is empty.");

  let subtotalCents = 0;
  for (const row of cart) {
    const product = row.products as JsonObject | null;
    const quantity = Number(row.quantity);
    if (
      !product ||
      !Number.isInteger(quantity) ||
      quantity < 1 ||
      product.is_available !== true ||
      quantity > Number(product.stock_quantity)
    ) {
      throw new Error("A cart item is unavailable or out of stock.");
    }
    const catalogPrice = Number(product.price);
    if (!Number.isFinite(catalogPrice) || catalogPrice <= 0) {
      throw new Error("A cart item has an invalid price.");
    }
    subtotalCents += 100 * quantity;
  }

  return subtotalCents +
    (fulfillment === "delivery" ? 100 : 0) +
    (wrapping ? 100 : 0) +
    (greetingCard ? 100 : 0);
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const authorization = request.headers.get("Authorization");
    const token = authorization?.replace(/^Bearer\s+/i, "");
    if (!token) return jsonResponse({ error: "Authentication required." }, 401);

    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const anonKey = requiredEnv("SUPABASE_ANON_KEY");
    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await authClient.auth.getUser(token);
    if (authError || !authData.user) {
      return jsonResponse({ error: "Invalid or expired session." }, 401);
    }

    const admin = createClient(
      supabaseUrl,
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const body = await request.json() as JsonObject;
    const action = body.action;

    if (action === "create") {
      const fulfillment = String(body.fulfillment ?? "");
      const wrapping = body.wrapping === true;
      const greetingCard = body.greetingCard === true;
      const amount = await calculateCartAmount(
        admin,
        authData.user.id,
        fulfillment,
        wrapping,
        greetingCard,
      );
      const { data: succeeded, error: succeededError } = await admin
        .from("paymongo_payment_sessions")
        .select("payment_intent_id, amount, qr_code_url, expires_at, status")
        .eq("customer_id", authData.user.id)
        .eq("status", "succeeded")
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (succeededError) throw new Error("Could not check completed payments.");
      if (succeeded) {
        const intentResponse = await paymongoRequest(
          `/payment_intents/${encodeURIComponent(succeeded.payment_intent_id)}`,
        );
        const intent = intentResponse.data as JsonObject;
        const intentAttributes = intent.attributes as JsonObject;
        const verifiedStatus = String(intentAttributes.status ?? "unknown");

        if (verifiedStatus === "succeeded") {
          if (succeeded.amount !== amount) {
            return jsonResponse({
              error: "A payment has already succeeded, but its amount no longer matches your cart. Do not pay again; contact support to resolve the order.",
            }, 409);
          }
          return jsonResponse({
            paymentIntentId: succeeded.payment_intent_id,
            qrCodeUrl: succeeded.qr_code_url,
            expiresAt: succeeded.expires_at,
            status: verifiedStatus,
            amount: succeeded.amount,
          });
        }

        const { error: syncError } = await admin
          .from("paymongo_payment_sessions")
          .update({
            status: verifiedStatus,
            updated_at: new Date().toISOString(),
          })
          .eq("customer_id", authData.user.id)
          .eq("payment_intent_id", succeeded.payment_intent_id)
          .eq("status", "succeeded");
        if (syncError) throw new Error("Could not refresh the payment status.");

        if (verifiedStatus === "processing") {
          return jsonResponse({
            error: "Payment is still processing. Do not pay again; try again shortly.",
          }, 409);
        }

        const qrIsActive = [
          "awaiting_payment_method",
          "awaiting_next_action",
        ].includes(verifiedStatus) &&
          Date.parse(succeeded.expires_at) > Date.now();
        if (qrIsActive) {
          if (succeeded.amount !== amount) {
            return jsonResponse({
              error: "A payment is still active for a different amount. Finish or wait for it to expire before starting another.",
            }, 409);
          }
          return jsonResponse({
            paymentIntentId: succeeded.payment_intent_id,
            qrCodeUrl: succeeded.qr_code_url,
            expiresAt: succeeded.expires_at,
            status: verifiedStatus,
            amount: succeeded.amount,
          });
        }

        if (
          !["awaiting_payment_method", "awaiting_next_action", "failed", "canceled", "cancelled", "expired", "requires_payment_method"].includes(verifiedStatus)
        ) {
          return jsonResponse({
            error: "Could not confirm the previous payment is safe to retry. Do not pay again; try again shortly.",
          }, 409);
        }
      }

      const { data: active, error: activeError } = await admin
        .from("paymongo_payment_sessions")
        .select("payment_intent_id, amount, qr_code_url, expires_at, status")
        .eq("customer_id", authData.user.id)
        .in("status", ["awaiting_payment_method", "awaiting_next_action", "processing"])
        .not("payment_intent_id", "is", null)
        .gt("expires_at", new Date().toISOString())
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (activeError) throw new Error("Could not check active payments.");
      if (active) {
        if (active.amount !== amount) {
          return jsonResponse({
            error: "A payment is already in progress. Finish or wait for it to expire before starting another.",
          }, 409);
        }
        return jsonResponse({
          paymentIntentId: active.payment_intent_id,
          qrCodeUrl: active.qr_code_url,
          expiresAt: active.expires_at,
          status: active.status,
          amount: active.amount,
        });
      }

      const { count: recentSessionCount, error: rateLimitError } = await admin
        .from("paymongo_payment_sessions")
        .select("id", { count: "exact", head: true })
        .eq("customer_id", authData.user.id)
        .gt("created_at", new Date(Date.now() - 60_000).toISOString());
      if (rateLimitError) throw new Error("Could not validate payment request rate.");
      if ((recentSessionCount ?? 0) >= 3) {
        return jsonResponse({ error: "Too many QR payment attempts. Try again in a minute." }, 429);
      }

      const intentResponse = await paymongoRequest("/payment_intents", {
        method: "POST",
        headers: {
          "Idempotency-Key": `lovelle-${authData.user.id}-${crypto.randomUUID()}`,
        },
        body: JSON.stringify({
          data: {
            attributes: {
              amount,
              currency: "PHP",
              payment_method_allowed: ["qrph"],
              description: "Lovelle order payment",
              metadata: { customer_id: authData.user.id },
            },
          },
        }),
      });
      const intent = intentResponse.data as JsonObject;
      const intentAttributes = intent.attributes as JsonObject;
      const paymentIntentId = String(intent.id ?? "");
      const clientKey = String(intentAttributes.client_key ?? "");
      if (!paymentIntentId || !clientKey) {
        throw new Error("PayMongo did not return a payment intent.");
      }

      const publicKey = requiredEnv("PAYMONGO_PUBLIC_KEY");
      const methodResponse = await paymongoRequest("/payment_methods", {
        method: "POST",
        headers: { "Idempotency-Key": `lovelle-qrph-${paymentIntentId}` },
        body: JSON.stringify({
          data: {
            attributes: {
              type: "qrph",
              expiry_seconds: 300,
            },
          },
        }),
      }, publicKey);
      const paymentMethod = methodResponse.data as JsonObject;
      const paymentMethodId = String(paymentMethod.id ?? "");
      if (!paymentMethodId) {
        throw new Error("PayMongo did not return a QR payment method.");
      }

      const attachResponse = await paymongoRequest(
        `/payment_intents/${encodeURIComponent(paymentIntentId)}/attach`,
        {
          method: "POST",
          headers: { "Idempotency-Key": `lovelle-attach-${paymentIntentId}` },
          body: JSON.stringify({
            data: {
              attributes: {
                payment_method: paymentMethodId,
                client_key: clientKey,
              },
            },
          }),
        },
        publicKey,
      );
      const attachedIntent = attachResponse.data as JsonObject;
      const attributes = attachedIntent.attributes as JsonObject;
      const nextAction = attributes.next_action as JsonObject | null;
      const code = nextAction?.code as JsonObject | undefined;
      const qrCodeUrl = String(code?.image_url ?? "");
      if (!qrCodeUrl) throw new Error("PayMongo did not return a QR code.");
      const expiresAt = new Date(Date.now() + 5 * 60_000).toISOString();
      const status = String(attributes.status ?? "awaiting_next_action");

      const { error: insertError } = await admin
        .from("paymongo_payment_sessions")
        .insert({
          customer_id: authData.user.id,
          payment_intent_id: paymentIntentId,
          amount,
          qr_code_url: qrCodeUrl,
          status,
          expires_at: expiresAt,
        });
      if (insertError) throw new Error("Could not save the payment session.");

      return jsonResponse({
        paymentIntentId,
        qrCodeUrl,
        expiresAt,
        status,
        amount,
      });
    }

    if (action === "status") {
      const paymentIntentId = String(body.paymentIntentId ?? "");
      if (!paymentIntentId || paymentIntentId.length > 100) {
        return jsonResponse({ error: "Invalid payment reference." }, 400);
      }
      const { data: session, error: sessionError } = await admin
        .from("paymongo_payment_sessions")
        .select("payment_intent_id, amount, status, expires_at")
        .eq("customer_id", authData.user.id)
        .eq("payment_intent_id", paymentIntentId)
        .maybeSingle();
      if (sessionError || !session) {
        return jsonResponse({ error: "Payment session not found." }, 404);
      }

      const intentResponse = await paymongoRequest(
        `/payment_intents/${encodeURIComponent(paymentIntentId)}`,
      );
      const intent = intentResponse.data as JsonObject;
      const status = String((intent.attributes as JsonObject).status ?? "pending");
      await admin.from("paymongo_payment_sessions").update({
        status,
        updated_at: new Date().toISOString(),
      }).eq("payment_intent_id", paymentIntentId)
        .eq("customer_id", authData.user.id)
        .neq("status", "order_created");
      return jsonResponse({ status });
    }

    if (action === "finalize") {
      const paymentIntentId = String(body.paymentIntentId ?? "");
      if (!paymentIntentId || paymentIntentId.length > 100) {
        return jsonResponse({ error: "Invalid payment reference." }, 400);
      }

      const { data: session, error: sessionError } = await admin
        .from("paymongo_payment_sessions")
        .select("amount, status, expires_at")
        .eq("customer_id", authData.user.id)
        .eq("payment_intent_id", paymentIntentId)
        .maybeSingle();
      if (sessionError || !session) {
        return jsonResponse({ error: "Payment session not found." }, 404);
      }

      const intentResponse = await paymongoRequest(
        `/payment_intents/${encodeURIComponent(paymentIntentId)}`,
      );
      const intent = intentResponse.data as JsonObject;
      const attributes = intent.attributes as JsonObject;
      const metadata = attributes.metadata as JsonObject | null;
      if (
        attributes.status !== "succeeded" ||
        Number(attributes.amount) !== session.amount ||
        String(attributes.currency).toUpperCase() !== "PHP" ||
        metadata?.customer_id !== authData.user.id
      ) {
        return jsonResponse({ error: "Payment has not been verified." }, 409);
      }

      await admin.from("paymongo_payment_sessions").update({
        status: "succeeded",
        updated_at: new Date().toISOString(),
      }).eq("payment_intent_id", paymentIntentId)
        .eq("customer_id", authData.user.id)
        .neq("status", "order_created");

      const { data: order, error: orderError } = await admin.rpc(
        "finalize_paid_paymongo_order",
        {
          p_customer_id: authData.user.id,
          p_payment_intent_id: paymentIntentId,
          p_fulfillment: String(body.fulfillment ?? ""),
          p_recipient: String(body.recipient ?? "").trim(),
          p_phone: String(body.phone ?? "").trim(),
          p_address: String(body.address ?? "").trim(),
          p_wrapping: body.wrapping === true,
          p_greeting_card: body.greetingCard === true,
          p_greeting_message: String(body.greetingMessage ?? "").trim(),
          p_rose_types: body.roseTypes ?? {},
        },
      );
      if (orderError) {
        console.error("Order finalization failed", orderError.message);
        throw new Error("Payment succeeded, but the order could not be created. Contact support with payment reference: " + paymentIntentId);
      }
      return jsonResponse({ order: order as JsonObject });
    }

    return jsonResponse({ error: "Unknown payment action." }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Payment request failed.";
    console.error("PayMongo function error", message);
    return jsonResponse({ error: message }, 400);
  }
});