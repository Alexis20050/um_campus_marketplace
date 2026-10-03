import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_history_item.dart';
import '../providers/rating_provider.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String? transactionId;
  const TransactionHistoryScreen({super.key, this.transactionId});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late Future<List<TransactionHistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();

    _historyFuture = context.read<RatingProvider>().fetchTransactionHistory();
    if (widget.transactionId != null) {
      _openInitialTransaction();
    }
  }

  Future<void> _openInitialTransaction() async {
    try {
      final history = await _historyFuture;
      if (!mounted) return;
      final matches = history.where(
        (item) => item.transactionId == widget.transactionId,
      );
      if (matches.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDetails(matches.first);
      });
    } catch (_) {
      // The existing history error state supplies retry.
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    final future = context.read<RatingProvider>().fetchTransactionHistory();

    setState(() {
      _historyFuture = future;
    });

    await future;
  }

  // ============================================================
  // DETAILS
  // ============================================================

  Future<void> _showDetails(TransactionHistoryItem item) async {
    final action = await showModalBottomSheet<_TransactionAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TransactionDetailsSheet(item: item),
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _TransactionAction.chat) {
      if (item.conversationId.isEmpty) {
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: item.conversationId),
        ),
      );

      return;
    }

    if (action == _TransactionAction.rate) {
      await _showRatingDialog(item);
    }
  }

  // ============================================================
  // RATE SELLER
  // ============================================================

  Future<void> _showRatingDialog(TransactionHistoryItem item) async {
    int selectedRating = 5;

    bool submitting = false;

    final reviewController = TextEditingController();

    final provider = context.read<RatingProvider>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rate Seller'),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Seller: ${item.counterpartyName}',
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'How was your experience?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1;

                        return IconButton(
                          onPressed: submitting
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedRating = star;
                                  });
                                },

                          icon: Icon(
                            star <= selectedRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppColors.gold,
                            size: 34,
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: reviewController,
                      enabled: !submitting,
                      maxLength: 500,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Review (optional)',
                        hintText: 'Share your experience with the seller...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.maroon,
                    foregroundColor: Colors.white,
                  ),

                  onPressed: submitting
                      ? null
                      : () async {
                          setDialogState(() {
                            submitting = true;
                          });

                          try {
                            await provider.submitSellerRating(
                              transactionId: item.transactionId,
                              rating: selectedRating,
                              review: reviewController.text,
                            );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext, true);
                          } catch (e) {
                            if (!dialogContext.mounted) {
                              return;
                            }

                            setDialogState(() {
                              submitting = false;
                            });

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text('Could not submit rating: $e'),
                              ),
                            );
                          }
                        },

                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit Rating'),
                ),
              ],
            );
          },
        );
      },
    );

    reviewController.dispose();

    if (submitted == true && mounted) {
      await _refresh();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rating submitted successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,

      child: Scaffold(
        backgroundColor: AppColors.backgroundOf(context),

        appBar: AppBar(
          title: const Text('Transaction History'),

          backgroundColor: AppColors.maroon,

          foregroundColor: Colors.white,

          elevation: 0,

          bottom: const TabBar(
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: Icon(Icons.shopping_bag_outlined),
                text: 'My Purchases',
              ),
              Tab(icon: Icon(Icons.sell_outlined), text: 'My Sales'),
            ],
          ),
        ),

        body: FutureBuilder<List<TransactionHistoryItem>>(
          future: _historyFuture,

          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _HistoryLoading();
            }

            if (snapshot.hasError) {
              return _HistoryError(
                error: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }

            final history = snapshot.data ?? [];

            final purchases = history.where((item) => item.isPurchase).toList();

            final sales = history.where((item) => item.isSale).toList();

            return Column(
              children: [
                _HistorySummary(purchases: purchases, sales: sales),

                Expanded(
                  child: TabBarView(
                    children: [
                      _HistoryList(
                        items: purchases,
                        type: _HistoryType.purchase,
                        onRefresh: _refresh,
                        onTap: _showDetails,
                      ),

                      _HistoryList(
                        items: sales,
                        type: _HistoryType.sale,
                        onRefresh: _refresh,
                        onTap: _showDetails,
                      ),
                    ],
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

// ============================================================
// HISTORY SUMMARY
// ============================================================

class _HistorySummary extends StatelessWidget {
  final List<TransactionHistoryItem> purchases;

  final List<TransactionHistoryItem> sales;

  const _HistorySummary({required this.purchases, required this.sales});

  @override
  Widget build(BuildContext context) {
    final spent = purchases.fold<double>(
      0,
      (total, item) => total + item.amount,
    );

    final earned = sales.fold<double>(0, (total, item) => total + item.amount);

    return Container(
      margin: const EdgeInsets.all(16),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: AppColors.borderOf(context)),

        boxShadow: [
          BoxShadow(
            color: AppColors.shadowOf(context),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completed Transactions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 4),

          Text(
            '${purchases.length + sales.length} completed transaction${purchases.length + sales.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryOf(context),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Purchased',
                  value: _formatMoney(spent),
                  color: AppColors.maroon,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _SummaryMetric(
                  icon: Icons.payments_outlined,
                  label: 'Sales',
                  value: _formatMoney(earned),
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),

          const SizedBox(height: 8),

          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryOf(context),
            ),
          ),

          const SizedBox(height: 2),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HISTORY LIST
// ============================================================

enum _HistoryType { purchase, sale }

class _HistoryList extends StatelessWidget {
  final List<TransactionHistoryItem> items;

  final _HistoryType type;

  final Future<void> Function() onRefresh;

  final Future<void> Function(TransactionHistoryItem) onTap;

  const _HistoryList({
    required this.items,
    required this.type,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 90),

            _HistoryEmpty(type: type),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,

      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),

        itemCount: items.length,

        separatorBuilder: (_, __) => const SizedBox(height: 10),

        itemBuilder: (context, index) {
          final item = items[index];

          return _TransactionCard(item: item, onTap: () => onTap(item));
        },
      ),
    );
  }
}

// ============================================================
// TRANSACTION CARD
// ============================================================

class _TransactionCard extends StatelessWidget {
  final TransactionHistoryItem item;

  final VoidCallback onTap;

  const _TransactionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceOf(context),

      borderRadius: BorderRadius.circular(16),

      child: InkWell(
        borderRadius: BorderRadius.circular(16),

        onTap: onTap,

        child: Container(
          padding: const EdgeInsets.all(12),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),

            border: Border.all(color: AppColors.borderOf(context)),
          ),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductImage(imageUrl: item.productImageUrl),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _formatMoney(item.amount),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandOf(context),
                      ),
                    ),

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        Icon(
                          item.isPurchase
                              ? Icons.storefront_outlined
                              : Icons.person_outline,
                          size: 15,
                          color: AppColors.textSecondaryOf(context),
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: Text(
                            '${item.isPurchase ? 'Seller' : 'Buyer'}: ${item.counterpartyName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.textTertiaryOf(context),
                        ),

                        const SizedBox(width: 5),

                        Text(
                          _formatDate(item.completedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 9),

                    _RatingBadge(item: item),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              Icon(
                Icons.chevron_right,
                color: AppColors.textTertiaryOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCT IMAGE
// ============================================================

class _ProductImage extends StatelessWidget {
  final String? imageUrl;

  const _ProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),

      child: SizedBox(
        width: 76,
        height: 76,

        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,

                errorBuilder: (_, __, ___) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: AppColors.surfaceAltOf(context),
      child: Icon(
        Icons.shopping_bag_outlined,
        color: AppColors.textTertiaryOf(context),
        size: 30,
      ),
    );
  }
}

// ============================================================
// RATING BADGE
// ============================================================

class _RatingBadge extends StatelessWidget {
  final TransactionHistoryItem item;

  const _RatingBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    late String label;
    late Color color;
    late IconData icon;

    if (item.isRated) {
      label = item.isPurchase
          ? 'You rated ${item.rating}/5'
          : 'Buyer rated ${item.rating}/5';

      color = AppColors.gold;

      icon = Icons.star_rounded;
    } else if (item.isPurchase) {
      label = 'Rate seller';

      color = AppColors.maroon;

      icon = Icons.star_border_rounded;
    } else {
      label = 'Waiting for buyer rating';

      color = AppColors.textSecondaryOf(context);

      icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),

        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),

          const SizedBox(width: 4),

          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DETAILS SHEET
// ============================================================

enum _TransactionAction { chat, rate }

class _TransactionDetailsSheet extends StatelessWidget {
  final TransactionHistoryItem item;

  const _TransactionDetailsSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderOf(context),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductImage(imageUrl: item.productImageUrl),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        _formatMoney(item.amount),
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            _DetailRow(
              icon: item.isPurchase
                  ? Icons.storefront_outlined
                  : Icons.person_outline,
              title: item.isPurchase ? 'Seller' : 'Buyer',
              value: item.counterpartyName,
            ),

            _DetailRow(
              icon: Icons.calendar_today_outlined,
              title: 'Completed',
              value: _formatDateTime(item.completedAt),
            ),

            _DetailRow(
              icon: Icons.receipt_long_outlined,
              title: 'Transaction ID',
              value: item.transactionId,
            ),

            const SizedBox(height: 12),

            if (item.isRated)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.gold),

                        const SizedBox(width: 6),

                        Text(
                          '${item.rating}/5 Rating',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),

                    if (item.review != null) ...[
                      const SizedBox(height: 8),

                      Text(
                        item.review!,
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 20),

            if (item.isPurchase && !item.isRated)
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, _TransactionAction.rate),
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Rate Seller'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.maroon,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

            if (item.isPurchase && !item.isRated) const SizedBox(height: 10),

            if (item.conversationId.isNotEmpty)
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, _TransactionAction.chat),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Open Conversation'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DETAIL ROW
// ============================================================

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondaryOf(context)),

          const SizedBox(width: 12),

          SizedBox(
            width: 95,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _HistoryEmpty extends StatelessWidget {
  final _HistoryType type;

  const _HistoryEmpty({required this.type});

  @override
  Widget build(BuildContext context) {
    final purchase = type == _HistoryType.purchase;

    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          Icon(
            purchase ? Icons.shopping_bag_outlined : Icons.sell_outlined,
            size: 60,
            color: AppColors.textTertiaryOf(context),
          ),

          const SizedBox(height: 14),

          Text(
            purchase ? 'No purchases yet' : 'No completed sales yet',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 6),

          Text(
            purchase
                ? 'Items you purchase will appear here after the seller completes the transaction.'
                : 'Items you successfully sell will appear here after completing the sale.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ERROR
// ============================================================

class _HistoryError extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _HistoryError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: AppColors.textTertiaryOf(context),
            ),

            const SizedBox(height: 14),

            const Text(
              'Could not load transactions',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 6),

            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondaryOf(context)),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOADING
// ============================================================

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),

      itemCount: 5,

      itemBuilder: (context, index) {
        return Container(
          height: 105,

          margin: const EdgeInsets.only(bottom: 12),

          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),

            borderRadius: BorderRadius.circular(16),

            border: Border.all(color: AppColors.borderOf(context)),
          ),

          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

// ============================================================
// FORMATTERS
// ============================================================

String _formatMoney(double amount) {
  final parts = amount.toStringAsFixed(2).split('.');

  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );

  return '₱$whole.${parts.last}';
}

String _formatDate(DateTime value) {
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

String _formatDateTime(DateTime value) {
  final date = value.toLocal();

  var hour = date.hour;

  final period = hour >= 12 ? 'PM' : 'AM';

  if (hour == 0) {
    hour = 12;
  } else if (hour > 12) {
    hour -= 12;
  }

  final minute = date.minute.toString().padLeft(2, '0');

  return '${_formatDate(date)} • $hour:$minute $period';
}
