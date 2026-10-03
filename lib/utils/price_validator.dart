String? validatePrice(String? value) {
  if (value == null || value.trim().isEmpty) return 'Please enter a price';
  final price = double.tryParse(value.trim());
  if (price == null || !price.isFinite) return 'Enter a valid number';
  if (price <= 0) return 'Price must be greater than 0';
  if (price > 1000000) return 'Price seems too high';
  return null;
}
