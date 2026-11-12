# Full Setup & Implementation Guide: Infinite Scroll, Notifications, Razorpay Webhooks, & App Security

## 1. Infinite Scroll on Buyer Homepage & Filter Screen
- **Batching & Pagination**:
  - Implemented in `Productprovider` (`lib/provider/productprovider.dart`).
  - Products load in batches of 12 (`pageSize = 12`) ordered by `created_at desc`.
  - Next page loads on-demand only when user scrolls near the bottom (`maxScroll - currentScroll <= 250`).
  - Deduplicates items by `id` to prevent duplicate renders across dynamic updates.
  - Pull-to-refresh (`RefreshIndicator`) cleanly resets pagination and fetches page 1.
- **UI State Handlers**:
  - Attached dedicated `ScrollController` in both `HomePageContent` and `FilterScreen`.
  - Bottom indicator displays loading spinner (`isLoadingMore`), error retry button (`loadMoreErrorMessage`), and end-of-list message (`No more products to show`).

---

## 2. System & Cross-Platform Local Notifications (`flutter_local_notifications`)
1. **Installed Dependency**:
   - `flutter_local_notifications` (v23.0.0) in `pubspec.yaml`.
2. **Android & iOS Permissions**:
   - `POST_NOTIFICATIONS` and `VIBRATE` configured in `android/app/src/main/AndroidManifest.xml` (Android 13+ support).
   - High importance channel `ecommerce_channel` configured with sound and vibration.
3. **Dual Notification Dispatch**:
   - `NotificationService` (`lib/services/notification_service.dart`) dispatches **both** native system notifications (status bar / lock screen) and floating in-app banners for every event.
4. **Triggers Implemented**:
   - **Add to Cart**: Displays `🛒 Added to Cart!` with product name.
   - **Order Placed**: Displays `🛍️ Order Placed Successfully!` with order ID and amount.
   - **Order Packaged**: When status updates to `packed` or `packaged`, displays `📦 Order Packaged!`.
   - **Order Shipped**: Displays `🚚 Order Shipped!`.
   - **Order Delivered**: Displays `🎉 Order Delivered!` for buyer and `✅ Package Delivered!` for seller with buyer ID.
   - **Order Cancelled**: Displays `❌ Order Cancelled`.

---

## 3. Razorpay Payment Success & Webhook Informer
- When a buyer completes payment (either via direct checkout verification or Razorpay Webhook `payment.captured` / `qr_code.credited`):
  - **Seller receives**:
    - **Title**: `💰 Payment Received & Order Paid! (Order #<shortId>)`
    - **Message**: `Buyer <Customer Name> (Buyer ID: <Buyer UUID>) successfully paid ₹<Amount> via Razorpay for Order #<Order ID>. Products: <Product Name (xQty)>`
  - **Buyer receives**:
    - **Title**: `🎉 Payment Successful!`
    - **Message**: `Your payment of ₹<Amount> for Order #<Order ID> was completed successfully via Razorpay.`
- **Edge Functions**:
  - `supabase_razorpay.js` ensures HMAC-SHA256 signature verification for webhooks (`x-razorpay-signature`).
  - `ensurePaymentNotifications()` guarantees both buyer and seller receive notifications with complete buyer details and product breakdown.

---

## 4. Comprehensive App & Database Security Hardening (OWASP Mobile Top 10)

### A. Authorization & Access Control (BOLA / IDOR / BFLA)
1. **Messaging Security**:
   - **Database Policy (`public.messages`)**: Strict RLS `INSERT` policy and `send_message()` RPC function ensure:
     - Sellers can **only** message a buyer if that buyer has an active, non-cancelled order containing that seller's products.
     - Buyers can **only** message sellers whose products they have purchased.
     - Unrelated users or arbitrary contacts cannot be messaged.
2. **Notification Security**:
   - **Database Policy (`public.notifications`)**: Enforces `public.is_buyer_of_seller_order(user_id, order_id)`.
   - Sellers can **only** send notifications to the verified buyer of an order containing their products.
   - Prevents notification spam or arbitrary user targeting.
3. **Customer & Profile Data Access Protection**:
   - Replaced open `public.users` read policy with `public.can_read_user_profile(id)`.
   - Buyers' sensitive contact info (phone, address, email, city) can **only** be read by sellers from whom the buyer made a purchase. Arbitrary users cannot scrape user data.
4. **Order Items Isolation**:
   - Sellers can only read order items where `seller_id = auth.uid()`. Multi-seller orders never leak competitor order items.

### B. SQL Injection & PostgreSQL Hardening
1. **Zero Dynamic SQL**: All queries and RPCs use parameterized queries and strict parameter type casting.
2. **Search Path Hijacking Prevention**: Enforced `SET search_path = public` on all `SECURITY DEFINER` functions and triggers (including `enforce_order_status_transition()`).

### C. Anti-Debugging & Credential Protection (Session Hijacking Mitigation)
1. **Android Data Backup Disabled**:
   - Added `android:allowBackup="false"` in `AndroidManifest.xml`.
   - Prevents ADB extraction of app sandbox files, SharedPreferences, and Supabase auth session tokens.
2. **Cleartext Traffic Disabled**:
   - Added `android:usesCleartextTraffic="false"` in `AndroidManifest.xml` to force TLS/HTTPS network encryption.
3. **Sensitive Logging Sanitization**:
   - Removed debugPrints dumping raw payment objects (`$paymentOrder`) and error stack traces containing auth tokens.
   - Password updates and auth failures log runtime error types rather than raw strings to protect credentials.

---

## 5. Verification & Code Quality
- `flutter analyze`: **0 errors, 0 warnings**.
