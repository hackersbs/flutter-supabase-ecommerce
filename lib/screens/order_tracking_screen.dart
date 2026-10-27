import 'package:e_comerce_appliction/provider/orderditiyalce.dart';
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
          ],
        ),
      ),
    );
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
