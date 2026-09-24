import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:e_comerce_appliction/utils/error_handling.dart';

class OrderDitiyalce extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  bool isCreating = false;
  bool isLoadingOrders = false;
  bool isLoadingDashboard = false;
  bool isLoadingNotifications = false;
  String? errorMessage;
  List<Map<String, dynamic>> sellerOrders = [];
  List<Map<String, dynamic>> dashboardProducts = [];
  List<Map<String, dynamic>> dashboardOrders = [];
  List<Map<String, dynamic>> buyerOrders = [];
  List<Map<String, dynamic>> buyerReturns = [];
  List<Map<String, dynamic>> sellerReturns = [];
  List<Map<String, dynamic>> notifications = [];

  Future<String?> createOrder({
    required List<Map<String, dynamic>> products,
    required Map<String, String> customer,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      errorMessage = 'Please log in before placing an order.';
      notifyListeners();
      return null;
    }

    isCreating = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await supabase.rpc(
        'place_order',
        params: {
          'p_customer': customer,
          'p_items': products
              .map(
                (product) => {
                  'product_id': product['id'],
                  'quantity': (product['quantity'] as num?)?.toInt() ?? 1,
                },
              )
              .toList(),
        },
      );
      return response.toString();
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error creating order: $error');
      return null;
    } finally {
      isCreating = false;
      notifyListeners();
    }
  }

  Future<void> loadBuyerOrders() async {
    final buyer = supabase.auth.currentUser;
    if (buyer == null) return;

    isLoadingOrders = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id', buyer.id)
          .order('created_at', ascending: false);
      buyerOrders = List<Map<String, dynamic>>.from(response);
      final returns = await supabase
          .from('return_requests')
          .select('order_item_id, status')
          .eq('buyer_id', buyer.id);
      buyerReturns = List<Map<String, dynamic>>.from(returns);
    } catch (error) {
      buyerOrders = [];
      errorMessage = providerErrorMessage(error);
      debugPrint('Error loading buyer orders: $error');
    } finally {
      isLoadingOrders = false;
      notifyListeners();
    }
  }

  bool hasReturnRequest(String orderItemId) => buyerReturns.any(
    (item) => item['order_item_id']?.toString() == orderItemId,
  );

  String? returnStatus(String orderItemId) {
    for (final item in buyerReturns) {
      if (item['order_item_id']?.toString() == orderItemId) {
        return item['status']?.toString();
      }
    }
    return null;
  }

  Future<bool> requestReturn({
    required String orderId,
    required String orderItemId,
    required String sellerId,
  }) async {
    final buyer = supabase.auth.currentUser;
    if (buyer == null) return false;
    try {
      await supabase.from('return_requests').insert({
        'order_item_id': orderItemId,
        'order_id': orderId,
        'buyer_id': buyer.id,
        'seller_id': sellerId,
      });
      await loadBuyerOrders();
      return true;
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error requesting return: $error');
      notifyListeners();
      return false;
    }
  }

  Future<void> loadSellerOrders() async {
    final seller = supabase.auth.currentUser;
    if (seller == null) {
      errorMessage = 'No signed-in seller was found.';
      notifyListeners();
      return;
    }

    isLoadingOrders = true;
    errorMessage = null;
    notifyListeners();
    try {
      sellerOrders = await _loadSellerOrderRows(seller.id);
    } catch (error) {
      sellerOrders = [];
      errorMessage = providerErrorMessage(error);
      debugPrint('Error loading seller orders: $error');
    } finally {
      isLoadingOrders = false;
      notifyListeners();
    }
  }

  Future<void> loadSellerReturns() async {
    final seller = supabase.auth.currentUser;
    if (seller == null) return;
    isLoadingOrders = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await supabase
          .from('return_requests')
          .select('*')
          .eq('seller_id', seller.id)
          .order('created_at', ascending: false);
      final requests = List<Map<String, dynamic>>.from(response);
      final itemIds = requests
          .map((item) => item['order_item_id']?.toString())
          .whereType<String>()
          .toList();
      final orderIds = requests
          .map((item) => item['order_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final items = itemIds.isEmpty
          ? <dynamic>[]
          : await supabase
                .from('order_items')
                .select('*')
                .inFilter('id', itemIds);
      final orders = orderIds.isEmpty
          ? <dynamic>[]
          : await supabase.from('orders').select('*').inFilter('id', orderIds);
      final itemById = <String, Map<String, dynamic>>{
        for (final item in items)
          item['id'].toString(): Map<String, dynamic>.from(item),
      };
      final orderById = <String, Map<String, dynamic>>{
        for (final order in orders)
          order['id'].toString(): Map<String, dynamic>.from(order),
      };
      sellerReturns = requests
          .map(
            (request) => {
              ...request,
              'order_item':
                  itemById[request['order_item_id']?.toString()] ??
                  <String, dynamic>{},
              'order':
                  orderById[request['order_id']?.toString()] ??
                  <String, dynamic>{},
            },
          )
          .toList();
    } catch (error) {
      sellerReturns = [];
      errorMessage = providerErrorMessage(error);
      debugPrint('Error loading seller returns: $error');
    } finally {
      isLoadingOrders = false;
      notifyListeners();
    }
  }

  Future<bool> updateReturnStatus({
    required String returnId,
    required String status,
    required String buyerId,
    required String orderId,
  }) async {
    try {
      await supabase
          .from('return_requests')
          .update({
            'status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', returnId);
      await supabase.from('notifications').insert({
        'user_id': buyerId,
        'order_id': orderId,
        'title': 'Return update',
        'message': 'Your return is now $status.',
      });
      await loadSellerReturns();
      return true;
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadSellerDashboard() async {
    final seller = supabase.auth.currentUser;
    if (seller == null) {
      errorMessage = 'No signed-in seller was found.';
      notifyListeners();
      return;
    }

    isLoadingDashboard = true;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        supabase.from('product').select('*').eq('user_id', seller.id),
        _loadSellerOrderRows(seller.id),
      ]);
      dashboardProducts = List<Map<String, dynamic>>.from(results[0]);
      dashboardOrders = List<Map<String, dynamic>>.from(results[1]);
    } catch (error) {
      dashboardProducts = [];
      dashboardOrders = [];
      errorMessage = providerErrorMessage(error);
      debugPrint('Error loading seller dashboard: $error');
    } finally {
      isLoadingDashboard = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> _loadSellerOrderRows(
    String sellerId,
  ) async {
    final itemResponse = await supabase
        .from('order_items')
        .select('*')
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false);
    final items = List<Map<String, dynamic>>.from(itemResponse);
    final orderIds = items
        .map((item) => item['order_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    if (orderIds.isEmpty) return items;

    final orderResponse = await supabase
        .from('orders')
        .select('*')
        .inFilter('id', orderIds);
    final orders = <String, Map<String, dynamic>>{
      for (final order in orderResponse)
        order['id'].toString(): Map<String, dynamic>.from(order),
    };
    return items
        .map(
          (item) => {
            ...item,
            'orders':
                orders[item['order_id']?.toString()] ?? <String, dynamic>{},
          },
        )
        .toList();
  }

  Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
    required String buyerId,
  }) async {
    try {
      await supabase
          .from('orders')
          .update({'status': status})
          .eq('id', orderId);
      await supabase.from('notifications').insert({
        'user_id': buyerId,
        'order_id': orderId,
        'title': 'Order update',
        'message': 'Your order is now $status.',
      });
      await loadSellerOrders();
      return true;
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error updating order status: $error');
      notifyListeners();
      return false;
    }
  }

  Future<void> loadNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    isLoadingNotifications = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      notifications = List<Map<String, dynamic>>.from(response);
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error loading notifications: $error');
    } finally {
      isLoadingNotifications = false;
      notifyListeners();
    }
  }

  Future<bool> clearNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    try {
      await supabase.from('notifications').delete().eq('user_id', user.id);
      notifications = [];
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      notifyListeners();
      return false;
    }
  }
}
