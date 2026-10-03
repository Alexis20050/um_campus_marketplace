import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/admin_data.dart';
import '../widgets/admin_widgets.dart';
import 'admin_listing_detail_screen.dart';

class AdminListingsScreen extends StatefulWidget {
  final String? userId;
  final String initialSearch;
  const AdminListingsScreen({super.key, this.userId, this.initialSearch = ''});
  @override
  State<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends State<AdminListingsScreen> {
  late final _controller = TextEditingController(text: widget.initialSearch);
  Timer? _debounce;
  late String _search = widget.initialSearch;
  String _status = 'all';
  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: widget.userId == null ? 'Listings' : 'User Listings',
    subtitle: 'Review and manage marketplace products',
    search: AdminSearchField(
      controller: _controller,
      hint: 'Search listing, seller name or email',
      onChanged: (value) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 350), () {
          if (mounted) setState(() => _search = value.trim());
        });
      },
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
                  'reserved',
                  'sold',
                  'archived',
                  'hidden',
                ],
                selected: _status,
                onSelected: (value) => setState(() => _status = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: AdminDataView<List<Map<String, dynamic>>>(
            errorTitle: 'Unable to load listings',
            requestKey: (widget.userId, _status, _search),
            load: (provider) async {
              if (widget.userId == null) {
                return provider.fetchListings(status: _status, search: _search);
              }
              final rows = await provider.fetchUserListings(widget.userId!);
              return rows
                  .where(
                    (row) =>
                        adminListingMatches(row, _status) &&
                        ['title', 'seller_name', 'seller_email'].any(
                          (field) => adminText(
                            row,
                            field,
                            '',
                          ).toLowerCase().contains(_search.toLowerCase()),
                        ),
                  )
                  .toList();
            },
            builder: (context, rows) {
              if (rows.isEmpty) {
                return const AdminEmpty(
                  'No listings found for this search or filter.',
                  title: 'No listings found',
                  icon: Icons.inventory_2_outlined,
                );
              }
              void open(Map<String, dynamic> row) {
                final id = adminText(row, 'product_id|id', '');
                if (id.isEmpty) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminListingDetailScreen(productId: id),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final table =
                      constraints.maxWidth >= 950 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 18;
                  if (!table) {
                    return AdminCollection(
                      itemCount: rows.length,
                      itemBuilder: (context, index) => AdminListingCard(
                        row: rows[index],
                        onTap: () => open(rows[index]),
                      ),
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: rows.length + 1,
                    itemBuilder: (context, index) => index == 0
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                            child: Row(
                              children: const [
                                Expanded(flex: 4, child: Text('LISTING')),
                                Expanded(flex: 2, child: Text('SELLER')),
                                Expanded(flex: 2, child: Text('PRICE')),
                                Expanded(flex: 2, child: Text('MARKETPLACE')),
                                Expanded(flex: 2, child: Text('MODERATION')),
                                Expanded(child: Text('REPORTS')),
                                Expanded(flex: 2, child: Text('CREATED')),
                                SizedBox(width: 20),
                              ],
                            ),
                          )
                        : AdminListingTableRow(
                            row: rows[index - 1],
                            onTap: () => open(rows[index - 1]),
                          ),
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
