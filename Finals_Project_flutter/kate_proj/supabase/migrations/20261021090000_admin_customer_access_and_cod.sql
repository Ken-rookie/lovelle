do $$
begin
  if to_regprocedure('public.has_role(text)') is null then
    raise exception 'Apply the product image storage migration before this migration to create public.has_role(text).';
  end if;
  if not exists (
    select 1 from public.user_roles where role = 'admin'
  ) then
    raise exception 'Assign at least one admin in public.user_roles before applying this migration.';
  end if;
end
$$;

grant select, insert, update, delete
  on public.products, public.categories, public.orders, public.order_items
  to authenticated;
grant select, insert, update, delete
  on public.profiles, public.addresses
  to authenticated;
revoke all
  on public.orders, public.order_items, public.profiles, public.addresses,
     public.cart_items, public.wishlist, public.reviews
  from public, anon;
grant select, insert, update, delete
  on public.cart_items, public.wishlist
  to authenticated;
grant select on public.reviews to authenticated;

alter table public.products enable row level security;
alter table public.categories enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.cart_items enable row level security;
alter table public.wishlist enable row level security;
alter table public.reviews enable row level security;

drop policy if exists lovelle_admin_manage_products on public.products;
create policy lovelle_admin_manage_products on public.products
  for all to authenticated
  using ((select public.has_role('admin')))
  with check ((select public.has_role('admin')));

drop policy if exists lovelle_limit_products_to_active_or_admin on public.products;
create policy lovelle_limit_products_to_active_or_admin on public.products
  as restrictive for all to authenticated
  using (is_available is true or (select public.has_role('admin')))
  with check (is_available is true or (select public.has_role('admin')));

drop policy if exists lovelle_admin_manage_categories on public.categories;
create policy lovelle_admin_manage_categories on public.categories
  for all to authenticated
  using ((select public.has_role('admin')))
  with check ((select public.has_role('admin')));

drop policy if exists lovelle_limit_categories_to_active_or_admin on public.categories;
create policy lovelle_limit_categories_to_active_or_admin on public.categories
  as restrictive for all to authenticated
  using (is_active is true or (select public.has_role('admin')))
  with check (is_active is true or (select public.has_role('admin')));

drop policy if exists lovelle_customer_read_own_orders on public.orders;
create policy lovelle_customer_read_own_orders on public.orders
  for select to authenticated
  using (customer_id = (select auth.uid()));

drop policy if exists lovelle_admin_manage_orders on public.orders;
create policy lovelle_admin_manage_orders on public.orders
  for all to authenticated
  using ((select public.has_role('admin')))
  with check ((select public.has_role('admin')));

drop policy if exists lovelle_limit_orders_to_owner_or_admin on public.orders;
create policy lovelle_limit_orders_to_owner_or_admin on public.orders
  as restrictive for all to authenticated
  using (customer_id = (select auth.uid()) or (select public.has_role('admin')))
  with check (customer_id = (select auth.uid()) or (select public.has_role('admin')));

drop policy if exists lovelle_customer_read_own_order_items on public.order_items;
create policy lovelle_customer_read_own_order_items on public.order_items
  for select to authenticated
  using (
    exists (
      select 1
      from public.orders o
      where o.id = order_items.order_id
        and o.customer_id = (select auth.uid())
    )
  );

drop policy if exists lovelle_admin_manage_order_items on public.order_items;
create policy lovelle_admin_manage_order_items on public.order_items
  for all to authenticated
  using ((select public.has_role('admin')))
  with check ((select public.has_role('admin')));

drop policy if exists lovelle_limit_order_items_to_owner_or_admin on public.order_items;
create policy lovelle_limit_order_items_to_owner_or_admin on public.order_items
  as restrictive for all to authenticated
  using (
    (select public.has_role('admin'))
    or exists (
      select 1
      from public.orders o
      where o.id = order_items.order_id
        and o.customer_id = (select auth.uid())
    )
  )
  with check (
    (select public.has_role('admin'))
    or exists (
      select 1
      from public.orders o
      where o.id = order_items.order_id
        and o.customer_id = (select auth.uid())
    )
  );

