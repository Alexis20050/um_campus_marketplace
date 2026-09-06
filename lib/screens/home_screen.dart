import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/product_search_delegate.dart';
import 'post_product_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Books',
    'Electronics',
    'Furniture',
    'Clothing',
    'School Supplies',
    'Services',
  ];

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/University_of_Mindanao_Logo.png',
              height: 40,
              width: 40,
            ),
            const SizedBox(width: 10),
            const Text('UM Marketplace'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ProductSearchDelegate(productProvider.productsStream),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Product>>(
        stream: productProvider.productsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allProducts = snapshot.data ?? [];
          final filteredProducts = _selectedCategory == 'All'
              ? allProducts
              : allProducts
                    .where((p) => p.category == _selectedCategory)
                    .toList();

          return Column(
            children: [
              // Category chips
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) {
                    final category = _categories[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _selectedCategory == category,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              // Product list
              Expanded(
                child: filteredProducts.isEmpty
                    ? const Center(child: Text('No items found'))
                    : ListView.builder(
                        itemCount: filteredProducts.length,
                        itemBuilder: (ctx, i) =>
                            ProductCard(product: filteredProducts[i]),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PostProductScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
