import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/rating_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';

Future<bool> completeSaleWithBuyer(
  BuildContext context, {
  required String productId,
  bool reserve = false,
}) async {
  final ratingProvider = context.read<RatingProvider>();
  final productProvider = context.read<ProductProvider>();

  List<SaleBuyerCandidate> buyers;
  late Product product;

  bool matchesReservation(Product item, SaleBuyerCandidate buyer) =>
      !item.isReserved ||
      (buyer.buyerId == item.reservedBy &&
          buyer.conversationId == item.reservedConversationId);

  void validate(Product? item) {
    if (item == null || !item.isActive) {
      throw StateError('This listing is no longer available.');
    }
    if (item.sellerId != productProvider.currentUserId) {
      throw StateError('Only the seller can update this listing.');
    }
    if (reserve && !item.canReserve) {
      throw StateError('Cancel the existing reservation first.');
    }
  }

  void showError(Object error, String fallback) {
    debugPrint('Reservation/sale flow failed: $error');
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is StateError ? error.message.toString() : fallback,
        ),
      ),
    );
  }

  try {
    final loaded = await productProvider.fetchProductById(productId);
    if (!context.mounted) return false;
    validate(loaded);
    product = loaded!;
    buyers = await ratingProvider.fetchBuyersForProduct(productId);
    buyers = buyers
        .where((buyer) => matchesReservation(product, buyer))
        .toList();
  } catch (error) {
    if (context.mounted) {
      showError(error, 'Could not load buyers. Please try again.');
    }
    return false;
  }

  if (!context.mounted) {
    return false;
  }

  if (buyers.isEmpty) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          product.isReserved
              ? 'The reserved buyer is unavailable. Cancel the reservation before choosing another buyer.'
              : 'No buyers have messaged you about this listing yet.',
        ),
      ),
    );

    return false;
  }

  final selectedBuyer = await showModalBottomSheet<SaleBuyerCandidate>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceOf(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.70,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  children: [
                    Text(
                      reserve ? 'Reserve Item' : 'Who bought this item?',
                      textAlign: TextAlign.center,
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reserve
                          ? 'Choose the buyer this item should be reserved for.'
                          : 'Select the buyer who actually completed the transaction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(sheetContext),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: AppColors.borderOf(sheetContext)),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: buyers.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: AppColors.borderOf(sheetContext),
                  ),
                  itemBuilder: (itemContext, index) {
                    final buyer = buyers[index];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.brandSoftOf(itemContext),
                        child: Icon(
                          Icons.person_outline,
                          color: AppColors.brandOf(itemContext),
                        ),
                      ),
                      title: Text(
                        buyer.buyerName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        product.isReserved
                            ? 'Reserved buyer for this listing'
                            : 'Conversation about this listing',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(itemContext, buyer);
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (selectedBuyer == null || !context.mounted) {
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          reserve
              ? 'Reserve this item for ${selectedBuyer.buyerName}?'
              : 'Complete transaction?',
        ),
        content: Text(
          reserve
              ? 'This listing will remain visible but will be marked RESERVED. Other buyers will not be able to complete the purchase while it is reserved.'
              : '${selectedBuyer.buyerName} will be recorded as the buyer.\n\n'
                    'Only this buyer will be able to rate you for this transaction.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            label: Text(reserve ? 'Reserve Item' : 'Complete Sale'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return false;
  }

  try {
    // A reservation may have changed while the picker or confirmation was open.
    final latest = await productProvider.fetchProductById(productId);
    if (!context.mounted) return false;
    validate(latest);
    if (!matchesReservation(latest!, selectedBuyer)) {
      throw StateError('Cancel the reservation before choosing another buyer.');
    }
    if (reserve) {
      await productProvider.reserveProduct(
        conversationId: selectedBuyer.conversationId,
      );
    } else {
      await ratingProvider.completeSale(
        conversationId: selectedBuyer.conversationId,
      );
    }

    if (!context.mounted) {
      return true;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reserve
              ? 'Item reserved successfully.'
              : 'Sale completed with ${selectedBuyer.buyerName}.',
        ),
      ),
    );

    return true;
  } catch (error) {
    if (context.mounted) {
      showError(
        error,
        'Could not ${reserve ? 'reserve item' : 'complete sale'}. Refresh the listing and try again.',
      );
    }
    return false;
  }
}