drop policy if exists lovelle_customer_manage_own_addresses on public.addresses;
create policy lovelle_customer_manage_own_addresses on public.addresses
  for all to authenticated
  using (customer_id = (select auth.uid()))
  with check (customer_id = (select auth.uid()));

drop policy if exists lovelle_admin_manage_addresses on public.addresses;
create policy lovelle_admin_manage_addresses on public.addresses
  for all to authenticated
  using ((select public.has_role('admin')))
  with check ((select public.has_role('admin')));

drop policy if exists lovelle_limit_addresses_to_owner_or_admin on public.addresses;
create policy lovelle_limit_addresses_to_owner_or_admin on public.addresses
  as restrictive for all to authenticated
  using (customer_id = (select auth.uid()) or (select public.has_role('admin')))
  with check (customer_id = (select auth.uid()) or (select public.has_role('admin')));

drop policy if exists lovelle_admin_read_profiles on public.profiles;
create policy lovelle_admin_read_profiles on public.profiles
  for select to authenticated
  using ((select public.has_role('admin')));

drop policy if exists lovelle_limit_profiles_to_owner_or_admin on public.profiles;
create policy lovelle_limit_profiles_to_owner_or_admin on public.profiles
  as restrictive for all to authenticated
  using (id = (select auth.uid()) or (select public.has_role('admin')))
  with check (id = (select auth.uid()) or (select public.has_role('admin')));

drop policy if exists lovelle_limit_cart_items_to_owner_or_admin on public.cart_items;
create policy lovelle_limit_cart_items_to_owner_or_admin on public.cart_items
  as restrictive for all to authenticated
  using (customer_id = (select auth.uid()) or (select public.has_role('admin')))
  with check (customer_id = (select auth.uid()) or (select public.has_role('admin')));

drop policy if exists lovelle_limit_wishlist_to_owner_or_admin on public.wishlist;
create policy lovelle_limit_wishlist_to_owner_or_admin on public.wishlist
  as restrictive for all to authenticated
  using (customer_id = (select auth.uid()) or (select public.has_role('admin')))
  with check (customer_id = (select auth.uid()) or (select public.has_role('admin')));

drop policy if exists lovelle_customer_read_own_reviews on public.reviews;
create policy lovelle_customer_read_own_reviews on public.reviews
  for select to authenticated
  using (customer_id = (select auth.uid()));

drop policy if exists lovelle_admin_read_reviews on public.reviews;
create policy lovelle_admin_read_reviews on public.reviews
  for select to authenticated
  using ((select public.has_role('admin')));

drop policy if exists lovelle_limit_reviews_to_owner_or_admin on public.reviews;
create policy lovelle_limit_reviews_to_owner_or_admin on public.reviews
  as restrictive for all to authenticated
  using (customer_id = (select auth.uid()) or (select public.has_role('admin')))
  with check (customer_id = (select auth.uid()) or (select public.has_role('admin')));

