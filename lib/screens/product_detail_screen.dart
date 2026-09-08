import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_service.dart';
import '../providers/product_provider.dart';
import '../providers/message_provider.dart';
import '../providers/favorites_provider.dart'; // <-- add this import
import '../theme/app_theme.dart';
import 'chat_screen.dart';

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
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
    ); // <-- add

    final currentUserId = authService.user?.id;
    final isSeller = currentUserId == widget.product.sellerId;
    final isSold = widget.product.isSold;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.product.title),
        actions: [
          // Favorite heart icon
          IconButton(
            icon: Icon(
              favoritesProvider.isFavorite(widget.product.id)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: favoritesProvider.isFavorite(widget.product.id)
                  ? Colors.red
                  : Colors.white,
            ),
            onPressed: () async {
              await favoritesProvider.toggleFavorite(widget.product.id);
              // Optional: show snackbar feedback
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    favoritesProvider.isFavorite(widget.product.id)
                        ? 'Added to favorites'
                        : 'Removed from favorites',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image carousel
            SizedBox(
              height: 280,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.product.imageUrls.isNotEmpty)
                    PageView.builder(
                      itemCount: widget.product.imageUrls.length,
                      onPageChanged: (index) =>
                          setState(() => _currentImageIndex = index),
                      itemBuilder: (ctx, i) => Image.network(
                        widget.product.imageUrls[i],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image, size: 80),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, size: 80),
                    ),
                  // Dot indicators
                  if (widget.product.imageUrls.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.product.imageUrls.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: index == _currentImageIndex ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: index == _currentImageIndex
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // SOLD badge
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
                          color: Colors.black.withOpacity(0.75),
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

            const SizedBox(height: 16),

            // Title and price
            Padding(
              padding: _kHPad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₱${widget.product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      color: AppColors.maroon,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Seller card
            Padding(
              padding: _kHPad,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kCardRadius),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.gold,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    widget.product.sellerName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isSeller ? 'You are the seller' : 'Seller',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Category and date
            Padding(
              padding: _kHPad,
              child: Row(
                children: [
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.category_outlined,
                      label: 'Category',
                      value: widget.product.category,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.schedule,
                      label: 'Posted',
                      value: _formatDate(widget.product.createdAt),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Description
            Padding(
              padding: _kHPad,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kCardRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.product.description.isEmpty
                            ? 'No description provided.'
                            : widget.product.description,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Sticky bottom action bar
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: isSeller
              ? Row(
                  children: [
                    if (!isSold)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Mark as Sold'),
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
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'This item has been sold',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )),
        ),
      ),
    );
  }

  // Helper to format date
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

// Info card widget
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kCardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.maroon, size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
