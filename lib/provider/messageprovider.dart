import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:e_comerce_appliction/utils/error_handling.dart';
import 'package:e_comerce_appliction/services/notification_service.dart';

class MessageContact {
  final String userId;
  final String name;
  final String? orderId;
  final String? productId;
  String lastMessage;
  DateTime? lastMessageAt;

  MessageContact({
    required this.userId,
    required this.name,
    this.orderId,
    this.productId,
    this.lastMessage = '',
    this.lastMessageAt,
  });
}

class MessageProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  final List<MessageContact> contacts = [];
  final Map<String, List<Map<String, dynamic>>> _messagesByUser = {};
  RealtimeChannel? _messageChannel;
  bool isLoading = false;
  String? errorMessage;

  String? get currentUserId => supabase.auth.currentUser?.id;

  bool _messageWindowOpen(Map<String, dynamic> order) {
    if (order['status']?.toString() != 'delivered') return true;
    final deliveredAt = DateTime.tryParse(
      order['updated_at']?.toString() ?? order['created_at']?.toString() ?? '',
    );
    if (deliveredAt == null) return false;
    return DateTime.now().toUtc().difference(deliveredAt.toUtc()) <
        const Duration(days: 7);
  }

  Future<void> loadContacts() async {
    final userId = currentUserId;
    if (userId == null) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final contactData = <String, Map<String, dynamic>>{};
      final role = await _loadRole(userId);

      if (role == 'Seller') {
        final response = await supabase
            .from('order_items')
            .select('order_id, product_id')
            .eq('seller_id', userId);
        final orderIds = response
            .map((row) => row['order_id']?.toString())
            .whereType<String>()
            .toSet()
            .toList();
        final orders = orderIds.isEmpty
            ? <dynamic>[]
            : await supabase
                  .from('orders')
                  .select(
                    'id, user_id, customer_name, status, created_at, updated_at',
                  )
                  .inFilter('id', orderIds);
        final ordersById = <String, Map<String, dynamic>>{
          for (final order in orders)
            order['id'].toString(): Map<String, dynamic>.from(order),
        };
        for (final row in response) {
          final order = ordersById[row['order_id']?.toString()] ?? {};
          if (!_messageWindowOpen(order)) continue;
          final buyerId = order['user_id']?.toString();
          if (buyerId != null) {
            final existing = contactData[buyerId];
            final orderDate = DateTime.tryParse(
              order['updated_at']?.toString() ??
                  order['created_at']?.toString() ??
                  '',
            );
            final existingDate = DateTime.tryParse(
              existing?['orderDate']?.toString() ?? '',
            );
            if (existing == null ||
                (orderDate != null &&
                    (existingDate == null ||
                        orderDate.isAfter(existingDate)))) {
              contactData[buyerId] = {
                'name': order['customer_name']?.toString() ?? 'Buyer',
                'orderId': row['order_id']?.toString(),
                'productId': row['product_id']?.toString(),
                'orderDate': orderDate?.toIso8601String(),
              };
            }
          }
        }
      } else {
        final response = await supabase
            .from('orders')
            .select(
              'id, user_id, status, created_at, updated_at, order_items(seller_id, product_id)',
            )
            .eq('user_id', userId);
        for (final row in response) {
          final order = Map<String, dynamic>.from(row);
          if (!_messageWindowOpen(order)) continue;
          final items = (row['order_items'] as List?) ?? const [];
          for (final item in items) {
            final sellerId = item['seller_id']?.toString();
            if (sellerId != null) {
              final orderDate = DateTime.tryParse(
                order['updated_at']?.toString() ??
                    order['created_at']?.toString() ??
                    '',
              );
              final existing = contactData[sellerId];
              final existingDate = DateTime.tryParse(
                existing?['orderDate']?.toString() ?? '',
              );
              if (existing == null ||
                  (orderDate != null &&
                      (existingDate == null ||
                          orderDate.isAfter(existingDate)))) {
                contactData[sellerId] = {
                  'name': 'Seller',
                  'orderId': row['id']?.toString(),
                  'productId': item['product_id']?.toString(),
                  'orderDate': orderDate?.toIso8601String(),
                };
              }
            }
          }
        }

        if (contactData.isNotEmpty) {
          final profiles = await supabase
              .from('users')
              .select('id, name')
              .inFilter('id', contactData.keys.toList());
          for (final profile in profiles) {
            final id = profile['id']?.toString();
            if (id != null && contactData.containsKey(id)) {
              contactData[id]!['name'] =
                  profile['name']?.toString() ?? 'Seller';
            }
          }
        }
      }

      contacts
        ..clear()
        ..addAll(
          contactData.entries.map(
            (entry) => MessageContact(
              userId: entry.key,
              name: entry.value['name'] as String,
              orderId: entry.value['orderId'] as String?,
              productId: entry.value['productId'] as String?,
            ),
          ),
        );
      await _loadRecentMessages(userId);
      _sortContacts();
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error loading message contacts: $error');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String> _loadRole(String userId) async {
    final profile = await supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    return profile?['role']?.toString() ?? 'Buyer';
  }

  Future<void> _loadRecentMessages(String userId) async {
    try {
      final response = await supabase.functions.invoke(
        'messaging',
        body: {'action': 'get_recent_messages'}
      );
      final data = response.data;
      if (data != null && data['error'] != null) {
        throw data['error'];
      }
      
      final messagesList = (data['messages'] as List<dynamic>?) ?? [];
      
      for (final messageObj in messagesList) {
        final message = Map<String, dynamic>.from(messageObj);
        final otherUser = message['sender_id'] == userId
            ? message['receiver_id']?.toString()
            : message['sender_id']?.toString();
        if (otherUser != null) {
          _appendMessage(otherUser, message);
        }
      }
      _applyRecentMessages();
    } catch (e) {
      debugPrint('Error fetching recent messages: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadConversation(
    String otherUserId,
  ) async {
    final userId = currentUserId;
    if (userId == null) return [];
    try {
      final response = await supabase.functions.invoke(
        'messaging',
        body: {
          'action': 'get_messages',
          'other_user_id': otherUserId
        },
      );
      
      final data = response.data;
      if (data != null && data['error'] != null) {
        throw data['error'];
      }
      
      final messages = (data['messages'] as List<dynamic>? ?? [])
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

      _messagesByUser[otherUserId] = messages;
      notifyListeners();
      return messages;
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      notifyListeners();
      return [];
    }
  }

  Future<bool> sendMessage({
    required MessageContact contact,
    required String body,
  }) async {
    final userId = currentUserId;
    final text = body.trim();
    if (userId == null || text.isEmpty) return false;
    try {
      final response = await supabase.functions.invoke(
        'messaging',
        body: {
          'action': 'send',
          'receiver_id': contact.userId,
          'order_id': contact.orderId,
          'product_id': contact.productId,
          'body': text,
        },
      );
      
      final data = response.data;
      if (data != null && data['error'] != null) {
        throw data['error'];
      }
      
      final inserted = data['message'];
      if (inserted == null) return false;
      _appendMessage(contact.userId, Map<String, dynamic>.from(inserted));
      _applyRecentMessages();
      _sortContacts();
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      notifyListeners();
      return false;
    }
  }

  void _applyRecentMessages() {
    for (final contact in contacts) {
      final recent = _messagesByUser[contact.userId]?.lastOrNull;
      if (recent == null) continue;
      contact.lastMessage = recent['body']?.toString() ?? '';
      contact.lastMessageAt = DateTime.tryParse(
        recent['created_at']?.toString() ?? '',
      );
    }
  }

  void _appendMessage(String userId, Map<String, dynamic> message) {
    final messages = _messagesByUser.putIfAbsent(userId, () => []);
    final messageId = message['id']?.toString();
    final alreadyAdded =
        messageId != null &&
        messages.any((item) => item['id']?.toString() == messageId);
    if (alreadyAdded) return;
    messages.add(message);
    messages.sort((first, second) {
      final firstDate =
          DateTime.tryParse(first['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final secondDate =
          DateTime.tryParse(second['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return firstDate.compareTo(secondDate);
    });
  }

  List<Map<String, dynamic>> conversationFor(String userId) {
    return List<Map<String, dynamic>>.unmodifiable(
      _messagesByUser[userId] ?? const [],
    );
  }

  void _sortContacts() {
    contacts.sort((first, second) {
      final firstDate =
          first.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final secondDate =
          second.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return secondDate.compareTo(firstDate);
    });
  }

  /// Subscribes to realtime incoming/outgoing messages
  Future<void> subscribeToRealtimeMessages() async {
    final userId = currentUserId;
    if (userId == null || _messageChannel != null) return;

    _messageChannel = supabase
        .channel('public:messages:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isEmpty) return;

            final senderId = newRecord['sender_id']?.toString();
            final receiverId = newRecord['receiver_id']?.toString();
            final body = newRecord['body']?.toString() ?? '';

            // Only process messages involving the current user
            if (senderId != userId && receiverId != userId) return;

            final otherUser = senderId == userId ? receiverId : senderId;
            if (otherUser == null) return;

            _appendMessage(otherUser, Map<String, dynamic>.from(newRecord));
            _applyRecentMessages();
            _sortContacts();
            notifyListeners();

            // If message was sent from someone else to the current user, show in-app notification banner
            if (senderId != userId) {
              final senderContact = contacts.where((c) => c.userId == senderId).firstOrNull;
              final senderName = senderContact?.name ?? 'New Message';
              NotificationService.instance.showNotification(
                title: '💬 $senderName',
                body: body,
              );
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _messageChannel?.unsubscribe();
    super.dispose();
  }
}
