import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Productprovider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> products = [];
  final Set<String> likedProductIds = {};
  List<Map<String, dynamic>> popularProducts = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> getProduct() async {
    isLoading = true;
    notifyListeners();
    try {
      // Products link to auth.users, so fetch the product row directly.
      final response = await supabase.from('product').select('*');
      products = List<Map<String, dynamic>>.from(response);
      await loadLikes();
      await loadPopularProducts();
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('Error fetching products: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPopularProducts() async {
    try {
      final response = await supabase.rpc('popular_products');
      popularProducts = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (error) {
      popularProducts = [];
      debugPrint('Error loading popular products: $error');
    }
  }

  bool isLiked(String productId) => likedProductIds.contains(productId);

  Future<void> loadLikes() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      likedProductIds.clear();
      return;
    }
    try {
      final response = await supabase
          .from('product_likes')
          .select('product_id')
          .eq('user_id', user.id);
      likedProductIds
        ..clear()
        ..addAll(
          response
              .map((row) => row['product_id']?.toString())
              .whereType<String>(),
        );
      notifyListeners();
    } catch (error) {
      debugPrint('Error loading liked products: $error');
    }
  }

  Future<void> toggleLike(Map<String, dynamic> product) async {
    final user = supabase.auth.currentUser;
    final productId = product['id']?.toString();
    if (user == null || productId == null) return;
    final wasLiked = isLiked(productId);
    if (wasLiked) {
      likedProductIds.remove(productId);
    } else {
      likedProductIds.add(productId);
    }
    notifyListeners();
    try {
      if (wasLiked) {
        await supabase
            .from('product_likes')
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', productId);
      } else {
        await supabase.from('product_likes').insert({
          'user_id': user.id,
          'product_id': productId,
        });
      }
    } catch (error) {
      if (wasLiked) {
        likedProductIds.add(productId);
      } else {
        likedProductIds.remove(productId);
      }
      debugPrint('Error changing product like: $error');
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> get likedProducts => products
      .where((product) => isLiked(product['id']?.toString() ?? ''))
      .toList();

  Future<List<Map<String, dynamic>>> getRelatedProducts(
    String productId,
  ) async {
    try {
      final response = await supabase.rpc(
        'recommended_products',
        params: {'target_product_id': productId},
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      debugPrint('Error loading related products: $error');
      return [];
    }
  }

  Future<bool> insertProduct({
    required String name,
    required double price,
    double? discountPrice,
    String? description,
    int? quantity,
    String? imgUrl,
    String? category,
    String? subcategory,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        errorMessage = 'Please log in as a seller first.';
        notifyListeners();
        return false;
      }

      await supabase.from('product').insert({
        'name': name,
        'price': price,
        'discount_price': discountPrice,
        'description': description,
        'quantity': quantity ?? 0,
        'img_url': imgUrl,
        'category': category ?? 'General',
        'subcategory': subcategory ?? 'General',
        'user_id': user.id,
      });
      await getProduct(); // Refresh the product list
      return true;
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('Error inserting product: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required double price,
    double? discountPrice,
    String? description,
    int? quantity,
    String? imgUrl,
    String? category,
    String? subcategory,
  }) async {
    try {
      await supabase
          .from('product')
          .update({
            'name': name,
            'price': price,
            'discount_price': discountPrice,
            'description': description,
            'quantity': quantity ?? 0,
            'img_url': imgUrl,
            'category': category ?? 'General',
            'subcategory': subcategory ?? 'General',
          })
          .eq('id', id);
      await getProduct(); // Refresh the product list
    } catch (e) {
      debugPrint('Error updating product: $e');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await supabase.from('product').delete().eq('id', id);
      await getProduct(); // Refresh the product list
    } catch (e) {
      debugPrint('Error deleting product: $e');
    }
  }
}
