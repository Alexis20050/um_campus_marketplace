import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_service.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import 'my_listings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Turns "juan.delacruz@umindanao.edu.ph" into "Juan Delacruz" as a
  // best-effort display name, since there's no separate name field yet.
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
      await authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    final user = authService.user;
    final displayName = _displayNameFromEmail(user?.email);
    final joinDate = _formatJoinDate(user?.createdAt);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const Center(child: Text('No user'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header card: avatar, name, email, join date
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.maroonLight,
                          child: Text(
                            displayName.isNotEmpty ? displayName[0] : '?',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.maroon,
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
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? '',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (joinDate.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Member since $joinDate',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stats row: active listings vs sold, computed live from
                // the seller's own products stream.
                StreamBuilder<List<Product>>(
                  stream: productProvider.sellerProductsStream(user.id),
                  builder: (context, snapshot) {
                    final products = snapshot.data ?? [];
                    final activeCount = products.where((p) => !p.isSold).length;
                    final soldCount = products.where((p) => p.isSold).length;

                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Active Listings',
                            value:
                                snapshot.connectionState ==
                                    ConnectionState.waiting
                                ? '—'
                                : '$activeCount',
                            icon: Icons.storefront,
                            color: AppColors.maroon,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Items Sold',
                            value:
                                snapshot.connectionState ==
                                    ConnectionState.waiting
                                ? '—'
                                : '$soldCount',
                            icon: Icons.sell,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // My Listings entry point
                Card(
                  elevation: 1,
                  child: ListTile(
                    leading: const Icon(
                      Icons.list_alt,
                      color: AppColors.maroon,
                    ),
                    title: const Text('My Listings'),
                    subtitle: const Text(
                      'View and manage everything you\'ve posted',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyListingsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Sign out
                Card(
                  elevation: 1,
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () => _confirmSignOut(context, authService),
                  ),
                ),
              ],
            ),
    );
  }
}

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
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
