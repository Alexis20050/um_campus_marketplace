import 'package:flutter/material.dart';
import '../models/product.dart';
import 'product_card.dart';

class ProductSearchDelegate extends SearchDelegate<String> {
  final Stream<List<Product>> productsStream;

  ProductSearchDelegate(this.productsStream)
    : super(
        searchFieldLabel: 'Search products',
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
      );

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
          return _buildMessage(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            subtitle: 'Please try again later.',
          );
        }

        final allProducts = snapshot.data ?? [];
        final queryLower = query.toLowerCase();
        final filtered = allProducts
            .where((p) => p.title.toLowerCase().contains(queryLower))
            .toList();

        if (query.isEmpty) {
          return _buildMessage(
            icon: Icons.search,
            title: 'Start typing to search',
            subtitle: 'Find products by title',
          );
        }

        if (filtered.isEmpty) {
          return _buildMessage(
            icon: Icons.inbox_outlined,
            title: 'No products found',
            subtitle: 'Try a different keyword',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final product = filtered[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ProductCard(product: product),
            );
          },
        );
      },
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
