import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../theme/app_theme.dart';
import '../utils/admin_data.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/seller_rating_section.dart';
import 'admin_reports_screen.dart';
import 'admin_user_detail_screen.dart';

class AdminListingDetailScreen extends StatelessWidget {
  final String productId;
  const AdminListingDetailScreen({super.key, required this.productId});
  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Listing Detail',
    subtitle: 'Product information, seller and moderation history',
    body: AdminDataView<Map<String, dynamic>>(
      requestKey: productId,
      errorTitle: 'Unable to load listing',
      load: (provider) => provider.fetchListingDetail(productId),
      builder: (context, row) {
        final provider = context.read<AdminProvider>();
        final hidden = row['moderation_status'] == 'hidden';
        final sellerId = adminText(row, 'seller_id', '');
        final title = adminText(row, 'title');
        final gallery = _ListingGallery(
          key: ValueKey(productId),
          images: adminImages(row),
        );
        final product = AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                adminPrice(row['price']),
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  AdminChip(adminMarketplaceStatus(row)),
                  AdminChip(adminVisibility(row)),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: AppColors.borderOf(context)),
              const AdminSectionHeader('Description'),
              Text(adminText(row, 'description', 'No description provided.')),
            ],
          ),
        );
        final information = AdminSection('Product information', {
          'Category': adminText(row, 'category'),
          'Condition': adminText(row, 'item_condition'),
          'Posted': adminDate(row['created_at']),
        });
        final seller = AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminSectionHeader(
                'Seller',
                subtitle: 'Account behind this listing',
              ),
              Row(
                children: [
                  AdminUserAvatar(
                    name: adminText(row, 'seller_name'),
                    imageUrl: adminText(row, 'seller_avatar_url', ''),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminText(row, 'seller_name'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          adminText(row, 'seller_email'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  AdminChip(adminText(row, 'seller_role')),
                  AdminChip(adminText(row, 'seller_account_status')),
                ],
              ),
              const SizedBox(height: 12),
              if (sellerId.isNotEmpty)
                SellerRatingSection(sellerId: sellerId, compact: true),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: sellerId.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AdminUserDetailScreen(userId: sellerId),
                        ),
                      ),
                icon: const Icon(Icons.person_outline),
                label: const Text('View Seller Profile'),
              ),
            ],
          ),
        );
        final reservation = adminText(row, 'reserved_by', '').isEmpty
            ? null
            : AdminSection('Reservation', {
                'Buyer': adminText(row, 'reserved_buyer_name|reserved_by_name'),
                'Email': adminText(
                  row,
                  'reserved_buyer_email|reserved_by_email',
                ),
                'Conversation ID': adminText(row, 'reserved_conversation_id'),
                'Reserved date': adminDate(row['reserved_at']),
              });
        final reports = AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminSectionHeader(
                'Reports',
                subtitle: 'Concerns raised about this listing',
              ),
              Text(
                '${adminText(row, 'report_count|reports_count')} reports about this listing',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminReportsScreen(productId: productId),
                  ),
                ),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('View Reports'),
              ),
            ],
          ),
        );
        final moderation = AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminSectionHeader(
                'Moderation actions',
                subtitle: 'Control public visibility',
              ),
              AdminActionButton(
                label: hidden ? 'Restore Listing' : 'Hide Listing',
                title: '${hidden ? 'Restore' : 'Hide'} $title?',
                destructive: !hidden,
                successMessage: hidden
                    ? 'Listing restored.'
                    : 'Listing hidden.',
                message: hidden
                    ? 'It will become visible again if its marketplace status allows it. Its sale and reservation state will be kept.'
                    : 'This listing will no longer appear in the public marketplace. Its history will be kept.',
                action: () => provider.setListingVisibility(
                  productId: productId,
                  status: hidden ? 'active' : 'hidden',
                ),
              ),
            ],
          ),
        );
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 870 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 19;
                if (!wide) {
                  return Column(
                    children: [
                      gallery,
                      product,
                      information,
                      seller,
                      if (reservation != null) reservation,
                      reports,
                      moderation,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(children: [gallery, product, information]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          seller,
                          if (reservation != null) reservation,
                          reports,
                          moderation,
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    ),
  );
}

class _ListingGallery extends StatefulWidget {
  final List<String> images;
  const _ListingGallery({super.key, required this.images});
  @override
  State<_ListingGallery> createState() => _ListingGalleryState();
}

class _ListingGalleryState extends State<_ListingGallery> {
  final _controller = PageController();
  int _index = 0;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ListingGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.join('|') != widget.images.join('|')) {
      _index = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPanel(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: widget.images.isEmpty
                ? const AdminImage()
                : PageView.builder(
                    controller: _controller,
                    itemCount: widget.images.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (_, index) => AdminImage(
                      url: widget.images[index],
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
        ),
        if (widget.images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous image',
                  onPressed: _index == 0
                      ? null
                      : () => _controller.previousPage(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                        ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${_index + 1} / ${widget.images.length}',
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                ),
                IconButton(
                  tooltip: 'Next image',
                  onPressed: _index == widget.images.length - 1
                      ? null
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                        ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
