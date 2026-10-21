alter table public.paymongo_payment_sessions
  add column if not exists payment_intent_id text,
  add column if not exists order_id text;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'paymongo_payment_sessions'
      and column_name = 'source_id'
  ) then
    alter table public.paymongo_payment_sessions
      alter column source_id drop not null;
  end if;
end
$$;

alter table public.paymongo_payment_sessions
  drop constraint if exists paymongo_payment_sessions_amount_check;

alter table public.paymongo_payment_sessions
  add constraint paymongo_payment_sessions_amount_check
  check (amount >= 100);

create unique index if not exists paymongo_payment_sessions_payment_intent_id_uidx
  on public.paymongo_payment_sessions (payment_intent_id)
  where payment_intent_id is not null;
