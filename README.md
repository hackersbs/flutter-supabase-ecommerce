# E-Commerce Flutter Application (E-Commerce)

A modern, full-featured Flutter e-commerce application with separate, tailored buyer and seller experiences. The app uses Supabase for authentication, PostgreSQL storage, row-level security (RLS), real-time notifications, atomic checkout, buyer-seller messaging, and reviews.

---

## What's New & Key Highlights

- **Real-Time Notification System**:
  - Global `NotificationService` providing instant floating in-app notification banners for **Order Shipped**, **Order Delivered**, **Return Status Updates**, and **Chat Messages**.
  - Powered by Supabase Realtime channel listeners and automated PostgreSQL triggers on `orders`, `notifications`, and `return_requests`.
  - Android 13+ support (`POST_NOTIFICATIONS`, `VIBRATE`).
- **Real-Time Chat & Instant Message Sync**:
  - Live buyer-seller chat powered by the `messaging` Edge Function and PostgreSQL streaming.
  - Reactive chat UI that updates instantly without losing state or requiring pull-to-refresh.
- **Redesigned Product Return Flow**:
  - Modern styled return button with an interactive confirmation dialog.
  - Real-time status badges: ⏳ **Pending**, ✅ **Approved**, and ❌ **Rejected**.
- **Atomic Checkout & Race Condition Protection**:
  - PostgreSQL `place_order` procedure enforces row-level locking (`FOR UPDATE`) on inventory and coupons to eliminate overselling and race conditions.
- **Brand Identity & 3D App Icon**:
  - App title branded as **E-Commerce** across Android, Windows, iOS, and Flutter.
  - Multi-platform 3D isometric shopping bag app icons configured across Android mipmap folders, Windows (`app_icon.ico`), and iOS asset catalogs.
- **Review System Stability**:
  - Protected modal sheet lifecycle with isolated `BuildContext` and deferred controller disposal to eliminate Flutter framework assertion errors.

---

## Features

### Buyer Features
- Create an account or sign in with email and password.
- Reset forgotten passwords via Supabase Auth email.
- Browse catalog, popular products, and top offers.
- Text search and voice search input (powered by `speech_to_text`).
- Filter by category, price range, offer status, and sorting order.
- Detailed product view with seller information, stock indicators, discount prices, and user reviews.
- Persistent shopping cart with real-time quantity adjustments.
- Multi-payment checkout:
  - Cash on Delivery (COD)
  - Razorpay Standard Checkout SDK
  - Fixed-amount UPI QR code generation with live payment polling
- Order history and progress tracking (`pending`, `packed`, `shipped`, `out for delivery`, `delivered`).
- Request product returns with instant status updates.
- Real-time chat with sellers for active orders.
- Edit profile details, change password, and switch between light and dark themes.

### Seller Features
- Dedicated seller workspace with role-based access control.
- Interactive business dashboard: Total revenue, active inventory, pending orders, completed deliveries, and top-selling products.
- Regional dashboard filtering by Country, State, and City.
- Full product management: Add, edit, and delete products with image uploads directly to the `product-images` Supabase Storage bucket.
- Buyer order management: Update status (`packed`, `shipped`, `delivered`), triggering automated notifications to the buyer.
- Return request handling: Review, approve, or reject item return requests with automated buyer notifications.
- Integrated messaging with customers.

---

## Technology Stack

- **Framework**: Flutter (Dart 3.13.3+ / Material 3)
- **State Management**: Provider
- **Backend / Database**: Supabase (PostgreSQL 15+, Auth, Storage, Edge Functions, Realtime)
- **Payments**: Razorpay Mobile SDK (`razorpay_flutter`), Server-side webhook verification, UPI QR codes
- **Notifications**: Cross-platform pure Dart `NotificationService`
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
    orderditiyalce.dart             Checkout, orders, returns, realtime notifications, dashboard
    razorpayprovider.dart           Razorpay checkout SDK and payment callbacks
    productprovider.dart            Products, likes, images, popular and related products
    reviewprovider.dart             Product ratings and reviews
    themeprovider.dart              Light and dark theme state
    userprovider.dart               Profile and password operations
  screens/
    home_screen.dart                Buyer home, search, navigation, voice search, global realtime triggers
    filter_screen.dart              Product filters and sorting
    product_details_screen.dart     Product information, safe review modal, related products
    cart_screen.dart                Cart management
    product_checkout_screen.dart    Delivery form, COD, Razorpay, and UPI QR payment
    order_tracking_screen.dart      Buyer orders, delivery progress, redesigned return button
    message_screen.dart             Reactive real-time chat and contact list
    notifications_screen.dart       Order and return notification center
    sellerscreen.dart               Seller workspace and analytics dashboard
    account_screen.dart             Profile settings and theme preferences
    login_screen.dart               Login and password recovery
    singup_screen.dart              Registration and role selection
  services/
    notification_service.dart       Floating in-app notification alerts
  utils/
    error_handling.dart             User-friendly Supabase and network errors
    currency.dart                   Currency formatting
    date_format.dart                Order date formatting
    product_pricing.dart            Price and discount helpers
  widgets/                          Shared product, seller, error, and image widgets
supabase_schema.sql                 Complete database tables, policies, triggers, and RPCs
supbase_edgfuction.js               Order placement Edge Function
supabase_messaging.js               Chat Edge Function
supabase_razorpay.js                Razorpay order creation, payment verification, and webhook handling
supabase_fcm.js                     Optional FCM push delivery
```

---

## Getting Started

### 1. Requirements
- Flutter SDK `3.13.3` or newer
- Android Studio / Android SDK (or VS Code)
- A Supabase project

### 2. Environment Configuration
Create a `.env` file in the project root:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-supabase-anon-key
RAZORPAY_KEY_ID=rzp_test_your_key_id
```

> **Note**: Never store your Razorpay Secret Key or Supabase Service Role Key in the `.env` file or client code. They must only reside in Supabase Edge Function Secrets.

### 3. Database Setup
1. Open the **SQL Editor** in your Supabase dashboard.
2. Execute the entire contents of `supabase_schema.sql`. This sets up:
   - Tables (`users`, `product`, `orders`, `order_items`, `cart_items`, `notifications`, `return_requests`, `messages`, `payments`, `coupons`).
   - RLS security policies.
   - Row-level lock checkout procedure `place_order`.
   - Real-time triggers for order and return notifications.
3. In **Storage**, create a bucket named `product-images` with public read access.

### 4. Running the Application

```bash
# Get dependencies
flutter pub get

# Check connected devices
flutter devices

# Run in debug mode
flutter run

# Run on a specific device (e.g. Android phone)
flutter run -d <DEVICE_ID>

# Build release APK
flutter build apk --release
```

---

## Database Architecture & Triggers

| Table | Purpose |
| --- | --- |
| `users` | Buyer and seller profiles with role-based routing (`Buyer` / `Seller`). |
| `product` | Inventory catalog owned by sellers. |
| `orders` | Customer delivery details, payment method, total, and status. |
| `order_items` | Snapshot of purchased items per order. |
| `return_requests` | Return workflow with automated trigger notifications. |
| `messages` | Direct buyer-seller conversations with Realtime broadcasting. |
| `notifications` | Real-time notification logs displayed in the notification center. |
| `payments` | Audit ledger for Razorpay transactions and QR codes. |
| `coupons` | Discount coupons validated atomically with `FOR UPDATE` locks. |

---

## License

This project is licensed under the MIT License.
