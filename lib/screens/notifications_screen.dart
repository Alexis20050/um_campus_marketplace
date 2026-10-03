import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';
import '../providers/product_provider.dart';
import '../providers/message_provider.dart';
import '../providers/rating_provider.dart';
import 'chat_screen.dart';
import 'product_detail_screen.dart';
import 'transaction_history_screen.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _opening = false;

  Future<void> _open(Map<String, dynamic> item) async {
    if (_opening) return;
    final notifications = context.read<NotificationProvider>();
    final products = context.read<ProductProvider>();
    final messages = context.read<MessageProvider>();
    final ratings = context.read<RatingProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _opening = true);
    try {
      await notifications.markAsRead(item['id'].toString());
      final transactionId = item['transaction_id']?.toString();
      final productId = item['product_id']?.toString();
      final conversationId = item['conversation_id']?.toString();
      Widget? destination;
      if (transactionId != null && transactionId.isNotEmpty) {
        final history = await ratings.fetchTransactionHistory();
        if (history.any((row) => row.transactionId == transactionId)) {
          destination = TransactionHistoryScreen(transactionId: transactionId);
        }
      } else if (item['type'] == 'sale_completed' ||
          item['type'] == 'seller_rated') {
        destination = const TransactionHistoryScreen();
      }
      if (destination == null && productId != null && productId.isNotEmpty) {
        final product = await products.fetchProductById(productId);
        if (product != null && !product.isHidden && !product.isArchived) {
          destination = ProductDetailScreen(product: product);
        }
      }
      if (destination == null &&
          conversationId != null &&
          conversationId.isNotEmpty) {
        await messages.fetchConversation(conversationId);
        destination = ChatScreen(conversationId: conversationId);
      }
      if (!mounted) return;
      if (destination != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destination!),
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(item['title']?.toString() ?? 'Notification'),
            content: Text(
              '${item['body'] ?? ''}\n\nRelated content is no longer available.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open this notification. The content may be unavailable; please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(value.toString())?.toLocal();

    if (date == null) {
      return '';
    }

    final now = DateTime.now();

    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

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

  IconData _iconForType(String? type) {
    switch (type) {
      case 'reservation_created':
        return Icons.bookmark_added_rounded;

      case 'reservation_cancelled':
        return Icons.bookmark_remove_rounded;

      case 'sale_completed':
        return Icons.shopping_bag_rounded;

      case 'seller_rated':
        return Icons.star_rounded;

      case 'report_reviewed':
        return Icons.verified_user_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'reservation_created':
        return AppColors.gold;

      case 'reservation_cancelled':
        return Colors.orange;

      case 'sale_completed':
        return AppColors.success;

      case 'seller_rated':
        return AppColors.gold;

      case 'report_reviewed':
        return AppColors.maroon;

      default:
        return AppColors.maroon;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    final notifications = provider.notifications;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        bottom: _opening
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await provider.markAllAsRead();
                } catch (_) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not mark notifications read. Please try again.',
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Read all',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: notifications.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 150),
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 72,
                    color: AppColors.textTertiaryOf(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reservation, transaction, rating, and moderation updates will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondaryOf(context)),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 76,
                  color: AppColors.borderOf(context),
                ),
                itemBuilder: (context, index) {
                  final item = notifications[index];

                  final unread = item['is_read'] != true;

                  final type = item['type']?.toString();

                  final color = _colorForType(type);

                  return Material(
                    color: unread
                        ? AppColors.brandSoftOf(context).withValues(alpha: 0.55)
                        : Colors.transparent,
                    child: InkWell(
                      onTap: _opening ? null : () => _open(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 23,
                              backgroundColor: color.withValues(alpha: 0.14),
                              child: Icon(_iconForType(type), color: color),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['title']?.toString() ??
                                              'Notification',
                                          style: TextStyle(
                                            fontWeight: unread
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      if (unread)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.maroon,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    item['body']?.toString() ?? '',
                                    style: TextStyle(
                                      color: AppColors.textSecondaryOf(context),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    _formatDate(item['created_at']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiaryOf(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
