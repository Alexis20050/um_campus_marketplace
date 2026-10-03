import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/admin_data.dart';
import '../widgets/admin_widgets.dart';
import 'admin_reports_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});
  void _reports(BuildContext context, [String? id]) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdminReportsScreen(reportId: id),
        ),
      );

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Dashboard',
    subtitle: 'Monitor marketplace activity and moderation',
    body:
        AdminDataView<
          ({
            Map<String, dynamic> stats,
            List<Map<String, dynamic>> reports,
            Object? reportError,
          })
        >(
          errorTitle: 'Unable to load dashboard',
          load: (provider) async {
            Object? reportError;
            final reports = provider.fetchReports().catchError((Object error) {
              reportError = error;
              debugPrint('Dashboard reports failed: $error');
              return <Map<String, dynamic>>[];
            });
            final stats = await provider.fetchDashboardStats();
            return (
              stats: stats,
              reports: await reports,
              reportError: reportError,
            );
          },
          builder: (context, data) {
            final stats = data.stats;
            final pending =
                int.tryParse(adminText(stats, 'pending_reports', '0')) ?? 0;
            final hidden =
                int.tryParse(adminText(stats, 'hidden_listings', '0')) ?? 0;
            final suspended =
                int.tryParse(adminText(stats, 'suspended_users', '0')) ?? 0;
            final reports = [...data.reports]
              ..sort(
                (a, b) => adminText(
                  b,
                  'last_reported_at|created_at',
                  '',
                ).compareTo(adminText(a, 'last_reported_at|created_at', '')),
              );
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Moderation overview',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start with the cases that need a decision today.',
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoftOf(context),
                    border: Border.all(
                      color: AppColors.brandOf(context).withValues(alpha: .18),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Icon(
                            Icons.priority_high_rounded,
                            size: 18,
                            color: AppColors.brandOf(context),
                          ),
                          Text(
                            'NEEDS ATTENTION',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandOf(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        pending == 0
                            ? 'Your report queue is clear'
                            : '$pending ${pending == 1 ? 'report needs' : 'reports need'} review',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 18,
                        runSpacing: 12,
                        children: [
                          _AttentionCount(
                            '$pending',
                            'Pending reports',
                            Icons.flag_outlined,
                          ),
                          _AttentionCount(
                            '$hidden',
                            'Hidden listings',
                            Icons.visibility_off_outlined,
                          ),
                          _AttentionCount(
                            '$suspended',
                            'Suspended accounts',
                            Icons.person_off_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => _reports(context),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Review reports'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const AdminSectionHeader(
                  'Marketplace overview',
                  subtitle: 'Key signals from the campus community',
                ),
                AdminGrid(
                  minWidth: 210,
                  children: [
                    AdminStatCard(
                      label: 'Total Users',
                      value: adminText(stats, 'total_users'),
                      icon: Icons.people_outline,
                      support:
                          '${adminText(stats, 'active_users')} active accounts',
                    ),
                    AdminStatCard(
                      label: 'Total Listings',
                      value: adminText(stats, 'total_listings'),
                      icon: Icons.inventory_2_outlined,
                      support:
                          '${adminText(stats, 'active_listings')} active listings',
                    ),
                    AdminStatCard(
                      label: 'Pending Reports',
                      value: adminText(stats, 'pending_reports'),
                      icon: Icons.flag_outlined,
                      support: 'Awaiting moderation',
                      accent: true,
                    ),
                    AdminStatCard(
                      label: 'Completed Transactions',
                      value: adminText(stats, 'completed_transactions'),
                      icon: Icons.handshake_outlined,
                      support: 'Completed marketplace sales',
                    ),
                  ],
                ),
                const AdminSectionHeader(
                  'Listing status',
                  subtitle: 'Marketplace state and moderation visibility',
                ),
                AdminPanel(
                  child: AdminGrid(
                    minWidth: 140,
                    maxColumns: 5,
                    children: [
                      for (final status in [
                        'active',
                        'reserved',
                        'sold',
                        'archived',
                        'hidden',
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AdminChip(status),
                              const SizedBox(height: 12),
                              Text(
                                adminText(stats, '${status}_listings'),
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
                ),
                AdminSectionHeader(
                  'Recent reports',
                  subtitle: 'Newest cases in the moderation queue',
                  action: TextButton(
                    onPressed: () => _reports(context),
                    child: const Text('View All'),
                  ),
                ),
                if (data.reportError != null)
                  AdminPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Unable to load recent reports.'),
                        TextButton(
                          onPressed: () => _reports(context),
                          child: const Text('Open Reports'),
                        ),
                      ],
                    ),
                  )
                else if (reports.isEmpty)
                  const AdminPanel(
                    child: AdminEmpty(
                      'Everything is clear. There are no reports waiting for review.',
                      title: 'No pending reports',
                      icon: Icons.task_alt,
                      scrollable: false,
                    ),
                  )
                else
                  AdminGrid(
                    minWidth: 280,
                    maxColumns: 3,
                    children: [
                      for (final report in reports.take(3))
                        AdminReportCard(
                          report: report,
                          onReview: () => _reports(
                            context,
                            adminText(report, 'report_id|id', ''),
                          ),
                        ),
                    ],
                  ),
                const AdminSectionHeader('Account health & moderation'),
                AdminGrid(
                  maxColumns: 2,
                  minWidth: 300,
                  children: [
                    AdminSection('Community accounts', {
                      'Active users': adminText(stats, 'active_users'),
                      'Suspended users': adminText(stats, 'suspended_users'),
                      'Moderators': adminText(
                        stats,
                        'moderators|moderator_users',
                      ),
                      'Admins': adminText(stats, 'admins|admin_users'),
                    }),
                    AdminSection('Report outcomes', {
                      'Pending review': adminText(stats, 'pending_reports'),
                      'Resolved reports': adminText(stats, 'resolved_reports'),
                      'Dismissed reports': adminText(
                        stats,
                        'dismissed_reports',
                      ),
                    }),
                  ],
                ),
              ],
            );
          },
        ),
  );
}

class _AttentionCount extends StatelessWidget {
  final String count;
  final String label;
  final IconData icon;
  const _AttentionCount(this.count, this.label, this.icon);

  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 5,
    runSpacing: 4,
    children: [
      Icon(icon, size: 18, color: AppColors.brandOf(context)),
      Text(count, style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondaryOf(context),
        ),
      ),
    ],
  );
}
