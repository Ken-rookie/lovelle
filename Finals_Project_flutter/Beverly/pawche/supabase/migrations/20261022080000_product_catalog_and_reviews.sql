create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  category text not null,
  description text not null,
  price numeric(12, 2) not null check (price >= 0),
  currency text not null default 'PHP',
  image_url text,
  stock_quantity integer check (stock_quantity is null or stock_quantity >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- CREATE TABLE IF NOT EXISTS does not add columns to a pre-existing catalog.
alter table public.products
  add column if not exists id uuid not null default gen_random_uuid(),
  add column if not exists sku text,
  add column if not exists slug text,
  add column if not exists name text not null default 'Unnamed product',
  add column if not exists category text not null default 'Uncategorized',
  add column if not exists description text not null default '',
  add column if not exists price numeric(12, 2) not null default 0,
  add column if not exists currency text not null default 'PHP',
  add column if not exists image_url text,
  add column if not exists stock_quantity integer,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

update public.products
set slug = 'legacy-' || id::text
where slug is null or char_length(trim(slug)) = 0;

update public.products
set sku = 'legacy-' || id::text
where sku is null or char_length(trim(sku)) = 0;

update public.products
set
  name = coalesce(name, 'Unnamed product'),
  category = coalesce(category, 'Uncategorized'),
  description = coalesce(description, ''),
  price = coalesce(price, 0),
  currency = coalesce(currency, 'PHP'),
  is_active = coalesce(is_active, true),
  created_at = coalesce(created_at, now()),
  updated_at = coalesce(updated_at, now());

with duplicate_slugs as (
  select
    ctid,
    row_number() over (partition by slug order by ctid) as duplicate_number
  from public.products
)
update public.products p
set slug = p.slug || '-' || p.id::text
from duplicate_slugs d
where p.ctid = d.ctid
  and d.duplicate_number > 1;

with duplicate_skus as (
  select
    ctid,
    row_number() over (partition by sku order by ctid) as duplicate_number
  from public.products
)
update public.products p
set sku = 'legacy-' || p.id::text
from duplicate_skus d
where p.ctid = d.ctid
  and d.duplicate_number > 1;

alter table public.products
  alter column sku set not null,
  alter column slug set not null,
  alter column name set not null,
  alter column category set not null,
  alter column description set not null,
  alter column price set not null,
  alter column currency set not null,
  alter column is_active set not null,
  alter column created_at set not null,
  alter column updated_at set not null;

-- NULL means inventory availability has not been provided.
alter table public.products
  alter column stock_quantity drop not null;

create unique index if not exists products_id_key
  on public.products (id);
create unique index if not exists products_sku_key
  on public.products (sku);
create unique index if not exists products_slug_key
  on public.products (slug);

do $$
declare
  product_id_type text;
begin
  select format_type(a.atttypid, a.atttypmod)
    into product_id_type
  from pg_catalog.pg_attribute a
  where a.attrelid = 'public.products'::regclass
    and a.attname = 'id'
    and not a.attisdropped;

  execute format(
    'create table if not exists public.product_reviews (
      id uuid primary key default gen_random_uuid(),
      product_id %s not null references public.products(id) on delete cascade,
      user_id uuid not null references auth.users(id) on delete cascade,
      rating smallint not null check (rating between 1 and 5),
      title text check (title is null or char_length(title) <= 120),
      body text not null check (char_length(trim(body)) between 10 and 2000),
      status text not null default ''pending''
        check (status in (''pending'', ''approved'', ''rejected'')),
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now(),
      unique (product_id, user_id)
    )',
    product_id_type
  );
end
$$;

-- CREATE TABLE IF NOT EXISTS does not add columns to a pre-existing reviews table.
alter table public.product_reviews
  add column if not exists id uuid not null default gen_random_uuid(),
  add column if not exists rating smallint,
  add column if not exists title text,
  add column if not exists body text,
  add column if not exists status text not null default 'pending';
alter table public.product_reviews
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
declare
  product_id_type text;
  reviews_product_id_type oid;
  product_id_oid oid;
begin
  select a.atttypid, format_type(a.atttypid, a.atttypmod)
    into product_id_oid, product_id_type
  from pg_catalog.pg_attribute a
  where a.attrelid = 'public.products'::regclass
    and a.attname = 'id'
    and not a.attisdropped;

  execute format(
    'alter table public.product_reviews add column if not exists product_id %s',
    product_id_type
  );

  select a.atttypid
    into reviews_product_id_type
  from pg_catalog.pg_attribute a
  where a.attrelid = 'public.product_reviews'::regclass
    and a.attname = 'product_id'
    and not a.attisdropped;

  if reviews_product_id_type <> product_id_oid then
    if exists (
      select 1
      from public.product_reviews
      where product_id is not null
    ) then
      raise exception
        'public.product_reviews.product_id type differs from public.products.id and contains data; review data was not altered.';
    end if;

    alter table public.product_reviews
      drop constraint if exists product_reviews_product_id_fkey;

    execute format(
      'alter table public.product_reviews alter column product_id type %s using null::%s',
      product_id_type,
      product_id_type
    );
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'product_reviews_product_id_fkey'
      and conrelid = 'public.product_reviews'::regclass
  ) then
    alter table public.product_reviews
      add constraint product_reviews_product_id_fkey
      foreign key (product_id) references public.products(id)
      on delete cascade not valid;
  end if;
end
$$;

update public.product_reviews
set status = 'pending'
where status is null
   or status not in ('pending', 'approved', 'rejected');

