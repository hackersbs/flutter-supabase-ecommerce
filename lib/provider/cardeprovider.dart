import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CardeProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  final List<Map<String, dynamic>> cartItems = [];
  bool isLoading = false;

  String? _productId(Map<String, dynamic> product) {
    final id = product['id']?.toString();
    return id == null || id.isEmpty ? null : id;
  }

  static double _priceFor(Map<String, dynamic> product) {
    final price = product['price'];
    final discountPrice = product['discount_price'];
    final originalPrice = price is num
        ? price.toDouble()
        : double.tryParse('$price') ?? 0;
    final salePrice = discountPrice is num
        ? discountPrice.toDouble()
        : double.tryParse('$discountPrice') ?? 0;
    return salePrice > 0 ? salePrice : originalPrice;
  }

  Future<void> loadCart() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    isLoading = true;
    notifyListeners();
    try {
      final response = await supabase
          .from('cart_items')
          .select('quantity, product:product_id(*)')
          .eq('user_id', user.id);
      cartItems
        ..clear()
        ..addAll(
          (response as List).map((item) {
            final cartItem = Map<String, dynamic>.from(item);
            final product = Map<String, dynamic>.from(
              cartItem['product'] as Map,
            );
            return {
              ...product,
              'quantity': (cartItem['quantity'] as num).toInt(),
            };
          }),
        );
    } catch (error) {
      debugPrint('Error loading cart: $error');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToCart(Map<String, dynamic> product) async {
    final productId = _productId(product);
    if (productId == null) {
      debugPrint('Cannot add cart item without a product id.');
      return;
    }
    final existingIndex = cartItems.indexWhere(
      (item) => _productId(item) == productId,
    );

    if (existingIndex == -1) {
      cartItems.add({...product, 'quantity': 1});
    } else {
      cartItems[existingIndex]['quantity'] =
          (cartItems[existingIndex]['quantity'] as int) + 1;
    }
    notifyListeners();

    await _saveCartItem(
      productId,
      cartItems[existingIndex == -1
              ? cartItems.length - 1
              : existingIndex]['quantity']
          as int,
    );
  }

  Future<void> increaseQuantity(int index) async {
    final productId = _productId(cartItems[index]);
    if (productId == null) return;
    cartItems[index]['quantity'] = (cartItems[index]['quantity'] as int) + 1;
    notifyListeners();
    await _saveCartItem(productId, cartItems[index]['quantity'] as int);
  }

  Future<void> decreaseQuantity(int index) async {
    final quantity = cartItems[index]['quantity'] as int;
    final productId = _productId(cartItems[index]);
    if (productId == null) return;
    if (quantity == 1) {
      cartItems.removeAt(index);
      await _deleteCartItem(productId);
    } else {
      cartItems[index]['quantity'] = quantity - 1;
      await _saveCartItem(productId, quantity - 1);
    }
    notifyListeners();
  }

  Future<void> removeFromCart(int index) async {
    final productId = _productId(cartItems[index]);
    if (productId == null) return;
    cartItems.removeAt(index);
    notifyListeners();
    await _deleteCartItem(productId);
  }

  Future<void> clearCart() async {
    final user = supabase.auth.currentUser;
    cartItems.clear();
    notifyListeners();
    if (user == null) return;

    try {
      await supabase.from('cart_items').delete().eq('user_id', user.id);
    } catch (error) {
      debugPrint('Error clearing cart: $error');
    }
  }

  Future<void> _saveCartItem(dynamic productId, int quantity) async {
    final user = supabase.auth.currentUser;
    if (user == null || productId == null) return;

    try {
      await supabase.from('cart_items').upsert({
        'user_id': user.id,
        'product_id': productId,
        'quantity': quantity,
      }, onConflict: 'user_id,product_id');
    } catch (error) {
      debugPrint('Error saving cart item: $error');
    }
  }

  Future<void> _deleteCartItem(dynamic productId) async {
    final user = supabase.auth.currentUser;
    if (user == null || productId == null) return;

    try {
      await supabase
          .from('cart_items')
          .delete()
          .eq('user_id', user.id)
          .eq('product_id', productId);
    } catch (error) {
      debugPrint('Error deleting cart item: $error');
    }
  }

  double get totalPrice => cartItems.fold(0, (total, item) {
    return total + _priceFor(item) * (item['quantity'] as int);
  });

  int get totalItems =>
      cartItems.fold(0, (total, item) => total + (item['quantity'] as int));
}
