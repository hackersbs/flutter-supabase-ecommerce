import 'package:e_comerce_appliction/provider/cardeprovider.dart';
import 'package:e_comerce_appliction/screens/product_checkout_screen.dart';
import 'package:e_comerce_appliction/provider/productprovider.dart';
import 'package:e_comerce_appliction/provider/reviewprovider.dart';
import 'package:e_comerce_appliction/widgets/home_widgets.dart';
import 'package:e_comerce_appliction/widgets/image_url.dart';
import 'package:flutter/material.dart';
import 'package:e_comerce_appliction/utils/currency.dart';
import 'package:e_comerce_appliction/utils/product_pricing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  String _sellerName = 'Seller';
  bool _isLoadingSeller = true;
  List<Map<String, dynamic>> _relatedProducts = [];

  @override
  void initState() {
    super.initState();
    _loadSellerName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productId = widget.product['id']?.toString();
      if (productId != null) {
        context.read<ReviewProvider>().loadReviews(productId);
        _loadRelatedProducts(productId);
      }
    });
  }

  Future<void> _loadRelatedProducts(String productId) async {
    final related = await context.read<Productprovider>().getRelatedProducts(
      productId,
    );
    if (mounted) setState(() => _relatedProducts = related);
  }

  Future<void> _loadSellerName() async {
    final sellerId = widget.product['user_id']?.toString();
    if (sellerId == null || sellerId.isEmpty) {
      if (mounted) setState(() => _isLoadingSeller = false);
      return;
    }

    try {
      final seller = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('id', sellerId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _sellerName = seller?['name']?.toString().trim().isNotEmpty == true
            ? seller!['name'].toString()
            : 'Seller';
        _isLoadingSeller = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingSeller = false);
    }
  }

  double get _price => productPrice(widget.product, 'price');
  bool get _hasDiscount => hasProductDiscount(widget.product);
  double get _sellingPrice => activeProductPrice(widget.product);

  int get _discountPercentage => productDiscountPercentage(widget.product);

  List<Map<String, dynamic>> _suggestions(BuildContext context) {
    final allProducts = context.read<Productprovider>().products;
    final category = widget.product['category']?.toString().toLowerCase();
    final currentId = widget.product['id']?.toString();
    final price = _sellingPrice;
    final sameCategory = allProducts.where((item) {
      return item['id']?.toString() != currentId &&
          category != null &&
          item['category']?.toString().toLowerCase() == category;
    }).toList();
    sameCategory.sort(
      (first, second) => (activeProductPrice(first) - price).abs().compareTo(
        (activeProductPrice(second) - price).abs(),
      ),
    );
    final remaining = allProducts.where((item) {
      return item['id']?.toString() != currentId &&
          !sameCategory.contains(item) &&
          (activeProductPrice(item) - price).abs() <= price * 0.5;
    }).toList();
    final fallback = [...sameCategory, ...remaining].take(4).toList();
    final combined = <Map<String, dynamic>>[];
    for (final product in [..._relatedProducts, ...fallback]) {
      if (product['id']?.toString() == currentId) continue;
      if (!combined.any(
        (existing) => existing['id']?.toString() == product['id']?.toString(),
      )) {
        combined.add(product);
      }
    }
    return combined.take(4).toList();
  }

  Future<void> _addToCart() async {
    final cartProvider = context.read<CardeProvider>();
    final added = await cartProvider.addToCart(widget.product);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Product added to cart'
              : cartProvider.errorMessage ?? 'Product could not be added',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _buyNow() {
    final productForCheckout = Map<String, dynamic>.from(widget.product)
      ..['quantity'] = 1;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProductCheckoutScreen(products: [productForCheckout]),
      ),
    );
  }

  Future<void> _editReview(ReviewProvider provider) async {
    final existing = provider.myReview;
    var rating = (existing?['rating'] as num?)?.toInt() ?? 5;
    final commentController = TextEditingController(
      text: existing?['comment']?.toString() ?? '',
    );
    final result = await showModalBottomSheet<(int, String)?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (dialogContext, setSheetState) {
          final bottomInset = MediaQuery.viewInsetsOf(dialogContext).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + bottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Write a review' : 'Edit your review',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    return IconButton(
                      tooltip: '$value star${value == 1 ? '' : 's'}',
                      onPressed: () => setSheetState(() => rating = value),
                      icon: Icon(
                        value <= rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 34,
                      ),
                    );
                  }),
                ),
                TextField(
                  controller: commentController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Your comment',
                    hintText: 'Tell other buyers about this product',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final text = commentController.text.trim();
                      if (text.isEmpty) return;
                      Navigator.of(sheetContext).pop((rating, text));
                    },
                    child: Text(
                      existing == null ? 'Post review' : 'Save changes',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      commentController.dispose();
    });
    if (result == null || !mounted) return;
    final productId = widget.product['id']?.toString();
    if (productId == null) return;
    final saved = await provider.saveReview(
      productId: productId,
      rating: result.$1,
      comment: result.$2,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Review saved'
              : provider.errorMessage ?? 'Only buyers can review this product.',
        ),
      ),
    );
  }

  Widget _reviewsSection(BuildContext context) {
    return Consumer<ReviewProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (provider.errorMessage != null && provider.reviews.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(provider.errorMessage!),
              TextButton.icon(
                onPressed: () {
                  final productId = widget.product['id']?.toString();
                  if (productId != null) provider.loadReviews(productId);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry reviews'),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Buyer reviews',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (provider.myReview != null)
                  TextButton.icon(
                    onPressed: () => _editReview(provider),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit yours'),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _editReview(provider),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('Review'),
                  ),
              ],
            ),
            if (provider.reviews.isNotEmpty)
              Row(
                children: [
                  Text(
                    provider.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Stars(rating: provider.averageRating),
                  const SizedBox(width: 8),
                  Text(
                    '${provider.reviews.length} review${provider.reviews.length == 1 ? '' : 's'}',
                  ),
                ],
              )
            else
              Text(
                'No reviews yet. Be the first buyer to review this product.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            const SizedBox(height: 10),
            ...provider.reviews.map(
              (review) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              review['user_name']?.toString() ?? 'Buyer',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _Stars(
                            rating: (review['rating'] as num?)?.toDouble() ?? 0,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(review['comment']?.toString() ?? ''),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.product['img_url']?.toString();
    final suggestions = _suggestions(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Product details'),
        backgroundColor: const Color(0xFF2874F0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Add to cart',
            onPressed: _addToCart,
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 300,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.all(16),
              child: ProductImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product['name']?.toString() ?? 'Product',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      formatIndianRupees(_sellingPrice),
                      style: const TextStyle(
                        color: Color(0xFF2874F0),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_hasDiscount) ...[
                      Text(
                        formatIndianRupees(_price),
                        style: const TextStyle(
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Chip(
                        label: Text('$_discountPercentage% OFF'),
                        backgroundColor: const Color(0xFFDDF2E1),
                        labelStyle: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.storefront_outlined,
                  label: 'Seller',
                  value: _isLoadingSeller ? 'Loading seller...' : _sellerName,
                ),
                _InfoRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Quantity available',
                  value: '${widget.product['quantity'] ?? 0}',
                ),
                _InfoRow(
                  icon: Icons.category_outlined,
                  label: 'Category',
                  value: widget.product['category']?.toString() ?? 'General',
                ),
                _InfoRow(
                  icon: Icons.account_tree_outlined,
                  label: 'Subcategory',
                  value: widget.product['subcategory']?.toString() ?? 'General',
                ),
                const SizedBox(height: 18),
                const Text(
                  'Description',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.product['description']?.toString().trim().isNotEmpty ==
                          true
                      ? widget.product['description'].toString()
                      : 'No description available for this product.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _addToCart,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add to cart'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _buyNow,
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Buy now'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2874F0),
                      side: const BorderSide(color: Color(0xFF2874F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _reviewsSection(context),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'You may also like',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 285,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: suggestions.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: 180,
                          child: FlipkartCardWidget(
                            product: suggestions[index],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2874F0)),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  final double size;

  const _Stars({required this.rating, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index + 1 <= rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }
}
