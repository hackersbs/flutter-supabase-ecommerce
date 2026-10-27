import 'package:flutter/material.dart';

/// In-app notification overlay & alert service that works smoothly across
/// all platforms (Android, Windows, iOS, Web) without C++ native compilation limits.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Future<void> initialize() async {
    debugPrint('NotificationService initialized successfully.');
  }

  /// Displays a floating in-app notification banner
  void showNotification({
    required String title,
    required String body,
    IconData icon = Icons.notifications_active,
    Color color = const Color(0xFF2874F0),
    Duration duration = const Duration(seconds: 4),
  }) {
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
  }

  /// Helper for Order Shipped
  void showOrderShipped({required String orderId}) {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    showNotification(
      title: '📦 Order Shipped!',
      body: 'Your order #$shortId has been shipped and is on the way.',
      icon: Icons.local_shipping,
      color: Colors.blueAccent,
    );
  }

  /// Helper for Order Delivered
  void showOrderDelivered({required String orderId}) {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    showNotification(
      title: '🎉 Order Delivered!',
      body: 'Your order #$shortId has been delivered. Enjoy!',
      icon: Icons.check_circle_outline,
      color: Colors.green,
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
