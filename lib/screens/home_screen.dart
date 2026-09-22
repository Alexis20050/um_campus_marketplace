import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/product_search_delegate.dart';
import '../widgets/skeleton_product_card.dart';
import '../widgets/empty_state.dart';
import '../theme/app_theme.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.maroon,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/images/University_of_Mindanao_Logo.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 10),
            const Text(
              'UM Marketplace',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Welcome banner ────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.maroon, AppColors.maroonDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.maroon.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.gold,
                  child: Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome, UM Students!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Buy and sell within the community',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Search bar ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Material(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(25),
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  showSearch(
                    context: context,
                    delegate: ProductSearchDelegate(
                      productProvider.productsStream,
                    ),
                  );
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2E2E2E)
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: Colors.grey[isDark ? 500 : 500],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Search for products',
                        style: TextStyle(
                          color: Colors.grey[isDark ? 400 : 600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Category chips ────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final category = _categories[i];
                final isSelected = _selectedCategory == category;

                final unselectedBg = isDark
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey[200];
                final unselectedText = isDark
                    ? Colors.grey[200]
                    : Colors.black87;

                return Material(
                  color: isSelected ? AppColors.maroon : unselectedBg,
                  borderRadius: BorderRadius.circular(20),
                  elevation: isSelected ? 2 : 0,
                  shadowColor: AppColors.maroon.withOpacity(0.3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _selectedCategory = category),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : unselectedText,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 4),

          // ── Product list ──────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: productProvider.productsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Something went wrong',
                    subtitle:
                        'We couldn\'t load the listings. Pull down to retry.',
                    actionLabel: 'Retry',
                    onAction: () => setState(() {}),
                  );
                }

                // Loading: show skeleton cards instead of a spinner.
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                    itemCount: 6,
                    itemBuilder: (_, __) => const SkeletonProductCard(),
                  );
                }

                final allProducts = snapshot.data ?? [];
                final filteredProducts = _selectedCategory == 'All'
                    ? allProducts
                    : allProducts
                          .where((p) => p.category == _selectedCategory)
                          .toList();

                // Empty state: friendlier copy + illustration.
                if (filteredProducts.isEmpty) {
                  final isAll = _selectedCategory == 'All';
                  return EmptyState(
                    icon: isAll
                        ? Icons.storefront_outlined
                        : Icons.filter_alt_off_outlined,
                    title: isAll
                        ? 'No listings yet'
                        : 'Nothing in "$_selectedCategory"',
                    subtitle: isAll
                        ? 'Be the first to post something for sale on campus.'
                        : 'Try a different category or check back later.',
                    actionLabel: isAll ? null : 'Show all',
                    onAction: isAll
                        ? null
                        : () => setState(() => _selectedCategory = 'All'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filteredProducts.length,
                  itemBuilder: (ctx, i) =>
                      ProductCard(product: filteredProducts[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PostProductScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Sell'),
        backgroundColor: AppColors.maroon,
        elevation: 3,
      ),
    );
  }
}
