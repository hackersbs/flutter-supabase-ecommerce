import 'package:e_comerce_appliction/utils/currency.dart';
import 'package:e_comerce_appliction/utils/product_pricing.dart';
import 'package:e_comerce_appliction/utils/date_format.dart';
import 'package:e_comerce_appliction/widgets/image_url.dart';
import 'package:flutter/material.dart';

class SellerDashboardFilters extends StatelessWidget {
  final List<String> countries;
  final List<String> states;
  final List<String> cities;
  final String selectedCountry;
  final String selectedState;
  final String selectedCity;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<String> onStateChanged;
  final ValueChanged<String> onCityChanged;

  const SellerDashboardFilters({
    super.key,
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
            LayoutBuilder(
              builder: (context, constraints) {
                final countryDropdown = SellerDropdown(
                  label: 'Country',
                  value: selectedCountry,
                  items: countries,
                  onChanged: onCountryChanged,
                );
                final stateDropdown = SellerDropdown(
                  label: 'State',
                  value: selectedState,
                  items: states,
                  onChanged: onStateChanged,
                );

                if (constraints.maxWidth < 420) {
                  return Column(
                    children: [
                      countryDropdown,
                      const SizedBox(height: 10),
                      stateDropdown,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: countryDropdown),
                    const SizedBox(width: 8),
                    Expanded(child: stateDropdown),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            SellerDropdown(
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

class SellerDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const SellerDropdown({
    super.key,
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
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (nextValue) {
        if (nextValue != null) onChanged(nextValue);
      },
    );
  }
}

class SellerMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const SellerMetricCard({
    super.key,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 20),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerChartCard extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;

  const SellerChartCard({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
  });

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

class SellerRevenueBar extends StatelessWidget {
  final double value;

  const SellerRevenueBar({super.key, required this.value});

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

class SellerProductBars extends StatelessWidget {
  final List<MapEntry<String, int>> entries;

  const SellerProductBars({super.key, required this.entries});

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

class SellerStatusBars extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const SellerStatusBars({super.key, required this.orders});

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

class SellerProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SellerProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = product['img_url']?.toString();
    final hasDiscount = hasProductDiscount(product);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SellerProductImage(imageUrl: imageUrl),
            Expanded(
              child: SellerProductDetails(
                product: product,
                hasDiscount: hasDiscount,
              ),
            ),
            SellerProductActions(onEdit: onEdit, onDelete: onDelete),
          ],
        ),
      ),
    );
  }
}

class SellerProductImage extends StatelessWidget {
  final String? imageUrl;

  const SellerProductImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ProductImage(imageUrl: imageUrl),
    );
  }
}

class SellerProductDetails extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool hasDiscount;

  const SellerProductDetails({
    super.key,
    required this.product,
    required this.hasDiscount,
  });

  @override
  Widget build(BuildContext context) {
    final category = product['category']?.toString() ?? '';
    final description = product['description']?.toString() ?? '';
    final addedDate = formatShortDate(product['created_at']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product['name'] ?? 'No Name',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        if (category.isNotEmpty)
          Text(
            category,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            if (hasDiscount)
              Text(
                formatIndianRupees(productPrice(product, 'price')),
                style: const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            Text(
              formatIndianRupees(activeProductPrice(product)),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Qty: ${product['quantity'] ?? 0}  Added: $addedDate',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        if (description.isNotEmpty)
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
      ],
    );
  }
}

class SellerProductActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SellerProductActions({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
      ],
    );
  }
}
