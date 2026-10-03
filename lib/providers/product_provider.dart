import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

class ProductProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Product> _products = [];

  bool _isLoading = true;
  String? _error;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _productsSubscription;

  Timer? _debounce;

  bool _disposed = false;
  int _generation = 0;

  // ============================================================
  // GETTERS
  // ============================================================

  List<Product> get products => List.unmodifiable(_products);

  bool get isLoading => _isLoading;

  String? get error => _error;

  SupabaseClient get client => _supabase;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  ProductProvider() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((_) {
      _startProductsSubscription();
    });

    _startProductsSubscription();
  }

  // ============================================================
  // RETRY
  // ============================================================

  Future<void> retry() async {
    await _startProductsSubscription();
  }

  // ============================================================
  // PUBLIC MARKETPLACE PRODUCT STREAM
  //
  // Shows:
  // - available products
  // - reserved products
  //
  // Hides:
  // - sold products
  // - archived products
  // - moderator-hidden products
  // ============================================================

  Future<void> _startProductsSubscription() async {
    if (_disposed) return;

    final generation = ++_generation;

    _debounce?.cancel();

    final previousSubscription = _productsSubscription;

    _productsSubscription = null;

    _isLoading = true;
    _error = null;

    notifyListeners();

    void fail(Object error) {
      if (_disposed || generation != _generation) {
        return;
      }

      _debounce?.cancel();

      debugPrint('Product realtime error: $error');

      _error = 'Unable to load listings. Please try again.';
      _isLoading = false;

      notifyListeners();
    }

    try {
      await previousSubscription?.cancel();

      if (_disposed || generation != _generation) {
        return;
      }

      _productsSubscription = _supabase
          .from('products')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen((rows) {
            if (_disposed || generation != _generation) {
              return;
            }

            _debounce?.cancel();

            _debounce = Timer(const Duration(milliseconds: 200), () {
              if (_disposed || generation != _generation) {
                return;
              }

              try {
                _products = rows
                    .where(
                      (row) =>
                          row['is_sold'] != true &&
                          row['is_archived'] != true &&
                          (row['moderation_status'] ?? 'active') == 'active',
                    )
                    .map(Product.fromMap)
                    .toList();

                _error = null;
                _isLoading = false;

                notifyListeners();
              } catch (e) {
                fail(e);
              }
            });
          }, onError: fail);
    } catch (e) {
      fail(e);
    }
  }

  // ============================================================
  // PUBLIC SELLER PROFILE PRODUCTS
  //
  // Used when viewing another user's seller profile.
  //
  // Hides:
  // - archived
  // - moderator-hidden
  //
  // Can include:
  // - active
  // - reserved
  // - sold
  // ============================================================

  Stream<List<Product>> sellerProductsStream(String sellerId) {
    return _supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .where(
                (row) =>
                    row['is_archived'] != true &&
                    (row['moderation_status'] ?? 'active') == 'active',
              )
              .map(Product.fromMap)
              .toList(),
        );
  }

  // ============================================================
  // ALL SELLER PRODUCTS
  //
  // Used ONLY by My Listings.
  //
  // Includes:
  // - active
  // - reserved
  // - sold
  // - archived
  //
  // This method fixes your analyzer error:
  // sellerAllProductsStream isn't defined
  // ============================================================

  Stream<List<Product>> sellerAllProductsStream(String sellerId) {
    return _supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(Product.fromMap).toList());
  }

  /// Refresh the seller's existing view without opening another realtime stream.
  Future<List<Product>> fetchSellerProducts(String sellerId) async {
    if (sellerId.trim().isEmpty) return [];
    final rows = await _supabase
        .from('products')
        .select()
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false);
    return rows.map(Product.fromMap).toList();
  }

  // ============================================================
  // FETCH SINGLE PRODUCT
  // ============================================================

  Future<Product?> fetchProductById(String productId) async {
    if (productId.trim().isEmpty) {
      return null;
    }

    final response = await _supabase
        .from('products')
        .select()
        .eq('id', productId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Product.fromMap(Map<String, dynamic>.from(response));
  }

  // ============================================================
  // FETCH PROFILE
  // ============================================================

  Future<Map<String, dynamic>?> fetchProfileById(String userId) async {
    if (userId.trim().isEmpty) {
      return null;
    }

    final response = await _supabase
        .from('profiles')
        .select('''
          id,
          name,
          email,
          created_at,
          role,
          account_status
          ''')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // ADD PRODUCT
  //
  // itemCondition has a fallback for compatibility with older
  // screens, while newer screens should pass it explicitly.
  // ============================================================

  Future<void> addProduct({
    required String sellerId,
    required String sellerName,
    required String title,
    required String description,
    required double price,
    required String category,
    String itemCondition = 'Good',
    required List<String> imageUrls,
  }) async {
    if (sellerId.trim().isEmpty) {
      throw ArgumentError('Seller ID is required.');
    }

    if (title.trim().isEmpty) {
      throw ArgumentError('Product title is required.');
    }

    if (price < 0) {
      throw ArgumentError('Price cannot be negative.');
    }

    await _supabase.from('products').insert({
      'seller_id': sellerId,
      'seller_name': sellerName.trim(),
      'title': title.trim(),
      'description': description.trim(),
      'price': price,
      'category': category,
      'item_condition': itemCondition,
      'image_urls': imageUrls,
      'is_sold': false,
      'is_archived': false,
      'moderation_status': 'active',
    });

    notifyListeners();
  }

  // ============================================================
  // UPDATE PRODUCT
  //
  // itemCondition is optional so your existing Edit Listing
  // screen remains compatible.
  // ============================================================

  Future<void> updateProduct({
    required String id,
    required String title,
    required String description,
    required double price,
    required String category,
    String? itemCondition,
    required List<String> imageUrls,
  }) async {
    if (id.trim().isEmpty) {
      throw ArgumentError('Product ID is required.');
    }

    if (title.trim().isEmpty) {
      throw ArgumentError('Product title is required.');
    }

    if (price < 0) {
      throw ArgumentError('Price cannot be negative.');
    }

    final updates = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'price': price,
      'category': category,
      'image_urls': imageUrls,
    };

    if (itemCondition != null && itemCondition.trim().isNotEmpty) {
      updates['item_condition'] = itemCondition.trim();
    }

    await _supabase.from('products').update(updates).eq('id', id);

    notifyListeners();
  }

  // ============================================================
  // RESERVE PRODUCT
  //
  // Secure Supabase RPC verifies:
  // - current user is seller
  // - buyer exists
  // - conversation belongs to product
  // - product is not sold
  // ============================================================

  Future<void> reserveProduct({required String conversationId}) async {
    if (conversationId.trim().isEmpty) {
      throw ArgumentError('Conversation ID is required.');
    }

    await _supabase.rpc(
      'reserve_product',
      params: {'p_conversation_id': conversationId},
    );

    notifyListeners();
  }

  // ============================================================
  // CANCEL RESERVATION
  // ============================================================

  Future<void> cancelReservation(String productId) async {
    if (productId.trim().isEmpty) {
      throw ArgumentError('Product ID is required.');
    }

    await _supabase.rpc(
      'cancel_product_reservation',
      params: {'p_product_id': productId},
    );

    notifyListeners();
  }

  // ============================================================
  // ARCHIVE PRODUCT
  //
  // Archive preserves sold/reserved state information rather
  // than deleting the listing.
  // ============================================================

  Future<void> archiveProduct(String productId) async {
    if (productId.trim().isEmpty) {
      throw ArgumentError('Product ID is required.');
    }

    await _supabase
        .from('products')
        .update({'is_archived': true})
        .eq('id', productId);

    notifyListeners();
  }

  // ============================================================
  // RESTORE PRODUCT
  // ============================================================

  Future<void> restoreProduct(String productId) async {
    if (productId.trim().isEmpty) {
      throw ArgumentError('Product ID is required.');
    }

    await _supabase
        .from('products')
        .update({'is_archived': false})
        .eq('id', productId);

    notifyListeners();
  }

  // ============================================================
  // LEGACY COMPATIBILITY
  //
  // Keep these temporarily because some existing screens may
  // still reference them.
  //
  // Your normal sold flow should use RatingProvider.completeSale()
  // instead of markAsSold().
  // ============================================================

  Future<void> markAsSold(String productId) async {
    if (productId.trim().isEmpty) {
      throw ArgumentError('Product ID is required.');
    }

    await _supabase
        .from('products')
        .update({'is_sold': true})
        .eq('id', productId);

    notifyListeners();
  }

  Future<void> markAsAvailable(String productId) async {
    if (productId.trim().isEmpty) {
      throw ArgumentError('Product ID is required.');
    }

    await _supabase
        .from('products')
        .update({'is_sold': false})
        .eq('id', productId);

    notifyListeners();
  }

  // ============================================================
  // DELETE
  //
  // Kept only for compatibility with older screens.
  // Prefer Archive for normal marketplace usage.
  // ============================================================

  Future<void> deleteProduct(String productId) async {
    if (productId.trim().isEmpty) {
      throw ArgumentError('Product ID is required.');
    }

    await _supabase.from('products').delete().eq('id', productId);

    notifyListeners();
  }

  // ============================================================
  // MANUAL REFRESH
  // ============================================================

  Future<void> refreshProducts() async {
    await _startProductsSubscription();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _disposed = true;

    ++_generation;

    _authSubscription?.cancel();
    _productsSubscription?.cancel();
    _debounce?.cancel();

    super.dispose();
  }
}
