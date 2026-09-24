import 'dart:math' as math;

import 'package:e_comerce_appliction/provider/productprovider.dart';
import 'package:e_comerce_appliction/data/catalog.dart';
import 'package:e_comerce_appliction/widgets/home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:e_comerce_appliction/utils/currency.dart';
import 'package:e_comerce_appliction/utils/product_pricing.dart';
import 'package:provider/provider.dart';
import 'package:e_comerce_appliction/widgets/error_state.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  double _minimumPrice = 0;
  double _maximumPrice = 100000;
  double _priceLimit = 100000;
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

  void _resetFilters() {
    setState(() {
      _minimumPrice = 0;
      _maximumPrice = 100000;
      _priceLimit = 100000;
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
          if (!provider.isLoading &&
              provider.errorMessage != null &&
              provider.products.isEmpty) {
            return ErrorState(
              message: provider.errorMessage!,
              onRetry: provider.getProduct,
            );
          }
          final categories = <String>{'All', ...productCategoryNames};
          for (final product in provider.products) {
            final category = (product['category'] ?? 'General')
                .toString()
                .trim();
            if (category.isNotEmpty) categories.add(category);
          }
          final highestProductPrice = provider.products.fold<double>(
            0,
            (highest, product) =>
                math.max(highest, activeProductPrice(product)),
          );
          final priceLimit = math
              .max(100000, (highestProductPrice / 10000).ceil() * 10000)
              .toDouble();
          if (priceLimit != _priceLimit) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                final wasAtPreviousLimit = _maximumPrice == _priceLimit;
                _priceLimit = priceLimit;
                if (wasAtPreviousLimit) _maximumPrice = priceLimit;
              });
            });
          }

          final filteredProducts = provider.products.where((product) {
            final activePrice = activeProductPrice(product);
            final category = (product['category'] ?? 'General').toString();
            final hasOffer = hasProductDiscount(product);

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
              (first, second) =>
                  activeProductPrice(first)
                      .compareTo(activeProductPrice(second)),
            );
          } else if (_selectedSort == 'Price: High to Low') {
            filteredProducts.sort(
              (first, second) =>
                  activeProductPrice(second)
                      .compareTo(activeProductPrice(first)),
            );
          } else if (_selectedSort == 'Biggest Discount') {
            filteredProducts.sort(
              (first, second) =>
                  productDiscountPercentage(second)
                      .compareTo(productDiscountPercentage(first)),
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
                  priceLimit: priceLimit,
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
  final double priceLimit;
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
    required this.priceLimit,
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
            max: priceLimit,
            divisions: priceLimit ~/ 1000,
            values: RangeValues(minimumPrice, maximumPrice),
            labels: RangeLabels(
              formatIndianRupees(minimumPrice, decimals: false),
              formatIndianRupees(maximumPrice, decimals: false),
            ),
            onChanged: onPriceChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatIndianRupees(minimumPrice, decimals: false)),
              Text(formatIndianRupees(maximumPrice, decimals: false)),
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
