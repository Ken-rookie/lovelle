-- Keep incompatible legacy tables intact and create a separate schema for
-- live checkout instead of applying the new RLS and RPC assumptions to them.
do $$
begin
  if to_regclass('public.customer_addresses') is not null and (
    (select count(*)
     from pg_catalog.pg_attribute
     where attrelid = to_regclass('public.customer_addresses')
       and attname = any(array[
         'id', 'user_id', 'full_name', 'phone', 'address_line1',
         'address_line2', 'city', 'province', 'postal_code',
         'delivery_note', 'updated_at'
       ])
       and not attisdropped) <> 11
    or not exists (
      select 1 from pg_catalog.pg_attribute
      where attrelid = to_regclass('public.customer_addresses')
        and attname = 'id'
        and atttypid = 'uuid'::regtype
        and not attisdropped
    )
    or not exists (
      select 1 from pg_catalog.pg_attribute
      where attrelid = to_regclass('public.customer_addresses')
        and attname = 'user_id'
        and atttypid = 'uuid'::regtype
        and not attisdropped
    )
  ) then
    if to_regclass('public.customer_addresses_legacy_pre_live_checkout') is not null then
      raise exception 'Cannot preserve the legacy customer_addresses table because customer_addresses_legacy_pre_live_checkout already exists.';
    end if;
    alter table public.customer_addresses
      rename to customer_addresses_legacy_pre_live_checkout;
  end if;

  if to_regclass('public.orders') is not null and (
    (select count(*)
     from pg_catalog.pg_attribute
     where attrelid = to_regclass('public.orders')
       and attname = any(array[
         'id', 'user_id', 'customer_address_id', 'checkout_request_id',
         'reference_number', 'status', 'payment_status', 'payment_method',
         'subtotal', 'delivery_fee', 'total_amount', 'currency',
         'shipping_address', 'paymongo_session_id', 'paymongo_checkout_url',
         'checkout_creation_started_at', 'reservation_expires_at', 'created_at'
       ])
       and not attisdropped) <> 18
    or not exists (
      select 1 from pg_catalog.pg_attribute
      where attrelid = to_regclass('public.orders')
        and attname = 'id'
        and atttypid = 'uuid'::regtype
        and not attisdropped
    )
  ) then
    if to_regclass('public.orders_legacy_pre_live_checkout') is not null then
      raise exception 'Cannot preserve the legacy orders table because orders_legacy_pre_live_checkout already exists.';
    end if;
    alter table public.orders rename to orders_legacy_pre_live_checkout;
  end if;

  if to_regclass('public.order_items') is not null and (
    (select count(*)
     from pg_catalog.pg_attribute
     where attrelid = to_regclass('public.order_items')
       and attname = any(array[
         'id', 'order_id', 'product_slug', 'product_name',
         'unit_price', 'quantity', 'line_total'
       ])
       and not attisdropped) <> 7
    or not exists (
      select 1 from pg_catalog.pg_attribute
      where attrelid = to_regclass('public.order_items')
        and attname = 'order_id'
        and atttypid = 'uuid'::regtype
        and not attisdropped
    )
    or not exists (
      select 1 from pg_catalog.pg_attribute
      where attrelid = to_regclass('public.order_items')
        and attname = 'line_total' and not attisdropped
    )
  ) then
    if to_regclass('public.order_items_legacy_pre_live_checkout') is not null then
      raise exception 'Cannot preserve the legacy order_items table because order_items_legacy_pre_live_checkout already exists.';
    end if;
    alter table public.order_items rename to order_items_legacy_pre_live_checkout;
  end if;
end;
$$;

create table if not exists public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  full_name text not null,
  phone text not null,
  address_line1 text not null,
  address_line2 text,
  barangay text,
  city text not null,
  province text not null,
  postal_code text not null,
  delivery_note text,
  updated_at timestamptz not null default now()
);

alter table public.customer_addresses
  add column if not exists barangay text;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_address_id uuid references public.customer_addresses(id) on delete set null,
  checkout_request_id text not null,
  reference_number text not null unique default
    ('PCH-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),
  status text not null check (
    status in ('awaiting_payment', 'confirmed', 'cancelled')
  ),
  payment_status text not null check (
    payment_status in ('awaiting_payment', 'unpaid', 'paid', 'expired')
  ),
  payment_method text not null check (payment_method in ('cod', 'qrph')),
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  delivery_fee numeric(12, 2) not null default 0 check (delivery_fee = 0),
  total_amount numeric(12, 2) not null check (total_amount >= 0),
  currency text not null default 'PHP' check (currency = 'PHP'),
  shipping_address jsonb not null,
  paymongo_session_id text unique,
  paymongo_checkout_url text,
  checkout_creation_started_at timestamptz,
  reservation_expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, checkout_request_id)
);

