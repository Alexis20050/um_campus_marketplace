import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_service.dart';
import '../providers/product_provider.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({required this.product});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    final currentUserId = authService.user?.id;
    final isSeller = currentUserId == product.sellerId;

    return Scaffold(
      appBar: AppBar(title: Text(product.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[300],
              child: product.imageUrls.isNotEmpty
                  ? Image.network(
                      product.imageUrls.first,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Detail image error: $error');
                        print('URL: ${product.imageUrls.first}');
                        return const Icon(Icons.image, size: 80);
                      },
                    )
                  : const Icon(Icons.image, size: 80),
            ),
            const SizedBox(height: 16),
            Text(
              product.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '₱${product.price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 22, color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text('Category: ${product.category}'),
            const SizedBox(height: 16),
            Text(product.description),
            const SizedBox(height: 16),
            Text('Seller: ${product.sellerName}'),
            const SizedBox(height: 20),

            // Seller actions (mark as sold, delete)
            if (isSeller) ...[
              Row(
                children: [
                  if (!product.isSold)
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Mark as Sold'),
                        onPressed: () async {
                          await productProvider.markAsSold(product.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
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
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await productProvider.deleteProduct(product.id);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Buyer actions (message seller)
              if (!product.isSold)
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat),
                  label: const Text('Message Seller'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Messaging coming soon!')),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}
