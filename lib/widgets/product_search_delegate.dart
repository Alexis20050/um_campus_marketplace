import 'package:flutter/material.dart';
import '../models/product.dart';
import 'product_card.dart';
import 'empty_state.dart';

class ProductSearchDelegate extends SearchDelegate<String> {
  final List<Product> products;

  ProductSearchDelegate(this.products)
    : super(
        searchFieldLabel: 'Search products',
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
      );

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        tooltip: 'Clear search',
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
      tooltip: 'Back',
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
    final queryLower = query.trim().toLowerCase();
    final filtered = products
        .where(
          (p) => '${p.title} ${p.category} ${p.description}'
              .toLowerCase()
              .contains(queryLower),
        )
        .toList();

    if (queryLower.isEmpty) {
      return _buildMessage(
        icon: Icons.search,
        title: 'Start typing to search',
        subtitle: 'Search by title, category, or description',
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
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return SingleChildScrollView(
      child: Center(
        child: EmptyState(icon: icon, title: title, subtitle: subtitle),
      ),
    );
  }
}
