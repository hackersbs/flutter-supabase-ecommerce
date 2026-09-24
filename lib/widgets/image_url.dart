import 'package:flutter/material.dart';

bool isValidImageUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

class ProductImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;

  const ProductImage({
    super.key,
    required this.imageUrl,
    this.width = 80,
    this.height = 80,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final validImage = isValidImageUrl(imageUrl);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: !validImage
          ? const Icon(Icons.image_not_supported, color: Colors.grey)
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl!,
                fit: fit,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image_outlined, color: Colors.grey),
              ),
            ),
    );
  }
}
