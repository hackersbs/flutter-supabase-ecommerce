import 'package:flutter/material.dart';

class CatalogCategory {
  final IconData icon;
  final String name;
  final List<String> subcategories;

  const CatalogCategory({
    required this.icon,
    required this.name,
    required this.subcategories,
  });
}

const catalogCategories = <CatalogCategory>[
  CatalogCategory(
    icon: Icons.devices_outlined,
    name: 'Electronics',
    subcategories: [
      'Laptop',
      'Mobile',
      'Tablet',
      'Charger',
      'USB Cable',
      'Headphones',
      'Keyboard',
      'Mouse',
      'Monitor',
    ],
  ),
  CatalogCategory(
    icon: Icons.checkroom_outlined,
    name: 'Fashion',
    subcategories: ['Men', 'Women', 'Kids', 'Shoes', 'Bags', 'Watches'],
  ),
  CatalogCategory(
    icon: Icons.fastfood_outlined,
    name: 'Food',
    subcategories: ['Snacks', 'Beverages', 'Bakery', 'Grocery', 'Organic'],
  ),
  CatalogCategory(
    icon: Icons.medication_outlined,
    name: 'Beauty',
    subcategories: ['Skin Care', 'Hair Care', 'Makeup', 'Fragrance'],
  ),
  CatalogCategory(
    icon: Icons.menu_book_outlined,
    name: 'Books',
    subcategories: ['Fiction', 'Education', 'Journals', 'Children'],
  ),
  CatalogCategory(
    icon: Icons.chair_outlined,
    name: 'Home',
    subcategories: ['Furniture', 'Kitchen', 'Decor', 'Lighting'],
  ),
];

const _searchAliases = <String, List<String>>{
  'laptop': [
    'laptop',
    'charger',
    'usb cable',
    'mouse',
    'keyboard',
    'tablet',
    'monitor',
  ],
  'computer': [
    'laptop',
    'charger',
    'usb cable',
    'mouse',
    'keyboard',
    'monitor',
  ],
  'mobile': ['mobile', 'charger', 'usb cable', 'headphones', 'tablet'],
  'phone': ['mobile', 'charger', 'usb cable', 'headphones', 'tablet'],
  'electronics': [
    'laptop',
    'mobile',
    'tablet',
    'charger',
    'usb cable',
    'headphones',
  ],
  'butti': ['snacks', 'beverages', 'bakery', 'grocery'],
  'food': ['snacks', 'beverages', 'bakery', 'grocery', 'organic'],
  'dress': ['men', 'women', 'kids', 'shoes', 'bags'],
  'clothes': ['men', 'women', 'kids', 'shoes', 'bags'],
  'book': ['fiction', 'education', 'journals', 'children'],
};

List<String> smartSearchTerms(String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return const [];
  final terms = <String>{normalized};
  for (final entry in _searchAliases.entries) {
    if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
      terms.addAll(entry.value);
    }
  }
  return terms.toList();
}

String categoryForSubcategory(String subcategory) {
  for (final category in catalogCategories) {
    if (category.subcategories.any(
      (item) => item.toLowerCase() == subcategory.toLowerCase(),
    )) {
      return category.name;
    }
  }
  return 'General';
}
