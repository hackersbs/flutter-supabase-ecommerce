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
- Place cash-on-delivery orders.
- View order history with a progress tracker for `pending`, `packed`, `shipped`, `out for delivery`, and `delivered`.
- Request a return for an eligible delivered item and follow return status updates.
- Receive order and return notifications.
- Message a seller about an order or product. Messages update through Supabase Realtime.
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
5. Checkout is performed by the database `place_order` function so stock validation, order creation, order items, and inventory reduction happen atomically.

## Technology Stack

- Flutter and Dart
- Material 3
- Provider for application state management
- Supabase Flutter for Auth, Postgres, Storage, and Realtime
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
    productprovider.dart            Products, likes, images, popular and related products
    reviewprovider.dart             Product reviews
    themeprovider.dart              Light and dark theme state
    userprovider.dart               Profile and password operations
  screens/
    home_screen.dart                Buyer home, search, navigation, voice search
    filter_screen.dart              Product filters and sorting
    product_details_screen.dart     Product information, reviews, related products
    cart_screen.dart                Cart management
    product_checkout_screen.dart    Delivery form and checkout
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
```

## Requirements

- Flutter SDK compatible with Dart `3.13.3` or newer.
- Android Studio or Android SDK with a configured emulator or physical Android phone.
- A Supabase project.
- A physical Android phone with USB debugging enabled, or an Android emulator.

## Supabase Setup

1. Create a project at [supabase.com](https://supabase.com/).
2. Open the Supabase SQL Editor.
3. Copy and run the complete contents of `supabase_schema.sql`.
4. In Supabase Storage, create a bucket named `product-images`.
5. Configure the bucket so product image URLs can be read by the app. Add Storage policies appropriate for your deployment; sellers need permission to upload their own images.
6. In Authentication, configure the email provider. During development, email confirmation can be disabled, or users can confirm the email sent by Supabase before logging in.
7. Copy the project URL and publishable key from Supabase project settings.

The schema includes:

- A signup trigger that creates a row in `public.users`.
- RLS policies for buyer and seller access.
- Realtime publication for `public.messages`.
- `place_order` for transactional checkout and stock reduction.
- `popular_products` for popular product results.
- `recommended_products` for related product results.

## Environment Configuration

Create a file named `.env` in the project root. Do not commit it.

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-or-anon-key
```

The app reads these values in `lib/main.dart`. If either value is missing, the app shows a startup configuration error instead of attempting to connect.

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

### Login succeeds but the wrong screen opens

Check the user's `public.users.role` value. It must be exactly `Buyer` or `Seller`, matching the schema check constraint.

### Products or orders do not load

Confirm that the SQL schema was run completely, the user is authenticated, and the relevant RLS policies exist. Check the Supabase logs for denied requests.

### Product image upload fails

Confirm that the `product-images` bucket exists and that authenticated sellers have Storage insert permission. Also check Android camera and media permissions.

### Checkout fails with an RPC error

Confirm that `place_order(jsonb, jsonb)` exists and that authenticated users have execute permission. Also verify that every product has enough stock and that the cart is not empty.

### Messages are not realtime

Confirm that `public.messages` was added to the Supabase realtime publication and that the user is allowed to read the conversation through the messages RLS policies.

## License

No license has been selected for this project yet. Add a license before publishing the repository for external use.
