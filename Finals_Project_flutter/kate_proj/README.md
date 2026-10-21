# Lovelle Customer App

Flutter customer-only gifting app with email/password sign-in, catalog browsing, wishlist, cart, cash-on-delivery checkout, order history, profile, and saved addresses. No admin screens or admin account logic are included.

## 1. Configure Supabase

Open `lib/config/app_config.dart` and set:

- `supabaseUrl` to your Supabase Project URL.
- `supabasePublishableKey` to your anon/publishable key from **Project Settings → API**.

Never put the `service_role` key in a mobile app.

## 2. Database

The repository does **not** currently include a baseline schema for all app tables. The migrations under `supabase/migrations` assume that the existing Supabase project already has the tables and columns used by the app. They are not enough to provision a fresh project. Before deployment, check in and review the canonical schema, indexes, constraints, triggers, grants, and row-level security policies for `profiles`, `categories`, `products`, `wishlist`, `cart_items`, `addresses`, `orders`, `order_items`, `reviews`, and `customer_settings`.

For product cards, populate `products` with a `name`, `price`, `image_url`, `description`, `stock_quantity`, `is_available`, `is_featured`, and optional `category_id`. Add product images to a public Supabase Storage bucket or another image host and save the URL in `image_url`.

Apply migrations in timestamp order. The rose migrations add rose gift checkout options and seed a sample **Lovelle Rose Gift** (₱499, 20 in stock); change its price, stock, and image in Supabase to match your store. Apply `20261020211000_product_images_storage.sql` to configure the `product-images` Storage bucket, then `20261021090000_admin_customer_access_and_cod.sql` to enforce owner/admin row access and create atomic cash-on-delivery and customer cancellation operations. The home screen refreshes its product catalog every 30 seconds, so updated names and photo URLs appear without restarting the app or enabling Supabase Realtime. Product photo URLs are read from `products.image_url`; use the admin image picker to upload a photo and update that field. The sample rose migration preserves a non-empty image URL if it is rerun.

## 3. Run

```bash
flutter pub get
flutter run
```

## 4. PayMongo QRPH

Store PayMongo credentials only as Supabase Edge Function secrets:
`PAYMONGO_SECRET_KEY` and `PAYMONGO_PUBLIC_KEY`. Never add them to the Flutter
app or a database table readable by clients. Apply the payment-session
migration, deploy the `paymongo` Edge Function, and make sure the function's
standard Supabase environment variables are available before enabling checkout.
Add the two PayMongo values in **Supabase Dashboard → Edge Functions → Secrets**.
With the Supabase CLI linked to this project, apply the migration and deploy the
function using `supabase db push` and `supabase functions deploy paymongo`.

This uses PayMongo's QR Ph Payment Intent flow with a five-minute QR expiry.
Paid orders are finalized in a server-side database transaction after PayMongo
confirms the intent as succeeded.

## 5. Android release configuration

Android release builds are blocked unless a registered application ID and release signing properties are configured. Keep `android/key.properties` and the keystore out of version control. Create `android/key.properties` locally with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`; pass the registered application ID with `-PlovelleApplicationId=...` or `LOVELLE_APPLICATION_ID`. Debug builds retain the development application ID.

## Production release gates

- Enable Email/Password in Supabase Authentication and verify email confirmation and password-reset redirect settings.
- Deploy and test the PayMongo Edge Function with PayMongo test credentials before using it; the repository does not deploy functions or migrations automatically.
- Apply and verify the admin/customer access migration on the target Supabase project. It assumes existing tables and columns, and an admin role established by the product image storage migration.
- The atomic COD and cancellation RPCs require the new migration to be applied before releasing the updated app. Cancelling a pending COD order also restores its reserved stock; paid PayMongo orders cannot be cancelled through this flow because refunds must be handled separately.
- The repository has no baseline schema or review-table RLS policies. Confirm the existing schema and separately secure reviews and any other tables before production.
- Set the production Android, iOS, and macOS bundle identifiers before store distribution; the current identifiers are development placeholders.
- Configure release signing separately for each platform and test the release build on supported devices/browsers. Do not share signing keys or service-role credentials.
