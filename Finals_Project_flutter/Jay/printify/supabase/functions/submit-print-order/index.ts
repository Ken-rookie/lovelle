import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "object" && error !== null) {
    const value = error as Record<string, unknown>;
    for (const key of ["message", "details", "hint"]) {
      if (typeof value[key] === "string" && value[key]) return value[key] as string;
    }
  }
  return "Order could not be created. Check the Supabase function logs and schema.";
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
    if (!url || !anon || !serviceKey) {
      throw new Error("Supabase function environment is incomplete.");
    }
    const auth = req.headers.get("Authorization");
    if (!auth) return Response.json({ error: "Missing authorization" }, { status: 401, headers: cors });

    const userClient = createClient(url, anon, { global: { headers: { Authorization: auth } } });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return Response.json({ error: "Unauthorized" }, { status: 401, headers: cors });

    const body = await req.json();
    const allowedSizes = ["A4", "A3", "Letter", "Legal", "Long (8.5 × 13 in)", "Short (8.5 × 11 in)", "Custom"];
    const allowedOrientations = ["Portrait", "Landscape"];
    const allowedColors = ["Color", "Black & White"];
    const allowedSides = ["Single-sided", "Double-sided"];
    const allowedPaper = ["Standard (80 gsm)", "Premium (100 gsm)", "Photo glossy", "Matte"];
    const copies = Number(body.copies ?? 1);
    if (!Number.isInteger(copies) || copies < 1 || copies > 100) throw new Error("Copies must be between 1 and 100.");
    if (!allowedSizes.includes(body.paper_size) || !allowedOrientations.includes(body.orientation) ||
        !allowedColors.includes(body.color_mode) || !allowedSides.includes(body.print_sides) ||
        !allowedPaper.includes(body.paper_type)) throw new Error("Invalid print settings.");
    if (!Array.isArray(body.files) || body.files.length < 1 || body.files.length > 20) throw new Error("Select between 1 and 20 files.");

    const rate = 1;
    const subtotal = Math.round(body.files.length * copies * rate * 100) / 100;
    const serviceFee = 0;
    const total = subtotal + serviceFee;

    const admin = createClient(url, serviceKey);
    const { data: order, error: orderError } = await admin.from("print_orders").insert({
      user_id: user.id,
      service_type: String(body.service_type ?? "Documents"),
      paper_size: body.paper_size,
      orientation: body.orientation,
      color_mode: body.color_mode,
      print_sides: body.print_sides,
      paper_type: body.paper_type,
      copies,
      notes: String(body.notes ?? "").slice(0, 1000),
      subtotal,
      service_fee: serviceFee,
      total,
      status: "awaiting_payment",
      payment_status: "unpaid",
      currency: "PHP",
    }).select().single();
    if (orderError) throw orderError;

    const fileRows = body.files.map((f: any) => ({
      order_id: order.id,
      user_id: user.id,
      file_name: String(f.file_name ?? "unnamed").slice(0, 255),
      file_size_bytes: Math.max(0, Number(f.file_size_bytes ?? 0)),
      file_extension: String(f.file_extension ?? "").slice(0, 20),
      storage_path: f.storage_path ?? null,
    }));
    const { error: filesError } = await admin.from("print_order_files").insert(fileRows);
    if (filesError) {
      await admin.from("print_orders").delete().eq("id", order.id);
      throw filesError;
    }
    const { error: eventError } = await admin.from("order_status_events").insert({
      order_id: order.id, status: "awaiting_payment", message: "Order created; waiting for QRPh payment.",
    });
    if (eventError) {
      console.error("Could not record order creation event:", eventError);
    }
    return Response.json({ order_id: order.id, order_number: order.order_number, subtotal, service_fee: serviceFee, total }, { headers: cors });
  } catch (error) {
    const message = errorMessage(error);
    console.error("submit-print-order failed:", error);
    return Response.json({ error: message }, { status: 400, headers: cors });
  }
});
