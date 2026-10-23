create table if not exists public.product_wishlist (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_slug text not null references public.products(slug) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_slug)
);

create index if not exists product_wishlist_user_created_idx
  on public.product_wishlist (user_id, created_at desc);

alter table public.product_wishlist enable row level security;

drop policy if exists "Customers can view their own wishlist"
  on public.product_wishlist;
create policy "Customers can view their own wishlist"
  on public.product_wishlist for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "Customers can save active products to their wishlist"
  on public.product_wishlist;
create policy "Customers can save active products to their wishlist"
  on public.product_wishlist for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.products
      where products.slug = product_wishlist.product_slug
        and products.is_active
    )
  );

drop policy if exists "Customers can remove products from their wishlist"
  on public.product_wishlist;
create policy "Customers can remove products from their wishlist"
  on public.product_wishlist for delete to authenticated
  using (user_id = (select auth.uid()));

grant select, insert, delete on public.product_wishlist to authenticated;
