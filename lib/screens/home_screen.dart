import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';
import '../providers/product_provider.dart';

import '../theme/app_theme.dart';

import '../widgets/empty_state.dart';
import '../widgets/product_card.dart';
import '../widgets/product_search_delegate.dart';
import '../widgets/skeleton_product_card.dart';

import 'favorites_screen.dart';
import 'notifications_screen.dart';
import 'post_product_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSell;

  const HomeScreen({super.key, this.onSell});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _Sort { newest, priceLow, priceHigh }

class _HomeScreenState extends State<HomeScreen> {
  String _category = 'All';

  _Sort _sort = _Sort.newest;

  static const _categories = [
    'All',
    'Books',
    'Electronics',
    'Furniture',
    'Clothing',
    'School Supplies',
    'Services',
  ];

  // ============================================================
  // SELL
  // ============================================================

  void _sell() {
    if (widget.onSell != null) {
      widget.onSell!();

      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostProductScreen(
          onPostSuccess: () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();

    final notificationCount = context.select<NotificationProvider, int>(
      (provider) => provider.unreadCount,
    );

    final products = provider.products
        .where((product) => _category == 'All' || product.category == _category)
        .toList();

    products.sort(
      (a, b) => switch (_sort) {
        _Sort.newest => b.createdAt.compareTo(a.createdAt),
        _Sort.priceLow => a.price.compareTo(b.price),
        _Sort.priceHigh => b.price.compareTo(a.price),
      },
    );

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surfaceOf(context),

        foregroundColor: AppColors.textPrimaryOf(context),

        surfaceTintColor: Colors.transparent,

        title: Row(
          children: [
            Image.asset(
              'assets/images/University_of_Mindanao_Logo.png',
              height: 34,
              width: 34,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'UM Marketplace',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),

        actions: [
          // ====================================================
          // NOTIFICATIONS
          // ====================================================
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
              ),

              if (notificationCount > 0)
                Positioned(
                  right: 2,
                  top: 2,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.surfaceOf(context),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        notificationCount > 99 ? '99+' : '$notificationCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ====================================================
          // FAVORITES
          // ====================================================
          IconButton(
            tooltip: 'Saved listings',
            icon: const Icon(Icons.favorite_border_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        top: false,

        child: LayoutBuilder(
          builder: (context, constraints) {
            final gutter = constraints.maxWidth > 1160
                ? (constraints.maxWidth - 1120) / 2
                : 16.0;

            final width = constraints.maxWidth - gutter * 2;

            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;

            final columns = width < 360 ? 1 : (width / 260).floor().clamp(2, 4);

            final tileWidth = (width - (columns - 1) * 16) / columns;

            return CustomScrollView(
              key: const PageStorageKey('marketplace-feed'),

              slivers: [
                // =================================================
                // HERO
                // =================================================
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 0),

                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(24),

                      decoration: BoxDecoration(
                        color: AppColors.maroonDark,
                        borderRadius: BorderRadius.circular(24),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Text(
                            'THE CAMPUS EXCHANGE',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Great finds.\nRight here on campus.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'Books, everyday essentials, and more from the UM community.',
                            style: TextStyle(
                              color: Color(0xFFEADADA),
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 18),

                          FilledButton.icon(
                            onPressed: _sell,

                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: const Color(0xFF301A00),
                              minimumSize: const Size(0, 48),
                            ),

                            icon: const Icon(Icons.add_rounded, size: 20),

                            label: const Text('Sell an item'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // =================================================
                // SEARCH
                // =================================================
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 16),

                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search books, gadgets, and more',
                        prefixIcon: Icon(Icons.search_rounded),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),

                      showCursor: false,

                      enableInteractiveSelection: false,

                      onTap: () {
                        showSearch(
                          context: context,
                          delegate: ProductSearchDelegate(provider.products),
                        );
                      },

                      readOnly: true,
                    ),
                  ),
                ),

                // =================================================
                // CATEGORIES
                // =================================================
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,

                    padding: EdgeInsets.symmetric(horizontal: gutter),

                    child: Row(
                      children: _categories
                          .map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(right: 8),

                              child: ChoiceChip(
                                label: Text(category),

                                selected: category == _category,

                                selectedColor: AppColors.brandSoftOf(context),

                                labelStyle: TextStyle(
                                  color: AppColors.textPrimaryOf(context),

                                  fontWeight: category == _category
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),

                                onSelected: (_) {
                                  setState(() {
                                    _category = category;
                                  });
                                },
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),

                // =================================================
                // HEADING + SORT
                // =================================================
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 12),

                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,

                      crossAxisAlignment: WrapCrossAlignment.center,

                      spacing: 16,

                      runSpacing: 8,

                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              _category == 'All'
                                  ? 'Explore the marketplace'
                                  : _category,

                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 21,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              provider.isLoading
                                  ? 'Finding campus favorites...'
                                  : provider.error != null
                                  ? 'Please try again'
                                  : '${products.length} ${products.length == 1 ? 'listing' : 'listings'} to explore',

                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),

                        PopupMenuButton<_Sort>(
                          tooltip: 'Sort listings',

                          initialValue: _sort,

                          onSelected: (value) {
                            setState(() {
                              _sort = value;
                            });
                          },

                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: _Sort.newest,
                              child: Text('Newest first'),
                            ),
                            PopupMenuItem(
                              value: _Sort.priceLow,
                              child: Text('Price: low to high'),
                            ),
                            PopupMenuItem(
                              value: _Sort.priceHigh,
                              child: Text('Price: high to low'),
                            ),
                          ],

                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),

                            child: Row(
                              mainAxisSize: MainAxisSize.min,

                              children: [
                                const Icon(Icons.sort_rounded, size: 20),

                                const SizedBox(width: 6),

                                Text(switch (_sort) {
                                  _Sort.newest => 'Newest',
                                  _Sort.priceLow => 'Price: low to high',
                                  _Sort.priceHigh => 'Price: high to low',
                                }),

                                const Icon(Icons.expand_more_rounded, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // =================================================
                // CONTENT
                // =================================================
                if (provider.isLoading)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    sliver: SliverList.builder(
                      itemCount: 4,
                      itemBuilder: (_, __) => const SkeletonProductCard(),
                    ),
                  )
                else if (provider.error != null)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,

                      title: 'Could not load listings',

                      subtitle: provider.error!,

                      actionLabel: 'Try again',

                      onAction: provider.retry,
                    ),
                  )
                else if (products.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.storefront_outlined,

                      title: _category == 'All'
                          ? 'Your campus marketplace starts here'
                          : 'No listings in $_category yet',

                      subtitle: _category == 'All'
                          ? 'Give something you no longer use a new home.'
                          : 'Explore another category or come back soon.',

                      actionLabel: _category == 'All'
                          ? 'Create a listing'
                          : 'Browse all listings',

                      onAction: _category == 'All'
                          ? _sell
                          : () {
                              setState(() {
                                _category = 'All';
                              });
                            },
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 28),

                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,

                        crossAxisSpacing: 16,

                        mainAxisSpacing: 16,

                        mainAxisExtent: tileWidth * 0.75 + 28 + 160 * scale,
                      ),

                      itemCount: products.length,

                      itemBuilder: (_, index) =>
                          ProductCard(product: products[index], gallery: true),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
