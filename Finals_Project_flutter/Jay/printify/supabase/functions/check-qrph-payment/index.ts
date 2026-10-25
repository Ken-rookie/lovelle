import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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
    if (!url || !anon || !serviceKey || !secretKey) {
      throw new Error("Payment status function environment is incomplete.");
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
      .select("id,total,payment_status,payment_reference")
      .eq("id", orderId)
      .eq("user_id", user.id)
      .single();
    if (orderError || !order) {
      return Response.json({ error: "Order not found" }, { status: 404, headers: cors });
    }

    if (order.payment_status === "paid" || !order.payment_reference) {
      return Response.json({ payment_status: order.payment_status }, { headers: cors });
    }

    const intentResponse = await fetch(
      `https://api.paymongo.com/v1/payment_intents/${encodeURIComponent(order.payment_reference)}`,
      {
        headers: {
          "Authorization": `Basic ${btoa(`${secretKey}:`)}`,
          "Accept": "application/json",
        },
      },
    );
    const intentResult = await intentResponse.json();
    if (!intentResponse.ok) {
      console.error("PayMongo payment status check failed:", intentResult);
      return Response.json(
        { error: "Could not verify payment with PayMongo." },
        { status: 502, headers: cors },
      );
    }

    const intent = intentResult?.data;
    const attributes = intent?.attributes;
    if (
      intent?.id !== order.payment_reference ||
      attributes?.metadata?.order_id !== order.id ||
      attributes?.currency?.toUpperCase() !== "PHP" ||
      Number(attributes?.amount) !== Math.round(Number(order.total) * 100)
    ) {
      return Response.json(
        { error: "PayMongo payment details do not match this order." },
        { status: 409, headers: cors },
      );
    }

    if (attributes.status !== "succeeded") {
      return Response.json({ payment_status: order.payment_status }, { headers: cors });
    }

    const { error: updateError } = await admin
      .from("print_orders")
      .update({
        payment_status: "paid",
        status: "paid",
        updated_at: new Date().toISOString(),
      })
      .eq("id", order.id)
      .eq("user_id", user.id)
      .neq("payment_status", "paid");
    if (updateError) throw updateError;

    const { error: eventError } = await admin.from("order_status_events").insert({
      order_id: order.id,
      status: "paid",
      message: "PayMongo payment verified during order status check.",
    });
    if (eventError) {
      console.error("Could not record payment verification event:", eventError);
    }

    return Response.json({ payment_status: "paid" }, { headers: cors });
  } catch (error) {
    console.error("check-qrph-payment failed:", error);
    return Response.json(
      { error: error instanceof Error ? error.message : "Unable to check payment status." },
      { status: 400, headers: cors },
    );
  }
});
