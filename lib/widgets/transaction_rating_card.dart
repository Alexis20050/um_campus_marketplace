import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/rating_provider.dart';
import '../theme/app_theme.dart';

class TransactionRatingCard extends StatelessWidget {
  final String conversationId;

  const TransactionRatingCard({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context) {
    context.select<RatingProvider, int>((provider) => provider.ratingsRevision);
    final provider = context.read<RatingProvider>();

    final currentUserId = provider.currentUserId;

    if (currentUserId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: provider.transactionStreamForConversation(conversationId),
      builder: (context, transactionSnapshot) {
        final transactions = transactionSnapshot.data ?? [];

        if (transactions.isEmpty) {
          return const SizedBox.shrink();
        }

        final transaction = transactions.first;

        final transactionId = transaction['id'].toString();

        final buyerId = transaction['buyer_id'].toString();

        final sellerId = transaction['seller_id'].toString();

        final isBuyer = currentUserId == buyerId;

        final isSeller = currentUserId == sellerId;

        if (!isBuyer && !isSeller) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: provider.ratingStreamForTransaction(transactionId),
          builder: (context, ratingSnapshot) {
            final ratings = ratingSnapshot.data ?? [];

            final rating = ratings.isNotEmpty ? ratings.first : null;

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.success,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Transaction Completed',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 2),

                            Text(
                              isBuyer
                                  ? 'You are the confirmed buyer.'
                                  : 'You completed this sale.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (rating == null) ...[
                    const SizedBox(height: 14),

                    if (isBuyer)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.star_border_rounded),
                          label: const Text('Rate Seller'),
                          onPressed: () {
                            _showRatingDialog(context, provider, transactionId);
                          },
                        ),
                      )
                    else
                      Text(
                        'The buyer can now rate this transaction.',
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 13,
                        ),
                      ),
                  ] else ...[
                    const SizedBox(height: 14),

                    Text(
                      isBuyer ? 'Your seller rating' : 'Buyer rating',
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 5),

                    _StarDisplay(rating: (rating['rating'] as num).toInt()),

                    finalReview(context, rating),

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Verified Purchase',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget finalReview(BuildContext context, Map<String, dynamic> rating) {
    final review = rating['review']?.toString().trim() ?? '';

    if (review.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        review,
        style: TextStyle(color: AppColors.textPrimaryOf(context), fontSize: 13),
      ),
    );
  }

  Future<void> _showRatingDialog(
    BuildContext context,
    RatingProvider provider,
    String transactionId,
  ) async {
    int selectedRating = 0;

    final reviewController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rate Seller'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'How was your experience with this seller?',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final value = index + 1;

                        return IconButton(
                          iconSize: 35,
                          onPressed: () {
                            setDialogState(() {
                              selectedRating = value;
                            });
                          },
                          icon: Icon(
                            value <= selectedRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppColors.gold,
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: reviewController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Review (optional)',
                        hintText: 'How was your experience?',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),

                FilledButton(
                  onPressed: selectedRating == 0
                      ? null
                      : () {
                          Navigator.pop(dialogContext, {
                            'rating': selectedRating,
                            'review': reviewController.text.trim(),
                          });
                        },
                  child: const Text('Submit Rating'),
                ),
              ],
            );
          },
        );
      },
    );

    reviewController.dispose();

    if (result == null || !context.mounted) {
      return;
    }

    try {
      await provider.submitSellerRating(
        transactionId: transactionId,
        rating: result['rating'] as int,
        review: result['review'] as String?,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller rating submitted!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit rating: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _StarDisplay extends StatelessWidget {
  final int rating;

  const _StarDisplay({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: AppColors.gold,
          size: 22,
        );
      }),
    );
  }
}
