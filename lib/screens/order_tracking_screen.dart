import 'package:e_comerce_appliction/provider/orderditiyalce.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  provider.errorMessage!,
                  textAlign: TextAlign.center,
                ),
              ),
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

  String _placedDateTime(BuildContext context, String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return 'Order time unavailable';
    final local = parsed.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date at $time';
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? 'pending';
    final statusIndex = _OrderTrackingScreenState.statuses.indexOf(status);
    final items = (order['order_items'] as List?) ?? const [];
    final date = order['created_at']?.toString() ?? '';

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
                    'Order #${order['id']?.toString().substring(0, 8) ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: Text(
                    '₹${order['total_price'] ?? 0}',
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
                  'Placed on ${_placedDateTime(context, date)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            const Divider(height: 22),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${item['product_name']}  ×  ${item['quantity']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
