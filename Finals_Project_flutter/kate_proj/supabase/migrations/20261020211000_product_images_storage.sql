create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('user', 'admin'))
);

alter table public.user_roles enable row level security;
revoke all on table public.user_roles from public, anon, authenticated;

create or replace function public.has_role(required_role text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = required_role
  );
$$;

revoke all on function public.has_role(text) from public, anon;
grant execute on function public.has_role(text) to authenticated;

do $$
begin
  if not exists (
    select 1
    from auth.users
    where lower(email) = 'admin@gmail.com'
  ) then
    raise exception 'Create the admin@gmail.com Auth account before applying this migration.';
  end if;
end
$$;

insert into public.user_roles (user_id, role)
select id, case lower(email)
  when 'admin@gmail.com' then 'admin'
  else 'user'
end
from auth.users
where lower(email) in ('admin@gmail.com', 'kate@gmail.com')
on conflict (user_id) do update
set role = excluded.role;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'product-images',
  'product-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists product_images_public_read on storage.objects;
create policy product_images_public_read
  on storage.objects
  for select
  to public
  using (bucket_id = 'product-images');

drop policy if exists product_images_admin_upload on storage.objects;
create policy product_images_admin_upload
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'product-images'
    and (select public.has_role('admin'))
  );

drop policy if exists product_images_admin_update on storage.objects;
create policy product_images_admin_update
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'product-images'
    and (select public.has_role('admin'))
  )
  with check (
    bucket_id = 'product-images'
    and (select public.has_role('admin'))
  );

drop policy if exists product_images_admin_delete on storage.objects;
create policy product_images_admin_delete
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'product-images'
    and (select public.has_role('admin'))
  );
