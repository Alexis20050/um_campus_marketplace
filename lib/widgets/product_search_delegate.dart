import 'package:flutter/material.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';

class ProductSearchDelegate extends SearchDelegate<String> {
  final Stream<List<Product>> productsStream;
  ProductSearchDelegate(this.productsStream);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
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
    return StreamBuilder<List<Product>>(
      stream: productsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final results = snapshot.data!
            .where((p) => p.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (ctx, i) => ListTile(
            title: Text(results[i].title),
            subtitle: Text('₱${results[i].price.toStringAsFixed(2)}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: results[i]),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: productsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final suggestions = snapshot.data!
            .where((p) => p.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (ctx, i) => ListTile(
            title: Text(suggestions[i].title),
            onTap: () {
              query = suggestions[i].title;
              showResults(context);
            },
          ),
        );
      },
    );
  }
}
