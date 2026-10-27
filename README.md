# E-Commerce Flutter Application

A full Flutter e-commerce application with separate buyer and seller experiences. The app uses Supabase for authentication, database storage, row-level security, product images, order processing, notifications, reviews, and realtime buyer-seller messaging.

## Features

### Buyer features

- Create a Buyer or Seller account and sign in with email and password.
- Reset a forgotten password by email.
- Browse products and popular products.
- Search products with text or voice input.
- Filter by category, price, offer status, and sort order.
- Open product details with seller information, discount pricing, related products, likes, and reviews.
- Add products to a persistent cart, change quantities, and remove products.
- Checkout with name, email, phone, and delivery address details.
- Place cash-on-delivery orders, pay through Razorpay Standard Checkout, or display a fixed-amount UPI QR code for scanning from another device.
- View order history with a progress tracker for `pending`, `paid`, `packed`, `shipped`, `out for delivery`, and `delivered`.
- Request a return for an eligible delivered item and follow return status updates.
- Receive order and return notifications.
- Message a seller about an order or product. The `messaging` Edge Function sends and loads messages, and Supabase Realtime keeps conversations up to date.
- Edit profile details, change password, switch theme, and delete the account.

### Seller features

- Seller accounts open directly to the seller workspace after login.
- View a dashboard with stock, sales, customer, delivery, revenue, pending payment, and top-product information.
- Filter dashboard data by country, state, and city.
- Add, edit, and delete products.
- Set product name, price, discount price, category, subcategory, description, quantity, and image URL.
- Upload product images to the Supabase Storage `product-images` bucket.
- Search and filter seller products.
- View buyer orders and filter them by search text and status.
- Update order status and automatically notify the buyer.
- View return requests, change return status, and notify the buyer.
- Message buyers while the order conversation is available.

## Project Description

This project is a two-sided marketplace:

1. A buyer discovers products, manages a cart, checks out, tracks delivery, reviews products, and communicates with sellers.
2. A seller manages inventory, monitors business activity, processes orders, handles returns, and communicates with buyers.
3. Supabase Auth identifies users. The `users.role` value determines whether the app opens the buyer home screen or the seller dashboard.
4. Supabase Row Level Security (RLS) protects user profiles, products, carts, orders, messages, returns, and notifications.
5. Checkout is performed by the database `place_order` function so stock validation, order creation, order items, and inventory reduction happen atomically. Razorpay standard and QR payments are created and verified by the `supabase-razorpay` Edge Function; confirmed payments are mirrored in the RLS-protected `payments` ledger.
6. The `messaging` Edge Function calls authenticated database RPCs for sending and loading buyer-seller conversations.

## Technology Stack

- Flutter and Dart
- Material 3
- Provider for application state management
- Supabase Flutter for Auth, Postgres, Storage, and Realtime
- `razorpay_flutter` for Razorpay's mobile checkout
- `flutter_dotenv` for local environment configuration
- `image_picker` and `file_selector` for product images
- `speech_to_text` for voice search
- `flutter_animate` for UI animation

## Project Structure

