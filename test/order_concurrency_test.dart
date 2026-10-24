import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

/// Simulated concurrent order placement service matching place_order behavior
class MockOrderService {
  int stock = 1;
  final String productName = 'Limited Edition Watch';

  /// Simulates PostgreSQL place_order RPC with row-level locking (FOR UPDATE)
  Future<String> placeOrderSimulated({
    required String userId,
    required int requestedQuantity,
  }) async {
    // Simulate database network latency / processing delay
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Exclusive row lock check: SELECT * FROM product WHERE id = ... FOR UPDATE
    if (stock < requestedQuantity) {
      throw Exception('OUT_OF_STOCK: $productName');
    }

    // Atomic update: UPDATE product SET quantity = quantity - requestedQuantity
    stock -= requestedQuantity;
    return 'order_${userId}_${DateTime.now().millisecondsSinceEpoch}';
  }
}

void main() {
  test('Simultaneous purchase of last item: exactly one succeeds and second receives OUT_OF_STOCK', () async {
    final orderService = MockOrderService();
    expect(orderService.stock, 1);

    String? user1OrderId;
    String? user1Error;
    String? user2OrderId;
    String? user2Error;

    // Both user 1 and user 2 trigger purchase simultaneously
    final user1Future = orderService
        .placeOrderSimulated(userId: 'user_1', requestedQuantity: 1)
        .then((orderId) => user1OrderId = orderId)
        .catchError((err) => user1Error = err.toString());

    final user2Future = orderService
        .placeOrderSimulated(userId: 'user_2', requestedQuantity: 1)
        .then((orderId) => user2OrderId = orderId)
        .catchError((err) => user2Error = err.toString());

    await Future.wait([user1Future, user2Future]);

    // Exactly one must succeed and exactly one must fail with OUT_OF_STOCK
    final successCount = (user1OrderId != null ? 1 : 0) + (user2OrderId != null ? 1 : 0);
    expect(successCount, 1, reason: 'Only one buyer can purchase the last remaining item');

    // Remaining stock must be exactly 0 (no overselling / negative stock)
    expect(orderService.stock, 0);

    // The failed attempt must contain OUT_OF_STOCK
    final failedError = user1Error ?? user2Error;
    expect(failedError, contains('OUT_OF_STOCK: Limited Edition Watch'));
  });
}
