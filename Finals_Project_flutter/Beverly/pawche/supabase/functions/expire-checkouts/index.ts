import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);
  const cronSecret = Deno.env.get("CHECKOUT_CLEANUP_SECRET");
  const paymongoSecret = Deno.env.get("PAYMONGO_SECRET_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!cronSecret || !paymongoSecret?.startsWith("sk_live_") || !supabaseUrl || !serviceRoleKey) {
    return json({ error: "Checkout cleanup is not configured." }, 500);
  }
  if (request.headers.get("Authorization") !== `Bearer ${cronSecret}`) {
    return json({ error: "Unauthorized." }, 401);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: orders, error: ordersError } = await admin.rpc(
    "stale_checkout_orders",
  );
  if (ordersError) return json({ error: "Could not load stale orders." }, 500);

  let expired = 0;
  for (const order of orders ?? []) {
    let providerExpired = order.session_id == null &&
      order.payment_intent_id == null;
    if (typeof order.payment_intent_id === "string") {
      let intentResponse: Response;
      try {
        intentResponse = await fetch(
          `https://api.paymongo.com/v1/payment_intents/${encodeURIComponent(order.payment_intent_id)}`,
          {
            headers: {
              Authorization: `Basic ${btoa(`${paymongoSecret}:`)}`,
              "Content-Type": "application/json",
            },
          },
        );
      } catch {
        return json({ error: "Could not reach PayMongo to check an expiring QR payment." }, 502);
      }
      let intentPayload: unknown;
      try {
        intentPayload = await intentResponse.json();
      } catch {
        return json({ error: "PayMongo returned an unreadable QR payment status." }, 502);
      }
      if (
        !intentResponse.ok ||
        !isRecord(intentPayload) ||
        !isRecord(intentPayload.data) ||
        !isRecord(intentPayload.data.attributes)
      ) {
        return json({ error: "Could not retrieve an expiring QR payment." }, 502);
      }
      let attributes = intentPayload.data.attributes;
      if (attributes.status === "succeeded") {
        if (
          attributes.livemode !== true ||
          typeof attributes.amount !== "number"
        ) {
          return json({ error: "PayMongo returned an invalid paid QR payment." }, 400);
        }
        const { data: paid, error: paidError } = await admin.rpc(
          "mark_qrph_intent_paid",
          {
            p_order_id: order.order_id,
            p_payment_intent_id: order.payment_intent_id,
            p_is_live: attributes.livemode,
            p_paid_amount: attributes.amount,
          },
        );
        if (paidError || paid !== true) {
          return json({ error: "Could not safely confirm the paid QR order." }, 500);
        }
        continue;
      }
      if (attributes.status !== "canceled") {
        let cancelResponse: Response;
        try {
          cancelResponse = await fetch(
            `https://api.paymongo.com/v1/payment_intents/${encodeURIComponent(order.payment_intent_id)}/cancel`,
            {
              method: "POST",
              headers: {
                Authorization: `Basic ${btoa(`${paymongoSecret}:`)}`,
                "Content-Type": "application/json",
              },
            },
          );
        } catch {
          return json({ error: "Could not cancel an expired QR payment with PayMongo." }, 502);
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
            isRecord(cancelledPayload.data.attributes)
          ) {
            attributes = cancelledPayload.data.attributes;
          }
        } else {
          let latestResponse: Response;
          try {
            latestResponse = await fetch(
              `https://api.paymongo.com/v1/payment_intents/${encodeURIComponent(order.payment_intent_id)}`,
              {
                headers: {
                  Authorization: `Basic ${btoa(`${paymongoSecret}:`)}`,
                  "Content-Type": "application/json",
                },
              },
            );
          } catch {
            return json({ error: "Could not verify final status of an expiring QR payment." }, 502);
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
            return json({ error: "Could not verify final status of an expiring QR payment." }, 502);
          }
          attributes = latestPayload.data.attributes;
        }
      }
      if (attributes.status === "succeeded") {
        if (
          attributes.livemode !== true ||
          typeof attributes.amount !== "number"
        ) {
          return json({ error: "PayMongo returned an invalid paid QR payment." }, 400);
        }
        const { data: paid, error: paidError } = await admin.rpc(
          "mark_qrph_intent_paid",
          {
            p_order_id: order.order_id,
            p_payment_intent_id: order.payment_intent_id,
            p_is_live: attributes.livemode,
            p_paid_amount: attributes.amount,
          },
        );
        if (paidError || paid !== true) {
          return json({ error: "Could not safely confirm the paid QR order." }, 500);
        }
        continue;
      }
      providerExpired = attributes.status === "canceled";
    } else if (typeof order.session_id === "string") {
      let expireResponse: Response;
      try {
        expireResponse = await fetch(
          `https://api.paymongo.com/v2/checkout_sessions/${encodeURIComponent(order.session_id)}/expire`,
          {
            method: "POST",
            headers: { Authorization: `Basic ${btoa(`${paymongoSecret}:`)}` },
          },
        );
      } catch {
        return json({ error: "Could not reach PayMongo to expire a checkout session." }, 502);
      }
      if (expireResponse.ok) {
        providerExpired = true;
      } else {
        let retrieveResponse: Response;
        try {
          retrieveResponse = await fetch(
            `https://api.paymongo.com/v2/checkout_sessions/${encodeURIComponent(order.session_id)}`,
            {
              headers: { Authorization: `Basic ${btoa(`${paymongoSecret}:`)}` },
            },
          );
        } catch {
          return json({ error: "Could not retrieve an expiring checkout session." }, 502);
        }
        let sessionPayload: unknown;
        try {
          sessionPayload = await retrieveResponse.json();
        } catch {
          return json({ error: "PayMongo returned an unreadable checkout status." }, 502);
        }
        if (retrieveResponse.ok && isRecord(sessionPayload)) {
          const session = sessionPayload.data;
          if (isRecord(session) && isRecord(session.attributes)) {
            providerExpired = session.attributes.status === "expired";
          }
        }
      }
    }
    if (!providerExpired) continue;

    const { data: released, error: releaseError } = await admin.rpc(
      typeof order.payment_intent_id === "string"
        ? "expire_qrph_intent_order"
        : "expire_checkout_order",
      {
        p_order_id: order.order_id,
        ...(typeof order.payment_intent_id === "string"
          ? { p_payment_intent_id: order.payment_intent_id }
          : { p_session_id: order.session_id }),
      },
    );
    if (releaseError) {
      return json({ error: "Could not release an expired order reservation." }, 500);
    }
    if (released === true) expired += 1;
  }

  return json({ expired });
});
