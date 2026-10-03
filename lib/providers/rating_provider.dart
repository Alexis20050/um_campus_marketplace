import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_history_item.dart';

// ============================================================
// SALE BUYER CANDIDATE
// ============================================================

class SaleBuyerCandidate {
  final String conversationId;
  final String buyerId;
  final String buyerName;
  final String? buyerEmail;

  const SaleBuyerCandidate({
    required this.conversationId,
    required this.buyerId,
    required this.buyerName,
    this.buyerEmail,
  });

  factory SaleBuyerCandidate.fromMap(Map<String, dynamic> map) {
    final rawName = map['buyer_name']?.toString().trim();

    final rawEmail = map['buyer_email']?.toString().trim();

    return SaleBuyerCandidate(
      conversationId: map['conversation_id']?.toString() ?? '',
      buyerId: map['buyer_id']?.toString() ?? '',
      buyerName: rawName != null && rawName.isNotEmpty ? rawName : 'UM Student',
      buyerEmail: rawEmail != null && rawEmail.isNotEmpty ? rawEmail : null,
    );
  }

  String get name => buyerName;

  String get displayName => buyerName;

  String? get email => buyerEmail;
}

// ============================================================
// RATING PROVIDER
// ============================================================

class RatingProvider extends ChangeNotifier {
  final SupabaseClient _supabase;