```text
lib/
  main.dart                         App startup, Supabase setup, themes, providers
  data/catalog.dart                 Product categories and catalog constants
  provider/
    authprovider.dart               Sign up, login, logout, password reset, roles
    cardeprovider.dart              Cart loading and quantity management
    messageprovider.dart            Contacts, chat, sending, realtime messages
    orderditiyalce.dart             Checkout, orders, returns, dashboard, notifications
    razorpayprovider.dart           Razorpay checkout SDK and payment callbacks
    productprovider.dart            Products, likes, images, popular and related products
    reviewprovider.dart             Product reviews
    themeprovider.dart              Light and dark theme state
    userprovider.dart               Profile and password operations
  screens/
    home_screen.dart                Buyer home, search, navigation, voice search
    filter_screen.dart              Product filters and sorting
    product_details_screen.dart     Product information, reviews, related products
    cart_screen.dart                Cart management
    product_checkout_screen.dart    Delivery form, COD, Standard Checkout, and UPI QR payment
    order_tracking_screen.dart      Buyer orders and delivery progress
    message_screen.dart              Contacts and chat screen
    notifications_screen.dart       Order and return notifications
    sellerscreen.dart               Seller dashboard and seller workspace
    account_screen.dart              Profile settings
    login_screen.dart                Login and password reset
    singup_screen.dart               Registration and role selection
  utils/
    error_handling.dart              User-friendly Supabase and network errors
    currency.dart                    Currency formatting
    date_format.dart                 Order date formatting
    product_pricing.dart              Price and discount helpers
  widgets/                           Shared product, seller, error, and image widgets
supabase_schema.sql                  Database tables, policies, triggers, and RPCs
supabase/migrations/20261027_razorpay_tables.sql
                                      Payment ledger, RLS, timestamp trigger, QR confirmation RPC
supabase_razorpay.js                 Dashboard-pasteable Razorpay Edge Function source
supabase/functions/
  supabase-razorpay/index.ts         Razorpay order creation, payment verification, and webhook handling
  messaging/index.ts                 Authenticated message send and conversation retrieval
  send-fcm/index.ts                  Optional push delivery for queued notifications
```

## Requirements

- Flutter SDK compatible with Dart `3.13.3` or newer.
- Android Studio or Android SDK with a configured emulator or physical Android phone.
- A Supabase project.
- A physical Android phone with USB debugging enabled, or an Android emulator.

## Supabase Setup

