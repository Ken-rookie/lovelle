alter table public.profiles
  add column if not exists address_line text,
  add column if not exists city text;

update public.profiles as profile
set
  address_line = coalesce(profile.address_line, saved.address_line),
  city = coalesce(profile.city, saved.city)
from (
  select distinct on (customer_id)
    customer_id,
    address_line,
    city
  from public.addresses
  order by customer_id, is_default desc
) as saved
where profile.id = saved.customer_id
  and (profile.address_line is null or profile.city is null);
