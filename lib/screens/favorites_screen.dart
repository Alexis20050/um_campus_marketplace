import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/favorites_provider.dart';
import '../widgets/product_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Product>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );
    favoritesProvider.loadFavorites(); // ensure IDs are loaded
    _favoritesFuture = favoritesProvider.fetchFavoriteProducts();
  }

  Future<void> _refresh() async {
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );
    await favoritesProvider.loadFavorites();
    setState(() {
      _favoritesFuture = favoritesProvider.fetchFavoriteProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: const Color(0xFF800000),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Product>>(
          future: _favoritesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              return const Center(
                child: Text(
                  'No favorites yet.\nTap the heart on a product to save it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: products.length,
              itemBuilder: (ctx, i) => ProductCard(product: products[i]),
            );
          },
        ),
      ),
    );
  }
}
