import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/admin_provider.dart';
import '../providers/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_widgets.dart';

import 'admin_dashboard_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_users_screen.dart';
import 'admin_listings_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  static const _labels = [
    'Dashboard',
    'Reports',
    'Users',
    'Listings',
    'Account',
  ];
  static const _icons = [
    Icons.space_dashboard_outlined,
    Icons.flag_outlined,
    Icons.people_outline,
    Icons.inventory_2_outlined,
    Icons.manage_accounts_outlined,
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;
      final extended = constraints.maxWidth >= 1100;
      final pendingReports = context.select<AdminProvider, int?>(
        (p) => p.pendingReportCount,
      );
      final staffRole = context.select<AdminProvider, String?>(
        (p) => p.staffRole,
      );
      final roleLabel = staffRole == 'moderator'
          ? 'Moderator'
          : 'Administrator';
      final auth = context.watch<AuthService>();
      final adminName = auth.profileName?.trim().isNotEmpty == true
          ? auth.profileName!.trim()
          : auth.user?.email?.split('@').first ?? 'Administrator';
      return Scaffold(
        backgroundColor: AppColors.backgroundOf(context),
        // The stack stays at the same tree location across navigation breakpoints.
        body: Row(
          children: [
            if (wide)
              SafeArea(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: AppColors.borderOf(context)),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: NavigationRail(
                          extended: extended,
                          minExtendedWidth: 244,
                          backgroundColor: AppColors.surfaceOf(context),
                          selectedIndex: _currentIndex,
                          onDestinationSelected: (index) =>
                              setState(() => _currentIndex = index),
                          labelType: extended
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          groupAlignment: -1,
                          scrollable: true,
                          indicatorColor: AppColors.brandSoftOf(context),
                          selectedIconTheme: IconThemeData(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          selectedLabelTextStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandOf(context),
                          ),
                          unselectedIconTheme: IconThemeData(
                            color: AppColors.textSecondaryOf(context),
                          ),
                          unselectedLabelTextStyle: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                          ),
                          leading: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 24, 12, 28),
                            child: extended
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.school_outlined,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'UM Campus',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'MARKETPLACE · ADMIN',
                                            style: TextStyle(
                                              fontSize: 11,
                                              letterSpacing: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : const Icon(Icons.school_outlined),
                          ),
                          destinations: [
                            for (var i = 0; i < _labels.length; i++)
                              NavigationRailDestination(
                                icon:
                                    i == 1 &&
                                        pendingReports != null &&
                                        pendingReports > 0
                                    ? Badge.count(
                                        count: pendingReports,
                                        child: Icon(_icons[i]),
                                      )
                                    : Icon(_icons[i]),
                                label: Text(_labels[i]),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: extended ? 244 : 80,
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(context),
                          border: Border(
                            top: BorderSide(color: AppColors.borderOf(context)),
                          ),
                        ),
                        child: extended
                            ? SizedBox(
                                width: 220,
                                child: Row(
                                  children: [
                                    AdminUserAvatar(
                                      name: adminName,
                                      radius: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            adminName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            roleLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondaryOf(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Tooltip(
                                message: adminName,
                                child: AdminUserAvatar(
                                  name: adminName,
                                  radius: 18,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              key: const ValueKey('admin-content'),
              child: IndexedStack(
                index: _currentIndex,
                children: const [
                  AdminDashboardScreen(),
                  AdminReportsScreen(),
                  AdminUsersScreen(),
                  AdminListingsScreen(),
                  _AdminAccountScreen(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) =>
                    setState(() => _currentIndex = index),
                destinations: [
                  for (var i = 0; i < _labels.length; i++)
                    NavigationDestination(
                      icon:
                          i == 1 && pendingReports != null && pendingReports > 0
                          ? Badge.count(
                              count: pendingReports,
                              child: Icon(_icons[i]),
                            )
                          : Icon(_icons[i]),
                      label: _labels[i],
                    ),
                ],
              ),
      );
    },
  );
}

class _AdminAccountScreen extends StatelessWidget {
  const _AdminAccountScreen();

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text('You will leave the administration dashboard.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.dangerTextOf(context),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !context.mounted) {
      return;
    }

    context.read<AdminProvider>().clearStaffCache();

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthService>().signOut();
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(adminActionError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    final email = auth.user?.email ?? '';

    final name = auth.profileName?.trim().isNotEmpty == true
        ? auth.profileName!.trim()
        : 'Marketplace Administrator';

    final role =
        context.select<AdminProvider, String?>((p) => p.staffRole) ?? 'staff';
    return AdminPage(
      title: 'Account',
      subtitle: 'Your administration profile and access',
      refreshable: false,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AdminPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminUserAvatar(name: name, radius: 32),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(email, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      AdminChip(role),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AdminGrid(
            maxColumns: 2,
            minWidth: 300,
            children: [
              AdminSection('Account', {
                'Role': role == 'admin'
                    ? 'Administrator'
                    : role == 'moderator'
                    ? 'Moderator'
                    : 'Staff',
                'Status': 'Active',
              }),
              const AdminSection('Security', {
                'Access': 'Protected admin access',
                'Permissions': 'Marketplace moderation',
              }),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dangerTextOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
