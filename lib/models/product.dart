class Product {
  final String id;
  final String sellerId;
  final String sellerName;

  final String title;
  final String description;

  final double price;

  final String category;
  final String itemCondition;

  final List<String> imageUrls;

  final DateTime createdAt;

  final bool isSold;
  final bool isArchived;

  // Reservation
  final String? reservedBy;
  final String? reservedConversationId;
  final DateTime? reservedAt;

  // Moderation
  final String moderationStatus;

  const Product({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.itemCondition,
    required this.imageUrls,
    required this.createdAt,
    this.isSold = false,
    this.isArchived = false,
    this.reservedBy,
    this.reservedConversationId,
    this.reservedAt,
    this.moderationStatus = 'active',
  });

  // ============================================================
  // CONVENIENCE GETTERS
  // ============================================================

  bool get isReserved =>
      !isSold && reservedBy != null && reservedBy!.trim().isNotEmpty;

  bool get isHidden => moderationStatus == 'hidden';

  bool get isActive => !isSold && !isArchived && !isHidden;

  bool get canReserve => isActive && !isReserved;

  bool get canCancelReservation => !isSold && !isArchived && isReserved;

  // ============================================================
  // FROM SUPABASE
  // ============================================================

  factory Product.fromMap(Map<String, dynamic> map) {
    final rawImages = map['image_urls'];
    if (rawImages != null && rawImages is! List) {
      throw const FormatException('Product images must be an array.');
    }

    final List<String> imageUrls = rawImages is List
        ? rawImages
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];

    final rawPrice = map['price'];

    if (rawPrice is! num || !rawPrice.isFinite || rawPrice < 0) {
      throw const FormatException(
        'Product price must be a finite, nonnegative number.',
      );
    }
    final price = rawPrice.toDouble();

    final createdAt = DateTime.tryParse(map['created_at']?.toString() ?? '');
    if (createdAt == null) {
      throw const FormatException('Product creation date is invalid.');
    }

    final reservedAt = map['reserved_at'] == null
        ? null
        : DateTime.tryParse(map['reserved_at'].toString());

    return Product(
      id: map['id']?.toString() ?? '',

      sellerId: map['seller_id']?.toString() ?? '',

      sellerName: map['seller_name']?.toString() ?? '',

      title: map['title']?.toString() ?? '',

      description: map['description']?.toString() ?? '',

      price: price,

      category: map['category']?.toString() ?? 'Other',

      itemCondition: map['item_condition']?.toString() ?? 'Good',

      imageUrls: List.unmodifiable(imageUrls),

      createdAt: createdAt,

      isSold: map['is_sold'] == true,

      isArchived: map['is_archived'] == true,

      reservedBy: map['reserved_by']?.toString(),

      reservedConversationId: map['reserved_conversation_id']?.toString(),

      reservedAt: reservedAt,

      moderationStatus: map['moderation_status']?.toString() ?? 'active',
    );
  }

  // ============================================================
  // TO MAP
  //
  // Reservation/moderation fields intentionally NOT included.
  // Those are controlled by secure Supabase RPCs.
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'seller_id': sellerId,

      'seller_name': sellerName,

      'title': title,

      'description': description,

      'price': price,

      'category': category,

      'item_condition': itemCondition,

      'image_urls': imageUrls,

      'is_sold': isSold,

      'is_archived': isArchived,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  Product copyWith({
    String? id,
    String? sellerId,
    String? sellerName,
    String? title,
    String? description,
    double? price,
    String? category,
    String? itemCondition,
    List<String>? imageUrls,
    DateTime? createdAt,
    bool? isSold,
    bool? isArchived,
    String? reservedBy,
    String? reservedConversationId,
    DateTime? reservedAt,
    String? moderationStatus,
    bool clearReservation = false,
  }) {
    return Product(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      itemCondition: itemCondition ?? this.itemCondition,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      isSold: isSold ?? this.isSold,
      isArchived: isArchived ?? this.isArchived,

      reservedBy: clearReservation ? null : reservedBy ?? this.reservedBy,

      reservedConversationId: clearReservation
          ? null
          : reservedConversationId ?? this.reservedConversationId,

      reservedAt: clearReservation ? null : reservedAt ?? this.reservedAt,

      moderationStatus: moderationStatus ?? this.moderationStatus,
    );
  }
}
