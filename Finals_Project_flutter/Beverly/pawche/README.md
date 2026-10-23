# Pawché Customer Flutter App

Customer-facing Flutter starter based on the supplied UI flow. No admin dashboard.

## Run
1. Install Flutter SDK.
2. Run `flutter pub get` then `flutter run`.
3. Paste your Supabase project URL and publishable (anon) key into `lib/config/app_config.dart`, replacing the key placeholder, then run `flutter run`. Authentication requires Supabase configuration. No `--dart-define` arguments are needed. Use only a client-safe publishable/anon key; never put a service-role key in the app.

Use only the Supabase anon/publishable key in the app, never the service-role or PayMongo secret keys. Authentication, product catalog/images/stock, customer wishlist, reviews, delivery details, stock reservation, and orders use Supabase. Pet profiles remain local. Checkout supports saved delivery details, server-priced COD orders, and PayMongo-hosted QRPH payment. QRPH orders remain pending until the PayMongo webhook is verified against the live PayMongo API. The app does not treat the browser return as proof of payment.

## Product catalog and reviews
The catalog migration seeds the initial catalog at PHP 1 and sets the requested minimum stock. The customer app reads current names, prices, images, active state, and stock from Supabase; it does not substitute local sample product data when the database is unavailable. Delivery remains free. Customer reviews remain pending until moderated. Apply this migration before the live-checkout migration below.

The customer wishlist is stored per authenticated user in Supabase. Apply `20261022120000_customer_product_wishlist.sql` to create its table and owner-only row-level security policies. The cart keeps quantities for the current app session and refreshes product names, prices, images, and stock from the active Supabase catalog when opened and again before checkout; checkout is blocked if current product details cannot be verified.

The checkout address selectors use a bundled Bohol municipalities/city and barangays snapshot from the public [GitLab barangay dataset](https://gitlab.com/greggicay/get-all-barangays-in-the-philippines/-/blob/main/ph-barangays-async.csv) (48 municipality/city groups, 1,109 barangays in the snapshot). The data is bundled offline so checkout does not depend on a third-party API; verify changes to local administrative boundaries before relying on it for production delivery. If you already ran the live-checkout SQL, rerun the updated `20261022100000_live_checkout.sql` so saved-address and order records include barangay and the checkout function accepts the new location fields.

## Live checkout deployment
The source integration is ready, but it will not accept live orders until deployed and configured in your Supabase project:

1. Apply the product catalog, live-checkout, PayMongo QRPH, and wishlist migrations in order (with the Supabase CLI commands below, or once each in the SQL Editor). The checkout migration creates private customer addresses, order snapshots and order items; only the owning customer can read them. If it finds incompatible pre-existing tables with those names, it preserves them as `customer_addresses_legacy_pre_live_checkout`, `orders_legacy_pre_live_checkout`, and/or `order_items_legacy_pre_live_checkout` before creating the checkout schema. A server-only Postgres function atomically validates live prices/stock, reserves inventory and saves the address. The QRPH migration stores payment-intent IDs and safely expires QR orders after five minutes.
2. From this project folder, link the Supabase CLI to your project and deploy `create-checkout`, `check-qrph-payment`, `paymongo-webhook`, and `expire-checkouts`:
   ```powershell
   supabase link --project-ref <project-ref>
   supabase db push
   supabase functions deploy create-checkout
   supabase functions deploy check-qrph-payment
   supabase functions deploy paymongo-webhook
   supabase functions deploy expire-checkouts
   ```
   The supplied `supabase/config.toml` disables JWT verification only for the provider webhook and scheduled cleanup endpoint; the cleanup endpoint separately requires its secret bearer token.
3. In PayMongo, finish account verification and enable QRPH for the live account. Configure Supabase Edge Function secrets (do not put them in Flutter or commit them): `PAYMONGO_SECRET_KEY` (`sk_live_...`), `PAYMONGO_PUBLIC_KEY` (`pk_live_...`), and a strong random `CHECKOUT_CLEANUP_SECRET`. Use the Supabase dashboard's Edge Function Secrets page or `supabase secrets set`; never paste secret values into chat or source control.
4. Add a PayMongo webhook pointing to `https://<project-ref>.supabase.co/functions/v1/paymongo-webhook` and subscribe to `payment.paid`. The function retrieves the PaymentIntent from PayMongo using the server-only secret and checks live mode and the exact order amount before marking the order paid. Keep `checkout_session.payment.paid` enabled if older hosted-checkout orders are still in progress.
5. Schedule `POST https://<project-ref>.supabase.co/functions/v1/expire-checkouts` with `Authorization: Bearer <CHECKOUT_CLEANUP_SECRET>` every few minutes using Supabase Scheduled Functions or an equivalent trusted scheduler. PayMongo does not send an expiry webhook; this job expires abandoned sessions before releasing reserved stock.

The scheduled cleanup now checks and cancels expired PaymentIntents before releasing stock; deploy the updated `expire-checkouts` function and apply the new migration before enabling five-minute QR expiry.

Cash on Delivery creates a confirmed order with payment due on delivery. QRPH creates a single-use dynamic PayMongo QR that is shown in-app for five minutes; the app checks payment status every five seconds, while the webhook independently confirms successful payment. All server-side totals come from the current products table; the client-submitted price is never trusted. Delivery remains free. Verify the full flow in a controlled environment before allowing customer use; this repository cannot deploy to or configure your Supabase/PayMongo accounts.

## Files
`lib/main.dart`, `config/`, `theme/`, `models/`, `data/`, `widgets/`, and one file per screen under `screens/`.
Reference-derived pet and product image crops are stored in `assets/images/` and registered in `pubspec.yaml`.
