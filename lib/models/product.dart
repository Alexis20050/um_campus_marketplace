class Product {
  final String id;
  final String sellerId;
  final String sellerName;
  final String title;
  final String description;
  final double price;
  final String category;
  final List<String> imageUrls;
  final DateTime createdAt;
  bool isSold;

  Product({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrls,
    required this.createdAt,
    this.isSold = false,
  });

  // Convert a Supabase row (Map) to a Product object
  factory Product.fromMap(Map<String, dynamic> map) {
    // Robust parsing of image_urls
    final raw = map['image_urls'];
    List<String> imageUrls = [];
    if (raw is List) {
      imageUrls = raw.map((e) => e.toString()).toList();
    } else if (raw is String && raw.isNotEmpty) {
      // Sometimes Supabase returns a string like "{url1,url2}"
      final cleaned = raw.replaceAll('{', '').replaceAll('}', '');
      imageUrls = cleaned
          .split(',')
          .map((s) => s.trim().replaceAll('"', ''))
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return Product(
      id: map['id'] as String? ?? '',
      sellerId: map['seller_id'] as String? ?? '',
      sellerName: map['seller_name'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Other',
      imageUrls: imageUrls,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isSold: map['is_sold'] ?? false,
    );
  }

  // Convert Product to a map for Supabase insert/update
  Map<String, dynamic> toMap() {
    return {
      'seller_id': sellerId,
      'seller_name': sellerName,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'image_urls': imageUrls,
      'is_sold': isSold,
    };
  }
}
