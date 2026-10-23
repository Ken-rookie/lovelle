alter table public.orders
  add column if not exists paymongo_payment_intent_id text;

create unique index if not exists orders_paymongo_payment_intent_id_idx
  on public.orders (paymongo_payment_intent_id)
  where paymongo_payment_intent_id is not null;

create or replace function public.mark_qrph_intent_paid(
  p_order_id uuid,
  p_payment_intent_id text,
  p_is_live boolean,
  p_paid_amount bigint
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found
    or v_order.paymongo_payment_intent_id is distinct from p_payment_intent_id
    or v_order.payment_method <> 'qrph'
    or p_is_live is distinct from true
    or p_paid_amount <> round(v_order.total_amount * 100)::bigint then
    return false;
  end if;

  if v_order.payment_status = 'paid' then
    return true;
  end if;
  if v_order.status <> 'awaiting_payment'
    or v_order.payment_status <> 'awaiting_payment' then
    return false;
  end if;

  update public.orders
  set status = 'confirmed', payment_status = 'paid'
  where id = p_order_id;
  return true;
end;
$$;

create or replace function public.expire_qrph_intent_order(
  p_order_id uuid,
  p_payment_intent_id text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders%rowtype;
  v_item record;
begin
  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found
    or v_order.status <> 'awaiting_payment'
    or v_order.payment_status <> 'awaiting_payment'
    or v_order.paymongo_payment_intent_id is distinct from p_payment_intent_id
    or v_order.reservation_expires_at is null
    or v_order.reservation_expires_at > now() then
    return false;
  end if;

  for v_item in
    select product_slug, quantity
    from public.order_items
    where order_id = p_order_id
  loop
    update public.products
    set stock_quantity = coalesce(stock_quantity, 0) + v_item.quantity,
        updated_at = now()
    where slug = v_item.product_slug;
  end loop;

  update public.orders
  set status = 'cancelled', payment_status = 'expired'
  where id = p_order_id;
  return true;
end;
$$;

create or replace function public.expire_checkout_order(
  p_order_id uuid,
  p_session_id text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders%rowtype;
  v_item record;
begin
  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found
    or v_order.status <> 'awaiting_payment'
    or v_order.payment_status <> 'awaiting_payment'
    or v_order.paymongo_session_id is distinct from p_session_id
    or v_order.reservation_expires_at is null
    or v_order.reservation_expires_at > now() then
    return false;
  end if;

  for v_item in
    select product_slug, quantity
    from public.order_items
    where order_id = p_order_id
  loop
    update public.products
    set stock_quantity = coalesce(stock_quantity, 0) + v_item.quantity,
        updated_at = now()
    where slug = v_item.product_slug;
  end loop;

  update public.orders
  set status = 'cancelled', payment_status = 'expired'
  where id = p_order_id;
  return true;
end;
$$;

drop function public.stale_checkout_orders();

create function public.stale_checkout_orders()
returns table(order_id uuid, session_id text, payment_intent_id text)
language sql
security definer
set search_path = public, pg_temp
as $$
  select o.id, o.paymongo_session_id, o.paymongo_payment_intent_id
  from public.orders o
  where o.status = 'awaiting_payment'
    and o.payment_status = 'awaiting_payment'
    and o.reservation_expires_at <= now()
  order by o.reservation_expires_at
  limit 100
$$;

revoke all on function public.mark_qrph_intent_paid(uuid, text, boolean, bigint)
  from public, anon, authenticated;
revoke all on function public.expire_qrph_intent_order(uuid, text)
  from public, anon, authenticated;
revoke all on function public.expire_checkout_order(uuid, text)
  from public, anon, authenticated;
revoke all on function public.stale_checkout_orders()
  from public, anon, authenticated;

grant execute on function public.mark_qrph_intent_paid(uuid, text, boolean, bigint)
  to service_role;
grant execute on function public.expire_qrph_intent_order(uuid, text)
  to service_role;
grant execute on function public.expire_checkout_order(uuid, text)
  to service_role;
grant execute on function public.stale_checkout_orders()
  to service_role;
