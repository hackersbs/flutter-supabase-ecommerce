import 'package:flutter/material.dart';

String formatOrderDateTime(BuildContext context, dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return 'Order time unavailable';
  final local = parsed.toLocal();
  final date = MaterialLocalizations.of(context).formatMediumDate(local);
  final time = MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date at $time';
}

String formatShortDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return '';
  final local = parsed.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String shortOrderId(dynamic value) {
  final id = value?.toString() ?? '';
  return id.length <= 8 ? id : id.substring(0, 8);
}

String resolveOrderId(
  Map<String, dynamic> order, {
  Map<String, dynamic>? item,
  Map<String, dynamic>? request,
  dynamic fallback,
}) {
  final candidates = [
    order['id'],
    order['order_id'],
    item?['order_id'],
    item?['id'],
    request?['order_id'],
    request?['id'],
    fallback,
  ];

  for (final candidate in candidates) {
    final value = candidate?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}