update public.product_reviews
set status = 'pending'
where product_id is null
   or rating is null
   or rating not between 1 and 5
   or body is null
   or char_length(trim(body)) not between 10 and 2000;

alter table public.product_reviews
  alter column status set default 'pending',
  alter column status set not null;

-- Preserve existing reviews as anonymous until they are reviewed manually.
-- New reviews will always require the authenticated user's ID through RLS.
alter table public.product_reviews
  add column if not exists user_id uuid
    references auth.users(id) on delete cascade;

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'product_reviews_status_allowed_check'
      and conrelid = 'public.product_reviews'::regclass
  ) then
    alter table public.product_reviews
      add constraint product_reviews_status_allowed_check
      check (status in ('pending', 'approved', 'rejected'));
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'product_reviews_product_id_user_id_key'
      and conrelid = 'public.product_reviews'::regclass
  ) then
    alter table public.product_reviews
      add constraint product_reviews_product_id_user_id_key
      unique (product_id, user_id);
  end if;
end
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.now();
  return new;
end;
$$;

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();

drop trigger if exists product_reviews_set_updated_at on public.product_reviews;
create trigger product_reviews_set_updated_at
  before update on public.product_reviews
  for each row execute function public.set_updated_at();

create index if not exists product_reviews_public_product_created_idx
  on public.product_reviews (product_id, created_at desc)
  where status = 'approved';

alter table public.products enable row level security;
alter table public.product_reviews enable row level security;

drop policy if exists "Anyone can read active products" on public.products;
create policy "Anyone can read active products"
  on public.products for select
  using (is_active);

drop policy if exists "Anyone can read approved reviews" on public.product_reviews;
create policy "Anyone can read approved reviews"
  on public.product_reviews for select
  using (status = 'approved' or user_id = (select auth.uid()));

drop policy if exists "Customers can submit their own pending reviews"
  on public.product_reviews;
create policy "Customers can submit their own pending reviews"
  on public.product_reviews for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and status = 'pending'
    and exists (
      select 1 from public.products
      where products.id = product_reviews.product_id
        and products.is_active
    )
  );

drop policy if exists "Customers can edit their own pending reviews"
  on public.product_reviews;
create policy "Customers can edit their own pending reviews"
  on public.product_reviews for update to authenticated
  using (user_id = (select auth.uid()) and status = 'pending')
  with check (user_id = (select auth.uid()) and status = 'pending');

drop policy if exists "Customers can delete their own pending reviews"
  on public.product_reviews;
create policy "Customers can delete their own pending reviews"
  on public.product_reviews for delete to authenticated
  using (user_id = (select auth.uid()) and status = 'pending');

grant select on public.products to anon, authenticated;
grant select on public.product_reviews to anon, authenticated;
revoke insert, update, delete on public.product_reviews from authenticated;
grant insert (product_id, user_id, rating, title, body)
  on public.product_reviews to authenticated;
grant update (rating, title, body)
  on public.product_reviews to authenticated;
grant delete on public.product_reviews to authenticated;

create or replace view public.product_rating_summary
with (security_invoker = true)
as
select
  p.id as product_id,
  coalesce(round(avg(r.rating)::numeric, 1), 0) as average_rating,
  count(r.id)::integer as review_count,
  count(r.id) filter (where r.rating = 1)::integer as rating_1_count,
  count(r.id) filter (where r.rating = 2)::integer as rating_2_count,
  count(r.id) filter (where r.rating = 3)::integer as rating_3_count,
  count(r.id) filter (where r.rating = 4)::integer as rating_4_count,
  count(r.id) filter (where r.rating = 5)::integer as rating_5_count
from public.products p
left join public.product_reviews r
  on r.product_id = p.id
  and r.status = 'approved'
where p.is_active
group by p.id;

grant select on public.product_rating_summary to anon, authenticated;

insert into public.products (
  sku, slug, name, category, description, price, stock_quantity
) values
  ('PAW-P1', 'p1', 'Royal Canin Dog Food', 'Dog Food', 'Complete nutrition for adult dogs. Supports healthy skin, coat, and digestion.', 1, 3),
  ('PAW-P2', 'p2', 'Cat Food', 'Cat Food', 'Balanced everyday nutrition for happy, healthy cats.', 1, 3),
  ('PAW-P3', 'p3', 'Pet Toy Ball', 'Pet Toys', 'Colorful playtime toy for curious pets.', 1, 3),
  ('PAW-P4', 'p4', 'Grooming Supplies', 'Grooming', 'Gentle grooming essentials for your furry friend.', 1, 3),
  ('PAW-P5', 'p5', 'Cat Tree', 'Furniture', 'A cozy climbing and scratching space for cats.', 1, 3),
  ('PAW-P6', 'p6', 'Dog Bed', 'Beds', 'A soft, supportive resting spot for your dog.', 1, 3),
  ('PAW-P7', 'p7', 'Pet Carrier', 'Accessories', 'Comfortable travel carrier for everyday adventures.', 1, 3),
  ('PAW-P8', 'p8', 'Cat Litter', 'Cat Supplies', 'Everyday litter essentials for a tidy home.', 1, 3)
on conflict (slug) do update set
  sku = excluded.sku,
  name = excluded.name,
  category = excluded.category,
  description = excluded.description,
  price = excluded.price,
  stock_quantity = greatest(
    coalesce(public.products.stock_quantity, 0),
    excluded.stock_quantity
  ),
  currency = 'PHP',
  updated_at = now();

update public.products
set
  price = 1,
  currency = 'PHP',
  stock_quantity = greatest(coalesce(stock_quantity, 0), 3),
  is_active = true;