1. Create a project at [supabase.com](https://supabase.com/).
2. Open the Supabase SQL Editor.
3. For a new project, copy and run the complete contents of `supabase_schema.sql`. It includes the payment ledger and QR confirmation SQL at the end.
4. For an existing project that already ran the base schema, run `supabase/migrations/20261027_razorpay_tables.sql` once. Do not run both copies of the payment SQL unnecessarily.
5. In Supabase Storage, create a bucket named `product-images`.
6. Configure the bucket so product image URLs can be read by the app. Add Storage policies appropriate for your deployment; sellers need permission to upload their own images.
7. In Authentication, configure the email provider. During development, email confirmation can be disabled, or users can confirm the email sent by Supabase before logging in.
8. Copy the project URL and publishable key from Supabase project settings.
9. Deploy the SQL functions before deploying the matching Edge Function.
10. Deploy the Edge Functions from `supabase/functions/` with the Supabase CLI, or use the **Supabase Dashboard** editor:
   - Open **Edge Functions** in your Supabase project and choose **Deploy a new function** / **Open Editor**.
  - Create/deploy `supabase-razorpay` and paste the complete root `supabase_razorpay.js` source into its editor. The equivalent CLI source is `supabase/functions/supabase-razorpay/index.ts`.
   - Deploy `supabase/functions/messaging/index.ts` as `messaging`. Keep JWT verification enabled so only authenticated app users can call it; the function forwards the caller's authorization to the database RPCs.
   - For Razorpay, turn off Supabase's automatic JWT verification for this function because the same endpoint receives Razorpay webhooks. The handler validates signed-in app requests itself, and verifies webhook signatures separately.
11. In **Edge Function Secrets** in the Supabase Dashboard, set `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, and `SUPABASE_SERVICE_ROLE_KEY` for `supabase-razorpay`. Use Razorpay **Test Mode** credentials; the key ID must start with `rzp_test_`. Set the Razorpay webhook URL to `https://<project-ref>.supabase.co/functions/v1/supabase-razorpay` and enable both `payment.captured` and `qr_code.credited` events. Never put the Razorpay secret, webhook secret, or service-role key in the Flutter app or `.env`.

The `supabase-razorpay` function dispatches app actions `place-order`, `create-razorpay-order`, `create-razorpay-qr`, `razorpay-payment-status`, `cancel-razorpay-qr`, and `verify-razorpay-payment` from the JSON `action` field. Razorpay webhook requests use the same URL and are routed by their signature/event headers. The function creates Razorpay orders and fixed-amount UPI QR codes using server-held credentials, verifies payments, and confirms status in the database. The QR flow displays Razorpay's hosted QR image and polls the authenticated status action; payment confirmation comes only from the verified webhook.

The `messaging` function supports `send`, `get_messages`, and `get_recent_messages` actions. It forwards the signed-in user's authorization to the `send_message`, `get_messages`, and `get_recent_messages` database RPCs; those RPCs and RLS policies enforce access. The Flutter app invokes this function from `lib/provider/messageprovider.dart`. Supabase Realtime is used to keep message conversations updated after messages are stored.

The optional `send-fcm` function processes queued push notifications. Configure its `SUPABASE_SERVICE_ROLE_KEY` secret before deploying it. Push delivery also requires `FIREBASE_SERVER_KEY`; without that secret, notifications remain available through the database and Supabase Realtime. Do not expose either server secret in the Flutter app.

The schema includes:

- A signup trigger that creates a row in `public.users`.
- RLS policies for buyer and seller access.
- Realtime publication for `public.messages`.
- `place_order` for transactional checkout and stock reduction.
- The `payments` table stores provider references and payment state with owner-only RLS. A trigger maintains `updated_at` and mirrors order payment transitions.
- Razorpay payment confirmation is checked server-side against the signed callback/webhook and captured-payment amount. The database records payment and order state atomically while locking the order row.
- `send_message`, `get_messages`, and `get_recent_messages` for authenticated buyer-seller messaging through the `messaging` Edge Function.
- `popular_products` for popular product results.
- `recommended_products` for related product results.

## Environment Configuration

Create a file named `.env` in the project root. Do not commit it.

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-or-anon-key
RAZORPAY_KEY_ID=rzp_test_your_key_id
```

The app reads the Supabase values in `lib/main.dart`. `RAZORPAY_KEY_ID` is the public Test Mode key ID used by Flutter and is also configured as a Supabase Edge Function secret. The Razorpay key secret, webhook secret, and Supabase service-role key must only be stored as Supabase Edge Function secrets; never add them to the Flutter `.env` file. Use your own test credentials in `.env`; the example file contains placeholders only.

## Install and Run

From the project root:

```bash
flutter pub get
flutter devices
flutter run
```

Run static analysis and tests with:

```bash
flutter analyze
flutter test
```

## Run on an Android Phone

### Windows and Android Studio method

1. Install Flutter, Android Studio, and the Android SDK.
2. On the phone, open **Settings > About phone** and tap **Build number** seven times to enable Developer options.
3. Open **Developer options** and enable **USB debugging**.
4. Connect the phone to the computer with a USB cable.
5. Accept the phone's USB debugging authorization prompt.
6. From the project directory, confirm that Flutter sees the phone:

```bash
flutter devices
```

7. Run the app on the phone:

```bash
flutter run -d YOUR_DEVICE_ID
```

You can also select the phone in the VS Code device picker and press `F5`.

### Wireless debugging

On Android 11 and newer, enable **Wireless debugging** in Developer options, pair the phone with Android Studio or `adb`, then confirm it appears in `flutter devices` before running `flutter run`.

### Release APK

To create an installable release APK:

```bash
flutter build apk --release
```

The APK is generated under `build/app/outputs/flutter-apk/`. Configure signing before distributing a production build.

## Android Permissions

The Android app requests permissions needed by implemented features:

- Internet for Supabase and product images.
- Camera and media access for selecting product images.
- Microphone access for voice search.

Android may show permission prompts when a feature is used. Denying a permission does not prevent normal browsing, cart, checkout, or order tracking, but the related camera, image, or voice feature will not work.

## Database Table Structure

The complete SQL definition is in `supabase_schema.sql`.

| Table | Purpose | Main relationships |
| --- | --- | --- |
| `users` | Buyer and seller profiles and roles | `id` references `auth.users.id` |
| `product` | Seller-owned catalog products and inventory | `user_id` references `auth.users.id` |
| `product_reviews` | Ratings and comments | `product_id` references `product.id`; one review per user/product |
| `product_likes` | Buyer product likes | Composite key: `user_id`, `product_id` |
| `cart_items` | Persistent buyer cart | Unique `user_id`, `product_id` |
| `orders` | Customer delivery details, total, payment, and status | `user_id` references `auth.users.id` |
| `payments` | Razorpay order/QR references, amount, and payment status | `order_id` references `orders.id`; `user_id` references `auth.users.id` |
| `order_items` | Product snapshots belonging to an order | References `orders`, `product`, and seller |
| `notifications` | Buyer updates for orders and returns | Optional `order_id` reference |
| `return_requests` | Item-level return workflow | References `order_items`, buyer, and seller |
| `messages` | Buyer-seller chat messages | Optional order and product references |

### Important statuses

- Order statuses: `pending`, `packed`, `shipped`, `out for delivery`, `delivered`, `cancelled`.
- Return statuses: `requested`, `pickup`, `checked`, `replacement packed`, `replacement shipped`, `shipped`, `payment done`, `rejected`.
- Roles: `Buyer` and `Seller`.

## Error Handling

Errors are translated into user-facing messages through `lib/utils/error_handling.dart` and provider-specific authentication handling.

- Missing `.env` values or Supabase startup failures show a startup error screen.
- Invalid login, unknown email, duplicate email, invalid email, password, and reset-email failures receive specific authentication messages.
- Out-of-stock checkout failures are converted to a cart review message.
- Supabase permission and RLS errors explain that the current user cannot perform the action.
- Network, timeout, socket, and host lookup errors explain that the user should check the connection.
- Screen-level load failures show an error state with a retry action.
- Provider actions expose errors through `errorMessage`, snackbars, or inline error states.
- Checkout uses a database transaction and row locks, preventing partial order creation when stock is unavailable.

For a production app, keep detailed server logs private and show users the safe messages already used by the app.

## Security Notes

- Keep `.env` out of source control. It is ignored by `.gitignore`.
- Use the Supabase publishable/anon key in the Flutter client; never place a service-role key in the app.
- Keep RLS enabled on every public table.
- Review Storage policies before allowing public image uploads.
- Configure email redirect URLs and production authentication settings in Supabase before release.
- Test buyer and seller accounts separately to verify RLS policies and role-based navigation.

## Troubleshooting

### The app shows a startup configuration error

Confirm that `.env` exists in the project root and contains both `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. Then stop and rerun the app.

### The splash screen cannot refresh a saved login

If the app reports that the Supabase server address cannot be found, verify that `SUPABASE_URL` in `.env` exactly matches the **Project URL** shown in the Supabase Dashboard under **Project Settings > API**. Confirm the project is active and the device has internet access, then rebuild and reinstall the app so the updated `.env` asset is included. The login screen remains available while the connection is unavailable, but authentication and app data require a working Supabase endpoint.

### Login succeeds but the wrong screen opens

Check the user's `public.users.role` value. It must be exactly `Buyer` or `Seller`, matching the schema check constraint.

### Products or orders do not load

Confirm that the SQL schema was run completely, the user is authenticated, and the relevant RLS policies exist. Check the Supabase logs for denied requests.

### Product image upload fails

Confirm that the `product-images` bucket exists and that authenticated sellers have Storage insert permission. Also check Android camera and media permissions.

### Checkout fails with an RPC error

Confirm that `place_order(jsonb, jsonb)` exists and that authenticated users have execute permission. Also verify that every product has enough stock and that the cart is not empty.

### Messages are not realtime

Confirm that the `messaging` Edge Function is deployed with JWT verification enabled, the message RPCs from `supabase_schema.sql` exist, and the caller is signed in. Also confirm that `public.messages` was added to the Supabase Realtime publication and that the user is allowed to read the conversation through the messages RLS policies.

### Razorpay checkout cannot start or payment is not confirmed

Confirm that `supabase-razorpay` is deployed, the Flutter `.env` contains a `RAZORPAY_KEY_ID` beginning with `rzp_test_`, and the Razorpay key ID and key secret in Supabase Edge Function secrets belong to the same Test Mode account. For webhook-based confirmation, also configure `RAZORPAY_WEBHOOK_SECRET`, use the function URL shown above, and enable the `payment.captured` event. Check the Supabase Edge Function logs for server-side errors.

## License

No license has been selected for this project yet. Add a license before publishing the repository for external use.
