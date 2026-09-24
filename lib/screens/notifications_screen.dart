import 'package:e_comerce_appliction/provider/orderditiyalce.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:e_comerce_appliction/widgets/error_state.dart';
import 'package:e_comerce_appliction/utils/date_format.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderDitiyalce>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Consumer<OrderDitiyalce>(
            builder: (context, provider, child) => TextButton.icon(
              onPressed: provider.notifications.isEmpty
                  ? null
                  : () async {
                      final cleared = await provider.clearNotifications();
                      if (!context.mounted || cleared) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            style: TextStyle(color: Colors.red),
                            provider.errorMessage ??
                                'Notifications could not be cleared.',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text(
                'Clear all',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<OrderDitiyalce>(
        builder: (context, provider, child) {
          if (provider.isLoadingNotifications &&
              provider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.errorMessage != null && provider.notifications.isEmpty) {
            return ErrorState(
              message: provider.errorMessage!,
              onRetry: provider.loadNotifications,
            );
          }
          if (provider.notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: provider.notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notification = provider.notifications[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.local_shipping_outlined),
                  ),
                  title: Text(
                    notification['title']?.toString() ?? 'Order update',
                  ),
                  subtitle: Text(notification['message']?.toString() ?? ''),
                  trailing: SizedBox(
                    width: 72,
                    child: Text(
                      formatShortDate(notification['created_at']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
