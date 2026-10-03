import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/rating_provider.dart';
import '../theme/app_theme.dart';

class SellerRatingSection extends StatelessWidget {
  final String sellerId;
  final bool compact;

  const SellerRatingSection({
    super.key,
    required this.sellerId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    context.select<RatingProvider, int>((provider) => provider.ratingsRevision);
    final provider = context.read<RatingProvider>();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: provider.sellerRatingsStream(sellerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (compact) return const Text('Loading rating…');
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          if (compact) return const Text('Rating unavailable');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Could not load seller ratings.',
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                ),
              ),
            ),
          );
        }

        final ratings = snapshot.data ?? [];

        if (ratings.isEmpty) {
          if (compact) return const Text('No ratings yet');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.star_border_rounded,
                      color: AppColors.textTertiaryOf(context),
                    ),

                    const SizedBox(width: 10),

                    Text(
                      'No seller ratings yet',
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        double total = 0;

        for (final row in ratings) {
          total += (row['rating'] as num).toDouble();
        }

        final average = total / ratings.length;

        if (compact) {
          return Text(
            '${average.toStringAsFixed(1)} / 5 (${ratings.length} ${ratings.length == 1 ? 'rating' : 'ratings'})',
          );
        }

        final recentReviews = ratings
            .where((row) {
              final review = row['review']?.toString().trim() ?? '';

              return review.isNotEmpty;
            })
            .take(3)
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seller Rating',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Text(
                        average.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: _AverageStars(average: average),
                            ),

                            const SizedBox(height: 3),

                            Text(
                              '${ratings.length} ${ratings.length == 1 ? 'rating' : 'ratings'}',
                              style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (recentReviews.isNotEmpty) ...[
                    const SizedBox(height: 16),

                    Divider(color: AppColors.borderOf(context)),

                    const SizedBox(height: 8),

                    const Text(
                      'Recent Reviews',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 10),

                    ...recentReviews.map((row) {
                      final rating = (row['rating'] as num).toInt();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                _SmallStars(rating: rating),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.verified_outlined,
                                      size: 14,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        'Verified Purchase',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondaryOf(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 5),

                            Text(
                              row['review'].toString(),
                              style: TextStyle(
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AverageStars extends StatelessWidget {
  final double average;

  const _AverageStars({required this.average});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final threshold = index + 1;

        return Icon(
          average >= threshold - 0.5
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          size: 20,
          color: AppColors.gold,
        );
      }),
    );
  }
}

class _SmallStars extends StatelessWidget {
  final int rating;

  const _SmallStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 15,
          color: AppColors.gold,
        );
      }),
    );
  }
}
