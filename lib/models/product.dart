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
    return Product(
      id: map['id'] as String,
      sellerId: map['seller_id'] as String,
      sellerName: map['seller_name'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num).toDouble(),
      category: map['category'] ?? 'Other',
      imageUrls: List<String>.from(map['image_urls'] ?? []),
      createdAt: DateTime.parse(map['created_at'] as String),
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