create table if not exists public.order_items (
  id bigint generated by default as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  product_slug text not null,
  product_name text not null,
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  quantity integer not null check (quantity between 1 and 50),
  line_total numeric(12, 2) not null check (line_total >= 0),
  unique (order_id, product_slug)
);

create index if not exists orders_user_created_at_idx
  on public.orders (user_id, created_at desc);
create index if not exists orders_pending_checkout_idx
  on public.orders (created_at)
  where status = 'awaiting_payment';
create index if not exists order_items_order_id_idx
  on public.order_items (order_id);

alter table public.customer_addresses enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists "Customers read their saved address"
  on public.customer_addresses;
create policy "Customers read their saved address"
  on public.customer_addresses for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Customers read their orders" on public.orders;
create policy "Customers read their orders"
  on public.orders for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Customers read their order items"
  on public.order_items;
create policy "Customers read their order items"
  on public.order_items for select to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_id and o.user_id = auth.uid()
    )
  );

grant select on public.customer_addresses, public.orders, public.order_items
  to authenticated;

create or replace function public.create_checkout_order(
  p_user_id uuid,
  p_request_id text,
  p_items jsonb,
  p_delivery jsonb,
  p_payment_method text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_existing public.orders%rowtype;
  v_address_id uuid;
  v_order_id uuid;
  v_reference text;
  v_status text;
  v_payment_status text;
  v_subtotal numeric(12, 2) := 0;
  v_lines jsonb := '[]'::jsonb;
  v_requested jsonb;
  v_product record;
  v_slug text;
  v_quantity integer;
  v_line_total numeric(12, 2);
begin
  if p_user_id is null
    or p_request_id is null
    or p_request_id !~ '^[0-9a-fA-F]{32}$'
    or p_payment_method is null
    or p_payment_method not in ('cod', 'qrph')
    or p_items is null
    or coalesce(jsonb_typeof(p_items), '') <> 'array'
    or jsonb_array_length(
      case
        when jsonb_typeof(p_items) = 'array' then p_items
        else '[]'::jsonb
      end
    ) not between 1 and 50
    or p_delivery is null
    or coalesce(jsonb_typeof(p_delivery), '') <> 'object' then
    raise exception 'Invalid checkout request.';
  end if;

  select * into v_existing
  from public.orders
  where user_id = p_user_id and checkout_request_id = p_request_id;

  if found then
    return jsonb_build_object(
      'order_id', v_existing.id,
      'reference_number', v_existing.reference_number,
      'status', v_existing.status,
      'payment_status', v_existing.payment_status,
      'payment_method', v_existing.payment_method,
      'total_amount', v_existing.total_amount,
      'checkout_url', v_existing.paymongo_checkout_url,
      'paymongo_session_id', v_existing.paymongo_session_id,
      'checkout_creation_started_at', v_existing.checkout_creation_started_at
    );
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_items) as item(value)
    group by value->>'slug'
    having count(*) > 1
  ) then
    raise exception 'Duplicate products are not allowed in one order.';
  end if;

  if coalesce(length(trim(p_delivery->>'full_name')), 0) not between 2 and 120
    or coalesce(length(trim(p_delivery->>'phone')), 0) not between 7 and 30
    or coalesce(length(trim(p_delivery->>'address_line1')), 0) not between 5 and 240
    or coalesce(length(trim(p_delivery->>'address_line2')), 0) > 240
    or coalesce(length(trim(p_delivery->>'municipality')), 0) not between 2 and 100
    or coalesce(length(trim(p_delivery->>'barangay')), 0) not between 2 and 120
    or coalesce(length(trim(p_delivery->>'province')), 0) not between 2 and 100
    or coalesce(length(trim(p_delivery->>'postal_code')), 0) not between 3 and 20
    or coalesce(length(trim(p_delivery->>'delivery_note')), 0) > 500 then
    raise exception 'Enter complete and valid delivery details.';
  end if;

  for v_requested in
    select value
    from jsonb_array_elements(p_items)
    order by value->>'slug'
  loop
    v_slug := trim(v_requested->>'slug');
    begin
      v_quantity := (v_requested->>'quantity')::integer;
    exception when others then
      raise exception 'Invalid product quantity.';
    end;
    if coalesce(length(v_slug), 0) not between 1 and 120
      or v_quantity not between 1 and 50 then
      raise exception 'Invalid product or quantity.';
    end if;

    select p.slug, p.name, p.price, p.currency, p.stock_quantity
      into v_product
    from public.products p
    where p.slug = v_slug and p.is_active = true
    for update;

    if not found or v_product.currency <> 'PHP'
      or v_product.stock_quantity is null
      or v_product.stock_quantity < v_quantity then
      raise exception 'A product is unavailable or has insufficient stock: %', v_slug;
    end if;

    v_line_total := round(v_product.price * v_quantity, 2);
    v_subtotal := v_subtotal + v_line_total;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'product_slug', v_product.slug,
      'product_name', v_product.name,
      'unit_price', v_product.price,
      'quantity', v_quantity,
      'line_total', v_line_total
    ));

    update public.products
    set stock_quantity = stock_quantity - v_quantity,
        updated_at = now()
    where slug = v_slug;
  end loop;

  insert into public.customer_addresses (
    user_id, full_name, phone, address_line1, address_line2, barangay,
    city, province, postal_code, delivery_note, updated_at
  ) values (
    p_user_id,
    trim(p_delivery->>'full_name'),
    trim(p_delivery->>'phone'),
    trim(p_delivery->>'address_line1'),
    nullif(trim(p_delivery->>'address_line2'), ''),
    trim(p_delivery->>'barangay'),
    trim(p_delivery->>'municipality'),
    'Bohol',
    trim(p_delivery->>'postal_code'),
    nullif(trim(p_delivery->>'delivery_note'), ''),
    now()
  )
  on conflict (user_id) do update set
    full_name = excluded.full_name,
    phone = excluded.phone,
    address_line1 = excluded.address_line1,
    address_line2 = excluded.address_line2,
    barangay = excluded.barangay,
    city = excluded.city,
    province = excluded.province,
    postal_code = excluded.postal_code,
    delivery_note = excluded.delivery_note,
    updated_at = now()
  returning id into v_address_id;

  v_order_id := gen_random_uuid();
  v_reference := 'PCH-' || upper(substr(replace(v_order_id::text, '-', ''), 1, 12));
  v_status := case when p_payment_method = 'cod'
    then 'confirmed' else 'awaiting_payment' end;
  v_payment_status := case when p_payment_method = 'cod'
    then 'unpaid' else 'awaiting_payment' end;

  insert into public.orders (
    id, user_id, customer_address_id, checkout_request_id, reference_number,
    status, payment_status, payment_method, subtotal, delivery_fee,
    total_amount, currency, shipping_address, reservation_expires_at
  ) values (
    v_order_id, p_user_id, v_address_id, p_request_id, v_reference,
    v_status, v_payment_status, p_payment_method, v_subtotal, 0,
    v_subtotal, 'PHP',
    jsonb_build_object(
      'full_name', trim(p_delivery->>'full_name'),
      'phone', trim(p_delivery->>'phone'),
      'address_line1', trim(p_delivery->>'address_line1'),
      'address_line2', nullif(trim(p_delivery->>'address_line2'), ''),
      'municipality', trim(p_delivery->>'municipality'),
      'barangay', trim(p_delivery->>'barangay'),
      'city', trim(p_delivery->>'municipality'),
      'province', 'Bohol',
      'postal_code', trim(p_delivery->>'postal_code'),
      'delivery_note', nullif(trim(p_delivery->>'delivery_note'), '')
    ),
    case when p_payment_method = 'qrph' then now() + interval '45 minutes' end
  );

  insert into public.order_items (
    order_id, product_slug, product_name, unit_price, quantity, line_total
  )
  select
    v_order_id,
    value->>'product_slug',
    value->>'product_name',
    (value->>'unit_price')::numeric,
    (value->>'quantity')::integer,
    (value->>'line_total')::numeric
  from jsonb_array_elements(v_lines) as item(value);

  return jsonb_build_object(
    'order_id', v_order_id,
    'reference_number', v_reference,
    'status', v_status,
    'payment_status', v_payment_status,
    'payment_method', p_payment_method,
    'total_amount', v_subtotal,
    'checkout_url', null,
    'paymongo_session_id', null,
    'checkout_creation_started_at', null
  );
