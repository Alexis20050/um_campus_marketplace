import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

class ProductProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Private controller to broadcast product updates to the UI
  final StreamController<List<Product>> _productsController =
      StreamController<List<Product>>.broadcast();

  // Cache the latest product list so new listeners get data instantly
  List<Product> _cachedProducts = [];

  // Public stream consumed by HomeScreen
  Stream<List<Product>> get productsStream => _productsController.stream;

  // Keep track of the realtime subscription so we can cancel it later
  StreamSubscription? _productsSubscription;

  // Constructor: initialize auth listener and start realtime
  ProductProvider() {
    _setupAuthListener();
    _startProductsSubscription();

    // When a new listener subscribes, immediately provide the cached list
    _productsController.onListen = () {
      if (_cachedProducts.isNotEmpty) {
        _productsController.add(_cachedProducts);
      }
    };
  }

  // Listen to Supabase auth changes (login, logout, token refresh)
  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      // When auth state changes, restart the products subscription
      // to use the new token (if any). This also handles logout.
      _startProductsSubscription();
    });
  }

  // Start or restart the realtime subscription for products
  Future<void> _startProductsSubscription() async {
    // Cancel existing subscription (if any) to avoid duplicates
    await _productsSubscription?.cancel();
    _productsSubscription = null;

    // Ensure session token is fresh before subscribing
    final session = _supabase.auth.currentSession;
    if (session != null) {
      // If token expires in less than 2 minutes, refresh it
      final expiresAt = session.expiresAt;
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      if (expiresAt != null && (expiresAt - now) < 120) {
        try {
          await _supabase.auth.refreshSession();
        } catch (_) {
          // If refresh fails, user may need to re-login.
          // Emit empty list and stop.
          _productsController.add([]);
          return;
        }
      }
    }

    // Create a new realtime subscription using the (possibly refreshed) token
    _productsSubscription = _supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            final products = rows
                .where((row) => row['is_sold'] == false)
                .map((row) => Product.fromMap(row))
                .toList();
            _cachedProducts = products; // update cache
            _productsController.add(products); // emit to current listeners
          },
          onError: (error) {
            // You can choose to emit empty or keep last data
            debugPrint('Product realtime error: $error');
          },
        );
  }

  // A seller's own products (includes sold items)
  Stream<List<Product>> sellerProductsStream(String sellerId) {
    // This method returns a stream directly; no need to manage manually.
    // It will also suffer from token expiry if not refreshed,
    // but for simplicity, the caller can refresh if needed.
    return _supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((row) => Product.fromMap(row)).toList());
  }

  // Fetch a public profile row for a given user id (used by UserProfileScreen)
  Future<Map<String, dynamic>?> fetchProfileById(String userId) async {
    final data = await _supabase
        .from('profiles')
        .select('id, name, email, created_at')
        .eq('id', userId)
        .maybeSingle();
    return data;
  }

  // Add a new product
  Future<void> addProduct({
    required String sellerId,
    required String sellerName,
    required String title,
    required String description,
    required double price,
    required String category,
    required List<String> imageUrls,
  }) async {
    await _supabase.from('products').insert({
      'seller_id': sellerId,
      'seller_name': sellerName,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'image_urls': imageUrls,
      'is_sold': false,
    });
    notifyListeners();
  }

  // Update an existing product's details
  Future<void> updateProduct({
    required String id,
    required String title,
    required String description,
    required double price,
    required String category,
    required List<String> imageUrls,
  }) async {
    await _supabase
        .from('products')
        .update({
          'title': title,
          'description': description,
          'price': price,
          'category': category,
          'image_urls': imageUrls,
        })
        .eq('id', id);
    notifyListeners();
  }

  // Mark a product as sold
  Future<void> markAsSold(String id) async {
    await _supabase.from('products').update({'is_sold': true}).eq('id', id);
    notifyListeners();
  }

  // Relist a sold item
  Future<void> markAsAvailable(String id) async {
    await _supabase.from('products').update({'is_sold': false}).eq('id', id);
    notifyListeners();
  }

  // Delete a product
  Future<void> deleteProduct(String id) async {
    await _supabase.from('products').delete().eq('id', id);
    notifyListeners();
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _productsController.close();
    super.dispose();
  }
}
