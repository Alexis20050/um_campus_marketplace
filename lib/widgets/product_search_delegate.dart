import 'package:flutter/material.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import 'product_card.dart'; // reuse for consistent result cards

class ProductSearchDelegate extends SearchDelegate<String> {
  final Stream<List<Product>> productsStream;
  ProductSearchDelegate(this.productsStream);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: productsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final allProducts = snapshot.data ?? [];
        final filtered = allProducts
            .where((p) => p.title.toLowerCase().contains(query.toLowerCase()))
            .toList();

        if (query.isEmpty) {
          return const Center(
            child: Text(
              'Start typing to search for products',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        if (filtered.isEmpty) {
          // Removed 'const' because we're using a variable ($query)
          return Center(
            child: Text(
              'No products found for "$query"',
              style: const TextStyle(fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) {
            final product = filtered[i];
            return ProductCard(product: product);
          },
        );
      },
    );
  }
}
