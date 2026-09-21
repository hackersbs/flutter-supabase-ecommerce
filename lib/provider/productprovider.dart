import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Productprovider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> products = [];
  bool isLoading = false;

  Future<void> getProduct() async {
    isLoading = true;
    notifyListeners();
    try {
      // The select('*, users(name)') gets all product fields AND the seller's name from the users table!
      final response = await supabase.from('product').select('*, users(name)');
      products = List<Map<String, dynamic>>.from(response);
      print(products);
    } catch (e) {
      print('Error fetching products: \$e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> insertProduct({
    required String name,
    required double price,
    double? discountPrice,
    String? description,
    int? quantity,
    String? imgUrl,
    String? category,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('product').insert({
        'name': name,
        'price': price,
        'discount_price': discountPrice,
        'description': description,
        'quantity': quantity ?? 0,
        'img_url': imgUrl,
        'category': category ?? 'General',
        'user_id': user.id,
      });
      await getProduct(); // Refresh the product list
    } catch (e) {
      print('Error inserting product: $e');
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
          })
          .eq('id', id);
      await getProduct(); // Refresh the product list
    } catch (e) {
      print('Error updating product: $e');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await supabase.from('product').delete().eq('id', id);
      await getProduct(); // Refresh the product list
    } catch (e) {
      print('Error deleting product: $e');
    }
  }
}
