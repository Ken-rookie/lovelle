# printify

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## PayMongo QRPh setup

The QRPh option creates a dynamic PayMongo QR for the order's server-calculated
total. The app displays it in a dialog and checks payment status every five
seconds through the `check-qrph-payment` Edge Function. That function verifies
the status directly with PayMongo and updates the order after verifying a
successful payment. A signed PayMongo webhook also updates the order; the
Flutter client never marks an order paid.

From the project root, link the Supabase project if it is not already linked,
then set the PayMongo values as Edge Function secrets. Use matching test-mode
or live-mode keys:

```powershell
npx supabase secrets set PAYMONGO_SECRET_KEY=sk_test_REPLACE_ME PAYMONGO_PUBLIC_KEY=pk_test_REPLACE_ME PAYMONGO_WEBHOOK_SECRET=whsk_REPLACE_ME PAYMONGO_MODE=test
npx supabase functions deploy submit-print-order
npx supabase functions deploy select-walkin-payment
npx supabase functions deploy create-qrph-payment
npx supabase functions deploy check-qrph-payment
npx supabase functions deploy paymongo-webhook --no-verify-jwt
```

The order function charges PHP 1 per selected file per copy, regardless of
paper size or color mode, with no additional service fee. The upload estimate
and order summary use the same calculation; payment and order history show the
server-calculated total saved when the order is created. Existing orders keep
their original totals, so create a new order to use updated pricing.

Never put `PAYMONGO_SECRET_KEY` or `PAYMONGO_WEBHOOK_SECRET` in Flutter or
commit them. Configure a PayMongo webhook pointing to
`https://YOUR_PROJECT_REF.supabase.co/functions/v1/paymongo-webhook` and enable
the `payment.paid`, `payment.failed`, and `qrph.expired` events. The webhook
endpoint validates PayMongo's signature and verifies successful payment with
the Payment Intent API before updating the order. `--no-verify-jwt` is needed
because PayMongo calls the endpoint; the function verifies the provider
signature itself.

Apply `supabase/schema.sql` to the Supabase project before deploying these
functions. It can be rerun safely to bring an existing project up to date.
Test the complete provider flow in PayMongo test mode before switching to live
keys and `PAYMONGO_MODE=live`.

The schema migration removes legacy color-mode and orientation check
constraints, if present. The `submit-print-order` Edge Function validates
these values against the app's supported options. To fix these errors directly
in Supabase SQL Editor, run:

```sql
alter table public.print_orders
  drop constraint if exists print_orders_color_mode_check,
  drop constraint if exists print_orders_orientation_check;
notify pgrst, 'reload schema';
```

If an order or payment operation reports that a `print_orders` column is
missing, run this in the Supabase SQL Editor to bring an existing table up to
date. It includes the order and payment fields as well as the fields used by
the schema's indexes. No function redeploy is needed for this schema change:

```sql
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
notify pgrst, 'reload schema';
```

If order creation reports an invalid enum value for `payment_status` or
`status`, run this after the column-addition migration above. It adds the
required values without changing column types or disturbing policies that
depend on them:

```sql
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
notify pgrst, 'reload schema';
```

After order creation, the app presents both walk-in and QRPh payment choices.
If order creation returns an error, deploy the latest `submit-print-order`
function and check its Supabase Edge Function logs for the reported database
or configuration issue.
