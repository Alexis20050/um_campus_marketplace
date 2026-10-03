import 'package:flutter/material.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import '../theme/app_theme.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final bool gallery;
  const ProductCard({super.key, required this.product, this.gallery = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = product.price.toStringAsFixed(2).split('.');
    final whole = price.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    final image = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: AppColors.surfaceAltOf(context),
          child: product.imageUrls.isEmpty
              ? _placeholder(context)
              : Image.network(
                  product.imageUrls.first,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, error, stack) => _placeholder(context),
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : _placeholder(context),
                ),
        ),
        if (product.isSold)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: const Text(
              'SOLD',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
        if (product.isReserved && !product.isArchived)
          Positioned(
            top: 6,
            left: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'RESERVED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
          ),
        if (gallery && product.imageUrls.length > 1)
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${product.imageUrls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          product.category.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondaryOf(context),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          product.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(height: 1.25),
        ),
        const SizedBox(height: 8),
        Text(
          '\u20b1$whole.${price.last}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.brandOf(context),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          product.sellerName.isEmpty ? 'UM community' : product.sellerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
    return Card(
      margin: gallery
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        ),
        child: gallery
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(aspectRatio: 4 / 3, child: image),
                  Padding(padding: const EdgeInsets.all(14), child: details),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(width: 88, height: 104, child: image),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: details),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Center(
    child: Icon(
      Icons.image_outlined,
      size: 32,
      color: AppColors.textTertiaryOf(context),
    ),
  );
}
