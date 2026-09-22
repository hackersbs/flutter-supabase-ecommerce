import 'package:e_comerce_appliction/provider/userprovider.dart';
import 'package:e_comerce_appliction/provider/orderditiyalce.dart';
import 'package:e_comerce_appliction/provider/cardeprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:e_comerce_appliction/widgets/image_url.dart';

class ProductCheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final bool clearCartAfterOrder;

  const ProductCheckoutScreen({
    super.key,
    required this.products,
    this.clearCartAfterOrder = false,
  });

  @override
  State<ProductCheckoutScreen> createState() => _ProductCheckoutScreenState();
}

class _ProductCheckoutScreenState extends State<ProductCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  static const _userFields = [
    ('name', 'Full name', Icons.person_outline),
    ('email', 'Email', Icons.email_outlined),
    ('phone', 'Phone number', Icons.phone_outlined),
    ('address', 'Address', Icons.home_outlined),
    ('country', 'Country', Icons.public_outlined),
    ('state', 'State', Icons.map_outlined),
    ('city', 'City', Icons.location_city_outlined),
  ];

  @override
  void initState() {
    super.initState();
    for (final field in _userFields) {
      _controllers[field.$1] = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProvider = context.read<UserProvider>();
      await userProvider.loadUser();
      if (!mounted) return;
      for (final field in _userFields) {
        _controllers[field.$1]!.text = userProvider.getValue(field.$1);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _priceFor(Map<String, dynamic> product) {
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

  double get _total => widget.products.fold(0, (total, product) {
    final quantity = (product['quantity'] as num?)?.toInt() ?? 1;
    return total + (_priceFor(product) * quantity);
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final orderProvider = context.watch<OrderDitiyalce>();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Product Checkout'),
        backgroundColor: const Color(0xFF2874F0),
        foregroundColor: Colors.white,
      ),
      body: userProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('Order details', Icons.shopping_bag_outlined),
                  ...widget.products.map(_productTile),
                  _totalCard(),
                  const SizedBox(height: 16),
                  _sectionTitle('Delivery details', Icons.location_on_outlined),
                  ..._userFields.map(_userField),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: orderProvider.isCreating ? null : _placeOrder,
                      icon: const Icon(Icons.check_circle_outline),
                      label: orderProvider.isCreating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Place order • ₹${_total.toStringAsFixed(2)}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2874F0),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2874F0)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _productTile(Map<String, dynamic> product) {
    final imageUrl = product['img_url']?.toString() ?? '';
    final quantity = (product['quantity'] as num?)?.toInt() ?? 1;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              height: 62,
              child: !isValidImageUrl(imageUrl)
                  ? const Icon(Icons.image_not_supported, color: Colors.grey)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name']?.toString() ?? 'Product',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Quantity: $quantity'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '₹${(_priceFor(product) * quantity).toStringAsFixed(2)}',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalCard() {
    return Card(
      color: const Color(0xFFEAF2FF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total price',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              '₹${_total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF2874F0),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userField((String, String, IconData) field) {
    final isEmail = field.$1 == 'email';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[field.$1],
        keyboardType: field.$1 == 'phone'
            ? TextInputType.phone
            : isEmail
            ? TextInputType.emailAddress
            : TextInputType.text,
        maxLines: field.$1 == 'address' ? 2 : 1,
        decoration: InputDecoration(
          labelText: field.$2,
          prefixIcon: Icon(field.$3),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter ${field.$2.toLowerCase()}'
            : null,
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final cartProvider = context.read<CardeProvider>();
    final customer = {
      for (final field in _userFields)
        field.$1: _controllers[field.$1]!.text.trim(),
    };
    final orderId = await context.read<OrderDitiyalce>().createOrder(
      products: widget.products,
      customer: customer,
    );
    if (!mounted) return;

    if (orderId == null) {
      final message =
          context.read<OrderDitiyalce>().errorMessage ??
          'Could not place order.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 52),
        title: const Text('Order placed'),
        content: Text('Your order ID is $orderId'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (widget.clearCartAfterOrder) {
      await cartProvider.clearCart();
    }
    if (!mounted) return;
    Navigator.pop(context);
  }
}
