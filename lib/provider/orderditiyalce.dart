import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderDitiyalce extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  bool isCreating = false;
  bool isLoadingOrders = false;
  bool isLoadingDashboard = false;
  String? errorMessage;
  List<Map<String, dynamic>> sellerOrders = [];
  List<Map<String, dynamic>> dashboardProducts = [];
  List<Map<String, dynamic>> dashboardOrders = [];
  List<Map<String, dynamic>> buyerOrders = [];
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
      errorMessage = error.toString();
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
    } catch (error) {
      buyerOrders = [];
      errorMessage = error.toString();
      debugPrint('Error loading buyer orders: $error');
    } finally {
      isLoadingOrders = false;
      notifyListeners();
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
      final response = await supabase
          .from('order_items')
          .select('*, orders!inner(*)')
          .eq('seller_id', seller.id)
          .order('created_at', ascending: false);
      sellerOrders = List<Map<String, dynamic>>.from(response);
    } catch (error) {
      sellerOrders = [];
      final message = error.toString();
      errorMessage = message.contains('42P17')
          ? 'Supabase order permissions have a recursive RLS policy. Run the seller orders SQL fix.'
          : message;
      debugPrint('Error loading seller orders: $error');
    } finally {
      isLoadingOrders = false;
      notifyListeners();
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
        supabase
            .from('order_items')
            .select('*, orders!inner(*)')
            .eq('seller_id', seller.id),
      ]);
      dashboardProducts = List<Map<String, dynamic>>.from(results[0]);
      dashboardOrders = List<Map<String, dynamic>>.from(results[1]);
    } catch (error) {
      dashboardProducts = [];
      dashboardOrders = [];
      errorMessage = error.toString();
      debugPrint('Error loading seller dashboard: $error');
    } finally {
      isLoadingDashboard = false;
      notifyListeners();
    }
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
      errorMessage = error.toString();
      debugPrint('Error updating order status: $error');
      notifyListeners();
      return false;
    }
  }

  Future<void> loadNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      notifications = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (error) {
      debugPrint('Error loading notifications: $error');
    }
  }
}
