bool isValidImageUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}
