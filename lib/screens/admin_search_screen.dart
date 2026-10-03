import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/admin_data.dart';
import '../widgets/admin_widgets.dart';
import 'admin_listing_detail_screen.dart';
import 'admin_listings_screen.dart';
import 'admin_user_detail_screen.dart';
import 'admin_users_screen.dart';

/// Searches the existing admin RPCs without adding a separate search service.
class AdminSearchScreen extends StatefulWidget {
  const AdminSearchScreen({super.key});

  @override
  State<AdminSearchScreen> createState() => _AdminSearchScreenState();
}

class _AdminSearchScreenState extends State<AdminSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Search',
    subtitle: 'Find accounts and marketplace listings',
    refreshable: false,
    showGlobalSearch: false,
    search: AdminSearchField(
      controller: _controller,
      hint: 'Search users, listings, or sellers',
      onChanged: _changed,
    ),
    body: _query.isEmpty
        ? const AdminEmpty(
            'Enter a name, email, listing title, or seller to start.',
            title: 'Search the marketplace',
            icon: Icons.search,
          )
        : AdminDataView<
            ({
              List<Map<String, dynamic>> users,
              List<Map<String, dynamic>> listings,
            })
          >(
            requestKey: _query,
            errorTitle: 'Unable to search the marketplace',
            load: (provider) async {
              final users = provider.fetchUsers(search: _query);
              final listings = provider.fetchListings(
                status: 'all',
                search: _query,
              );
              return (users: await users, listings: await listings);
            },
            builder: (context, data) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                AdminSectionHeader(
                  'Users · ${data.users.length}',
                  action: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminUsersScreen(initialSearch: _query),
                      ),
                    ),
                    child: const Text('View all'),
                  ),
                ),
                if (data.users.isEmpty)
                  const AdminPanel(
                    child: AdminEmpty(
                      'No users matched this search.',
                      scrollable: false,
                      icon: Icons.people_outline,
                    ),
                  )
                else
                  for (final row in data.users.take(5))
                    AdminPanel(
                      onTap: () {
                        final id = adminText(row, 'user_id|id', '');
                        if (id.isNotEmpty) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AdminUserDetailScreen(userId: id),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          AdminUserAvatar(
                            name: adminText(row, 'name|user_name'),
                            radius: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  adminText(row, 'name|user_name'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  adminText(row, 'email'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          AdminChip(adminText(row, 'account_status')),
                        ],
                      ),
                    ),
                AdminSectionHeader(
                  'Listings · ${data.listings.length}',
                  action: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AdminListingsScreen(initialSearch: _query),
                      ),
                    ),
                    child: const Text('View all'),
                  ),
                ),
                if (data.listings.isEmpty)
                  const AdminPanel(
                    child: AdminEmpty(
                      'No listings matched this search.',
                      scrollable: false,
                      icon: Icons.inventory_2_outlined,
                    ),
                  )
                else
                  for (final row in data.listings.take(5))
                    AdminListingCard(
                      row: row,
                      onTap: () {
                        final id = adminText(row, 'product_id|id', '');
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
            ),
          ),
  );
}
