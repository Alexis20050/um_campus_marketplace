import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

class FavoritesProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Locally cached favorite product IDs, keyed for O(1) lookup.
  final Set<String> _favoriteIds = {};

  // Guard against overlapping toggles on the same product (rapid taps).
  final Set<String> _inFlight = {};

  String? _lastUserId;

  // ────────────────────────────────────────────────────────────
  // GETTERS
  // ────────────────────────────────────────────────────────────
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  int get count => _favoriteIds.length;

  bool isFavorite(String productId) => _favoriteIds.contains(productId);

  // ────────────────────────────────────────────────────────────
  // LOAD
  // ────────────────────────────────────────────────────────────

  /// Fetches the current user's favorite IDs from Supabase.
  ///
  /// Call this once after the user signs in, and again whenever
  /// the auth state changes. Passing no args uses the current session.
  Future<void> loadFavorites() async {
    final userId = _supabase.auth.currentUser?.id;

    // If the user signed out, clear the cache so the next user
    // doesn't see stale favorites.
    if (userId == null) {
      _lastUserId = null;
      if (_favoriteIds.isNotEmpty) {
        _favoriteIds.clear();
        notifyListeners();
      }
      return;
    }

    // If a different user just signed in, drop the previous cache.
    if (_lastUserId != null && _lastUserId != userId) {
      _favoriteIds.clear();
    }
    _lastUserId = userId;

    try {
      final data = await _supabase
          .from('favorites')
          .select('product_id')
          .eq('user_id', userId);

      _favoriteIds
        ..clear()
        ..addAll(data.map<String>((row) => row['product_id'] as String));

      notifyListeners();
    } catch (e) {
      // Non-fatal: keep whatever cache we had, but log for debugging.
      debugPrint('loadFavorites failed: $e');
    }
  }

  /// Explicitly clears the cache (call from signOut).
  void clear() {
    if (_favoriteIds.isEmpty && _lastUserId == null) return;
    _favoriteIds.clear();
    _lastUserId = null;
    _inFlight.clear();
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────
  // TOGGLE
  // ────────────────────────────────────────────────────────────

  /// Toggles a product's favorite state with an optimistic UI update.
  ///
  /// The local set is updated first so the heart icon flips instantly.
  /// If the DB call fails, the change is rolled back and an error is
  /// rethrown so the caller can surface a SnackBar.
  Future<void> toggleFavorite(String productId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw 'You must be signed in to save favorites.';
    }

    // Prevent double-tap races on the same product.
    if (_inFlight.contains(productId)) return;
    _inFlight.add(productId);

    final wasFavorite = _favoriteIds.contains(productId);

    // 1. Optimistic update — flip the local state immediately.
    if (wasFavorite) {
      _favoriteIds.remove(productId);
    } else {
      _favoriteIds.add(productId);
    }
    notifyListeners();

    try {
      if (wasFavorite) {
        // 2a. Persist removal.
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('product_id', productId);
      } else {
        // 2b. Persist addition. Using upsert so a duplicate
        //     (e.g., from a previous partial failure) doesn't throw.
        await _supabase.from('favorites').upsert({
          'user_id': userId,
          'product_id': productId,
        });
      }
    } catch (e) {
      // 3. Roll back on failure.
      if (wasFavorite) {
        _favoriteIds.add(productId);
      } else {
        _favoriteIds.remove(productId);
      }
      notifyListeners();
      rethrow;
    } finally {
      _inFlight.remove(productId);
    }
  }

  // ────────────────────────────────────────────────────────────
  // FETCH
  // ────────────────────────────────────────────────────────────

  /// Returns the full product records for every favorited product.
  ///
  /// Products that no longer exist (deleted, sold and removed) simply
  /// won't be in the response — Supabase's FK cascade handles cleanup
  /// of the favorite rows on the database side.
  Future<List<Product>> fetchFavoriteProducts() async {
    if (_favoriteIds.isEmpty) return [];

    try {
      final data = await _supabase
          .from('products')
          .select()
          .inFilter('id', _favoriteIds.toList());

      final products = data.map((row) => Product.fromMap(row)).toList();

      // Sort: newest first — matches the Home feed ordering so
      // favorited items feel consistent with the rest of the app.
      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return products;
    } catch (e) {
      debugPrint('fetchFavoriteProducts failed: $e');
      return [];
    }
  }
}
