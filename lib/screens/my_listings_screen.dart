import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/auth_service.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/complete_sale_flow.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_product_card.dart';

import 'edit_product_screen.dart';
import 'product_detail_screen.dart';

enum _ListingFilter { active, sold, archived }

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  StreamSubscription<List<Product>>? _subscription;
  List<Product> _products = [];
  String? _sellerId;
  Object? _error;
  bool _loading = true;
  int _generation = 0;
  int _streamRevision = 0;
  int _refreshRequest = 0;
  _ListingFilter _filter = _ListingFilter.active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sellerId = context.watch<AuthService>().user?.id;
    if (_sellerId != sellerId || _generation == 0) {
      _sellerId = sellerId;
      _listen(context.read<ProductProvider>());
    }
  }

  Future<void> _listen(ProductProvider provider) async {
    final generation = ++_generation;
    final sellerId = _sellerId;
    _products = [];
    _loading = sellerId != null;
    _error = null;
    await _subscription?.cancel();
    if (!mounted || generation != _generation || sellerId == null) return;
    _subscription = provider
        .sellerAllProductsStream(sellerId)
        .listen(
          (products) {
            if (!mounted || generation != _generation) return;
            _streamRevision++;
            setState(() {
              _products = products;
              _loading = false;
              _error = null;
            });
          },
          onError: (Object error) {
            if (!mounted || generation != _generation) return;
            setState(() {
              _error = error;
              _loading = false;
            });
          },
        );
  }

  Future<void> _refresh() async {
    final sellerId = _sellerId;
    if (sellerId == null) return;
    final generation = _generation;
    final revision = _streamRevision;
    final request = ++_refreshRequest;
    try {
      final products = await context
          .read<ProductProvider>()
          .fetchSellerProducts(sellerId);
      if (!mounted ||
          generation != _generation ||
          request != _refreshRequest ||
          revision != _streamRevision) {
        return;
      }
      setState(() {
        _products = products;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _generation || request != _refreshRequest) {
        return;
      }
      debugPrint('Seller listing refresh failed: $error');
      if (_products.isEmpty) {
        setState(() {
          _error = error;
          _loading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to refresh listings. Pull down to try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    _subscription?.cancel();
    super.dispose();
  }

  List<Product> _filterProducts(List<Product> products) {
    switch (_filter) {
      case _ListingFilter.active:
        return products
            .where((product) => !product.isSold && !product.isArchived)
            .toList();

      case _ListingFilter.sold:
        return products
            .where((product) => product.isSold && !product.isArchived)
            .toList();

      case _ListingFilter.archived:
        return products.where((product) => product.isArchived).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(title: const Text('My Listings')),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return ListView.builder(
              itemCount: 6,
              itemBuilder: (_, __) => const SkeletonProductCard(),
            );
          }

          if (_error != null) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Something went wrong',
                    subtitle: 'Pull down to try again.',
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  ),
                ],
              ),
            );
          }

          final allProducts = _products;

          final active = allProducts
              .where((p) => !p.isSold && !p.isArchived)
              .length;

          final sold = allProducts
              .where((p) => p.isSold && !p.isArchived)
              .length;

          final archived = allProducts.where((p) => p.isArchived).length;

          final products = _filterProducts(allProducts);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: _FilterSelector(
                  selected: _filter,
                  activeCount: active,
                  soldCount: sold,
                  archivedCount: archived,
                  onChanged: (value) {
                    setState(() {
                      _filter = value;
                    });
                  },
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: products.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            EmptyState(
                              icon: _filter == _ListingFilter.active
                                  ? Icons.inventory_2_outlined
                                  : _filter == _ListingFilter.sold
                                  ? Icons.check_circle_outline
                                  : Icons.archive_outlined,
                              title: _filter == _ListingFilter.active
                                  ? 'No active listings'
                                  : _filter == _ListingFilter.sold
                                  ? 'No sold listings'
                                  : 'No archived listings',
                              subtitle: _filter == _ListingFilter.active
                                  ? 'Your available items will appear here.'
                                  : _filter == _ListingFilter.sold
                                  ? 'Completed sales will appear here.'
                                  : 'Archived listings will appear here.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            return _MyListingTile(
                              key: ValueKey(products[index].id),
                              product: products[index],
                              onChanged: _refresh,
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterSelector extends StatelessWidget {
  final _ListingFilter selected;

  final int activeCount;
  final int soldCount;
  final int archivedCount;

  final ValueChanged<_ListingFilter> onChanged;

  const _FilterSelector({
    required this.selected,
    required this.activeCount,
    required this.soldCount,
    required this.archivedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_ListingFilter>(
      segments: [
        ButtonSegment(
          value: _ListingFilter.active,
          label: Text('Active $activeCount'),
          icon: const Icon(Icons.storefront_outlined),
        ),
        ButtonSegment(
          value: _ListingFilter.sold,
          label: Text('Sold $soldCount'),
          icon: const Icon(Icons.check_circle_outline),
        ),
        ButtonSegment(
          value: _ListingFilter.archived,
          label: Text('Archived $archivedCount'),
          icon: const Icon(Icons.archive_outlined),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (values) {
        if (values.isEmpty) {
          return;
        }

        onChanged(values.first);
      },
      showSelectedIcon: false,
    );
  }
}

class _MyListingTile extends StatefulWidget {
  final Product product;
  final Future<void> Function() onChanged;
  const _MyListingTile({
    super.key,
    required this.product,
    required this.onChanged,
  });
  @override
  State<_MyListingTile> createState() => _MyListingTileState();
}

class _MyListingTileState extends State<_MyListingTile> {
  bool _busy = false;
  Product get product => widget.product;

  Future<void> _run(String action) async {
    if (_busy) return;
    final provider = context.read<ProductProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    var changed = false;
    try {
      switch (action) {
        case 'reserve':
          if (!product.canReserve) return;
          changed = await completeSaleWithBuyer(
            context,
            productId: product.id,
            reserve: true,
          );
        case 'complete':
          if (!product.isActive) return;
          changed = await completeSaleWithBuyer(context, productId: product.id);
        case 'cancel':
          if (!product.canCancelReservation) return;
          final confirmed = await _confirm(
            'Cancel reservation?',
            'This item will become available to buyers again.',
            'Cancel Reservation',
          );
          if (!mounted || !confirmed) return;
          await provider.cancelReservation(product.id);
          changed = true;
          if (mounted) {
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              const SnackBar(content: Text('Reservation cancelled.')),
            );
          }
        case 'edit':
          changed =
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProductScreen(product: product),
                ),
              ) ==
              true;
        case 'archive':
          final confirmed = await _confirm(
            'Archive listing?',
            'The listing will be hidden, but conversations and transaction history remain.',
            'Archive',
          );
          if (!mounted || !confirmed) return;
          await provider.archiveProduct(product.id);
          changed = true;
        case 'restore':
          await provider.restoreProduct(product.id);
          changed = true;
      }
    } catch (error) {
      debugPrint('Seller listing action failed: $error');
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not update listing. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted && changed) await widget.onChanged();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Widget _action(
    String label,
    IconData icon,
    String action, {
    bool primary = false,
  }) {
    final onPressed = _busy ? null : () => _run(action);
    return primary
        ? FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _busy
                ? null
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: product),
                      ),
                    );
                    if (mounted) await widget.onChanged();
                  },
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: product.imageUrls.isEmpty
                        ? _placeholder(context)
                        : Image.network(
                            product.imageUrls.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholder(context),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '\u20b1${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppColors.brandOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product.itemCondition,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _StatusChip(product: product),
                          if (product.isHidden)
                            Text(
                              'HIDDEN',
                              style: TextStyle(
                                color: AppColors.dangerTextOf(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Updating listing',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (product.isReserved && product.reservedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Reserved on ${_reservationDate(product.reservedAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (product.isArchived)
                _action('Restore', Icons.unarchive_outlined, 'restore')
              else if (product.isSold)
                _action('Archive', Icons.archive_outlined, 'archive')
              else ...[
                _action('Edit', Icons.edit_outlined, 'edit'),
                if (product.canReserve)
                  _action(
                    'Reserve Item',
                    Icons.bookmark_add_outlined,
                    'reserve',
                    primary: true,
                  ),
                if (product.isActive)
                  _action(
                    'Complete Sale',
                    Icons.check_circle_outline,
                    'complete',
                  ),
                if (product.canCancelReservation)
                  _action(
                    'Cancel Reservation',
                    Icons.bookmark_remove_outlined,
                    'cancel',
                  ),
                if (!product.isReserved)
                  _action('Archive', Icons.archive_outlined, 'archive'),
              ],
            ],
          ),
        ],
      ),
    ),
  );

  String _reservationDate(DateTime value) {
    final date = value.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: AppColors.surfaceAltOf(context),
    child: Icon(
      Icons.image_not_supported,
      color: AppColors.textTertiaryOf(context),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final Product product;

  const _StatusChip({required this.product});

  @override
  Widget build(BuildContext context) {
    String text;
    IconData icon;

    if (product.isArchived) {
      text = 'ARCHIVED';
      icon = Icons.archive_outlined;
    } else if (product.isSold) {
      text = 'SOLD';
      icon = Icons.check_circle_outline;
    } else if (product.isReserved) {
      text = 'RESERVED';
      icon = Icons.bookmark_added_outlined;
    } else {
      text = 'ACTIVE';
      icon = Icons.storefront_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondaryOf(context)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
