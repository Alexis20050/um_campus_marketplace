import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_service.dart';
import '../providers/product_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/theme_picker_sheet.dart';
import 'my_listings_screen.dart';
import 'favorites_screen.dart';
import 'change_password_screen.dart';
import 'user_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // HELPERS
  // ────────────────────────────────────────────────────────────
  String _displayNameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return 'UM Student';
    final localPart = email.split('@').first;
    final words = localPart.split(RegExp(r'[._]+'));
    return words
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _formatJoinDate(String? isoDate) {
    if (isoDate == null) return '';
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

  // ────────────────────────────────────────────────────────────
  // ACTIONS
  // ────────────────────────────────────────────────────────────
  Future<void> _editName(AuthService authService, String currentName) async {
    _nameController.text = currentName;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.maroon,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, _nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await authService.updateProfileName(result);
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
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    AuthService authService,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You\'ll need to sign in again to buy or sell items.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (context.mounted) {
        context.read<FavoritesProvider>().clear();
      }
      await authService.signOut();
    }
  }

  // ────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    final displayName = (authService.profileName?.isNotEmpty ?? false)
        ? authService.profileName!
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
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                const SizedBox(height: 16),

                // ── Header card ────────────────────────────────
                _buildHeader(
                  displayName: displayName,
                  email: user.email ?? '',
                  joinDate: joinDate,
                  onEditName: () => _editName(authService, displayName),
                ),

                const SizedBox(height: 16),

                // ── Stats ──────────────────────────────────────
                _StatsRow(userId: user.id),

                const SizedBox(height: 24),

                // ── My Activity ────────────────────────────────
                _sectionLabel('My Activity'),
                const SizedBox(height: 8),
                _menuCard(
                  children: [
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
                  ],
                ),

                const SizedBox(height: 24),

                // ── Account Security ───────────────────────────
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

                // ── Appearance ─────────────────────────────────
                _sectionLabel('Appearance'),
                const SizedBox(height: 8),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    final subtitle = themeProvider.isDark
                        ? 'Dark'
                        : themeProvider.isLight
                        ? 'Light'
                        : 'System default';
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
              ],
            ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // HEADER
  // ────────────────────────────────────────────────────────────
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

  // ────────────────────────────────────────────────────────────
  // REUSABLE WIDGETS
  // ────────────────────────────────────────────────────────────
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
        backgroundColor: iconColor.withOpacity(0.12),
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

// ─────────────────────────────────────────────────────────────
// ISOLATED STATS ROW
// ─────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final String userId;
  const _StatsRow({required this.userId});

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<List<Product>>(
        stream: productProvider.sellerProductsStream(userId),
        builder: (context, snapshot) {
          final products = snapshot.data ?? [];
          final activeCount = products.where((p) => !p.isSold).length;
          final soldCount = products.where((p) => p.isSold).length;
          final waiting = snapshot.connectionState == ConnectionState.waiting;

          return Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Active Listings',
                  value: waiting ? '—' : '$activeCount',
                  icon: Icons.storefront,
                  color: AppColors.brandOf(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
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

// ─────────────────────────────────────────────────────────────
// STAT CARD
// ─────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