end;
$$;

create or replace function public.mark_checkout_paid(
  p_order_id uuid,
  p_reference_number text,
  p_session_id text,
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
    or v_order.reference_number <> p_reference_number
    or v_order.paymongo_session_id is distinct from p_session_id
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
    or v_order.created_at > now() - interval '45 minutes' then
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

create or replace function public.stale_checkout_orders()
returns table(order_id uuid, session_id text)
language sql
security definer
set search_path = public, pg_temp
as $$
  select o.id, o.paymongo_session_id
  from public.orders o
  where o.status = 'awaiting_payment'
    and o.payment_status = 'awaiting_payment'
    and o.created_at <= now() - interval '45 minutes'
  order by o.created_at
  limit 100
$$;

revoke all on function public.create_checkout_order(uuid, text, jsonb, jsonb, text)
  from public, anon, authenticated;
revoke all on function public.mark_checkout_paid(uuid, text, text, boolean, bigint)
  from public, anon, authenticated;
revoke all on function public.expire_checkout_order(uuid, text)
  from public, anon, authenticated;
revoke all on function public.stale_checkout_orders()
  from public, anon, authenticated;

grant execute on function public.create_checkout_order(uuid, text, jsonb, jsonb, text)
  to service_role;
grant execute on function public.mark_checkout_paid(uuid, text, text, boolean, bigint)
  to service_role;
grant execute on function public.expire_checkout_order(uuid, text)
  to service_role;
grant execute on function public.stale_checkout_orders()
  to service_role;
