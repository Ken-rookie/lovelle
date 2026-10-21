grant select on table public.categories to authenticated;
grant select on table public.products to authenticated;
grant select, insert, update on table public.profiles to authenticated;
grant select, insert, update, delete on table public.cart_items to authenticated;
grant select, insert, delete on table public.wishlist to authenticated;

alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.profiles enable row level security;
alter table public.cart_items enable row level security;
alter table public.wishlist enable row level security;

drop policy if exists lovelle_customer_read_active_categories
  on public.categories;
create policy lovelle_customer_read_active_categories
  on public.categories
  for select
  to authenticated
  using (is_active is true);

drop policy if exists lovelle_customer_read_available_products
  on public.products;
create policy lovelle_customer_read_available_products
  on public.products
  for select
  to authenticated
  using (is_available is true);

drop policy if exists lovelle_customer_read_own_profile
  on public.profiles;
create policy lovelle_customer_read_own_profile
  on public.profiles
  for select
  to authenticated
  using (id = (select auth.uid()));

drop policy if exists lovelle_customer_insert_own_profile
  on public.profiles;
create policy lovelle_customer_insert_own_profile
  on public.profiles
  for insert
  to authenticated
  with check (id = (select auth.uid()));

drop policy if exists lovelle_customer_update_own_profile
  on public.profiles;
create policy lovelle_customer_update_own_profile
  on public.profiles
  for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

drop policy if exists lovelle_customer_read_own_cart
  on public.cart_items;
create policy lovelle_customer_read_own_cart
  on public.cart_items
  for select
  to authenticated
  using (customer_id = (select auth.uid()));

drop policy if exists lovelle_customer_insert_own_cart
  on public.cart_items;
create policy lovelle_customer_insert_own_cart
  on public.cart_items
  for insert
  to authenticated
  with check (customer_id = (select auth.uid()));

drop policy if exists lovelle_customer_update_own_cart
  on public.cart_items;
create policy lovelle_customer_update_own_cart
  on public.cart_items
  for update
  to authenticated
  using (customer_id = (select auth.uid()))
  with check (customer_id = (select auth.uid()));

drop policy if exists lovelle_customer_delete_own_cart
  on public.cart_items;
create policy lovelle_customer_delete_own_cart
  on public.cart_items
  for delete
  to authenticated
  using (customer_id = (select auth.uid()));

drop policy if exists lovelle_customer_read_own_wishlist
  on public.wishlist;
create policy lovelle_customer_read_own_wishlist
  on public.wishlist
  for select
  to authenticated
  using (customer_id = (select auth.uid()));

drop policy if exists lovelle_customer_insert_own_wishlist
  on public.wishlist;
create policy lovelle_customer_insert_own_wishlist
  on public.wishlist
  for insert
  to authenticated
  with check (customer_id = (select auth.uid()));

drop policy if exists lovelle_customer_delete_own_wishlist
  on public.wishlist;
create policy lovelle_customer_delete_own_wishlist
  on public.wishlist
  for delete
  to authenticated
  using (customer_id = (select auth.uid()));
