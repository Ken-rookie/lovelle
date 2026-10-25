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
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const auth = req.headers.get("Authorization");
    if (!auth) {
      return Response.json({ error: "Missing authorization" }, { status: 401, headers: cors });
    }

    const userClient = createClient(url, anon, {
      global: { headers: { Authorization: auth } },
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
      .select("id,payment_status,payment_provider,qr_expires_at")
      .eq("id", orderId)
      .eq("user_id", user.id)
      .single();
    if (orderError || !order) {
      return Response.json({ error: "Order not found" }, { status: 404, headers: cors });
    }
    if (order.payment_status === "paid") {
      return Response.json({ error: "Order is already paid" }, { status: 409, headers: cors });
    }
    if (
      order.payment_provider === "paymongo" &&
      order.payment_status === "pending" &&
      order.qr_expires_at &&
      new Date(order.qr_expires_at).getTime() > Date.now()
    ) {
      return Response.json(
        { error: "An active QRPh payment exists. Wait for it to expire before switching to walk-in." },
        { status: 409, headers: cors },
      );
    }

    const { error: updateError } = await admin
      .from("print_orders")
      .update({
        payment_provider: "walkin",
        payment_status: "pending",
        payment_reference: null,
        qr_payload: null,
        qr_expires_at: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", order.id)
      .neq("payment_status", "paid");
    if (updateError) throw updateError;

    const { error: eventError } = await admin.from("order_status_events").insert({
      order_id: order.id,
      status: "awaiting_payment",
      message: "Walk-in payment selected; payment is pending at the shop counter.",
    });
    if (eventError) throw eventError;

    return Response.json({ order_id: order.id, payment_status: "pending" }, { headers: cors });
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : "Unknown error" },
      { status: 400, headers: cors },
    );
  }
});
