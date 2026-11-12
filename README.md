# E-Commerce Flutter Application (E-Commerce)

A modern, full-featured Flutter e-commerce application with separate, tailored buyer and seller experiences. The app uses Supabase for authentication, PostgreSQL storage, row-level security (RLS), real-time notifications, atomic checkout, buyer-seller messaging, review management, and secure Razorpay payment processing.

---

## What's New & Key Highlights

### 1. Robust Security & Anti-Exploit Coupon System
- **SQL Injection Prevention**: Strict multi-layer regex validation (`^[A-Z0-9_-]{2,30}$`) across Flutter UI, Dart providers, Supabase Edge Functions, and PostgreSQL RPCs (`validate_coupon` & `place_order`).
- **Server-Side Price & Discount Enforcement**:
  - Subtotals are strictly recomputed on the server from database product records, eliminating client-side price tampering.
  - Hardened threshold rules: Coupons with minimum order requirements (e.g., `min_order_amount = 300`) cannot be applied to smaller orders (e.g., ₹100 items).
  - Maximum discount caps (`max_discount`) protect percentage discounts against excessive deductions.
  - Atomic single-use redemption tracking with `FOR UPDATE` row locks in `coupon_redemptions`.

### 2. Product Reviews System & RLS Fixes
- **Public & Authenticated Review Visibility**: Row-Level Security (RLS) updated so all visitors (authenticated and anonymous) can read reviews.
- **Review Creation & Management**: Authenticated users can write, edit, and delete their reviews directly from the product details screen.
- **Reviewer Profile Display**: Updated `can_read_user_profile` in PostgreSQL to permit looking up reviewer display names without permission errors.
- **Fault-Tolerant Loading**: Isolated profile name loading in `ReviewProvider` ensures reviews always render smoothly even during temporary network interruptions.

### 3. Razorpay Payment Lifecycle & Inventory Recovery
- **Zero-Secret Client Architecture**: The client `.env` does not store sensitive Razorpay secrets. Public key IDs are fetched dynamically from the `supabase-razorpay` Edge Function.
- **Automatic Stock & Coupon Recovery**: If a payment crashes, fails, or is cancelled by the user, `cancel_razorpay_order` immediately increments product quantities back into the database (`quantity = quantity + v_item.quantity`) and restores coupon redemptions.
- **Eliminated Premature Notifications**: "Order Placed" notifications are no longer dispatched when clicking the checkout button. Notifications are sent **strictly after payment verification and confirmation**.
- **Resume Payment Support**: Pending orders in the Order Tracking screen can resume Razorpay Standard Checkout (cards, netbanking, UPI) or UPI QR code payment.
- **Seller Screen & Dashboard Integration**:
  - Dynamically highlights paid orders (`Razorpay (Paid) ✅` vs `Cash on delivery`).
  - Added `paid` status to the seller workflow (`pending` ➔ `paid` ➔ `packed` ➔ `shipped` ➔ `out for delivery` ➔ `delivered`).

### 4. Cross-Platform Notification Safety (Windows 11 & Android)
- **Windows 11 Desktop Compatibility**: Device local notifications are safely bypassed on Windows desktop via `NotificationService.isSupportedOnDevice`, eliminating desktop plugin exceptions and unwanted popups.
- **Android Full Feature Support**: High-importance notification channels (`POST_NOTIFICATIONS`, vibration, sound, badge) and floating in-app banners on Android devices.

---

## Features

### Buyer Features
- Create an account or sign in with email and password.
- Reset forgotten passwords via Supabase Auth email.
- Browse catalog, popular products, and top offers.
- Text search and voice search input (powered by `speech_to_text`).
- Filter by category, price range, offer status, and sorting order.
- Detailed product view with seller information, stock indicators, discount prices, and user reviews.
- Post, edit, and delete product ratings (1–5 stars) and comments.
- Persistent shopping cart with real-time quantity adjustments.
- Multi-payment checkout:
  - Cash on Delivery (COD)
  - Razorpay Standard Checkout SDK (Cards, Netbanking, UPI, Wallets)
  - Fixed-amount UPI QR code generation with live payment polling and test mode simulation
- Order history and progress tracking (`pending`, `paid`, `packed`, `shipped`, `out for delivery`, `delivered`).
- Resume payment on pending orders directly from order tracking.
- Request product returns with instant status updates.
- Real-time chat with sellers for active orders.
- Edit profile details, change password, and switch between light and dark themes.

### Seller Features
- Dedicated seller workspace with role-based access control.
- Interactive business dashboard: Total revenue, active inventory, pending orders, completed deliveries, and top-selling products.
- Regional dashboard filtering by Country, State, and City.
- Full product management: Add, edit, and delete products with image uploads directly to the `product-images` Supabase Storage bucket.
- Buyer order management: Real-time visibility of paid orders and status updates (`packed`, `shipped`, `delivered`), triggering automated notifications to the buyer.
- Return request handling: Review, approve, or reject item return requests with automated buyer notifications.
- Integrated customer messaging.

---

## Technology Stack

