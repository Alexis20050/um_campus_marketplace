class TransactionHistoryItem {
  final String transactionId;
  final String conversationId;
  final String productId;

  /// purchase | sale
  final String role;

  final String productTitle;
  final String? productImageUrl;

  final double amount;

  final String counterpartyId;
  final String counterpartyName;

  final DateTime completedAt;

  final int? rating;
  final String? review;
  final DateTime? ratedAt;

  const TransactionHistoryItem({
    required this.transactionId,
    required this.conversationId,
    required this.productId,
    required this.role,
    required this.productTitle,
    required this.productImageUrl,
    required this.amount,
    required this.counterpartyId,
    required this.counterpartyName,
    required this.completedAt,
    required this.rating,
    required this.review,
    required this.ratedAt,
  });

  bool get isPurchase => role == 'purchase';

  bool get isSale => role == 'sale';

  bool get isRated => rating != null;

  factory TransactionHistoryItem.fromMap(Map<String, dynamic> map) {
    final completedAt =
        DateTime.tryParse(map['completed_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final ratedAt = map['rated_at'] == null
        ? null
        : DateTime.tryParse(map['rated_at'].toString());

    final amountValue = map['amount'];

    double amount = 0;

    if (amountValue is num) {
      amount = amountValue.toDouble();
    } else {
      amount = double.tryParse(amountValue?.toString() ?? '') ?? 0;
    }

    final ratingValue = map['rating'];

    int? rating;

    if (ratingValue is num) {
      rating = ratingValue.toInt();
    } else if (ratingValue != null) {
      rating = int.tryParse(ratingValue.toString());
    }

    final rawReview = map['review']?.toString().trim();

    final rawImage = map['product_image_url']?.toString().trim();

    return TransactionHistoryItem(
      transactionId: map['transaction_id']?.toString() ?? '',

      conversationId: map['conversation_id']?.toString() ?? '',

      productId: map['product_id']?.toString() ?? '',

      role: map['transaction_role']?.toString() ?? '',

      productTitle: map['product_title']?.toString().trim().isNotEmpty == true
          ? map['product_title'].toString().trim()
          : 'Product',

      productImageUrl: rawImage != null && rawImage.isNotEmpty
          ? rawImage
          : null,

      amount: amount,

      counterpartyId: map['counterparty_id']?.toString() ?? '',

      counterpartyName:
          map['counterparty_name']?.toString().trim().isNotEmpty == true
          ? map['counterparty_name'].toString().trim()
          : 'UM Student',

      completedAt: completedAt,

      rating: rating,

      review: rawReview != null && rawReview.isNotEmpty ? rawReview : null,

      ratedAt: ratedAt,
    );
  }
}
