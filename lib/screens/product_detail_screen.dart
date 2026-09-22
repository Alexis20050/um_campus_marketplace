import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_service.dart';
import '../providers/product_provider.dart';
import '../providers/message_provider.dart';
import '../providers/favorites_provider.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';

const double _kCardRadius = 12;
const EdgeInsets _kHPad = EdgeInsets.symmetric(horizontal: 16);

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({required this.product});

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _currentImageIndex = 0;
  bool _isDescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    final messageProvider = Provider.of<MessageProvider>(
      context,
      listen: false,
    );
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final theme = Theme.of(context);

    final currentUserId = authService.user?.id;
    final isSeller = currentUserId == widget.product.sellerId;
    final isSold = widget.product.isSold;
    final bool isFavorited = favoritesProvider.isFavorite(widget.product.id);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(widget.product.title),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        actions: [
          // Favorite button
          IconButton(
            icon: Icon(
              isFavorited ? Icons.favorite : Icons.favorite_border,
              color: isFavorited ? Colors.red : Colors.white,
            ),
            onPressed: () async {
              try {
                await favoritesProvider.toggleFavorite(widget.product.id);
                if (!context.mounted) return;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isFavorited
                          ? 'Removed from favorites'
                          : 'Added to favorites',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              } catch (e) {
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
          // Share button
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
          ),
          // More menu (Report)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'report') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report feature coming soon!')),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Report'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ══════════════════════════════════════════════════
            // Image carousel (with overlay, dots, SOLD badge)
            // ══════════════════════════════════════════════════
            SizedBox(
              height: 350,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.product.imageUrls.isNotEmpty)
                    PageView.builder(
                      itemCount: widget.product.imageUrls.length,
                      onPageChanged: (index) =>
                          setState(() => _currentImageIndex = index),
                      itemBuilder: (ctx, i) => Hero(
                        tag: 'product_image_${widget.product.id}_$i',
                        child: Image.network(
                          widget.product.imageUrls[i],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: AppColors.surfaceAltOf(context),
                                child: Icon(
                                  Icons.broken_image,
                                  size: 80,
                                  color: AppColors.textTertiaryOf(context),
                                ),
                              ),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: AppColors.surfaceAltOf(context),
                      child: Icon(
                        Icons.image,
                        size: 80,
                        color: AppColors.textTertiaryOf(context),
                      ),
                    ),

                  // Bottom gradient over the image (keeps dots legible)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Dot indicators (always white — over image)
                  if (widget.product.imageUrls.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.product.imageUrls.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: index == _currentImageIndex ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: index == _currentImageIndex
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // SOLD badge (black chip — over image)
                  if (isSold)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'SOLD',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ══════════════════════════════════════════════════
            // Title & Price
            // ══════════════════════════════════════════════════
            Padding(
              padding: _kHPad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 26,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.maroon,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₱${widget.product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ══════════════════════════════════════════════════
            // Seller card
            // ══════════════════════════════════════════════════
            Padding(
              padding: _kHPad,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kCardRadius),
                ),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(_kCardRadius),
                  onTap: isSeller
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                userId: widget.product.sellerId,
                                initialName: widget.product.sellerName,
                              ),
                            ),
                          );
                        },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.gold,
                      child: Text(
                        widget.product.sellerName.isNotEmpty
                            ? widget.product.sellerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      widget.product.sellerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      isSeller ? 'You are the seller' : 'Tap to view profile',
                      style: TextStyle(
                        color: isSeller
                            ? AppColors.brandOf(context)
                            : AppColors.textSecondaryOf(context),
                        fontSize: 13,
                        fontWeight: isSeller
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: !isSeller
                        ? TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserProfileScreen(
                                    userId: widget.product.sellerId,
                                    initialName: widget.product.sellerName,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chevron_right, size: 18),
                            label: const Text('Profile'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.brandOf(context),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ══════════════════════════════════════════════════
            // Category & Posted
            // ══════════════════════════════════════════════════
            Padding(
              padding: _kHPad,
              child: Row(
                children: [
                  _AttributeChip(
                    icon: Icons.category_outlined,
                    label: widget.product.category,
                  ),
                  const SizedBox(width: 16),
                  _AttributeChip(
                    icon: Icons.access_time,
                    label: _formatDate(widget.product.createdAt),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ══════════════════════════════════════════════════
            // Description
            // ══════════════════════════════════════════════════
            Padding(
              padding: _kHPad,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kCardRadius),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StatefulBuilder(
                        builder: (context, setStateBuilder) {
                          final desc = widget.product.description;
                          final bool isLong = desc.length > 150;
                          final String displayText =
                              isLong && !_isDescriptionExpanded
                              ? '${desc.substring(0, 150)}...'
                              : desc;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayText.isNotEmpty
                                    ? displayText
                                    : 'No description provided.',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              if (isLong)
                                GestureDetector(
                                  onTap: () {
                                    setStateBuilder(() {
                                      _isDescriptionExpanded =
                                          !_isDescriptionExpanded;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _isDescriptionExpanded
                                          ? 'See less'
                                          : 'See more',
                                      style: TextStyle(
                                        color: AppColors.brandOf(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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

      // ══════════════════════════════════════════════════════
      // Sticky bottom action bar
      // ══════════════════════════════════════════════════════
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, -2),
                blurRadius: 8,
                color: AppColors.shadowOf(context),
              ),
            ],
          ),
          child: isSeller
              ? Row(
                  children: [
                    if (!isSold)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Mark as Sold'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandOf(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            await productProvider.markAsSold(widget.product.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ),
                    if (!isSold) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete product?'),
                              content: const Text(
                                'This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await productProvider.deleteProduct(
                              widget.product.id,
                            );
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                )
              : (!isSold
                    ? SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Message Seller'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandOf(context),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            try {
                              final conversationId = await messageProvider
                                  .getOrCreateConversation(
                                    productId: widget.product.id,
                                    sellerId: widget.product.sellerId,
                                  );
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      conversationId: conversationId,
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAltOf(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'This item has been sold',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'Just now';
    }
  }
}

// ═════════════════════════════════════════════════════════════
// ATTRIBUTE CHIP (category / posted)
// ═════════════════════════════════════════════════════════════
class _AttributeChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AttributeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondaryOf(context)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textPrimaryOf(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
