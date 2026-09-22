import 'package:e_comerce_appliction/provider/authprovider.dart';
import 'package:e_comerce_appliction/provider/orderditiyalce.dart';
import 'package:e_comerce_appliction/provider/productprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:e_comerce_appliction/widgets/image_url.dart';
import 'package:e_comerce_appliction/screens/message_screen.dart';
import 'package:e_comerce_appliction/screens/account_screen.dart';
import 'package:e_comerce_appliction/data/catalog.dart';

class SellerScreen extends StatefulWidget {
  const SellerScreen({super.key});

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  int _selectedIndex = 0;
  String _selectedCountry = 'All';
  String _selectedState = 'All';
  String _selectedCity = 'All';

  String _placedDateTime(BuildContext context, dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return 'Order time unavailable';
    final local = parsed.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date at $time';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<Productprovider>().getProduct();
      context.read<OrderDitiyalce>().loadSellerDashboard();
    });
  }

  void _showProductDialog({Map<String, dynamic>? product}) {
    final nameController = TextEditingController(text: product?['name'] ?? '');
    final priceController = TextEditingController(
      text: product?['price']?.toString() ?? '',
    );
    final discountPriceController = TextEditingController(
      text: product?['discount_price']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: product?['description'] ?? '',
    );
    final categoryController = TextEditingController(
      text: product?['category'] ?? '',
    );
    var selectedCategory = product?['category']?.toString();
    var selectedSubcategory = product?['subcategory']?.toString();
    final quantityController = TextEditingController(
      text: product?['quantity']?.toString() ?? '',
    );
    final imgUrlController = TextEditingController(
      text: product?['img_url'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(product == null ? 'Add Product' : 'Edit Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                ),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                TextField(
                  controller: discountPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Discount Price (Optional)',
                  ),
                ),
                StatefulBuilder(
                  builder: (context, setDialogState) {
                    final category =
                        catalogCategories.any(
                          (item) => item.name == selectedCategory,
                        )
                        ? selectedCategory
                        : null;
                    final categoryData = catalogCategories.firstWhere(
                      (item) => item.name == category,
                      orElse: () => catalogCategories.first,
                    );
                    return Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: catalogCategories
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.name,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCategory = value;
                              categoryController.text = value ?? 'General';
                              selectedSubcategory = null;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue:
                              categoryData.subcategories.contains(
                                selectedSubcategory,
                              )
                              ? selectedSubcategory
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Subcategory',
                          ),
                          items: categoryData.subcategories
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => selectedSubcategory = value),
                        ),
                      ],
                    );
                  },
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                  ),
                  maxLines: 3,
                ),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity (Optional)',
                  ),
                ),
                TextField(
                  controller: imgUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (Optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final category = categoryController.text.trim();
                final price = double.tryParse(priceController.text) ?? 0.0;
                final discountPrice = double.tryParse(
                  discountPriceController.text,
                );
                final description = descriptionController.text.trim().isNotEmpty
                    ? descriptionController.text.trim()
                    : null;
                final quantity = int.tryParse(quantityController.text);
                final imgUrl = imgUrlController.text.trim().isNotEmpty
                    ? imgUrlController.text.trim()
                    : null;
                final productProvider = context.read<Productprovider>();
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                if (name.isNotEmpty && price > 0 && category.isNotEmpty) {
                  if (product == null) {
                    final inserted = await productProvider.insertProduct(
                      name: name,
                      price: price,
                      discountPrice: discountPrice,
                      description: description,
                      quantity: quantity,
                      imgUrl: imgUrl,
                      category: category,
                      subcategory: selectedSubcategory ?? category,
                    );
                    if (!inserted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            productProvider.errorMessage ??
                                'Product could not be added.',
                          ),
                        ),
                      );
                      return;
                    }
                  } else {
                    productProvider.updateProduct(
                      id: product['id'].toString(),
                      name: name,
                      price: price,
                      discountPrice: discountPrice,
                      description: description,
                      quantity: quantity,
                      imgUrl: imgUrl,
                      category: category,
                      subcategory: selectedSubcategory ?? category,
                    );
                  }
                  navigator.pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter valid name, category and price',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardPage(),
          _buildProductsPage(),
          _buildOrdersPage(),
          _buildMessagesPage(),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) {
            context.read<OrderDitiyalce>().loadSellerDashboard();
          } else if (index == 2) {
            context.read<OrderDitiyalce>().loadSellerOrders();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            selectedIcon: Icon(Icons.message),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardPage() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AthenDiction>().logOut(context),
          ),
        ],
      ),
      body: Consumer<OrderDitiyalce>(
        builder: (context, provider, child) {
          if (provider.isLoadingDashboard) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.errorMessage != null &&
              provider.dashboardProducts.isEmpty &&
              provider.dashboardOrders.isEmpty) {
            return Center(child: Text(provider.errorMessage!));
          }

          final locations = provider.dashboardOrders.map((item) {
            return Map<String, dynamic>.from(item['orders'] ?? {});
          }).toList();
          final countries = _locationValues(locations, 'country');
          final states = _locationValues(
            locations.where((order) {
              return _selectedCountry == 'All' ||
                  order['country']?.toString() == _selectedCountry;
            }).toList(),
            'state',
          );
          final cities = _locationValues(
            locations.where((order) {
              return (_selectedCountry == 'All' ||
                      order['country']?.toString() == _selectedCountry) &&
                  (_selectedState == 'All' ||
                      order['state']?.toString() == _selectedState);
            }).toList(),
            'city',
          );
          final filteredRows = provider.dashboardOrders.where((item) {
            final order = Map<String, dynamic>.from(item['orders'] ?? {});
            return (_selectedCountry == 'All' ||
                    order['country']?.toString() == _selectedCountry) &&
                (_selectedState == 'All' ||
                    order['state']?.toString() == _selectedState) &&
                (_selectedCity == 'All' ||
                    order['city']?.toString() == _selectedCity);
          }).toList();
          final activeRows = filteredRows.where((item) {
            final order = Map<String, dynamic>.from(item['orders'] ?? {});
            return order['status'] != 'cancelled';
          }).toList();
          final activeOrders = _uniqueOrders(activeRows);
          final soldQuantity = activeRows.fold<int>(
            0,
            (sum, item) => sum + _intValue(item['quantity']),
          );
          final customers = activeOrders
              .map((order) => order['user_id']?.toString())
              .whereType<String>()
              .toSet()
              .length;
          final stock = provider.dashboardProducts.fold<int>(
            0,
            (sum, product) => sum + _intValue(product['quantity']),
          );
          final revenue = activeRows
              .where((item) {
                final order = Map<String, dynamic>.from(item['orders'] ?? {});
                return order['status'] == 'delivered';
              })
              .fold<double>(
                0,
                (sum, item) => sum + _doubleValue(item['item_total']),
              );
          final pendingMoney = activeRows
              .where((item) {
                final order = Map<String, dynamic>.from(item['orders'] ?? {});
                return order['status'] != 'delivered';
              })
              .fold<double>(
                0,
                (sum, item) => sum + _doubleValue(item['item_total']),
              );
          final topProducts = <String, int>{};
          for (final item in activeRows) {
            final name = item['product_name']?.toString() ?? 'Product';
            topProducts[name] =
                (topProducts[name] ?? 0) + _intValue(item['quantity']);
          }
          final sortedProducts = topProducts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return RefreshIndicator(
            onRefresh: provider.loadSellerDashboard,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Business overview',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Track your stock, sales, customers, and deliveries.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _DashboardFilters(
                  countries: countries,
                  states: states,
                  cities: cities,
                  selectedCountry: _selectedCountry,
                  selectedState: _selectedState,
                  selectedCity: _selectedCity,
                  onCountryChanged: (value) {
                    setState(() {
                      _selectedCountry = value;
                      _selectedState = 'All';
                      _selectedCity = 'All';
                    });
                  },
                  onStateChanged: (value) {
                    setState(() {
                      _selectedState = value;
                      _selectedCity = 'All';
                    });
                  },
                  onCityChanged: (value) {
                    setState(() => _selectedCity = value);
                  },
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 600
                      ? 3
                      : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _MetricCard(
                      label: 'Sales items',
                      value: '$soldQuantity',
                      icon: Icons.shopping_bag_outlined,
                      color: Colors.green,
                    ),
                    _MetricCard(
                      label: 'Total revenue',
                      value: '₹${revenue.toStringAsFixed(0)}',
                      icon: Icons.payments_outlined,
                      color: Colors.indigo,
                    ),
                    _MetricCard(
                      label: 'Pending COD money',
                      value: '₹${pendingMoney.toStringAsFixed(0)}',
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.orange,
                    ),
                    _MetricCard(
                      label: 'Products in stock',
                      value: '$stock',
                      icon: Icons.inventory_2_outlined,
                      color: Colors.blueGrey,
                    ),
                    _MetricCard(
                      label: 'Customers',
                      value: '$customers',
                      icon: Icons.people_outline,
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ChartCard(
                  title: 'Delivered COD revenue',
                  trailing: '₹${revenue.toStringAsFixed(0)}',
                  child: _RevenueBar(value: revenue),
                ),
                const SizedBox(height: 14),
                _ChartCard(
                  title: 'Top-selling products',
                  child: sortedProducts.isEmpty
                      ? const Text('No sales data for this selection.')
                      : _ProductBars(entries: sortedProducts.take(5).toList()),
                ),
                const SizedBox(height: 14),
                _ChartCard(
                  title: 'Order status',
                  child: _StatusBars(orders: activeOrders),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<String> _locationValues(
    List<Map<String, dynamic>> orders,
    String field,
  ) {
    final values =
        orders
            .map((order) => order[field]?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  List<Map<String, dynamic>> _uniqueOrders(List<Map<String, dynamic>> rows) {
    final unique = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final order = Map<String, dynamic>.from(row['orders'] ?? {});
      final id = order['id']?.toString() ?? row['order_id']?.toString();
      if (id != null) unique[id] = order;
    }
    return unique.values.toList();
  }

  int _intValue(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  double _doubleValue(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  Widget _buildOrdersPage() {
    return Scaffold(
      appBar: AppBar(title: const Text('Buyer Orders')),
      body: Consumer<OrderDitiyalce>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoadingOrders) {
            return const Center(child: CircularProgressIndicator());
          }
          if (orderProvider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load buyer orders',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      orderProvider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: orderProvider.loadSellerOrders,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (orderProvider.sellerOrders.isEmpty) {
            return const Center(child: Text('No buyer orders yet.'));
          }
          return RefreshIndicator(
            onRefresh: orderProvider.loadSellerOrders,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orderProvider.sellerOrders.length,
              itemBuilder: (context, index) {
                final item = orderProvider.sellerOrders[index];
                final order = Map<String, dynamic>.from(item['orders'] ?? {});
                final status = order['status']?.toString() ?? 'pending';
                final buyer = order['customer_name']?.toString() ?? 'Buyer';
                final orderId = order['id']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                buyer,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              status,
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                        const Divider(),
                        Text(item['product_name']?.toString() ?? 'Product'),
                        Text('Quantity: ${item['quantity'] ?? 1}'),
                        Text('Total: ₹${item['item_total'] ?? 0}'),
                        const Text(
                          'Payment: Cash on delivery',
                          style: TextStyle(color: Colors.deepOrange),
                        ),
                        Text(
                          'Placed on ${_placedDateTime(context, order['created_at'])}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Buyer contact details',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                order['customer_phone']?.toString() ??
                                    'Phone not provided',
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                order['customer_email']?.toString() ??
                                    'Email not provided',
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${order['address'] ?? ''}, ${order['city'] ?? ''}, ${order['state'] ?? ''}, ${order['country'] ?? ''}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _statusOptions.contains(status)
                              ? status
                              : _statusOptions.first,
                          decoration: const InputDecoration(
                            labelText: 'Shipping status',
                            border: OutlineInputBorder(),
                          ),
                          items: _statusOptions
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null || value == status) return;
                            orderProvider.updateOrderStatus(
                              orderId: orderId,
                              status: value,
                              buyerId: order['user_id'].toString(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static const _statusOptions = [
    'pending',
    'packed',
    'shipped',
    'out for delivery',
    'delivered',
  ];

  Widget _buildMessagesPage() {
    return const MessageScreen();
  }

  Widget _buildProductsPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AthenDiction>().logOut(context);
            },
          ),
        ],
      ),
      body: Consumer<Productprovider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.products.isEmpty) {
            return const Center(child: Text('No products found. Add some!'));
          }

          return ListView.builder(
            itemCount: provider.products.length,
            itemBuilder: (context, index) {
              final product = provider.products[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Section
                      if (isValidImageUrl(product['img_url']?.toString()))
                        Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(
                                product['img_url'].toString(),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        ),

                      // Details Section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? 'No Name',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (product['category'] != null &&
                                product['category'].toString().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  product['category'],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            // Pricing
                            Row(
                              children: [
                                if (product['discount_price'] != null) ...[
                                  Text(
                                    '\$${product['price']}',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '\$${product['discount_price']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                      fontSize: 14,
                                    ),
                                  ),
                                ] else
                                  Text(
                                    '\$${product['price'] ?? 0.0}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Quantity & Date
                            Text(
                              'Qty: ${product['quantity'] ?? 0} | Added: ${product['created_at'] != null ? DateTime.parse(product['created_at']).toLocal().toString().split(' ')[0] : 'N/A'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Description
                            if (product['description'] != null &&
                                product['description'].toString().isNotEmpty)
                              Text(
                                product['description'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ),

                      // Actions Section
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () =>
                                _showProductDialog(product: product),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              context.read<Productprovider>().deleteProduct(
                                product['id'].toString(),
                              );
                            },
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DashboardFilters extends StatelessWidget {
  final List<String> countries;
  final List<String> states;
  final List<String> cities;
  final String selectedCountry;
  final String selectedState;
  final String selectedCity;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<String> onStateChanged;
  final ValueChanged<String> onCityChanged;

  const _DashboardFilters({
    required this.countries,
    required this.states,
    required this.cities,
    required this.selectedCountry,
    required this.selectedState,
    required this.selectedCity,
    required this.onCountryChanged,
    required this.onStateChanged,
    required this.onCityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales location',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DashboardDropdown(
                    label: 'Country',
                    value: selectedCountry,
                    items: countries,
                    onChanged: onCountryChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DashboardDropdown(
                    label: 'State',
                    value: selectedState,
                    items: states,
                    onChanged: onStateChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _DashboardDropdown(
              label: 'City',
              value: selectedCity,
              items: cities,
              onChanged: onCityChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DashboardDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : 'All';
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (nextValue) {
        if (nextValue != null) onChanged(nextValue);
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 26),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;

  const _ChartCard({required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: const TextStyle(
                      color: Color(0xFF2874F0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _RevenueBar extends StatelessWidget {
  final double value;

  const _RevenueBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          minHeight: 12,
          value: value > 0 ? 1 : 0,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF2874F0),
          backgroundColor: const Color(0xFFDDE8FF),
        ),
        const SizedBox(height: 8),
        const Text(
          'Revenue from delivered and active orders',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}

class _ProductBars extends StatelessWidget {
  final List<MapEntry<String, int>> entries;

  const _ProductBars({required this.entries});

  @override
  Widget build(BuildContext context) {
    final maximum = entries.fold<int>(0, (max, item) {
      return item.value > max ? item.value : max;
    });
    return Column(
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: maximum == 0 ? 0 : entry.value / maximum,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF32A852),
                  backgroundColor: const Color(0xFFDDF2E1),
                ),
              ),
              const SizedBox(width: 8),
              Text('${entry.value}'),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatusBars extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const _StatusBars({required this.orders});

  @override
  Widget build(BuildContext context) {
    const statuses = ['pending', 'packed', 'shipped', 'delivered'];
    final counts = <String, int>{for (final status in statuses) status: 0};
    for (final order in orders) {
      final status = order['status']?.toString() ?? 'pending';
      final normalized = status == 'out for delivery' ? 'shipped' : status;
      if (counts.containsKey(normalized)) {
        counts[normalized] = counts[normalized]! + 1;
      }
    }
    final maximum = counts.values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );

    return Column(
      children: counts.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(width: 92, child: Text(entry.key)),
              Expanded(
                child: LinearProgressIndicator(
                  value: maximum == 0 ? 0 : entry.value / maximum,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFFF9F43),
                  backgroundColor: const Color(0xFFFFE8CC),
                ),
              ),
              const SizedBox(width: 8),
              Text('${entry.value}'),
            ],
          ),
        );
      }).toList(),
    );
  }
}
