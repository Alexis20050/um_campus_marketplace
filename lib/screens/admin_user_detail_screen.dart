import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../utils/admin_data.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/seller_rating_section.dart';
import 'admin_listing_detail_screen.dart';
import 'admin_listings_screen.dart';
import 'admin_reports_screen.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final String userId;
  const AdminUserDetailScreen({super.key, required this.userId});
  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'User Profile',
    subtitle: 'Account activity, seller reputation and moderation',
    body:
        AdminDataView<
          ({
            Map<String, dynamic> profile,
            List<Map<String, dynamic>> listings,
            Object? listingError,
          })
        >(
          requestKey: userId,
          errorTitle: 'Unable to load user profile',
          load: (provider) async {
            Object? listingError;
            final listings = provider.fetchUserListings(userId).catchError((
              Object error,
            ) {
              listingError = error;
              debugPrint('User listing preview failed: $error');
              return <Map<String, dynamic>>[];
            });
            final profile = await provider.fetchUserDetail(userId);
            return (
              profile: profile,
              listings: await listings,
              listingError: listingError,
            );
          },
          builder: (context, data) {
            final row = data.profile;
            final provider = context.read<AdminProvider>();
            final suspended = row['account_status'] == 'suspended';
            final name = adminText(row, 'name|user_name');
            void listings() => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AdminListingsScreen(userId: userId),
              ),
            );
            void reports() => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AdminReportsScreen(userId: userId),
              ),
            );
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                AdminPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminUserAvatar(
                            name: name,
                            imageUrl: adminText(
                              row,
                              'avatar_url|profile_image_url',
                              '',
                            ),
                            radius: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  adminText(row, 'email'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    AdminChip(adminText(row, 'role')),
                                    AdminChip(adminText(row, 'account_status')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          Text(
                            'Joined ${adminDate(adminValue(row, 'created_at|joined_at'))}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: listings,
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('View Listings'),
                          ),
                          OutlinedButton.icon(
                            onPressed: reports,
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('View Reports'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SellerRatingSection(sellerId: userId),
                const AdminSectionHeader('Marketplace activity'),
                AdminGrid(
                  minWidth: 155,
                  maxColumns: 5,
                  children: [
                    for (final status in [
                      'active',
                      'reserved',
                      'sold',
                      'archived',
                      'hidden',
                    ])
                      AdminPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AdminChip(status),
                            const SizedBox(height: 12),
                            Text(
                              adminText(
                                row,
                                '${status}_listings|${status}_listing_count',
                              ),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                AdminGrid(
                  minWidth: 280,
                  maxColumns: 2,
                  children: [
                    AdminSection('Transactions', {
                      'Completed sales': adminText(
                        row,
                        'completed_sales|completed_sales_count',
                      ),
                      'Purchases': adminText(
                        row,
                        'purchases|completed_purchases|purchase_count',
                      ),
                    }),
                    AdminSection('Moderation signals', {
                      'Reports received': adminText(
                        row,
                        'reports_received|reports_received_count',
                      ),
                      'Reports submitted': adminText(
                        row,
                        'reports_submitted|reports_submitted_count',
                      ),
                    }),
                  ],
                ),
                AdminSectionHeader(
                  'User listings',
                  subtitle: 'Recent marketplace listings',
                  action: TextButton(
                    onPressed: listings,
                    child: const Text('View All'),
                  ),
                ),
                if (data.listingError != null)
                  AdminPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Unable to load listing preview.'),
                        TextButton(
                          onPressed: listings,
                          child: const Text('Open Listings'),
                        ),
                      ],
                    ),
                  )
                else if (data.listings.isEmpty)
                  const AdminPanel(
                    child: AdminEmpty(
                      'This user has no listings.',
                      scrollable: false,
                    ),
                  )
                else ...[
                  for (final listing
                      in (List<Map<String, dynamic>>.of(data.listings)..sort(
                            (a, b) => adminText(
                              b,
                              'created_at',
                              '',
                            ).compareTo(adminText(a, 'created_at', '')),
                          ))
                          .take(3))
                    AdminListingCard(
                      row: listing,
                      onTap: () {
                        final id = adminText(listing, 'product_id|id', '');
                        if (id.isNotEmpty) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AdminListingDetailScreen(productId: id),
                            ),
                          );
                        }
                      },
                    ),
                ],
                const AdminSectionHeader(
                  'Moderation actions',
                  subtitle: 'Control this account’s marketplace access',
                ),
                AdminPanel(
                  child: AdminActionButton(
                    label: suspended ? 'Restore User' : 'Suspend User',
                    title: '${suspended ? 'Restore' : 'Suspend'} $name?',
                    destructive: !suspended,
                    successMessage: suspended
                        ? 'User restored.'
                        : 'User suspended.',
                    message: suspended
                        ? 'This user will regain access to protected marketplace actions.'
                        : 'This user will lose access to protected marketplace actions until the account is restored.',
                    disabledReason: provider.userStatusRestriction(
                      userId,
                      row['role']?.toString(),
                    ),
                    action: () => provider.setUserStatus(
                      userId: userId,
                      status: suspended ? 'active' : 'suspended',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
  );
}
