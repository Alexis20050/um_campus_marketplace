import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

class FavoritesProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  Set<String> _favoriteIds = {};

  Set<String> get favoriteIds => _favoriteIds;

  // Load the current user's favorite product IDs
  Future<void> loadFavorites() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final data = await _supabase
        .from('favorites')
        .select('product_id')
        .eq('user_id', userId);
    _favoriteIds = data
        .map<String>((row) => row['product_id'] as String)
        .toSet();
    notifyListeners();
  }

  bool isFavorite(String productId) => _favoriteIds.contains(productId);

  Future<void> toggleFavorite(String productId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    if (_favoriteIds.contains(productId)) {
      await _supabase
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
      _favoriteIds.remove(productId);
    } else {
      await _supabase.from('favorites').insert({
        'user_id': userId,
        'product_id': productId,
      });
      _favoriteIds.add(productId);
    }
    notifyListeners();
  }

  // Fetch full product details for all favorite IDs
  Future<List<Product>> fetchFavoriteProducts() async {
    if (_favoriteIds.isEmpty) return [];
    final data = await _supabase
        .from('products')
        .select()
        .inFilter('id', _favoriteIds.toList());
    return data.map((row) => Product.fromMap(row)).toList();
  }
}
