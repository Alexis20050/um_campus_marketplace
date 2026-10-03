/// Field aliases support both table-returning and JSON-returning admin RPCs.
dynamic adminValue(Map<String, dynamic> row, String keys) {
  for (final key in keys.split('|')) {
    if (row[key] != null) return row[key];
  }
  return null;
}

String adminText(
  Map<String, dynamic> row,
  String keys, [
  String fallback = '—',
]) {
  final value = adminValue(row, keys)?.toString().trim();
  return value == null || value.isEmpty ? fallback : value;
}

String adminDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return '—';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String adminRelativeTime(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return adminDate(value);
  final elapsed = DateTime.now().difference(date);
  if (elapsed.isNegative) return adminDate(value);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours} hr ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays} d ago';
  return adminDate(value);
}

String adminPrice(dynamic value) {
  final price = num.tryParse(value?.toString() ?? '');
  if (price == null || !price.isFinite) return '—';
  final parts = price.toStringAsFixed(2).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '₱$whole.${parts.last}';
}

List<String> adminImages(Map<String, dynamic> row) {
  final images = row['image_urls'];
  return images is List
      ? images.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
      : [];
}

String adminMarketplaceStatus(Map<String, dynamic> row) {
  // Moderation visibility is independent of sale/archive/reservation state.
  if (row['is_archived'] == true) return 'archived';
  if (row['is_sold'] == true) return 'sold';
  if (adminText(row, 'reserved_by', '').isNotEmpty) return 'reserved';
  final supplied = adminText(
    row,
    'listing_status|marketplace_status',
    '',
  ).toLowerCase();
  if (['active', 'reserved', 'sold', 'archived'].contains(supplied)) {
    return supplied;
  }
  if (row.containsKey('is_sold') && row.containsKey('is_archived')) {
    return 'active';
  }
  return 'unknown';
}

bool adminListingMatches(Map<String, dynamic> row, String status) =>
    status == 'all' ||
    (status == 'hidden'
        ? row['moderation_status'] == 'hidden'
        : adminMarketplaceStatus(row) == status);
