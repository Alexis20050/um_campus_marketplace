import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/admin_data.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/seller_rating_section.dart';
import 'admin_user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  final String initialSearch;
  const AdminUsersScreen({super.key, this.initialSearch = ''});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late final _controller = TextEditingController(text: widget.initialSearch);
  Timer? _debounce;
  late String _search = widget.initialSearch;
  String _filter = 'all';
  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Users',
    subtitle: 'Manage marketplace accounts and moderation status',
    search: AdminSearchField(
      controller: _controller,
      hint: 'Search users by name or email',
      onChanged: _searchChanged,
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            children: [
              AdminFilters(
                values: const [
                  'all',
                  'active',
                  'suspended',
                  'users',
                  'moderators',
                  'admins',
                ],
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: AdminDataView<List<Map<String, dynamic>>>(
            requestKey: _search,
            errorTitle: 'Unable to load users',
            load: (provider) => provider.fetchUsers(search: _search),
            builder: (context, rows) {
              final filtered = rows
                  .where(
                    (row) => switch (_filter) {
                      'active' ||
                      'suspended' => row['account_status'] == _filter,
                      'users' => row['role'] == 'user',
                      'moderators' => row['role'] == 'moderator',
                      'admins' => row['role'] == 'admin',
                      _ => true,
                    },
                  )
                  .toList();
              if (filtered.isEmpty) {
                return const AdminEmpty(
                  'No users matched your search or filter.',
                  title: 'No users found',
                  icon: Icons.people_outline,
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final table =
                      constraints.maxWidth >= 1050 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 18;
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${filtered.length} accounts',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              if (table)
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 4, child: Text('USER')),
                                      Expanded(flex: 2, child: Text('ROLE')),
                                      Expanded(flex: 2, child: Text('STATUS')),
                                      Expanded(child: Text('ACTIVE')),
                                      Expanded(child: Text('SALES')),
                                      Expanded(child: Text('REPORTS')),
                                      Expanded(child: Text('RATING')),
                                      Expanded(flex: 2, child: Text('JOINED')),
                                      SizedBox(width: 20),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }
                      final row = filtered[index - 1];
                      final id = adminText(row, 'user_id|id', '');
                      final identity = Row(
                        children: [
                          AdminUserAvatar(
                            name: adminText(row, 'name|user_name'),
                            imageUrl: adminText(
                              row,
                              'avatar_url|profile_image_url',
                              '',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  adminText(row, 'name|user_name'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  adminText(row, 'email'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      return AdminPanel(
                        padding: const EdgeInsets.all(16),
                        onTap: id.isEmpty
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      AdminUserDetailScreen(userId: id),
                                ),
                              ),
                        child: table
                            ? Row(
                                children: [
                                  Expanded(flex: 4, child: identity),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: AdminChip(adminText(row, 'role')),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: AdminChip(
                                        adminText(row, 'account_status'),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      adminText(
                                        row,
                                        'active_listings|active_listing_count',
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      adminText(
                                        row,
                                        'completed_sales|completed_sales_count',
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      adminText(
                                        row,
                                        'reports_received|reports_received_count',
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: SellerRatingSection(
                                      sellerId: adminText(
                                        row,
                                        'user_id|id',
                                        '',
                                      ),
                                      compact: true,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      adminDate(
                                        adminValue(row, 'created_at|joined_at'),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 20),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  identity,
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      AdminChip(adminText(row, 'role')),
                                      AdminChip(
                                        adminText(row, 'account_status'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 6,
                                    children: [
                                      Text(
                                        '${adminText(row, 'active_listings|active_listing_count')} active listings',
                                      ),
                                      Text(
                                        '${adminText(row, 'reports_received|reports_received_count')} reports',
                                      ),
                                      SellerRatingSection(
                                        sellerId: adminText(
                                          row,
                                          'user_id|id',
                                          '',
                                        ),
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Joined ${adminDate(adminValue(row, 'created_at|joined_at'))}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
