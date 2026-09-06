import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

class ProductProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Cached once (see earlier fix) so it isn't recreated on every access.
  late final Stream<List<Product>> productsStream = _supabase
      .from('products')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map(
        (rows) => rows
            .where((row) => row['is_sold'] == false)
            .map((row) => Product.fromMap(row))
            .toList(),
      );

  // NEW: a seller's own products — includes sold items, unlike the main
  // feed, so they can manage everything they've ever posted.
  Stream<List<Product>> sellerProductsStream(String sellerId) {
    return _supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((row) => Product.fromMap(row)).toList());
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

  // Mark a product as sold
  Future<void> markAsSold(String id) async {
    await _supabase.from('products').update({'is_sold': true}).eq('id', id);
    notifyListeners();
  }

  // NEW: relist a sold item (undo mark-as-sold)
  Future<void> markAsAvailable(String id) async {
    await _supabase.from('products').update({'is_sold': false}).eq('id', id);
    notifyListeners();
  }

  // Delete a product
  Future<void> deleteProduct(String id) async {
    await _supabase.from('products').delete().eq('id', id);
    notifyListeners();
  }
}