- **Framework**: Flutter (Dart 3.13.3+ / Material 3)
- **State Management**: Provider
- **Backend / Database**: Supabase (PostgreSQL 15+, Auth, Storage, Edge Functions, Realtime)
- **Payments**: Razorpay Mobile SDK (`razorpay_flutter`), Server-side webhook verification, UPI QR codes
- **Notifications**: `flutter_local_notifications` (Android) and platform-guarded `NotificationService`
- **Voice Search**: `speech_to_text`
- **Animations**: `flutter_animate`
- **Configuration**: `flutter_dotenv`

---

## Project Structure

```text
lib/
  main.dart                         App startup, Supabase setup, themes, global scaffold messenger
  data/catalog.dart                 Product categories and catalog constants
  provider/
    authprovider.dart               Sign up, login, logout, password reset, roles
    cardeprovider.dart              Cart loading, persistence, and quantity management
    messageprovider.dart            Realtime messaging, contacts, and active conversations
    orderditiyalce.dart             Checkout, orders, returns, coupon validation, realtime notifications, dashboard
    razorpayprovider.dart           Razorpay checkout SDK, callbacks, and platform checks
    productprovider.dart            Products, likes, images, popular and related products
    reviewprovider.dart             Product ratings, reviews, editing, deleting, and reviewer profile loading
    themeprovider.dart              Light and dark theme state
    userprovider.dart               Profile and password operations
  screens/
    home_screen.dart                Buyer home, search, navigation, voice search, global realtime triggers
    filter_screen.dart              Product filters and sorting
    product_details_screen.dart     Product information, review modal, related products
    cart_screen.dart                Cart management
    product_checkout_screen.dart    Delivery details, coupon application, COD, Razorpay Standard, and UPI QR
    order_tracking_screen.dart      Buyer orders, delivery progress, resume payment, return button
    message_screen.dart             Reactive real-time chat and contact list
    notifications_screen.dart       Order and return notification center
    sellerscreen.dart               Seller workspace, order fulfillment, and analytics dashboard
    account_screen.dart             Profile settings and theme preferences
    login_screen.dart               Login and password recovery
    singup_screen.dart              Registration and role selection
  services/
    notification_service.dart       Platform-safe notifications (Android system notifications & floating banners)
  utils/
    error_handling.dart             User-friendly Supabase and network errors
    currency.dart                   Currency formatting
    date_format.dart                Order date formatting
    product_pricing.dart            Price and discount helpers
  widgets/                          Shared product, seller, error, and image widgets
supabase_schema.sql                 Complete database tables, RLS policies, triggers, and RPCs
supbase_edgfuction.js               Order placement Edge Function
supabase_messaging.js               Chat Edge Function
supabase_razorpay.js                Razorpay order creation, resume order, payment verification, and QR handling
supabase_fcm.js                     Optional FCM push delivery
```

---

## Getting Started

### 1. Requirements
- Flutter SDK `3.13.3` or newer
- Android Studio / Android SDK (for Android) or Visual Studio (for Windows)
- A Supabase project

### 2. Environment Configuration
Create a `.env` file in the project root:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-supabase-anon-key
```

> **Security Note**: Never store your Razorpay Secret Key or Supabase Service Role Key in `.env` or client code. They reside securely in Supabase Edge Function Secrets (`RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`).

### 3. Database Setup
1. Open the **SQL Editor** in your Supabase dashboard.
2. Execute the entire contents of `supabase_schema.sql`. This sets up:
   - Tables (`users`, `product`, `orders`, `order_items`, `cart_items`, `notifications`, `return_requests`, `messages`, `payments`, `coupons`, `coupon_redemptions`).
   - Row-Level Security (RLS) policies for products, reviews, orders, and profiles.
   - Atomic checkout procedure `place_order` and cancellation procedure `cancel_razorpay_order`.
   - Coupon verification function `validate_coupon`.
   - Seeded initial coupons (`WELCOME50`, `FLAT100`, `SAVE10`, `SUPER20`, `FREESHIP`).
   - Real-time triggers for notifications and returns.
3. In **Storage**, create a bucket named `product-images` with public read access.

### 4. Running the Application

```bash
# Get dependencies
flutter pub get

# Check connected devices
flutter devices

# Run in debug mode (Android or Windows)
flutter run

# Run on a specific device
flutter run -d <DEVICE_ID>

# Build release APK for Android
flutter build apk --release
```

---

## Database Architecture & Triggers

| Table | Purpose |
| --- | --- |
| `users` | Buyer and seller profiles with role-based routing (`Buyer` / `Seller`). |
| `product` | Inventory catalog owned by sellers. |
| `product_reviews` | Product star ratings and buyer reviews with public read and authenticated write access. |
| `orders` | Customer delivery details, payment method, total price, payment status, and order status. |
| `order_items` | Snapshot of purchased items per order. |
| `coupons` | Active discount coupons with minimum order amounts and maximum discount caps. |
| `coupon_redemptions` | Audit ledger ensuring coupons are redeemed single-use per buyer. |
| `return_requests` | Return workflow with automated trigger notifications. |
| `messages` | Direct buyer-seller conversations with Realtime broadcasting. |
| `notifications` | Real-time notification logs displayed in the notification center. |
| `payments` | Audit ledger for Razorpay transactions and UPI QR codes. |

---

## License

This project is licensed under the MIT License.
