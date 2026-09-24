import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:e_comerce_appliction/utils/error_handling.dart';
import 'package:e_comerce_appliction/utils/product_pricing.dart';

class CardeProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  final List<Map<String, dynamic>> cartItems = [];
  bool isLoading = false;
  String? errorMessage;

  String? _productId(Map<String, dynamic> product) {
    final id = product['id']?.toString();
    return id == null || id.isEmpty ? null : id;
  }

  int _stock(Map<String, dynamic> product) {
    final value = product['quantity'];
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  Future<void> loadCart() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    isLoading = true;
    errorMessage = null;
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
            final availableStock = _stock(product);
            final savedQuantity = (cartItem['quantity'] as num).toInt();
            return {
              ...product,
              'available_stock': availableStock,
              'quantity': availableStock > 0
                  ? savedQuantity.clamp(1, availableStock).toInt()
                  : 0,
            };
          }),
        );
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error loading cart: $error');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addToCart(Map<String, dynamic> product) async {
    final productId = _productId(product);
    if (productId == null) {
      errorMessage = 'This product cannot be added to the cart.';
      debugPrint('Cannot add cart item without a product id.');
      notifyListeners();
      return false;
    }
    final existingIndex = cartItems.indexWhere(
      (item) => _productId(item) == productId,
    );
    final previousQuantity = existingIndex == -1
        ? 0
        : cartItems[existingIndex]['quantity'] as int;
    final availableStock = _stock(product);
    if (availableStock <= 0) {
      errorMessage = 'This product is out of stock.';
      notifyListeners();
      return false;
    }
    if (previousQuantity >= availableStock) {
      errorMessage = 'Only $availableStock item(s) are available.';
      notifyListeners();
      return false;
    }

    if (existingIndex == -1) {
      cartItems.add({
        ...product,
        'available_stock': availableStock,
        'quantity': 1,
      });
    } else {
      cartItems[existingIndex]['quantity'] =
          (cartItems[existingIndex]['quantity'] as int) + 1;
    }
    notifyListeners();

    final saved = await _saveCartItem(
      productId,
      cartItems[existingIndex == -1
              ? cartItems.length - 1
              : existingIndex]['quantity']
          as int,
    );
    if (!saved) {
      if (existingIndex == -1) {
        cartItems.removeWhere((item) => _productId(item) == productId);
      } else {
        cartItems[existingIndex]['quantity'] = previousQuantity;
      }
      notifyListeners();
    }
    return saved;
  }

  Future<void> increaseQuantity(int index) async {
    final productId = _productId(cartItems[index]);
    if (productId == null) return;
    final currentQuantity = cartItems[index]['quantity'] as int;
    final availableStock =
        (cartItems[index]['available_stock'] as num?)?.toInt() ??
        _stock(cartItems[index]);
    if (currentQuantity >= availableStock) {
      errorMessage = 'Only $availableStock item(s) are available.';
      notifyListeners();
      return;
    }
    cartItems[index]['quantity'] = currentQuantity + 1;
    notifyListeners();
    final saved = await _saveCartItem(
      productId,
      cartItems[index]['quantity'] as int,
    );
    if (!saved) {
      cartItems[index]['quantity'] = currentQuantity;
      notifyListeners();
    }
  }

  Future<void> decreaseQuantity(int index) async {
    final quantity = cartItems[index]['quantity'] as int;
    final productId = _productId(cartItems[index]);
    if (productId == null) return;
    if (quantity <= 1) {
      final removedItem = Map<String, dynamic>.from(cartItems[index]);
      cartItems.removeAt(index);
      final deleted = await _deleteCartItem(productId);
      if (!deleted) cartItems.insert(index, removedItem);
    } else {
      cartItems[index]['quantity'] = quantity - 1;
      final saved = await _saveCartItem(productId, quantity - 1);
      if (!saved) cartItems[index]['quantity'] = quantity;
    }
    notifyListeners();
  }

  Future<void> removeFromCart(int index) async {
    final productId = _productId(cartItems[index]);
    if (productId == null) return;
    final removedItem = Map<String, dynamic>.from(cartItems[index]);
    cartItems.removeAt(index);
    notifyListeners();
    final deleted = await _deleteCartItem(productId);
    if (!deleted) {
      cartItems.insert(index, removedItem);
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    final user = supabase.auth.currentUser;
    cartItems.clear();
    notifyListeners();
    if (user == null) return;

    try {
      await supabase.from('cart_items').delete().eq('user_id', user.id);
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error clearing cart: $error');
    }
  }

  Future<bool> _saveCartItem(dynamic productId, int quantity) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      errorMessage = 'Please log in before adding items to the cart.';
      return false;
    }
    if (productId == null) return false;

    try {
      await supabase.from('cart_items').upsert({
        'user_id': user.id,
        'product_id': productId,
        'quantity': quantity,
      }, onConflict: 'user_id,product_id');
      errorMessage = null;
      return true;
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error saving cart item: $error');
      return false;
    }
  }

  Future<bool> _deleteCartItem(dynamic productId) async {
    final user = supabase.auth.currentUser;
    if (user == null || productId == null) return false;

    try {
      await supabase
          .from('cart_items')
          .delete()
          .eq('user_id', user.id)
          .eq('product_id', productId);
      errorMessage = null;
      return true;
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error deleting cart item: $error');
      return false;
    }
  }

  double get totalPrice => cartItems.fold(0, (total, item) {
    return total + activeProductPrice(item) * (item['quantity'] as int);
  });

  int get totalItems =>
      cartItems.fold(0, (total, item) => total + (item['quantity'] as int));
}
