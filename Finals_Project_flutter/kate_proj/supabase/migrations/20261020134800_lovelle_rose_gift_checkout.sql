alter table public.products
  add column if not exists is_rose_gift boolean not null default false;

alter table public.order_items
  add column if not exists rose_type text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'order_items_rose_type_check'
      and conrelid = 'public.order_items'::regclass
  ) then
    alter table public.order_items
      add constraint order_items_rose_type_check
      check (rose_type is null or rose_type in ('fresh', 'artificial'));
  end if;
end
$$;
