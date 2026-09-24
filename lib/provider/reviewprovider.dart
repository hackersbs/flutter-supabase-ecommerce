import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:e_comerce_appliction/utils/error_handling.dart';

class ReviewProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> reviews = [];
  Map<String, dynamic>? myReview;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  double get averageRating {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<int>(
      0,
      (sum, review) => sum + ((review['rating'] as num?)?.toInt() ?? 0),
    );
    return total / reviews.length;
  }

  Future<void> loadReviews(String productId) async {
    final userId = supabase.auth.currentUser?.id;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await supabase
          .from('product_reviews')
          .select()
          .eq('product_id', productId)
          .order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(response);
      final userIds = rows
          .map((review) => review['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final names = <String, String>{};
      if (userIds.isNotEmpty) {
        final profiles = await supabase
            .from('users')
            .select('id, name')
            .inFilter('id', userIds);
        for (final profile in profiles) {
          final id = profile['id']?.toString();
          if (id != null) names[id] = profile['name']?.toString() ?? 'Buyer';
        }
      }
      for (final review in rows) {
        review['user_name'] = names[review['user_id']?.toString()] ?? 'Buyer';
      }
      reviews = rows;
      myReview = userId == null
          ? null
          : rows.cast<Map<String, dynamic>?>().firstWhere(
              (review) => review?['user_id'] == userId,
              orElse: () => null,
            );
    } catch (error) {
      reviews = [];
      myReview = null;
      errorMessage = providerErrorMessage(error);
      debugPrint('Error loading product reviews: $error');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveReview({
    required String productId,
    required int rating,
    required String comment,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    final text = comment.trim();
    if (userId == null || rating < 1 || rating > 5 || text.isEmpty) {
      return false;
    }
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await supabase.from('product_reviews').upsert({
        'product_id': productId,
        'user_id': userId,
        'rating': rating,
        'comment': text,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'product_id,user_id');
      await loadReviews(productId);
      return true;
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error saving product review: $error');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