create or replace function public.place_cash_on_delivery_order(
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
  v_customer_id uuid := auth.uid();
  v_cart record;
  v_rose_type text;
  v_subtotal numeric := 0;
  v_delivery_fee numeric := 0;
  v_wrapping_fee numeric := 0;
  v_card_fee numeric := 0;
  v_total numeric;
  v_order public.orders%rowtype;
  v_items jsonb := '[]'::jsonb;
  v_product_ids uuid[] := array[]::uuid[];
begin
  if v_customer_id is null then
    raise exception 'Sign in before placing an order';
  end if;
  if p_fulfillment not in ('delivery', 'pickup') then
    raise exception 'Invalid fulfillment method';
  end if;
  if nullif(trim(p_recipient), '') is null
    or nullif(trim(p_phone), '') is null then
    raise exception 'Recipient name and contact number are required';
  end if;
  if p_fulfillment = 'delivery'
    and nullif(trim(p_address), '') is null then
    raise exception 'A delivery address is required';
  end if;

  for v_cart in
    select ci.quantity, p.id, p.name, p.image_url, p.price,
           p.stock_quantity, p.is_available, p.is_rose_gift
    from public.cart_items ci
    join public.products p on p.id = ci.product_id
    where ci.customer_id = v_customer_id
    order by p.id
    for update of ci, p
  loop
    if v_cart.quantity < 1 or v_cart.is_available is not true
      or v_cart.quantity > v_cart.stock_quantity then
      raise exception 'A cart item is unavailable or out of stock';
    end if;

    v_rose_type := coalesce(p_rose_types, '{}'::jsonb) ->> v_cart.id::text;
    if v_cart.is_rose_gift
      and coalesce(v_rose_type not in ('fresh', 'artificial'), true) then
      raise exception 'Choose a style for every rose gift';
    end if;
    if not v_cart.is_rose_gift then
      v_rose_type := null;
    end if;

    v_subtotal := v_subtotal
      + (case when v_cart.price > 0 then 1 else 0 end) * v_cart.quantity;
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'product_id', v_cart.id,
      'product_name', v_cart.name,
      'product_image_url', v_cart.image_url,
      'unit_price', case when v_cart.price > 0 then 1 else 0 end,
      'quantity', v_cart.quantity,
      'line_total', (case when v_cart.price > 0 then 1 else 0 end) * v_cart.quantity,
      'rose_type', v_rose_type
    ));
    v_product_ids := array_append(v_product_ids, v_cart.id);

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

  insert into public.orders (
    customer_id, fulfillment_method, payment_method, recipient_name,
    contact_number, delivery_address, gift_wrapping, greeting_card,
    greeting_message, subtotal, delivery_fee, gift_wrapping_fee,
    greeting_card_fee, total_amount
  ) values (
    v_customer_id, p_fulfillment, 'cash_on_delivery', trim(p_recipient),
    trim(p_phone), nullif(trim(p_address), ''), coalesce(p_wrapping, false),
    coalesce(p_greeting_card, false), nullif(trim(p_greeting_message), ''),
    v_subtotal, v_delivery_fee, v_wrapping_fee, v_card_fee, v_total
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

  delete from public.cart_items
  where customer_id = v_customer_id
    and product_id = any(v_product_ids);

  return to_jsonb(v_order) || jsonb_build_object('order_items', v_items);
end;
$$;

revoke all on function public.place_cash_on_delivery_order(
  text, text, text, text, boolean, boolean, text, jsonb
) from public, anon;
grant execute on function public.place_cash_on_delivery_order(
  text, text, text, text, boolean, boolean, text, jsonb
) to authenticated;

create or replace function public.cancel_own_pending_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in before cancelling an order';
  end if;

  update public.orders
  set status = 'cancelled'
  where id = p_order_id
    and customer_id = auth.uid()
    and status = 'pending'
    and payment_method = 'cash_on_delivery'
    and lower(coalesce(payment_status, '')) <> 'paid'
  returning id into v_order_id;

  if v_order_id is null then
    raise exception 'Only your own pending cash-on-delivery orders can be cancelled';
  end if;

  update public.products p
  set stock_quantity = p.stock_quantity + cancelled_items.quantity
  from (
    select oi.product_id, sum(oi.quantity)::integer as quantity
    from public.order_items oi
    where oi.order_id = v_order_id
    group by oi.product_id
  ) as cancelled_items
  where p.id = cancelled_items.product_id;
end;
$$;

revoke all on function public.cancel_own_pending_order(uuid)
  from public, anon;
grant execute on function public.cancel_own_pending_order(uuid)
  to authenticated;
