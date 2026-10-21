alter table public.orders
  drop constraint if exists orders_payment_method_check;

alter table public.orders
  add constraint orders_payment_method_check
  check (
    payment_method = any (
      array['cash_on_delivery', 'gcash', 'card', 'maya', 'paymongo']::text[]
    )
  );

create or replace function public.finalize_paid_paymongo_order(
  p_customer_id uuid,
  p_payment_intent_id text,
  p_fulfillment text,
  p_recipient text,
  p_phone text,
  p_address text,
  p_wrapping boolean,
  p_greeting_card boolean,
  p_greeting_message text,
  p_rose_types jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session_amount integer;
  v_subtotal numeric := 0;
  v_delivery_fee numeric := 0;
  v_wrapping_fee numeric := 0;
  v_card_fee numeric := 0;
  v_total numeric;
  v_order public.orders%rowtype;
  v_existing_order public.orders%rowtype;
  v_existing_order_id text;
  v_session_status text;
  v_cart record;
  v_rose_type text;
  v_items jsonb := '[]'::jsonb;
begin
  if p_fulfillment not in ('delivery', 'pickup') then
    raise exception 'Invalid fulfillment method';
  end if;

  select s.amount, s.status, s.order_id
    into v_session_amount, v_session_status, v_existing_order_id
  from public.paymongo_payment_sessions s
  where s.customer_id = p_customer_id
    and s.payment_intent_id = p_payment_intent_id
  for update;
  if not found then
    raise exception 'Payment is not verified or has expired';
  end if;
  if v_session_status = 'order_created' and v_existing_order_id is not null then
    select o.* into v_existing_order
    from public.orders o
    where o.id::text = v_existing_order_id
      and o.customer_id = p_customer_id;
    if not found then
      raise exception 'Previously created order could not be found';
    end if;
    select coalesce(jsonb_agg(to_jsonb(oi)), '[]'::jsonb) into v_items
    from public.order_items oi
    where oi.order_id::text = v_existing_order_id;
    return to_jsonb(v_existing_order) || jsonb_build_object('order_items', v_items);
  end if;
  if v_session_status <> 'succeeded' then
    raise exception 'Payment is not verified';
  end if;

  for v_cart in
    select ci.quantity, p.id, p.name, p.image_url, p.stock_quantity,
           p.is_available, p.is_rose_gift
    from public.cart_items ci
    join public.products p on p.id = ci.product_id
    where ci.customer_id = p_customer_id
    order by p.id
    for update of p
  loop
    if v_cart.quantity < 1 or v_cart.is_available is not true
      or v_cart.quantity > v_cart.stock_quantity then
      raise exception 'A cart item is unavailable or out of stock';
    end if;

    v_rose_type := p_rose_types ->> v_cart.id::text;
    if v_cart.is_rose_gift
      and coalesce(v_rose_type not in ('fresh', 'artificial'), true) then
      raise exception 'A rose gift style is missing or invalid';
    end if;
    if not v_cart.is_rose_gift then
      v_rose_type := null;
    end if;

    v_subtotal := v_subtotal + v_cart.quantity;
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'product_id', v_cart.id,
      'product_name', v_cart.name,
      'product_image_url', v_cart.image_url,
      'unit_price', 1,
      'quantity', v_cart.quantity,
      'line_total', v_cart.quantity,
      'rose_type', v_rose_type
    ));

    update public.products
    set stock_quantity = stock_quantity - v_cart.quantity
    where id = v_cart.id;
  end loop;

  if jsonb_array_length(v_items) = 0 then
    raise exception 'Your cart is empty';
  end if;

  v_delivery_fee := case when p_fulfillment = 'delivery' then 1 else 0 end;
  v_wrapping_fee := case when p_wrapping then 1 else 0 end;
  v_card_fee := case when p_greeting_card then 1 else 0 end;
  v_total := v_subtotal + v_delivery_fee + v_wrapping_fee + v_card_fee;
  if round(v_total * 100)::integer <> v_session_amount then
    raise exception 'Payment amount does not match the current cart';
  end if;

  insert into public.orders (
    customer_id, fulfillment_method, payment_method, payment_status,
    payment_reference, recipient_name, contact_number, delivery_address,
    gift_wrapping, greeting_card, greeting_message, subtotal, delivery_fee,
    gift_wrapping_fee, greeting_card_fee, total_amount
  ) values (
    p_customer_id, p_fulfillment, 'paymongo', 'paid', p_payment_intent_id,
    p_recipient, p_phone, nullif(p_address, ''), p_wrapping, p_greeting_card,
    nullif(p_greeting_message, ''), v_subtotal, v_delivery_fee,
    v_wrapping_fee, v_card_fee, v_total
  ) returning * into v_order;

  insert into public.order_items (
    order_id, product_id, product_name, product_image_url,
    unit_price, quantity, line_total, rose_type
  )
  select v_order.id,
         (item ->> 'product_id')::uuid,
         item ->> 'product_name',
         item ->> 'product_image_url',
         (item ->> 'unit_price')::numeric,
         (item ->> 'quantity')::integer,
         (item ->> 'line_total')::numeric,
         item ->> 'rose_type'
  from jsonb_array_elements(v_items) item;

  delete from public.cart_items where customer_id = p_customer_id;
  update public.paymongo_payment_sessions
  set status = 'order_created', order_id = v_order.id::text, updated_at = now()
  where payment_intent_id = p_payment_intent_id
    and customer_id = p_customer_id;

  return to_jsonb(v_order) || jsonb_build_object('order_items', v_items);
end;
$$;

revoke all on function public.finalize_paid_paymongo_order(
  uuid, text, text, text, text, text, boolean, boolean, text, jsonb
) from public, anon, authenticated;
grant execute on function public.finalize_paid_paymongo_order(
  uuid, text, text, text, text, text, boolean, boolean, text, jsonb
) to service_role;
