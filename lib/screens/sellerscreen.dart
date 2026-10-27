import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:e_comerce_appliction/provider/authprovider.dart';
import 'package:e_comerce_appliction/provider/orderditiyalce.dart';
import 'package:e_comerce_appliction/provider/productprovider.dart';
import 'package:e_comerce_appliction/provider/messageprovider.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:provider/provider.dart';
import 'package:e_comerce_appliction/screens/message_screen.dart';
import 'package:e_comerce_appliction/screens/account_screen.dart';
import 'package:e_comerce_appliction/data/catalog.dart';
import 'package:e_comerce_appliction/utils/currency.dart';
import 'package:e_comerce_appliction/utils/date_format.dart';
import 'package:e_comerce_appliction/widgets/seller_widgets.dart';

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
  String _searchQuery = '';
  String _orderSearchQuery = '';
  String _orderStatusFilter = 'All';
  String _returnSearchQuery = '';
  String _returnStatusFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<Productprovider>().getSellerProducts();
      context.read<OrderDitiyalce>().loadSellerDashboard();
    });
  }

  void _showProductDialog({Map<String, dynamic>? product}) {
    final nameController = TextEditingController(
      text: product?['name']?.toString() ?? '',
    );
    final priceController = TextEditingController(
      text: product?['price']?.toString() ?? '',
    );
    final discountPriceController = TextEditingController(
      text: product?['discount_price']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: product?['description']?.toString() ?? '',
    );
    final categoryController = TextEditingController(
      text: product?['category']?.toString() ?? '',
    );
    var selectedCategory = product?['category']?.toString();
    final subcategoryController = TextEditingController(
      text: product?['subcategory']?.toString() ?? '',
    );
    final quantityController = TextEditingController(
      text: product?['quantity']?.toString() ?? '',
    );
    final imgUrlController = TextEditingController(
      text: product?['img_url']?.toString() ?? '',
    );
    XFile? selectedImage;
    Uint8List? selectedImageBytes;
    var isUploadingImage = false;
    var isPickingImage = false;

    showDialog(
      context: context,
      builder: (context) {
        final screenSize = MediaQuery.sizeOf(context);
        final dialogWidth = math.min(500.0, screenSize.width - 48);
        final dialogHeight = math.min(620.0, screenSize.height * 0.62);
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(product == null ? 'Add Product' : 'Edit Product'),
          content: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                        ),
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
                              productCategoryNames.contains(selectedCategory)
                              ? selectedCategory
                              : null;
                          return Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: category,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                ),
                                items: productCategoryNames
                                    .map(
                                      (item) => DropdownMenuItem(
                                        value: item,
                                        child: Text(item),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedCategory = value;
                                    categoryController.text =
                                        value ?? 'General';
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: subcategoryController,
                                decoration: const InputDecoration(
                                  labelText: 'Subcategory',
                                ),
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
                          labelText: 'Image URL (Or upload below)',
                        ),
                      ),
                      if (selectedImage != null ||
                          imgUrlController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: selectedImage != null
                                ? Image.memory(
                                    selectedImageBytes!,
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    imgUrlController.text,
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const SizedBox(
                                              height: 140,
                                              child: Center(
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                ),
                                              ),
                                            ),
                                  ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isUploadingImage || isPickingImage
                              ? null
                              : () async {
                                  setDialogState(() => isPickingImage = true);
                                  try {
                                    final XFile? picked;
                                    if (Platform.isAndroid || Platform.isIOS) {
                                      picked = await image_picker.ImagePicker()
                                          .pickImage(
                                            source: image_picker
                                                .ImageSource
                                                .gallery,
                                            imageQuality: 85,
                                          );
                                    } else {
                                      picked = await openFile(
                                        acceptedTypeGroups: [
                                          const XTypeGroup(
                                            label: 'Images',
                                            extensions: [
                                              'jpg',
                                              'jpeg',
                                              'png',
                                              'webp',
                                            ],
                                          ),
                                        ],
                                      );
                                    }
                                    if (picked == null) return;
                                    final bytes = await picked.readAsBytes();
                                    if (!context.mounted) return;
                                    setDialogState(() {
                                      selectedImage = picked;
                                      selectedImageBytes = bytes;
                                    });
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'The image could not be selected. Please try again.',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (context.mounted) {
                                      setDialogState(
                                        () => isPickingImage = false,
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            isPickingImage
                                ? 'Opening gallery...'
                                : selectedImage == null
                                ? 'Choose Product Image'
                                : 'Change Image',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploadingImage
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final category = categoryController.text.trim();
                      final price =
                          double.tryParse(priceController.text) ?? 0.0;
                      final discountPrice = double.tryParse(
                        discountPriceController.text,
                      );
                      final description =
                          descriptionController.text.trim().isNotEmpty
                          ? descriptionController.text.trim()
                          : null;
                      final quantity = int.tryParse(quantityController.text);
                      final productProvider = context.read<Productprovider>();
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);

                      if (name.isEmpty || price <= 0 || category.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Name, Category, and a valid Price are required.',
                            ),
                          ),
                        );
                        return;
                      }

                      final imgUrl = imgUrlController.text.trim().isNotEmpty
                          ? imgUrlController.text.trim()
                          : null;

                      if (selectedImage == null && imgUrl == null) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Either an Image URL or an Uploaded Image is required.',
                            ),
                          ),
                        );
                        return;
                      }

                      if (selectedImage != null) {
                        setState(() => isUploadingImage = true);
                        final uploadedUrl = await productProvider
                            .uploadProductImage(selectedImage!);
                        if (uploadedUrl == null) {
                          setState(() => isUploadingImage = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                productProvider.errorMessage ??
                                    'Image upload failed. Please try again.',
                              ),
                            ),
                          );
                          return;
                        }
                        imgUrlController.text = uploadedUrl;
                        setState(() => isUploadingImage = false);
                      }

                      final finalImgUrl = imgUrlController.text.trim();

                      if (product == null) {
                        final inserted = await productProvider.insertProduct(
                          name: name,
                          price: price,
                          discountPrice: discountPrice,
                          description: description,
                          quantity: quantity,
                          imgUrl: finalImgUrl,
                          category: category,
                          subcategory:
                              subcategoryController.text.trim().isNotEmpty
                              ? subcategoryController.text.trim()
                              : category,
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
                        await productProvider.updateProduct(
                          id: product['id'].toString(),
                          name: name,
                          price: price,
                          discountPrice: discountPrice,
                          description: description,
                          quantity: quantity,
                          imgUrl: finalImgUrl,
                          category: category,
                          subcategory:
                              subcategoryController.text.trim().isNotEmpty
                              ? subcategoryController.text.trim()
                              : category,
                        );
                        if (productProvider.errorMessage != null) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(productProvider.errorMessage!),
                            ),
                          );
                          return;
                        }
                      }
                      navigator.pop();
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
          _buildReturnsPage(),
          _buildMessagesPage(),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          return NavigationBar(
            height: 68,
            labelTextStyle: WidgetStatePropertyAll(
              const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
            labelBehavior: constraints.maxWidth < 600
                ? NavigationDestinationLabelBehavior.onlyShowSelected
                : NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
              if (index == 0) {
                context.read<OrderDitiyalce>().loadSellerDashboard();
              } else if (index == 2) {
                context.read<OrderDitiyalce>().loadSellerOrders();
              } else if (index == 3) {
                context.read<OrderDitiyalce>().loadSellerReturns();
              } else if (index == 4) {
                context.read<MessageProvider>().loadContacts();
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dash',
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
                icon: Icon(Icons.assignment_return_outlined),
                selectedIcon: Icon(Icons.assignment_return),
                label: 'Returns',
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
          );
        },
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
                SellerDashboardFilters(
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
                  childAspectRatio: MediaQuery.sizeOf(context).width < 600
                      ? 1.2
                      : 1.55,
                  children: [
                    SellerMetricCard(
                      label: 'Sales items',
                      value: '$soldQuantity',
                      icon: Icons.shopping_bag_outlined,
                      color: Colors.green,
                    ),
                    SellerMetricCard(
                      label: 'Total revenue',
                      value: formatIndianRupees(revenue, decimals: false),
                      icon: Icons.payments_outlined,
                      color: Colors.indigo,
                    ),
                    SellerMetricCard(
                      label: 'Pending COD money',
                      value: formatIndianRupees(pendingMoney, decimals: false),
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.orange,
                    ),
                    SellerMetricCard(
                      label: 'Products in stock',
                      value: '$stock',
                      icon: Icons.inventory_2_outlined,
                      color: Colors.blueGrey,
                    ),
                    SellerMetricCard(
                      label: 'Customers',
                      value: '$customers',
                      icon: Icons.people_outline,
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SellerChartCard(
                  title: 'Delivered COD revenue',
                  trailing: formatIndianRupees(revenue, decimals: false),
                  child: SellerRevenueBar(value: revenue),
                ),
                const SizedBox(height: 14),
                SellerChartCard(
                  title: 'Top-selling products',
                  child: sortedProducts.isEmpty
                      ? const Text('No sales data for this selection.')
                      : SellerProductBars(
                          entries: sortedProducts.take(5).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                SellerChartCard(
                  title: 'Order status',
                  child: SellerStatusBars(orders: activeOrders),
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
          final search = _orderSearchQuery.trim().toLowerCase();
          final filteredOrders = orderProvider.sellerOrders.where((item) {
            final order = Map<String, dynamic>.from(item['orders'] ?? {});
            final status = order['status']?.toString() ?? 'pending';
            final buyer =
                order['customer_name']?.toString().toLowerCase() ?? '';
            final product =
                item['product_name']?.toString().toLowerCase() ?? '';
            final orderId = resolveOrderId(order, item: item).toLowerCase();
            final matchesStatus =
                _orderStatusFilter == 'All' || status == _orderStatusFilter;
            final matchesSearch =
                search.isEmpty ||
                buyer.contains(search) ||
                product.contains(search) ||
                orderId.contains(search);
            return matchesStatus && matchesSearch;
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _orderSearchQuery = value),
                        decoration: const InputDecoration(
                          labelText: 'Search buyer, product or order ID',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 145,
                      child: DropdownButtonFormField<String>(
                        initialValue: _orderStatusFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: _orderStatusOptions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _orderStatusFilter = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredOrders.isEmpty
                    ? const Center(
                        child: Text('No orders match these filters.'),
                      )
                    : RefreshIndicator(
                        onRefresh: orderProvider.loadSellerOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final item = filteredOrders[index];
                            final order = Map<String, dynamic>.from(
                              item['orders'] ?? {},
                            );
                            final status =
                                order['status']?.toString() ?? 'pending';
                            final buyer =
                                order['customer_name']?.toString() ?? 'Buyer';
                            final orderId = resolveOrderId(order, item: item);
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
                                          style: const TextStyle(
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Order #${shortOrderId(orderId)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                    const Divider(),
                                    Text(
                                      item['product_name']?.toString() ??
                                          'Product',
                                    ),
                                    Text('Quantity: ${item['quantity'] ?? 1}'),
                                    Text(
                                      'Total: ${formatIndianRupees(item['item_total'])}',
                                    ),
                                    const Text(
                                      'Payment: Cash on delivery',
                                      style: TextStyle(
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                    Text(
                                      'Placed on ${formatOrderDateTime(context, order['created_at'])}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Buyer contact details',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.phone_outlined,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            order['customer_phone']
                                                    ?.toString() ??
                                                'Phone not provided',
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.email_outlined,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            order['customer_email']
                                                    ?.toString() ??
                                                'Email not provided',
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${order['address'] ?? ''}, ${order['city'] ?? ''}, ${order['state'] ?? ''}, ${order['country'] ?? ''}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      initialValue:
                                          _statusOptions.contains(status)
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
                                        if (value == null || value == status) {
                                          return;
                                        }
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
                      ),
              ),
            ],
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

  static const _orderStatusOptions = ['All', ..._statusOptions, 'cancelled'];

  Widget _buildReturnsPage() {
    return Scaffold(
      appBar: AppBar(title: const Text('Return Items')),
      body: Consumer<OrderDitiyalce>(
        builder: (context, provider, child) {
          if (provider.isLoadingOrders) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.errorMessage != null && provider.sellerReturns.isEmpty) {
            return Center(child: Text(provider.errorMessage!));
          }
          if (provider.sellerReturns.isEmpty) {
            return const Center(child: Text('No return requests yet.'));
          }

          final search = _returnSearchQuery.trim().toLowerCase();
          final filteredReturns = provider.sellerReturns.where((request) {
            final item = Map<String, dynamic>.from(request['order_item'] ?? {});
            final order = Map<String, dynamic>.from(request['order'] ?? {});
            final status = request['status']?.toString() ?? 'requested';
            final buyer =
                order['customer_name']?.toString().toLowerCase() ?? '';
            final product =
                item['product_name']?.toString().toLowerCase() ?? '';
            final productId = (item['product_id'] ?? item['id'] ?? '')
                .toString()
                .toLowerCase();
            final matchesStatus =
                _returnStatusFilter == 'All' || status == _returnStatusFilter;
            final matchesSearch =
                search.isEmpty ||
                buyer.contains(search) ||
                product.contains(search) ||
                productId.contains(search);
            return matchesStatus && matchesSearch;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _returnSearchQuery = value),
                        decoration: const InputDecoration(
                          labelText: 'Search buyer, product or product ID',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        initialValue: _returnStatusFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: _returnStatusFilterOptions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _returnStatusFilter = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredReturns.isEmpty
                    ? const Center(
                        child: Text('No return requests match these filters.'),
                      )
                    : RefreshIndicator(
                        onRefresh: provider.loadSellerReturns,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredReturns.length,
                          itemBuilder: (context, index) {
                            final request = filteredReturns[index];
                            final item = Map<String, dynamic>.from(
                              request['order_item'] ?? {},
                            );
                            final order = Map<String, dynamic>.from(
                              request['order'] ?? {},
                            );
                            final status =
                                request['status']?.toString() ?? 'requested';
                            final orderId = resolveOrderId(
                              order,
                              item: item,
                              request: request,
                              fallback: request['order_id'],
                            );
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['product_name']?.toString() ??
                                          'Product',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Buyer: ${order['customer_name']?.toString() ?? 'Buyer'}',
                                    ),
                                    Text('Quantity: ${item['quantity'] ?? 1}'),
                                    Text(
                                      'Product ID: ${item['product_id'] ?? item['id'] ?? 'N/A'}',
                                    ),
                                    Text('Order #${shortOrderId(orderId)}'),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      initialValue:
                                          _returnStatusOptions.contains(status)
                                          ? status
                                          : _returnStatusOptions.first,
                                      decoration: const InputDecoration(
                                        labelText: 'Return status',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: _returnStatusOptions
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null || value == status) {
                                          return;
                                        }
                                        provider.updateReturnStatus(
                                          returnId: request['id'].toString(),
                                          status: value,
                                          buyerId: request['buyer_id']
                                              .toString(),
                                          orderId: request['order_id']
                                              .toString(),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
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

  static const _returnStatusOptions = [
    'requested',
    'pickup',
    'checked',
    'replacement packed',
    'replacement shipped',
    'shipped',
    'payment done',
    'rejected',
  ];

  static const _returnStatusFilterOptions = ['All', ..._returnStatusOptions];

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

          final filteredProducts = provider.products.where((product) {
            final name = product['name']?.toString().toLowerCase() ?? '';
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search Products',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: filteredProducts.isEmpty
                    ? const Center(
                        child: Text('No products match your search.'),
                      )
                    : ListView.builder(
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return SellerProductCard(
                            product: product,
                            onEdit: () => _showProductDialog(product: product),
                            onDelete: () {
                              context.read<Productprovider>().deleteProduct(
                                product['id'].toString(),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
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
