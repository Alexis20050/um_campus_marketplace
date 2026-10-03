import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';

import '../providers/admin_provider.dart';
import '../providers/auth_service.dart';
import '../providers/favorites_provider.dart';
import '../providers/product_provider.dart';
import '../providers/theme_provider.dart';

import '../theme/app_theme.dart';

import '../widgets/stat_card.dart';
import '../widgets/seller_rating_section.dart';
import '../widgets/theme_picker_sheet.dart';

import 'admin_dashboard_screen.dart';
import 'change_password_screen.dart';
import 'favorites_screen.dart';
import 'my_listings_screen.dart';
import 'transaction_history_screen.dart';
import 'user_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();

  late Future<bool> _isStaffFuture;

  bool _staffCheckInitialized = false;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_staffCheckInitialized) {
      _staffCheckInitialized = true;

      _isStaffFuture = context.read<AdminProvider>().isStaff();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();

    super.dispose();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _displayNameFromEmail(String? email) {
    if (email == null || !email.contains('@')) {
      return 'UM Student';
    }

    final localPart = email.split('@').first;

    final words = localPart.split(RegExp(r'[._]+'));

    final result = words
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');

    return result.isEmpty ? 'UM Student' : result;
  }

  String _formatJoinDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(isoDate);

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

      return '${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return '';
    }
  }

  // ============================================================
  // EDIT NAME
  // ============================================================

  Future<void> _editName(AuthService authService, String currentName) async {
    _nameController.text = currentName;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              hintText: 'e.g., Juan Dela Cruz',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maroon,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, _nameController.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null || result.trim().isEmpty) {
      return;
    }

    try {
      await authService.updateProfileName(result.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> _confirmSignOut(
    BuildContext context,
    AuthService authService,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You\'ll need to sign in again to buy or sell items.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    if (context.mounted) {
      context.read<FavoritesProvider>().clear();
    }

    await authService.signOut();
  }

  // ============================================================
  // REFRESH STAFF STATUS
  // ============================================================

  void _refreshStaffStatus() {
    setState(() {
      _isStaffFuture = context.read<AdminProvider>().isStaff(refresh: true);
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    final user = authService.user;

    final profileName = authService.profileName;

    final displayName = profileName != null && profileName.trim().isNotEmpty
        ? profileName.trim()
        : _displayNameFromEmail(user?.email);

    final joinDate = _formatJoinDate(user?.createdAt);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),

      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        elevation: 0,

        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Preview public profile',
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      userId: user.id,
                      initialName: displayName,
                      initialEmail: user.email ?? '',
                    ),
                  ),
                );
              },
            ),
        ],
      ),

      body: user == null
          ? const Center(child: Text('No user'))
          : RefreshIndicator(
              onRefresh: () async {
                _refreshStaffStatus();

                await _isStaffFuture;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  const SizedBox(height: 16),

                  // =========================================
                  // PROFILE HEADER
                  // =========================================
                  _buildHeader(
                    displayName: displayName,
                    email: user.email ?? '',
                    joinDate: joinDate,
                    onEditName: () => _editName(authService, displayName),
                  ),

                  const SizedBox(height: 16),

                  // =========================================
                  // STATS
                  // =========================================
                  _StatsRow(userId: user.id),

                  const SizedBox(height: 16),

                  SellerRatingSection(sellerId: user.id),

                  const SizedBox(height: 24),

                  // =========================================
                  // MY ACTIVITY
                  // =========================================
                  _sectionLabel('My Activity'),

                  const SizedBox(height: 8),

                  _menuCard(
                    children: [
                      // Favorites
                      _menuTile(
                        icon: Icons.favorite,
                        iconColor: Colors.red,
                        title: 'My Favorites',
                        subtitle: 'Items you\'ve saved',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FavoritesScreen(),
                            ),
                          );
                        },
                      ),

                      Divider(
                        height: 1,
                        indent: 72,
                        color: AppColors.borderOf(context),
                      ),

                      // Listings
                      _menuTile(
                        icon: Icons.list_alt,
                        iconColor: AppColors.maroon,
                        title: 'My Listings',
                        subtitle: 'Manage everything you\'ve posted',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyListingsScreen(),
                            ),
                          );
                        },
                      ),

                      Divider(
                        height: 1,
                        indent: 72,
                        color: AppColors.borderOf(context),
                      ),

                      // Transaction history
                      _menuTile(
                        icon: Icons.receipt_long_outlined,
                        iconColor: AppColors.maroon,
                        title: 'Transaction History',
                        subtitle: 'View your purchases and completed sales',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TransactionHistoryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // =========================================
                  // ADMINISTRATION
                  // Only rendered for staff.
                  // =========================================
                  FutureBuilder<bool>(
                    future: _isStaffFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      }

                      if (snapshot.data != true) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Administration'),

                          const SizedBox(height: 8),

                          _menuCard(
                            children: [
                              _menuTile(
                                icon: Icons.admin_panel_settings_outlined,
                                iconColor: AppColors.maroon,
                                title: 'Admin Dashboard',
                                subtitle:
                                    'Review reports and manage marketplace moderation',
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminDashboardScreen(),
                                    ),
                                  );

                                  if (!mounted) {
                                    return;
                                  }

                                  _refreshStaffStatus();
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),

                  // =========================================
                  // ACCOUNT SECURITY
                  // =========================================
                  _sectionLabel('Account Security'),

                  const SizedBox(height: 8),

                  _menuCard(
                    children: [
                      _menuTile(
                        icon: Icons.lock_outline,
                        iconColor: AppColors.maroon,
                        title: 'Change Password',
                        subtitle: 'Update your account password',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChangePasswordScreen(),
                            ),
                          );
                        },
                      ),

                      Divider(
                        height: 1,
                        indent: 72,
                        color: AppColors.borderOf(context),
                      ),

                      _menuTile(
                        icon: Icons.logout,
                        iconColor: Colors.red,
                        title: 'Sign Out',
                        titleColor: Colors.red,
                        subtitle: 'Log out of your account',
                        onTap: () => _confirmSignOut(context, authService),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // =========================================
                  // APPEARANCE
                  // =========================================
                  _sectionLabel('Appearance'),

                  const SizedBox(height: 8),

                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
                      final String subtitle;

                      if (themeProvider.isDark) {
                        subtitle = 'Dark';
                      } else if (themeProvider.isLight) {
                        subtitle = 'Light';
                      } else {
                        subtitle = 'System default';
                      }

                      return _menuCard(
                        children: [
                          _menuTile(
                            icon: Icons.palette_outlined,
                            iconColor: AppColors.maroon,
                            title: 'Appearance',
                            subtitle: subtitle,
                            onTap: () => ThemePickerSheet.show(context),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  Center(
                    child: Text(
                      'UM Campus Marketplace',
                      style: TextStyle(
                        color: AppColors.textTertiaryOf(context),
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader({
    required String displayName,
    required String email,
    required String joinDate,
    required VoidCallback onEditName,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.brandSoftOf(context),
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandOf(context),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              if (joinDate.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoftOf(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Member since $joinDate',
                    style: TextStyle(
                      color: AppColors.brandOf(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: onEditName,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit Name'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandOf(context),
                  side: BorderSide(color: AppColors.brandOf(context)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION LABEL
  // ============================================================

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondaryOf(context),
        ),
      ),
    );
  }

  // ============================================================
  // MENU CARD
  // ============================================================

  Widget _menuCard({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  // ============================================================
  // MENU TILE
  // ============================================================

  Widget _menuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.12),
        radius: 22,
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondaryOf(context),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// ============================================================
// STATS ROW
// ============================================================

class _StatsRow extends StatefulWidget {
  final String userId;

  const _StatsRow({required this.userId});

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  late final Stream<List<Product>> _stream;

  @override
  void initState() {
    super.initState();

    final productProvider = context.read<ProductProvider>();

    _stream = productProvider.sellerProductsStream(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<List<Product>>(
        stream: _stream,
        builder: (context, snapshot) {
          final products = snapshot.data ?? [];

          final activeCount = products
              .where((product) => !product.isSold)
              .length;

          final soldCount = products.where((product) => product.isSold).length;

          final waiting = snapshot.connectionState == ConnectionState.waiting;

          return Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Active Listings',
                  value: waiting ? '—' : '$activeCount',
                  icon: Icons.storefront,
                  color: AppColors.brandOf(context),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: StatCard(
                  label: 'Items Sold',
                  value: waiting ? '—' : '$soldCount',
                  icon: Icons.sell,
                  color: Colors.green,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
