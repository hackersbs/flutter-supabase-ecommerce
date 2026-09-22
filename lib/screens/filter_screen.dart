import 'package:e_comerce_appliction/provider/productprovider.dart';
import 'package:e_comerce_appliction/widgets/home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  static const _defaultCategories = [
    'All',
    'Food',
    'Electronics',
    'Laptop',
    'Phone',
    'Fashion',
    'Home Appliances',
    'Fan',
    'Fridge',
    'Beauty',
    'Grocery',
    'Books',
    'Toys',
    'Furniture',
    'Sports',
  ];

  double _minimumPrice = 0;
  double _maximumPrice = 100000;
  String _selectedCategory = 'All';
  String _selectedOffer = 'All offers';
  String _selectedSort = 'Relevance';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<Productprovider>();
      if (provider.products.isEmpty && !provider.isLoading) {
        provider.getProduct();
      }
    });
  }

  static double _readPrice(Map<String, dynamic> product, String key) {
    final value = product[key];
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  static int _discountPercentage(Map<String, dynamic> product) {
    final price = _readPrice(product, 'price');
    final discountPrice = _readPrice(product, 'discount_price');
    if (price <= 0 || discountPrice <= 0 || discountPrice >= price) return 0;
    return ((price - discountPrice) / price * 100).round();
  }

  void _resetFilters() {
    setState(() {
      _minimumPrice = 0;
      _maximumPrice = 100000;
      _selectedCategory = 'All';
      _selectedOffer = 'All offers';
      _selectedSort = 'Relevance';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Filter Products'),
        backgroundColor: const Color(0xFF2874F0),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _resetFilters,
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Consumer<Productprovider>(
        builder: (context, provider, child) {
          final categories = <String>{..._defaultCategories};
          for (final product in provider.products) {
            final category = (product['category'] ?? 'General')
                .toString()
                .trim();
            if (category.isNotEmpty) categories.add(category);
          }

          final filteredProducts = provider.products.where((product) {
            final originalPrice = _readPrice(product, 'price');
            final salePrice = _readPrice(product, 'discount_price');
            final activePrice = salePrice > 0 ? salePrice : originalPrice;
            final category = (product['category'] ?? 'General').toString();
            final hasOffer = salePrice > 0 && salePrice < originalPrice;

            final matchesPrice =
                activePrice >= _minimumPrice && activePrice <= _maximumPrice;
            final matchesCategory =
                _selectedCategory == 'All' || category == _selectedCategory;
            final matchesOffer =
                _selectedOffer == 'All offers' ||
                (_selectedOffer == 'Only offers' && hasOffer) ||
                (_selectedOffer == 'Without offers' && !hasOffer);

            return matchesPrice && matchesCategory && matchesOffer;
          }).toList();

          if (_selectedSort == 'Price: Low to High') {
            filteredProducts.sort(
              (first, second) => _readPrice(
                first,
                'price',
              ).compareTo(_readPrice(second, 'price')),
            );
          } else if (_selectedSort == 'Price: High to Low') {
            filteredProducts.sort(
              (first, second) => _readPrice(
                second,
                'price',
              ).compareTo(_readPrice(first, 'price')),
            );
          } else if (_selectedSort == 'Biggest Discount') {
            filteredProducts.sort(
              (first, second) =>
                  _discountPercentage(second)
                      .compareTo(_discountPercentage(first)),
            );
          } else if (_selectedSort == 'Name') {
            filteredProducts.sort(
              (first, second) => (first['name'] ?? '').toString().compareTo(
                (second['name'] ?? '').toString(),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _FilterPanel(
                  minimumPrice: _minimumPrice,
                  maximumPrice: _maximumPrice,
                  selectedCategory: _selectedCategory,
                  selectedOffer: _selectedOffer,
                  selectedSort: _selectedSort,
                  categories: categories.toList()..sort(),
                  onPriceChanged: (values) {
                    setState(() {
                      _minimumPrice = values.start;
                      _maximumPrice = values.end;
                    });
                  },
                  onCategoryChanged: (value) {
                    setState(() => _selectedCategory = value);
                  },
                  onOfferChanged: (value) {
                    setState(() => _selectedOffer = value);
                  },
                  onSortChanged: (value) {
                    setState(() => _selectedSort = value);
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '${filteredProducts.length} products found',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (provider.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filteredProducts.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('No products match these filters.'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.sizeOf(context).width >= 600
                          ? 4
                          : 2,
                      childAspectRatio: MediaQuery.sizeOf(context).width < 360
                          ? 0.68
                          : 0.75,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return FlipkartCardWidget(
                        product: filteredProducts[index],
                      );
                    }, childCount: filteredProducts.length),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final double minimumPrice;
  final double maximumPrice;
  final String selectedCategory;
  final String selectedOffer;
  final String selectedSort;
  final List<String> categories;
  final ValueChanged<RangeValues> onPriceChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onOfferChanged;
  final ValueChanged<String> onSortChanged;

  const _FilterPanel({
    required this.minimumPrice,
    required this.maximumPrice,
    required this.selectedCategory,
    required this.selectedOffer,
    required this.selectedSort,
    required this.categories,
    required this.onPriceChanged,
    required this.onCategoryChanged,
    required this.onOfferChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by price',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          RangeSlider(
            min: 0,
            max: 100000,
            divisions: 100,
            values: RangeValues(minimumPrice, maximumPrice),
            labels: RangeLabels(
              '₹${minimumPrice.round()}',
              '₹${maximumPrice.round()}',
            ),
            onChanged: onPriceChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₹${minimumPrice.round()}'),
              Text('₹${maximumPrice.round()}'),
            ],
          ),
          const SizedBox(height: 10),
          _FilterDropdown(
            label: 'Category',
            value: selectedCategory,
            items: categories,
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 12),
          _FilterDropdown(
            label: 'Offers',
            value: selectedOffer,
            items: const ['All offers', 'Only offers', 'Without offers'],
            onChanged: onOfferChanged,
          ),
          const SizedBox(height: 12),
          _FilterDropdown(
            label: 'Sort by',
            value: selectedSort,
            items: const [
              'Relevance',
              'Price: Low to High',
              'Price: High to Low',
              'Biggest Discount',
              'Name',
            ],
            onChanged: onSortChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
