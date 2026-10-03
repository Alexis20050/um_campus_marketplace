import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';

import '../providers/auth_service.dart';
import '../providers/favorites_provider.dart';
import '../providers/message_provider.dart';
import '../providers/moderation_provider.dart';
import '../widgets/report_dialog.dart';
import '../providers/product_provider.dart';

import '../theme/app_theme.dart';
import '../utils/complete_sale_flow.dart';

import 'chat_screen.dart';
import 'edit_product_screen.dart';
import 'user_profile_screen.dart';

const EdgeInsets _kHPad = EdgeInsets.symmetric(horizontal: 16);

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // Reuse the public product subscription for live reservation changes.
  Product get _product => context.read<ProductProvider>().products.firstWhere(
    (product) => product.id == widget.product.id,
    orElse: () => widget.product,
  );

  int _currentImageIndex = 0;

  bool _isDescriptionExpanded = false;
  bool _reporting = false;
  bool _completingSale = false;

  Future<void> _reportListing() async {
    if (_reporting) return;
    final report = await showReportDialog(
      context: context,
      title: 'Report Listing',
      description: _product.title,
    );
    if (!mounted || report == null) return;
    final provider = context.read<ModerationProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reporting = true);
    try {
      await provider.reportListing(
        productId: _product.id,
        reason: report.reason,
        details: report.details,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Report submitted for review.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not submit report: ${provider.error ?? e}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  Future<void> _editListing() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProductScreen(product: _product)),
    );

    if (updated == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _archive(ProductProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive listing?'),
        content: const Text(
          'This listing will be hidden from the marketplace. Existing conversations and transaction history remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await provider.archiveProduct(_product.id);

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }

  Future<void> _restore(ProductProvider provider) async {
    await provider.restoreProduct(_product.id);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Listing restored.')));

    Navigator.pop(context);
  }

  Future<void> _completeSale() async {
    if (_completingSale) return;
    setState(() => _completingSale = true);
    try {
      final completed = await completeSaleWithBuyer(
        context,
        productId: _product.id,
      );
      if (completed && mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _completingSale = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    final productProvider = context.watch<ProductProvider>();

    final messageProvider = context.read<MessageProvider>();

    final favoritesProvider = context.watch<FavoritesProvider>();

    final theme = Theme.of(context);

    final currentUserId = authService.user?.id;

    final isSeller = currentUserId == _product.sellerId;

    final isSold = _product.isSold;

    final isArchived = _product.isArchived;

    final isFavorited = favoritesProvider.isFavorite(_product.id);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(_product.title),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        actions: [
          if (!isSeller && !isSold && !isArchived)
            IconButton(
              icon: Icon(
                isFavorited ? Icons.favorite : Icons.favorite_border,
                color: isFavorited ? Colors.red : Colors.white,
              ),
              onPressed: () async {
                try {
                  await favoritesProvider.toggleFavorite(_product.id);

                  if (!mounted) {
                    return;
                  }

                  setState(() {});
                } catch (e) {
                  if (!mounted) {
                    return;
                  }

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not update favorite: $e'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
            ),

          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
          ),

          PopupMenuButton<String>(
            enabled: !_reporting && !_completingSale,
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  await _editListing();

                case 'archive':
                  await _archive(productProvider);

                case 'restore':
                  await _restore(productProvider);

                case 'report':
                  await _reportListing();
              }
            },
            itemBuilder: (_) {
              if (isSeller) {
                return [
                  if (!isSold && !isArchived)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit Listing'),
                      ),
                    ),

                  if (!isArchived)
                    const PopupMenuItem(
                      value: 'archive',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.archive_outlined),
                        title: Text('Archive Listing'),
                      ),
                    ),

                  if (isArchived)
                    const PopupMenuItem(
                      value: 'restore',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.unarchive_outlined),
                        title: Text('Restore Listing'),
                      ),
                    ),
                ];
              }

              return const [
                PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.flag_outlined, color: AppColors.danger),
                    title: Text('Report Listing'),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 350,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_product.imageUrls.isNotEmpty)
                    PageView.builder(
                      itemCount: _product.imageUrls.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                          _product.imageUrls[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.surfaceAltOf(context),
                            child: Icon(
                              Icons.broken_image,
                              size: 70,
                              color: AppColors.textTertiaryOf(context),
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      color: AppColors.surfaceAltOf(context),
                      child: Icon(
                        Icons.image,
                        size: 70,
                        color: AppColors.textTertiaryOf(context),
                      ),
                    ),

                  if (_product.imageUrls.length > 1)
                    Positioned(
                      bottom: 15,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _product.imageUrls.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: index == _currentImageIndex ? 18 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: index == _currentImageIndex
                                  ? Colors.white
                                  : Colors.white54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (isSold)
                    _TopBadge(text: 'SOLD')
                  else if (isArchived)
                    _TopBadge(text: 'ARCHIVED')
                  else if (_product.isReserved)
                    _TopBadge(text: 'RESERVED'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: _kHPad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _product.title,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 26),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandOf(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₱${_product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: _kHPad,
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.gold,
                    child: Text(
                      _product.sellerName.isNotEmpty
                          ? _product.sellerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    _product.sellerName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isSeller ? 'You are the seller' : 'Tap to view profile',
                  ),
                  trailing: isSeller ? null : const Icon(Icons.chevron_right),
                  onTap: isSeller
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                userId: _product.sellerId,
                                initialName: _product.sellerName,
                              ),
                            ),
                          );
                        },
                ),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: _kHPad,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _AttributeChip(
                    icon: Icons.category_outlined,
                    label: _product.category,
                  ),

                  _AttributeChip(
                    icon: Icons.verified_outlined,
                    label: _product.itemCondition,
                  ),

                  _AttributeChip(
                    icon: Icons.access_time,
                    label: _formatDate(_product.createdAt),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: _kHPad,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Description', style: theme.textTheme.titleMedium),

                      const SizedBox(height: 8),

                      Builder(
                        builder: (context) {
                          final description = _product.description;

                          final isLong = description.length > 150;

                          final display = isLong && !_isDescriptionExpanded
                              ? '${description.substring(0, 150)}...'
                              : description;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                display.isEmpty
                                    ? 'No description provided.'
                                    : display,
                                style: TextStyle(
                                  height: 1.5,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),

                              if (isLong)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isDescriptionExpanded =
                                          !_isDescriptionExpanded;
                                    });
                                  },
                                  child: Text(
                                    _isDescriptionExpanded
                                        ? 'See less'
                                        : 'See more',
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border(top: BorderSide(color: AppColors.borderOf(context))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_product.isReserved && !isArchived && !isSeller)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    currentUserId == _product.reservedBy
                        ? 'This item is reserved for you.'
                        : 'Reserved for another buyer. You can still message the seller.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              _buildBottomAction(
                context,
                isSeller: isSeller,
                isSold: isSold,
                isArchived: isArchived,
                messageProvider: messageProvider,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(
    BuildContext context, {
    required bool isSeller,
    required bool isSold,
    required bool isArchived,
    required MessageProvider messageProvider,
  }) {
    if (_product.isHidden) {
      return _InfoBox(text: 'This listing is unavailable');
    }
    if (isSeller) {
      if (isSold) {
        return _InfoBox(text: 'This listing has been sold');
      }

      if (isArchived) {
        return _InfoBox(text: 'This listing is archived');
      }

      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _completingSale ? null : _completeSale,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(_completingSale ? 'Please wait…' : 'Complete Sale'),
        ),
      );
    }

    if (isSold) {
      return _InfoBox(text: 'This item has been sold');
    }

    if (isArchived) {
      return _InfoBox(text: 'This listing is unavailable');
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Message Seller'),
        onPressed: () async {
          try {
            final conversationId = await messageProvider
                .getOrCreateConversation(
                  productId: _product.id,
                  sellerId: _product.sellerId,
                );

            if (!context.mounted) {
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(conversationId: conversationId),
              ),
            );
          } catch (e) {
            if (!context.mounted) {
              return;
            }

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date.toLocal());

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    }

    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    }

    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }

    return 'Just now';
  }
}

class _TopBadge extends StatelessWidget {
  final String text;

  const _TopBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _AttributeChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AttributeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.brandOf(context)),

          const SizedBox(width: 6),

          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;

  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondaryOf(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
