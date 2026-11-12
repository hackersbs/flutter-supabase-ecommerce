import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification service that provides both:
/// 1. Device-level system local notifications (status bar / heads-up / lockscreen)
///    via flutter_local_notifications.
/// 2. Smooth floating in-app notification banners overlaying the UI.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initializes local notifications on Android, iOS, macOS, and desktop.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      // Create high importance Android notification channel & request permission
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'ecommerce_channel',
          'Order & Store Updates',
          description:
              'Notifications for order status, payments, cart updates, and shipments.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await androidPlugin.createNotificationChannel(channel);
      }
      _isInitialized = true;
      debugPrint('NotificationService initialized with flutter_local_notifications.');
    } catch (e) {
      debugPrint('Error initializing flutter_local_notifications: $e');
    }
  }

  /// Displays both a floating in-app overlay banner and a native device notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    IconData icon = Icons.notifications_active,
    Color color = const Color(0xFF2874F0),
    Duration duration = const Duration(seconds: 4),
  }) async {
    // 1. Floating in-app notification overlay
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: duration,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 2. Native system local notification on device
    try {
      final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      const NotificationDetails platformDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'ecommerce_channel',
          'Order & Store Updates',
          channelDescription:
              'Notifications for order status, payments, cart updates, and shipments.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Local notification show error: $e');
    }
  }

  /// Helper for Added to Cart
  void showAddedToCart({required String productName}) {
    showNotification(
      title: '🛒 Added to Cart!',
      body: '$productName has been added to your shopping cart.',
      icon: Icons.add_shopping_cart,
      color: const Color(0xFF2874F0),
    );
  }

  /// Helper for Order Placed
  void showOrderPlaced({
    required String orderId,
    required double totalAmount,
    String paymentMethod = 'Cash on Delivery',
  }) {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    showNotification(
      title: '🛍️ Order Placed Successfully!',
      body: 'Order #$shortId for ₹${totalAmount.toStringAsFixed(0)} placed via $paymentMethod.',
      icon: Icons.check_circle_outline,
      color: Colors.green,
    );
  }

  /// Helper for Payment Success (Buyer side)
  void showPaymentSuccess({
    required String orderId,
    required double amount,
  }) {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    showNotification(
      title: '💳 Payment Successful!',
      body: 'Your payment of ₹${amount.toStringAsFixed(0)} for Order #$shortId was completed.',
      icon: Icons.payment,
      color: Colors.teal,
    );
  }

  /// Helper for Payment Received & New Order (Seller side)
  void showSellerPaymentReceived({
    required String orderId,
    required String buyerName,
    required String buyerId,
    required double amount,
    String products = '',
  }) {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    final shortBuyerId = buyerId.length > 8 ? buyerId.substring(0, 8) : buyerId;
    showNotification(
      title: '💰 Payment Received (Order #$shortId)',
      body: 'Buyer $buyerName (ID: #$shortBuyerId) paid ₹${amount.toStringAsFixed(0)}. Products: $products',
      icon: Icons.monetization_on,
      color: Colors.amber.shade700,
    );
  }

  /// Helper for Order Packaged
  void showOrderPackaged({required String orderId}) {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    showNotification(
      title: '📦 Order Packaged!',
      body: 'Your order #$shortId has been packed and is ready for dispatch.',
      icon: Icons.inventory_2_outlined,
      color: Colors.indigo,
    );
  }

  /// Helper for Order Shipped
  void showOrderShipped({required String orderId}) {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    showNotification(
      title: '🚚 Order Shipped!',
      body: 'Your order #$shortId has been shipped and is on the way.',
      icon: Icons.local_shipping,
      color: Colors.blueAccent,
    );
  }

  /// Helper for Order Delivered (Buyer side)
  void showOrderDelivered({required String orderId}) {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    showNotification(
      title: '🎉 Order Delivered!',
      body: 'Your order #$shortId has been delivered. Enjoy!',
      icon: Icons.check_circle_outline,
      color: Colors.green,
    );
  }

  /// Helper for Package Delivered (Seller side)
  void showSellerOrderDelivered({
    required String orderId,
    required String customerName,
    String? buyerId,
  }) {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    showNotification(
      title: '✅ Package Delivered!',
      body: 'Order #$shortId for customer $customerName has been marked as delivered.',
      icon: Icons.done_all,
      color: Colors.green,
    );
  }

  /// Helper for Order Cancelled
  void showOrderCancelled({required String orderId}) {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    showNotification(
      title: '❌ Order Cancelled',
      body: 'Order #$shortId has been cancelled.',
      icon: Icons.cancel_outlined,
      color: Colors.redAccent,
    );
  }

  /// Helper for Return Status Updates
  void showReturnUpdate({required String status, required String orderId}) {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    showNotification(
      title: '🔄 Return Status: ${status.toUpperCase()}',
      body: 'Your return for order #$shortId is currently $status.',
      icon: Icons.assignment_return_outlined,
      color: Colors.deepOrange,
    );
  }
}
