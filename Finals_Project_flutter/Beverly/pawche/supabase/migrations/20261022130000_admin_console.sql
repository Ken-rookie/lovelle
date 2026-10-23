create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;
revoke all on public.admin_users from anon, authenticated;
grant select on public.admin_users to authenticated;

drop policy if exists "Admins can read their own role" on public.admin_users;
create policy "Admins can read their own role"
  on public.admin_users for select to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "Admins can read all products" on public.products;
create policy "Admins can read all products"
  on public.products for select to authenticated
  using ((select public.is_admin()));

drop policy if exists "Admins can insert products" on public.products;
create policy "Admins can insert products"
  on public.products for insert to authenticated
  with check ((select public.is_admin()));

drop policy if exists "Admins can update products" on public.products;
create policy "Admins can update products"
  on public.products for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

grant select, insert, update on public.products to authenticated;
revoke delete on public.products from authenticated;

drop policy if exists "Admins can read all reviews" on public.product_reviews;
create policy "Admins can read all reviews"
  on public.product_reviews for select to authenticated
  using ((select public.is_admin()));

drop policy if exists "Admins can moderate reviews" on public.product_reviews;
create policy "Admins can moderate reviews"
  on public.product_reviews for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

grant select on public.product_reviews to authenticated;
grant update (status) on public.product_reviews to authenticated;

drop policy if exists "Admins can read all orders" on public.orders;
create policy "Admins can read all orders"
  on public.orders for select to authenticated
  using ((select public.is_admin()));

drop policy if exists "Admins can read all order items" on public.order_items;
create policy "Admins can read all order items"
  on public.order_items for select to authenticated
  using ((select public.is_admin()));

grant select on public.orders, public.order_items to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pawche-products',
  'pawche-products',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Anyone can view Pawche product images" on storage.objects;
create policy "Anyone can view Pawche product images"
  on storage.objects for select
  using (bucket_id = 'pawche-products');

drop policy if exists "Admins can upload Pawche product images" on storage.objects;
create policy "Admins can upload Pawche product images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'pawche-products'
    and (select public.is_admin())
  );

drop policy if exists "Admins can replace Pawche product images" on storage.objects;
create policy "Admins can replace Pawche product images"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'pawche-products'
    and (select public.is_admin())
  )
  with check (
    bucket_id = 'pawche-products'
    and (select public.is_admin())
  );

drop policy if exists "Admins can delete Pawche product images" on storage.objects;
create policy "Admins can delete Pawche product images"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'pawche-products'
    and (select public.is_admin())
  );
