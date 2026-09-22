import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  RealtimeChannel? _channel;
  bool isLoading = false;
  String? errorMessage;

  String? get currentUserId => supabase.auth.currentUser?.id;

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
            .select(
              'order_id, product_id, orders!inner(user_id, customer_name)',
            )
            .eq('seller_id', userId);
        for (final row in response) {
          final order = Map<String, dynamic>.from(row['orders'] ?? {});
          final buyerId = order['user_id']?.toString();
          if (buyerId != null) {
            contactData.putIfAbsent(
              buyerId,
              () => {
                'name': order['customer_name']?.toString() ?? 'Buyer',
                'orderId': row['order_id']?.toString(),
                'productId': row['product_id']?.toString(),
              },
            );
          }
        }
      } else {
        final response = await supabase
            .from('orders')
            .select('id, order_items(seller_id, product_id)')
            .eq('user_id', userId);
        for (final row in response) {
          final items = (row['order_items'] as List?) ?? const [];
          for (final item in items) {
            final sellerId = item['seller_id']?.toString();
            if (sellerId != null) {
              contactData.putIfAbsent(
                sellerId,
                () => {
                  'name': 'Seller',
                  'orderId': row['id']?.toString(),
                  'productId': item['product_id']?.toString(),
                },
              );
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
      _subscribeToMessages(userId);
    } catch (error) {
      errorMessage = error.toString();
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
    final response = await supabase
        .from('messages')
        .select()
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false);
    _messagesByUser.clear();
    for (final message in response) {
      final otherUser = message['sender_id'] == userId
          ? message['receiver_id']?.toString()
          : message['sender_id']?.toString();
      if (otherUser != null && !_messagesByUser.containsKey(otherUser)) {
        _messagesByUser[otherUser] = [Map<String, dynamic>.from(message)];
      }
    }
    _applyRecentMessages();
  }

  void _subscribeToMessages(String userId) {
    _channel?.unsubscribe();
    _channel = supabase
        .channel('messages-for-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final message = Map<String, dynamic>.from(payload.newRecord);
            if (message['sender_id'] != userId &&
                message['receiver_id'] != userId) {
              return;
            }
            final otherUser = message['sender_id'] == userId
                ? message['receiver_id']?.toString()
                : message['sender_id']?.toString();
            if (otherUser == null) return;
            _messagesByUser[otherUser] = [message];
            _applyRecentMessages();
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<List<Map<String, dynamic>>> loadConversation(
    String otherUserId,
  ) async {
    final userId = currentUserId;
    if (userId == null) return [];
    final response = await supabase
        .from('messages')
        .select()
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at');
    final messages = response
        .map(Map<String, dynamic>.from)
        .where(
          (message) =>
              (message['sender_id'] == userId &&
                  message['receiver_id'] == otherUserId) ||
              (message['sender_id'] == otherUserId &&
                  message['receiver_id'] == userId),
        )
        .toList();
    _messagesByUser[otherUserId] = messages.isEmpty ? [] : [messages.last];
    return messages;
  }

  Future<bool> sendMessage({
    required MessageContact contact,
    required String body,
  }) async {
    final userId = currentUserId;
    final text = body.trim();
    if (userId == null || text.isEmpty) return false;
    try {
      await supabase.from('messages').insert({
        'sender_id': userId,
        'receiver_id': contact.userId,
        'order_id': contact.orderId,
        'product_id': contact.productId,
        'body': text,
      });
      return true;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  void _applyRecentMessages() {
    for (final contact in contacts) {
      final recent = _messagesByUser[contact.userId]?.firstOrNull;
      if (recent == null) continue;
      contact.lastMessage = recent['body']?.toString() ?? '';
      contact.lastMessageAt = DateTime.tryParse(
        recent['created_at']?.toString() ?? '',
      );
    }
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

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
