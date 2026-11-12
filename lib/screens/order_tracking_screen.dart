import 'package:e_comerce_appliction/provider/orderditiyalce.dart';
import 'package:e_comerce_appliction/provider/razorpayprovider.dart';
import 'package:e_comerce_appliction/services/notification_service.dart';
import 'package:e_comerce_appliction/screens/product_checkout_screen.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';
import 'package:e_comerce_appliction/utils/currency.dart';
import 'package:e_comerce_appliction/utils/date_format.dart';
import 'package:provider/provider.dart';
import 'package:e_comerce_appliction/widgets/error_state.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const statuses = [
    'pending',
    'packed',
    'shipped',
    'out for delivery',
    'delivered',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderDitiyalce>().loadBuyerOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: const Color(0xFF2874F0),
        foregroundColor: Colors.white,
      ),
      body: Consumer<OrderDitiyalce>(
        builder: (context, provider, child) {
          if (provider.isLoadingOrders) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.errorMessage != null) {
            return ErrorState(
              message: provider.errorMessage!,
              onRetry: provider.loadBuyerOrders,
            );
          }
          if (provider.buyerOrders.isEmpty) {
            return const Center(child: Text('You have no orders yet.'));
          }
          return RefreshIndicator(
            onRefresh: provider.loadBuyerOrders,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.buyerOrders.length,
              itemBuilder: (context, index) {
                return _OrderCard(order: provider.buyerOrders[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? 'pending';
    final statusIndex = _OrderTrackingScreenState.statuses.indexOf(status);
    final items = (order['order_items'] as List?) ?? const [];
    final date = order['created_at']?.toString() ?? '';
    final orderId = resolveOrderId(order);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF2874F0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order #${shortOrderId(orderId)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: Text(
                    formatIndianRupees(order['total_price']),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (date.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Placed on ${formatOrderDateTime(context, date)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            const Divider(height: 22),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['product_name']}  ×  ${item['quantity']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final returnStatus = context
                            .read<OrderDitiyalce>()
                            .returnStatus(item['id']?.toString() ?? '');
                        return returnStatus == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  returnStatus,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              );
                      },
                    ),
                    if (_returnIsAvailable(order))
                      _ReturnButton(order: order, item: item),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              status.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF2874F0),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            _TrackingProgress(currentIndex: statusIndex < 0 ? 0 : statusIndex),
            const SizedBox(height: 8),
            Text(
              '${order['address'] ?? ''}, ${order['city'] ?? ''}, ${order['state'] ?? ''}, ${order['country'] ?? ''}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (status == 'pending' && order['payment_status'] == 'pending') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openResumePayment(context, order),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2874F0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.payment, size: 20),
                  label: const Text(
                    'Resume Payment (Pay Now)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openResumePayment(BuildContext context, Map<String, dynamic> order) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Color(0xFF2874F0)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pay for Order #${shortOrderId(resolveOrderId(order))}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      formatIndianRupees(order['total_price']),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2874F0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select how you want to complete your payment:',
                  style: TextStyle(color: Colors.grey),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2874F0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.credit_card, color: Color(0xFF2874F0)),
                  ),
                  title: const Text(
                    'Razorpay Standard Checkout',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Pay via Cards, UPI, Netbanking, or Wallets'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _payWithRazorpay(context, order);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_2, color: Colors.orange),
                  ),
                  title: const Text(
                    'Pay with UPI QR Code',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Scan with any UPI app on your phone'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _payWithQr(context, order);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _payWithRazorpay(
    BuildContext context,
    Map<String, dynamic> order,
  ) async {
    final razorpayProvider = context.read<RazorpayProvider>();
    final orderProvider = context.read<OrderDitiyalce>();
    final orderId = resolveOrderId(order);

    if (!razorpayProvider.isSupportedPlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Razorpay payments are supported on Android or iOS devices.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting Razorpay payment...'),
        duration: Duration(seconds: 2),
      ),
    );

    final paymentOrder =
        await orderProvider.resumeRazorpayOrder(orderId: orderId);
    if (!context.mounted) return;
    if (paymentOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orderProvider.errorMessage ?? 'Could not start Razorpay payment.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final razorpayOrderId =
        paymentOrder['razorpay_order_id']?.toString() ?? '';
    final razorpayKeyId = paymentOrder['key_id']?.toString() ?? '';
    final rawAmount = paymentOrder['amount'];
    final amount = rawAmount is num
        ? rawAmount.round()
        : int.tryParse(rawAmount?.toString() ?? '') ??
            ((order['total_price'] as num).toDouble() * 100).round();
    final currency =
        paymentOrder['currency']?.toString().toUpperCase() ?? 'INR';
    final customer = paymentOrder['customer'] as Map? ?? {};

    if (razorpayKeyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment service did not provide a Razorpay key ID.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final PaymentSuccessResponse payment =
          await razorpayProvider.openCheckout(
        options: {
          'key': razorpayKeyId,
          'amount': amount,
          'currency': currency,
          'order_id': razorpayOrderId,
          'name': 'E-commerce Store',
          'description': 'Resume Order payment',
          'prefill': {
            'name': customer['name'] ?? order['customer_name'] ?? 'Test Buyer',
            'email': customer['email'] ??
                order['customer_email'] ??
                'testbuyer@example.com',
            'contact': customer['phone'] ??
                order['customer_phone'] ??
                '9123456789',
          },
          'theme': {'color': '#2874F0'},
        },
      );

      final confirmed = await orderProvider.verifyRazorpayPayment(
        orderId: orderId,
        razorpayOrderId: payment.orderId!,
        razorpayPaymentId: payment.paymentId!,
        razorpaySignature: payment.signature!,
      );

      if (!context.mounted) return;
      if (confirmed) {
        orderProvider.loadBuyerOrders();
        NotificationService.instance.showPaymentSuccess(
          orderId: orderId,
          amount: (order['total_price'] as num?)?.toDouble() ?? (amount / 100),
        );
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 52),
            title: const Text('Payment Successful'),
            content: const Text(
              'Your Razorpay payment has been verified! Your order is now paid.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              orderProvider.errorMessage ?? 'Payment verification failed.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment cancelled or failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _payWithQr(
    BuildContext context,
    Map<String, dynamic> order,
  ) async {
    final orderProvider = context.read<OrderDitiyalce>();
    final orderId = resolveOrderId(order);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating UPI QR code...'),
        duration: Duration(seconds: 2),
      ),
    );

    final qrData = await orderProvider.resumeRazorpayQrCode(orderId: orderId);
    if (!context.mounted) return;
    if (qrData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orderProvider.errorMessage ?? 'Could not create UPI QR code.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final imageUrl = qrData['image_url']?.toString() ?? '';
    final rawAmount = qrData['amount'];
    final amountInPaise = rawAmount is num
        ? rawAmount.round()
        : int.tryParse(rawAmount?.toString() ?? '') ??
            ((order['total_price'] as num).toDouble() * 100).round();

    final paid = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => RazorpayQrDialog(
            imageUrl: imageUrl,
            amount: amountInPaise / 100,
            getPaymentStatus: () =>
                orderProvider.razorpayPaymentStatus(orderId: orderId),
            cancelPayment: () =>
                orderProvider.cancelRazorpayQr(orderId: orderId),
            simulatePayment: () =>
                orderProvider.simulateTestQrPayment(orderId: orderId),
          ),
        ) ??
        false;

    if (!context.mounted) return;
    if (paid) {
      orderProvider.loadBuyerOrders();
      NotificationService.instance.showPaymentSuccess(
        orderId: orderId,
        amount: amountInPaise / 100,
      );
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 52),
          title: const Text('Payment Successful'),
          content: const Text(
            'Your UPI payment was verified and confirmed! Your order is now paid.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  bool _returnIsAvailable(Map<String, dynamic> order) {
    if (order['status']?.toString() != 'delivered') return false;
    final deliveredAt = DateTime.tryParse(
      order['updated_at']?.toString() ?? order['created_at']?.toString() ?? '',
    );
    return deliveredAt != null &&
        DateTime.now().toUtc().difference(deliveredAt.toUtc()) <
            const Duration(days: 6);
  }
}

class _ReturnButton extends StatelessWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> item;

  const _ReturnButton({required this.order, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<OrderDitiyalce>();
    final itemId = item['id']?.toString() ?? '';
    final status = provider.returnStatus(itemId);

    if (status != null) {
      Color badgeBg;
      Color badgeTextColor;
      IconData badgeIcon;

      switch (status.toLowerCase()) {
        case 'approved':
          badgeBg = Colors.green.withValues(alpha: 0.12);
          badgeTextColor = Colors.green.shade700;
          badgeIcon = Icons.check_circle_outline;
          break;
        case 'rejected':
          badgeBg = Colors.red.withValues(alpha: 0.12);
          badgeTextColor = Colors.red.shade700;
          badgeIcon = Icons.cancel_outlined;
          break;
        default:
          badgeBg = Colors.orange.withValues(alpha: 0.12);
          badgeTextColor = Colors.orange.shade800;
          badgeIcon = Icons.hourglass_top_outlined;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeTextColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badgeIcon, size: 14, color: badgeTextColor),
            const SizedBox(width: 4),
            Text(
              'Return: ${status[0].toUpperCase()}${status.substring(1)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeTextColor,
              ),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.error,
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: const Icon(Icons.assignment_return_outlined, size: 14),
      label: const Text(
        'Return Item',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onPressed: itemId.isEmpty
          ? null
          : () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.assignment_return_outlined, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Return Product?'),
                    ],
                  ),
                  content: Text(
                    'Are you sure you want to request a return for "${item['title'] ?? 'this item'}"?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      child: const Text('Confirm Return'),
                    ),
                  ],
                ),
              );

              if (confirmed != true) return;

              final sellerId = item['seller_id']?.toString();
              final orderId = order['id']?.toString();
              if (sellerId == null || orderId == null) return;

              final requested = await provider.requestReturn(
                orderId: orderId,
                orderItemId: itemId,
                sellerId: sellerId,
              );

              if (!context.mounted) return;

              if (requested) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.green,
                    content: Text('Return request submitted successfully!'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red,
                    content: Text(
                      provider.errorMessage ?? 'Return request failed.',
                    ),
                  ),
                );
              }
            },
    );
  }
}

class _TrackingProgress extends StatelessWidget {
  final int currentIndex;

  const _TrackingProgress({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_OrderTrackingScreenState.statuses.length, (
        index,
      ) {
        final active = index <= currentIndex;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? const Color(0xFF2874F0)
                      : Colors.grey.shade300,
                ),
                child: active
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                _OrderTrackingScreenState.statuses[index].replaceAll(
                  'out for delivery',
                  'out',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9),
              ),
            ],
          ),
        );
      }),
    );
  }
}
