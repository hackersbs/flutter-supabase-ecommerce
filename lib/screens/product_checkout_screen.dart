import 'package:e_comerce_appliction/provider/userprovider.dart';
import 'package:e_comerce_appliction/provider/orderditiyalce.dart';
import 'package:e_comerce_appliction/provider/cardeprovider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:e_comerce_appliction/utils/currency.dart';
import 'package:e_comerce_appliction/utils/product_pricing.dart';
import 'package:provider/provider.dart';
import 'package:e_comerce_appliction/widgets/image_url.dart';
import 'package:e_comerce_appliction/widgets/error_state.dart';
import 'package:e_comerce_appliction/provider/razorpayprovider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

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
  final TextEditingController _couponController = TextEditingController();
  String _paymentMethod = 'cash_on_delivery';
  bool _isSubmitting = false;

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
      final orderProvider = context.read<OrderDitiyalce>();
      await Future.wait([
        userProvider.loadUser(),
        orderProvider.loadActiveCoupons(),
      ]);
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
    _couponController.dispose();
    super.dispose();
  }

  double get _subtotal => widget.products.fold(0.0, (total, product) {
    final quantity = (product['quantity'] as num?)?.toInt() ?? 1;
    return total + (activeProductPrice(product) * quantity);
  });

  double _discount(OrderDitiyalce orderProvider) {
    final applied = orderProvider.appliedCoupon;
    if (applied == null) return 0.0;
    return (applied['discount'] as num?)?.toDouble() ?? 0.0;
  }

  double _finalTotal(OrderDitiyalce orderProvider) {
    final net = _subtotal - _discount(orderProvider);
    return net > 0 ? net : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final orderProvider = context.watch<OrderDitiyalce>();
    final payableTotal = _finalTotal(orderProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Product Checkout'),
        backgroundColor: const Color(0xFF2874F0),
        foregroundColor: Colors.white,
      ),
      body: userProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : userProvider.errorMessage != null && userProvider.userData.isEmpty
          ? ErrorState(
              message: userProvider.errorMessage!,
              onRetry: userProvider.loadUser,
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('Order details', Icons.shopping_bag_outlined),
                  ...widget.products.map(_productTile),
                  const SizedBox(height: 12),
                  _couponSection(orderProvider),
                  const SizedBox(height: 12),
                  _totalCard(orderProvider),
                  const SizedBox(height: 16),
                  _sectionTitle('Delivery details', Icons.location_on_outlined),
                  ..._userFields.map(_userField),
                  const SizedBox(height: 16),
                  _sectionTitle('Payment method', Icons.payment_outlined),
                  _paymentMethodOption(
                    value: 'cash_on_delivery',
                    title: 'Cash on delivery',
                    subtitle: 'Pay when your order is delivered',
                    icon: Icons.payments_outlined,
                  ),
                  _paymentMethodOption(
                    value: 'razorpay',
                    title: 'Razorpay Test Mode',
                    subtitle: 'Pay securely using Razorpay test credentials',
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting || orderProvider.isCreating
                          ? null
                          : () => _placeOrder(payableTotal),
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
                          : Text(
                              _paymentMethod == 'razorpay'
                                  ? 'Pay • ${formatIndianRupees(payableTotal)}'
                                  : 'Place order • ${formatIndianRupees(payableTotal)}',
                            ),
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
    final imageUrl = product['img_url']?.toString();
    final quantity = (product['quantity'] as num?)?.toInt() ?? 1;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ProductImage(imageUrl: imageUrl, width: 62, height: 62),
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
                formatIndianRupees(activeProductPrice(product) * quantity),
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

  Widget _couponSection(OrderDitiyalce orderProvider) {
    final appliedCoupon = orderProvider.appliedCoupon;
    final activeCoupons = orderProvider.activeCoupons;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: appliedCoupon != null
              ? const Color(0xFF388E3C)
              : Colors.grey.shade300,
          width: appliedCoupon != null ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  color: appliedCoupon != null
                      ? const Color(0xFF388E3C)
                      : const Color(0xFF2874F0),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Apply Coupons & Offers',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: appliedCoupon != null
                        ? const Color(0xFF2E7D32)
                        : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (appliedCoupon != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, color: Color(0xFF2E7D32), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Applied',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (appliedCoupon != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                appliedCoupon['code']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 1.1,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• Saved ${formatIndianRupees((appliedCoupon['discount'] as num?)?.toDouble() ?? 0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (appliedCoupon['title'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                appliedCoupon['title'].toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        orderProvider.removeCoupon();
                        _couponController.clear();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('REMOVE'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _couponController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Enter coupon code',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF2874F0),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: orderProvider.isValidatingCoupon
                          ? null
                          : () => _handleApplyCoupon(orderProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2874F0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: orderProvider.isValidatingCoupon
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('APPLY'),
                    ),
                  ),
                ],
              ),
              if (activeCoupons.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Available Offers:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: activeCoupons.map((coupon) {
                    final code = coupon['code']?.toString() ?? '';
                    final minOrder = (coupon['min_order_amount'] as num?)?.toDouble() ?? 0.0;
                    final isEligible = _subtotal >= minOrder;

                    return ActionChip(
                      avatar: Icon(
                        Icons.discount_outlined,
                        size: 15,
                        color: isEligible
                            ? const Color(0xFF2874F0)
                            : Colors.grey.shade500,
                      ),
                      label: Text(
                        '$code ${minOrder > 0 ? '(min ₹${minOrder.toInt()})' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isEligible
                              ? const Color(0xFF2874F0)
                              : Colors.grey.shade600,
                        ),
                      ),
                      backgroundColor: isEligible
                          ? const Color(0xFFEAF2FF)
                          : Colors.grey.shade100,
                      side: BorderSide(
                        color: isEligible
                            ? const Color(0xFF90CAF9)
                            : Colors.grey.shade300,
                      ),
                      onPressed: isEligible
                          ? () {
                              _couponController.text = code;
                              _handleApplyCoupon(orderProvider, code: code);
                            }
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Add ₹${(minOrder - _subtotal).toStringAsFixed(0)} more to unlock $code',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleApplyCoupon(OrderDitiyalce orderProvider, {String? code}) async {
    final couponCode = (code ?? _couponController.text).trim().toUpperCase();
    if (couponCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a coupon code.')),
      );
      return;
    }

    final result = await orderProvider.applyCoupon(
      code: couponCode,
      orderAmount: _subtotal,
    );

    if (!mounted) return;
    if (result != null) {
      final discountVal = (result['discount'] as num?)?.toDouble() ?? 0.0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coupon $couponCode applied! Saved ${formatIndianRupees(discountVal)}',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderProvider.errorMessage ?? 'Invalid coupon code.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _totalCard(OrderDitiyalce orderProvider) {
    final discountVal = _discount(orderProvider);
    final applied = orderProvider.appliedCoupon;
    final payableTotal = _finalTotal(orderProvider);

    return Card(
      color: const Color(0xFFEAF2FF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                Text(
                  formatIndianRupees(_subtotal),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (discountVal > 0 && applied != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Coupon Discount',
                        style: TextStyle(fontSize: 14, color: Color(0xFF2E7D32)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${applied['code']})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '- ${formatIndianRupees(discountVal)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total payable',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  formatIndianRupees(payableTotal),
                  style: const TextStyle(
                    color: Color(0xFF2874F0),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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

  Widget _paymentMethodOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: RadioListTile<String>(
        value: value,
        groupValue: _paymentMethod,
        onChanged: _isSubmitting
            ? null
            : (selected) {
                if (selected != null) {
                  setState(() => _paymentMethod = selected);
                }
              },
        secondary: Icon(icon, color: const Color(0xFF2874F0)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }

  Future<void> _placeOrder(double payableTotal) async {
    if (!_formKey.currentState!.validate()) return;

    final razorpayKeyId = dotenv.env['RAZORPAY_KEY_ID']?.trim() ?? '';
    if (_paymentMethod == 'razorpay') {
      final razorpayProvider = context.read<RazorpayProvider>();
      if (!razorpayProvider.isSupportedPlatform) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Razorpay is only supported on Android or iOS devices. Please run on Android to test payments.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      if (!razorpayKeyId.startsWith('rzp_test_')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add a valid Razorpay Test Mode key ID to the app .env.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    final cartProvider = context.read<CardeProvider>();
    final orderProvider = context.read<OrderDitiyalce>();
    final razorpayProvider = context.read<RazorpayProvider>();
    final customer = {
      for (final field in _userFields)
        field.$1: _controllers[field.$1]!.text.trim(),
    };
    final appliedCouponCode = orderProvider.appliedCoupon?['code']?.toString();
    String? orderId;
    var paymentConfirmed = false;
    try {
      if (_paymentMethod == 'cash_on_delivery') {
        orderId = await orderProvider.createOrder(
          products: widget.products,
          customer: customer,
          couponCode: appliedCouponCode,
        );
        if (orderId == null) {
          throw Exception(
            orderProvider.errorMessage ?? 'Could not place the order.',
          );
        }
        paymentConfirmed = true;
      } else {
        final paymentOrder = await orderProvider.createRazorpayOrder(
          products: widget.products,
          customer: customer,
          couponCode: appliedCouponCode,
        );
        if (paymentOrder == null) {
          throw Exception(
            orderProvider.errorMessage ?? 'Could not start Razorpay payment.',
          );
        }

        debugPrint('Razorpay Order Response: $paymentOrder');

        orderId = paymentOrder['order_id']?.toString();
        final razorpayOrderId =
            paymentOrder['razorpay_order_id']?.toString() ??
            paymentOrder['id']?.toString() ??
            '';
        final rawAmount = paymentOrder['amount'];
        final amount = rawAmount is num
            ? rawAmount.round()
            : int.tryParse(rawAmount?.toString() ?? '') ??
                (payableTotal * 100).round();
        final currency =
            paymentOrder['currency']?.toString().toUpperCase() ?? 'INR';

        if (orderId == null || orderId.isEmpty) {
          throw Exception(
            'Missing internal order ID from payment service: $paymentOrder',
          );
        }
        if (razorpayOrderId.isEmpty) {
          throw Exception(
            'Missing Razorpay order ID from payment service: $paymentOrder',
          );
        }

        if (!mounted) return;
        final PaymentSuccessResponse payment = await razorpayProvider
            .openCheckout(
              options: {
                'key': razorpayKeyId,
                'amount': amount,
                'currency': currency,
                'order_id': razorpayOrderId,
                'name': 'E-commerce Store',
                'description': 'Order payment',
                'prefill': {
                  'name': customer['name'],
                  'email': customer['email'],
                  'contact': customer['phone'],
                },
                'theme': {'color': '#2874F0'},
              },
            );
        if (payment.paymentId == null ||
            payment.orderId == null ||
            payment.signature == null) {
          throw Exception('Razorpay returned incomplete payment details.');
        }

        paymentConfirmed = await orderProvider.verifyRazorpayPayment(
          orderId: orderId,
          razorpayOrderId: payment.orderId!,
          razorpayPaymentId: payment.paymentId!,
          razorpaySignature: payment.signature!,
        );
        if (!paymentConfirmed) {
          throw Exception(
            orderProvider.errorMessage ??
                'Payment could not be confirmed. Contact support with payment ID ${payment.paymentId}.',
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!mounted || !paymentConfirmed || orderId == null) return;

    // Immediately refresh orders in background so both buyer and seller screens reflect the new order
    orderProvider.loadBuyerOrders();
    orderProvider.loadSellerOrders();
    orderProvider.loadSellerDashboard();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 52),
        title: Text(
          _paymentMethod == 'razorpay' ? 'Payment successful' : 'Order placed',
        ),
        content: Text(
          _paymentMethod == 'razorpay'
              ? 'Your Razorpay payment has been confirmed! Your order is now visible in "My Orders" for you and in the seller dashboard for the seller.'
              : 'Your order ID is $orderId. You can track this order under "My Orders".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (widget.clearCartAfterOrder) {
      await cartProvider.clearCart();
    }
    _couponController.clear();
    orderProvider.removeCoupon();
    if (!mounted) return;
    Navigator.pop(context);
  }
}
