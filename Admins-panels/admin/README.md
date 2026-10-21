# Lovelle Admin Studio (HTML / CSS / JavaScript)

This is a separate web admin panel for the Lovelle Flutter customer app. It does not modify the Flutter app or its files.

## Files
- `index.html` — page structure and screens
- `style.css` — responsive pastel Lovelle design
- `config.js` — Supabase project URL, publishable/anon key, authorized admin email, and product image bucket
- `script.js` — navigation, Supabase Auth, data loading, product editing, order status updates, and customer list
- `README.md` — setup and security notes

## Run locally
1. Place the `admin` folder beside your Flutter project folder (or inside your existing `PROJECT FINAL/admin` folder).
2. Open `admin/index.html` using VS Code Live Server. Avoid opening it as `file://` if your browser blocks external scripts or authentication redirects.
3. Before the first login, open `config.js` and set `url`, `key`, and `adminEmail`. The Settings screen is behind authentication, so first-time connection setup must be done in this file. After signing in, you can update the saved connection settings from the Settings screen.
4. Use the Supabase project URL and publishable/anon key from the same project as the Flutter customer app.
5. Create an administrator account through Supabase Authentication (Dashboard → Authentication → Users) or the approved sign-up flow, then set that exact email as `adminEmail` in `config.js`.
6. Sign in with that administrator's email and password.
7. Apply the migrations in `supabase/migrations` in timestamp order. `20261020211000_product_images_storage.sql` creates the public `product-images` bucket and admin role; `20261021090000_admin_customer_access_and_cod.sql` enforces owner/admin access, atomic COD orders, and safe customer cancellation. These migrations assume the project already has the expected tables/columns. Product images are saved as public URLs in `products.image_url`.

## Important: current project limitations found during inspection
The uploaded project has a Supabase client in `lib/config/app_config.dart`, a `SupabaseService` that reads/writes tables such as `products`, `categories`, `profiles`, `orders`, and `order_items`, and multiple migrations related to customer access and PayMongo. The README explicitly notes that the repository does not contain a complete baseline database schema or complete RLS setup. The included customer-facing RLS policies are not an admin authorization system.

Therefore:
- This dashboard uses the publishable/anon key and the signed-in Supabase Auth session.
- `adminEmail` in `config.js` only controls the sign-in UI; database policies use the server-side role table and are the actual access control.
- The database must enforce admin permissions using Row Level Security (RLS) policies or a proper server-side admin role.
- `config.js` is loaded by the browser and is not a secret store. Only put the Supabase publishable/anon key there; never put a `service_role` key or PayMongo secret key in it.
- If reads or writes fail with permission errors, configure the correct policies in Supabase first. The dashboard deliberately does not bypass them.
- Product fields expected by the current code include `name`, `description`, `price`, `image_url`, `stock_quantity`, `is_available`, `is_featured`, and `category_id`.
- The customer app currently normalizes product prices to ₱1 when prices are positive, according to `lib/models/product.dart`. The admin panel shows the actual database price. Decide whether this demo-price behavior should remain before treating the displayed admin price as the customer-facing price.
- Order status values can vary depending on the actual database schema. The status dropdown uses common values; confirm the database constraint before using status updates.
- The customer `profiles` table may not contain an email for every account. Customer list data is limited to the columns readable by the authenticated admin session.

## Admin access and RLS
Do not grant unrestricted access to `anon` or `authenticated` for convenience. The included migrations create `public.user_roles` and `public.has_role(text)`, and assign `admin@gmail.com` the admin role. The access migration uses that database-controlled role for admin policies and restricts customer rows to their owner. Verify the actual table columns, existing policies, constraints, and account roles in staging before applying the migrations. The browser email allowlist is only a sign-in UI guard; it is not database authorization.

## What works in the front end
- Responsive admin layout with Overview, Products, Orders, Customers, and Settings.
- Supabase email/password sign-in.
- Dashboard counts and recent order / low-stock views when policies permit access.
- Product search, filtering, add, edit, and availability toggle.
- Product image picker with preview and Supabase Storage upload (JPG, PNG, WebP, or GIF up to 5 MB).
- Order search, detail view, and status update.
- Customer search and a basic order-count / spend summary.
- Error messages when Supabase tables or permissions are unavailable.

All data actions depend on the real project schema and RLS policies; test with non-production data first.