  RatingProvider({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  int _ratingsRevision = 0;

  int get ratingsRevision => _ratingsRevision;

  // ============================================================
  // GETTERS
  // ============================================================

  bool get isLoading => _isLoading;

  String? get error => _error;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  SupabaseClient get client => _supabase;

  // ============================================================
  // INTERNAL HELPERS
  // ============================================================

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  String _friendlyError(Object error) {
    if (error is PostgrestException) {
      return error.message;
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  void clearError() {
    if (_error == null) {
      return;
    }

    _error = null;
    notifyListeners();
  }

  // ============================================================
  // BUYERS FOR PRODUCT
  //
  // Used by complete_sale_flow.dart
  //
  // RPC:
  // sale_buyer_candidates(
  //   p_product_id uuid
  // )
  // ============================================================

  Future<List<SaleBuyerCandidate>> fetchBuyersForProduct(
    String productId,
  ) async {
    if (productId.trim().isEmpty) {
      return [];
    }

    try {
      _setError(null);

      final response = await _supabase.rpc(
        'sale_buyer_candidates',
        params: {'p_product_id': productId},
      );

      if (response == null) {
        return [];
      }

      if (response is! List) {
        throw StateError('Invalid buyer response from server.');
      }

      final buyers = <SaleBuyerCandidate>[];

      for (final item in response) {
        if (item is! Map) {
          continue;
        }

        final candidate = SaleBuyerCandidate.fromMap(
          Map<String, dynamic>.from(item),
        );

        if (candidate.conversationId.isEmpty || candidate.buyerId.isEmpty) {
          continue;
        }

        final messages = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', candidate.conversationId)
            .eq('sender_id', candidate.buyerId)
            .limit(1);
        if (messages.isNotEmpty) buyers.add(candidate);
      }

      return buyers;
    } catch (e) {
      debugPrint('fetchBuyersForProduct failed: $e');

      _setError(_friendlyError(e));

      rethrow;
    }
  }

  // Compatibility alias
  Future<List<SaleBuyerCandidate>> getSaleBuyerCandidates(String productId) {
    return fetchBuyersForProduct(productId);
  }

  // ============================================================
  // COMPLETE SALE
  //
  // RPC:
  // complete_sale(
  //   p_conversation_id uuid
  // )
  // ============================================================

  Future<String> completeSale({required String conversationId}) async {
    if (conversationId.trim().isEmpty) {
      throw ArgumentError('Conversation ID is required.');
    }

    _setLoading(true);
    _setError(null);

    try {
      final response = await _supabase.rpc(
        'complete_sale',
        params: {'p_conversation_id': conversationId},
      );

      if (response == null) {
        throw StateError('Sale could not be completed.');
      }

      final transactionId = response.toString();

      notifyListeners();

      return transactionId;
    } catch (e) {
      debugPrint('completeSale failed: $e');

      _setError(_friendlyError(e));

      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // TRANSACTION STREAM FOR CONVERSATION
  //
  // Required by transaction_rating_card.dart
  // ============================================================

  Stream<List<Map<String, dynamic>>> transactionStreamForConversation(
    String conversationId,
  ) {
    return _supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .map((rows) {
          return rows.map((row) => Map<String, dynamic>.from(row)).toList();
        });
  }

  // ============================================================
  // RATING STREAM FOR TRANSACTION
  //
  // Required by transaction_rating_card.dart
  // ============================================================

  Stream<List<Map<String, dynamic>>> ratingStreamForTransaction(
    String transactionId,
  ) {
    return _supabase
        .from('seller_ratings')
        .stream(primaryKey: ['id'])
        .eq('transaction_id', transactionId)
        .map((rows) {
          return rows.map((row) => Map<String, dynamic>.from(row)).toList();
        });
  }

  // ============================================================
  // SELLER RATINGS STREAM
  // ============================================================

  Stream<List<Map<String, dynamic>>> sellerRatingsStream(String sellerId) {
    return _supabase
        .from('seller_ratings')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false)
        .map((rows) {
          return rows.map((row) => Map<String, dynamic>.from(row)).toList();
        });
  }

  // ============================================================
  // GET TRANSACTION FOR CONVERSATION
  // ============================================================

  Future<Map<String, dynamic>?> getTransactionForConversation(
    String conversationId,
  ) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('''
                id,
                product_id,
                conversation_id,
                seller_id,
                buyer_id,
                status,
                completed_at
                ''')
          .eq('conversation_id', conversationId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('getTransactionForConversation failed: $e');

      rethrow;
    }
  }

  Future<Map<String, dynamic>?> transactionForConversation(
    String conversationId,
  ) {
    return getTransactionForConversation(conversationId);
  }

  // ============================================================
  // GET TRANSACTION FOR PRODUCT
  // ============================================================

  Future<Map<String, dynamic>?> getTransactionForProduct(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('''
                id,
                product_id,
                conversation_id,
                seller_id,
                buyer_id,
                status,
                completed_at
                ''')
          .eq('product_id', productId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('getTransactionForProduct failed: $e');

      rethrow;
    }
  }

  // ============================================================
  // GET RATING FOR TRANSACTION
  // ============================================================

  Future<Map<String, dynamic>?> getRatingForTransaction(
    String transactionId,
  ) async {
    try {
      final response = await _supabase
          .from('seller_ratings')
          .select('''
                id,
                transaction_id,
                seller_id,
                buyer_id,
                rating,
                review,
                created_at
                ''')
          .eq('transaction_id', transactionId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('getRatingForTransaction failed: $e');

      rethrow;
    }
  }

  // ============================================================
  // SUBMIT SELLER RATING
  //
  // RPC:
  // submit_seller_rating(
  //   p_transaction_id uuid,
  //   p_rating integer,
  //   p_review text
  // )
  // ============================================================

  Future<String> submitSellerRating({
    required String transactionId,
    required int rating,
    String? review,
  }) async {
    if (transactionId.trim().isEmpty) {
      throw ArgumentError('Transaction ID is required.');
    }

    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5.');
    }

    final cleanedReview = review?.trim();

    if (cleanedReview != null && cleanedReview.length > 500) {
      throw ArgumentError('Review must be 500 characters or fewer.');
    }

    _setLoading(true);
    _setError(null);

    try {
      final response = await _supabase.rpc(
        'submit_seller_rating',
        params: {
          'p_transaction_id': transactionId,
          'p_rating': rating,
          'p_review': cleanedReview == null || cleanedReview.isEmpty
              ? null
              : cleanedReview,
        },
      );

      if (response == null) {
        throw StateError('Rating could not be submitted.');
      }

      // Refresh local readers even when no realtime event arrives.
      _ratingsRevision++;
      notifyListeners();

      return response.toString();
    } catch (e) {
      debugPrint('submitSellerRating failed: $e');

      _setError(_friendlyError(e));

      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // CAN CURRENT USER RATE TRANSACTION
  // ============================================================

  Future<bool> canCurrentUserRate(String transactionId) async {
    final userId = currentUserId;

    if (userId == null) {
      return false;
    }

    try {
      final transaction = await _supabase
          .from('transactions')
          .select('''
                id,
                buyer_id,
                seller_id,
                status
                ''')
          .eq('id', transactionId)
          .maybeSingle();

      if (transaction == null) {
        return false;
      }

      if (transaction['status']?.toString() != 'completed') {
        return false;
      }

      if (transaction['buyer_id']?.toString() != userId) {
        return false;
      }

      if (transaction['seller_id']?.toString() == userId) {
        return false;
      }

      final existingRating = await getRatingForTransaction(transactionId);

      return existingRating == null;
    } catch (e) {
      debugPrint('canCurrentUserRate failed: $e');

      return false;
    }
  }

  // ============================================================
  // FETCH SELLER RATINGS
  // ============================================================

  Future<List<Map<String, dynamic>>> fetchSellerRatings(String sellerId) async {
    try {
      final response = await _supabase
          .from('seller_ratings')
          .select('''
                id,
                transaction_id,
                seller_id,
                buyer_id,
                rating,
                review,
                created_at
                ''')
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('fetchSellerRatings failed: $e');

      rethrow;
    }
  }

  // ============================================================
  // SELLER RATING SUMMARY
  // ============================================================

  Future<Map<String, dynamic>> getSellerRatingSummary(String sellerId) async {
    final ratings = await fetchSellerRatings(sellerId);

    if (ratings.isEmpty) {
      return {'average': 0.0, 'count': 0};
    }

    double total = 0;

    for (final row in ratings) {
      total += (row['rating'] as num?)?.toDouble() ?? 0;
    }

    return {'average': total / ratings.length, 'count': ratings.length};
  }

  // ============================================================
  // TRANSACTION HISTORY
  //
  // RPC:
  // my_transaction_history()
  // ============================================================

  Future<List<TransactionHistoryItem>> fetchTransactionHistory() async {
    if (currentUserId == null) {
      return [];
    }

    try {
      _setError(null);

      final response = await _supabase.rpc('my_transaction_history');

      if (response == null) {
        return [];
      }

      if (response is! List) {
        throw StateError('Invalid transaction history response.');
      }

      final history = <TransactionHistoryItem>[];

      for (final item in response) {
        if (item is! Map) {
          continue;
        }

        final row = Map<String, dynamic>.from(item);

        final transaction = TransactionHistoryItem.fromMap(row);

        if (transaction.transactionId.isEmpty) {
          continue;
        }

        history.add(transaction);
      }

      return history;
    } catch (e) {
      debugPrint('fetchTransactionHistory failed: $e');

      _setError(_friendlyError(e));

      rethrow;
    }
  }

  // ============================================================
  // PURCHASE HISTORY ONLY
  // ============================================================

  Future<List<TransactionHistoryItem>> fetchPurchaseHistory() async {
    final history = await fetchTransactionHistory();

    return history.where((item) => item.isPurchase).toList();
  }

  // ============================================================
  // SALES HISTORY ONLY
  // ============================================================

  Future<List<TransactionHistoryItem>> fetchSalesHistory() async {
    final history = await fetchTransactionHistory();

    return history.where((item) => item.isSale).toList();
  }
}
