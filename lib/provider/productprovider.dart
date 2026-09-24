import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:e_comerce_appliction/utils/error_handling.dart';

class Productprovider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> products = [];
  final Set<String> likedProductIds = {};
  List<Map<String, dynamic>> popularProducts = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> getProduct() async {
    await _loadProducts();
  }

  Future<void> getSellerProducts() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      products = [];
      errorMessage = 'Please log in as a seller first.';
      notifyListeners();
      return;
    }
    await _loadProducts(userId: user.id);
  }

  Future<void> _loadProducts({String? userId}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      var query = supabase.from('product').select('*');
      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      final response = await query;
      products = List<Map<String, dynamic>>.from(response);
      await loadLikes();
      if (userId == null) {
        await loadPopularProducts();
      }
    } catch (e) {
      errorMessage = providerErrorMessage(e);
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
      errorMessage = providerErrorMessage(error);
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
      errorMessage = providerErrorMessage(error);
      debugPrint('Error loading related products: $error');
      return [];
    }
  }

  Future<String?> uploadProductImage(XFile image) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        errorMessage = 'Please log in as a seller first.';
        notifyListeners();
        return null;
      }

      final bytes = await image.readAsBytes();
      final fileName = image.name.isEmpty ? 'product.jpg' : image.name;
      final path =
          '${user.id}/${DateTime.now().microsecondsSinceEpoch}_$fileName';

      await supabase.storage
          .from('product-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: image.mimeType ?? 'image/jpeg',
              upsert: false,
            ),
          );

      return supabase.storage.from('product-images').getPublicUrl(path);
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error uploading product image: $error');
      notifyListeners();
      return null;
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
      await getSellerProducts();
      return true;
    } catch (e) {
      errorMessage = providerErrorMessage(e);
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
    errorMessage = null;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        errorMessage = 'Please log in as a seller first.';
        notifyListeners();
        return;
      }
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
          .eq('id', id)
          .eq('user_id', user.id);
      await getSellerProducts();
    } catch (e) {
      errorMessage = providerErrorMessage(e);
      debugPrint('Error updating product: $e');
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      await supabase
          .from('product')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);
      await getSellerProducts();
    } catch (e) {
      debugPrint('Error deleting product: $e');
    }
  }
}
