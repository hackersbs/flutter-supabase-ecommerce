import 'package:e_comerce_appliction/provider/cardeprovider.dart';
import 'package:e_comerce_appliction/screens/product_checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:e_comerce_appliction/utils/currency.dart';
import 'package:e_comerce_appliction/utils/product_pricing.dart';
import 'package:e_comerce_appliction/widgets/image_url.dart';
import 'package:e_comerce_appliction/widgets/error_state.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String? _shownError;
  late final CardeProvider _cartProvider;

  @override
  void initState() {
    super.initState();
    _cartProvider = context.read<CardeProvider>();
    _cartProvider.addListener(_showProviderError);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cartProvider.loadCart();
    });
  }

  @override
  void dispose() {
    _cartProvider.removeListener(_showProviderError);
    super.dispose();
  }

  void _showProviderError() {
    final message = _cartProvider.errorMessage;
    if (message == null) {
      _shownError = null;
      return;
    }
    if (!mounted || message == _shownError) return;
    _shownError = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Cart'),
        backgroundColor: const Color(0xFF2874F0),
        foregroundColor: Colors.white,
      ),
      body: Consumer<CardeProvider>(
        builder: (context, cart, child) {
          if (cart.errorMessage != null && cart.cartItems.isEmpty) {
            return ErrorState(
              message: cart.errorMessage!,
              onRetry: cart.loadCart,
            );
          }
          if (cart.cartItems.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 72,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text('Add products to see them here.'),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.cartItems.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = cart.cartItems[index];
                    final imageUrl = product['img_url']?.toString() ?? '';
                    final quantity = product['quantity'] as int;
                    final availableStock =
                        (product['available_stock'] as num?)?.toInt() ??
                        quantity;
                    return Card(
                      margin: EdgeInsets.zero,
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            ProductImage(
                              imageUrl: imageUrl,
                              width: 92,
                              height: 104,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name']?.toString() ?? 'Product',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    formatIndianRupees(
                                      activeProductPrice(product),
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF2874F0),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _QuantityButton(
                                        icon: Icons.remove,
                                        onPressed: () =>
                                            cart.decreaseQuantity(index),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        child: Text(
                                          '$quantity',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      _QuantityButton(
                                        icon: Icons.add,
                                        onPressed: quantity >= availableStock
                                            ? null
                                            : () =>
                                                  cart.increaseQuantity(index),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Remove',
                                        onPressed: () =>
                                            cart.removeFromCart(index),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final summary = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${cart.totalItems} items'),
                          Text(
                            formatIndianRupees(cart.totalPrice),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                      final checkout = ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductCheckoutScreen(
                                products: List<Map<String, dynamic>>.from(
                                  cart.cartItems,
                                ),
                                clearCartAfterOrder: true,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Checkout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2874F0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 13,
                          ),
                        ),
                      );
                      if (constraints.maxWidth < 340) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summary,
                            const SizedBox(height: 12),
                            checkout,
                          ],
                        );
                      }
                      return Row(children: [summary, const Spacer(), checkout]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QuantityButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onPressed == null ? Colors.grey : null,
        ),
      ),
    );
  }
}
