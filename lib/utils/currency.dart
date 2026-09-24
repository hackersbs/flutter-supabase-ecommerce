String formatIndianRupees(dynamic value, {bool decimals = true}) {
  final amount = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  final fixed = amount.abs().toStringAsFixed(decimals ? 2 : 0);
  final parts = fixed.split('.');
  final digits = parts.first;
  final grouped = _groupIndianDigits(digits);
  final sign = amount < 0 ? '-' : '';
  return '$sign₹$grouped${decimals ? '.${parts[1]}' : ''}';
}

String _groupIndianDigits(String digits) {
  if (digits.length <= 3) return digits;
  final lastThree = digits.substring(digits.length - 3);
  var prefix = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (prefix.length > 2) {
    groups.insert(0, prefix.substring(prefix.length - 2));
    prefix = prefix.substring(0, prefix.length - 2);
  }
  if (prefix.isNotEmpty) groups.insert(0, prefix);
  return '${groups.join(',')},$lastThree';
}
