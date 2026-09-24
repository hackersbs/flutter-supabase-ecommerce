double productPrice(Map<String, dynamic> product, String key) {
  final value = product[key];
  return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

double activeProductPrice(Map<String, dynamic> product) {
  final originalPrice = productPrice(product, 'price');
  final discountPrice = productPrice(product, 'discount_price');
  return hasProductDiscount(product) ? discountPrice : originalPrice;
}

bool hasProductDiscount(Map<String, dynamic> product) {
  final originalPrice = productPrice(product, 'price');
  final discountPrice = productPrice(product, 'discount_price');
  return originalPrice > 0 &&
      discountPrice > 0 &&
      discountPrice < originalPrice;
}

int productDiscountPercentage(Map<String, dynamic> product) {
  if (!hasProductDiscount(product)) return 0;
  final originalPrice = productPrice(product, 'price');
  final discountPrice = productPrice(product, 'discount_price');
  return ((originalPrice - discountPrice) / originalPrice * 100).round();
}
