-- Printify schema for Supabase SQL Editor.
-- Run in a development project first and review before production.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.print_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  order_number text not null unique default ('PRT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  service_type text not null default 'Documents',
  paper_size text not null default 'A4',
  orientation text not null default 'Portrait',
  color_mode text not null default 'Color',
  print_sides text not null default 'Single-sided',
  paper_type text not null default 'Standard (80 gsm)',
  copies integer not null default 1 check (copies between 1 and 100),
  notes text,
  subtotal numeric(10,2) not null default 0 check (subtotal >= 0),
  service_fee numeric(10,2) not null default 0 check (service_fee >= 0),
  total numeric(10,2) not null default 0 check (total >= 0),
  currency text not null default 'PHP',
  status text not null default 'pending'
    check (status in ('pending','awaiting_payment','paid','received','printing','quality_check','ready','completed','cancelled','failed')),
  payment_status text not null default 'unpaid'
    check (payment_status in ('unpaid','pending','paid','failed','expired','refunded')),
  payment_provider text,
  payment_reference text,
  qr_payload text,
  qr_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.print_orders
  add column if not exists order_number text not null default ('PRT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  add column if not exists service_type text not null default 'Documents',
  add column if not exists paper_size text not null default 'A4',
  add column if not exists orientation text not null default 'Portrait',
  add column if not exists color_mode text not null default 'Color',
  add column if not exists print_sides text not null default 'Single-sided',
  add column if not exists paper_type text not null default 'Standard (80 gsm)',
  add column if not exists copies integer not null default 1,
  add column if not exists notes text,
  add column if not exists subtotal numeric(10,2) not null default 0,
  add column if not exists service_fee numeric(10,2) not null default 0,
  add column if not exists total numeric(10,2) not null default 0,
  add column if not exists currency text not null default 'PHP',
  add column if not exists status text not null default 'pending',
  add column if not exists payment_status text not null default 'unpaid',
  add column if not exists payment_provider text,
  add column if not exists payment_reference text,
  add column if not exists qr_payload text,
  add column if not exists qr_expires_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.print_orders
  drop constraint if exists print_orders_color_mode_check,
  drop constraint if exists print_orders_orientation_check;

do $$
declare
  payment_status_type text;
  order_status_type text;
begin
  select format('%I.%I', udt_schema, udt_name)
    into payment_status_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'print_orders'
      and column_name = 'payment_status'
      and data_type = 'USER-DEFINED';

  if payment_status_type is not null then
    execute format(
      'alter type %s add value if not exists %L',
      payment_status_type,
      'unpaid'
    );
  end if;

  select format('%I.%I', udt_schema, udt_name)
    into order_status_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'print_orders'
      and column_name = 'status'
      and data_type = 'USER-DEFINED';

  if order_status_type is not null then
    execute format(
      'alter type %s add value if not exists %L',
      order_status_type,
      'awaiting_payment'
    );
  end if;
end
$$;

create table if not exists public.print_order_files (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.print_orders(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  file_name text not null,
  file_size_bytes bigint not null default 0,
  file_extension text,
  storage_path text,
  page_count integer,
  created_at timestamptz not null default now()
);

create table if not exists public.order_status_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.print_orders(id) on delete cascade,
  status text not null,
  message text,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  kind text not null default 'general',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists print_orders_user_created_idx on public.print_orders(user_id, created_at desc);
create index if not exists print_orders_payment_reference_idx
  on public.print_orders(payment_reference) where payment_reference is not null;
create index if not exists print_order_files_order_idx on public.print_order_files(order_id);
create index if not exists notifications_user_created_idx on public.notifications(user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.print_orders enable row level security;
alter table public.print_order_files enable row level security;
alter table public.order_status_events enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "profiles select own" on public.profiles;
drop policy if exists "profiles update own" on public.profiles;
drop policy if exists "profiles insert own" on public.profiles;
drop policy if exists "orders select own" on public.print_orders;
drop policy if exists "orders files select own" on public.print_order_files;
drop policy if exists "order events select own" on public.order_status_events;
drop policy if exists "notifications select own" on public.notifications;
drop policy if exists "notifications update own" on public.notifications;

create policy "profiles select own" on public.profiles for select to authenticated using (auth.uid() = id);
create policy "profiles update own" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy "profiles insert own" on public.profiles for insert to authenticated with check (auth.uid() = id);

create policy "orders select own" on public.print_orders for select to authenticated using (auth.uid() = user_id);
create policy "orders files select own" on public.print_order_files for select to authenticated using (auth.uid() = user_id);
create policy "order events select own" on public.order_status_events for select to authenticated
  using (exists (select 1 from public.print_orders o where o.id = order_id and o.user_id = auth.uid()));
create policy "notifications select own" on public.notifications for select to authenticated using (auth.uid() = user_id);
create policy "notifications update own" on public.notifications for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Intentionally do not permit direct client insert/update of orders or payment state.
-- Edge Functions using service role must validate auth, file metadata, and pricing.
-- Create a private storage bucket named print-files and upload through a validated
-- authenticated flow; avoid making print files public.

notify pgrst, 'reload schema';
