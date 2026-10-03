import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/admin_provider.dart';
import '../theme/app_theme.dart';
import '../utils/admin_data.dart';
import '../widgets/admin_widgets.dart';
import 'admin_listing_detail_screen.dart';
import 'admin_user_detail_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  final String? userId;
  final String? productId;
  final String? reportId;
  final String initialStatus;
  const AdminReportsScreen({
    super.key,
    this.userId,
    this.productId,
    this.reportId,
    this.initialStatus = 'pending',
  });

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _status = 'pending';
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    if (widget.reportId == null &&
        (widget.userId != null || widget.productId != null)) {
      _status = 'all';
    }
  }

  void _changeStatus(String value) => setState(() => _status = value);

  Future<List<Map<String, dynamic>>> _load(AdminProvider provider) async {
    final List<Map<String, dynamic>> reports;
    if (widget.userId != null) {
      reports = await provider.fetchReportsForUser(widget.userId!);
    } else if (widget.productId != null) {
      reports = await provider.fetchReportsForListing(widget.productId!);
    } else {
      reports = await provider.fetchReports(status: _status);
    }
    final matches = reports
        .where(
          (row) =>
              (widget.reportId == null ||
                  adminText(row, 'report_id|id') == widget.reportId) &&
              (_status == 'all' ||
                  adminText(row, 'status|report_status', _status) == _status),
        )
        .toList();
    if (_status == 'pending' && widget.reportId == null) {
      matches.sort((a, b) {
        final countA =
            int.tryParse(adminText(a, 'report_count|reports_count', '1')) ?? 1;
        final countB =
            int.tryParse(adminText(b, 'report_count|reports_count', '1')) ?? 1;
        final priority = countB.compareTo(countA);
        return priority != 0
            ? priority
            : adminText(
                b,
                'last_reported_at|created_at',
                '',
              ).compareTo(adminText(a, 'last_reported_at|created_at', ''));
      });
    }
    return matches;
  }

  Future<String?> _askNote({required String title}) => showDialog<String>(
    context: context,
    builder: (_) => _ReportNoteDialog(title: title),
  );
  Future<void> _runAction({
    required String reportId,
    required String action,
    required String title,
  }) async {
    if (_acting) return;
    final note = await _askNote(title: title);

    if (note == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final provider = context.read<AdminProvider>();
    setState(() => _acting = true);

    try {
      await provider.resolveReport(
        reportId: reportId,
        action: action,
        note: note,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (action) {
            'dismiss' => 'Report dismissed.',
            'hide_listing' => 'Listing hidden.',
            _ => 'User suspended.',
          }),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(adminActionError(e))));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _restoreTarget({String? productId, String? userId}) async {
    if (_acting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(productId != null ? 'Restore listing?' : 'Restore user?'),
        content: const Text(
          'This reverses the moderation restriction on this target.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final provider = context.read<AdminProvider>();
    setState(() => _acting = true);
    try {
      if (productId != null) {
        await provider.setListingVisibility(
          productId: productId,
          status: 'active',
        );
      } else {
        await provider.setUserStatus(userId: userId!, status: 'active');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            productId != null ? 'Listing restored.' : 'User restored.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(adminActionError(e))));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: widget.reportId != null
        ? 'Review Report'
        : widget.userId != null
        ? 'User Reports'
        : widget.productId != null
        ? 'Listing Reports'
        : 'Reports',
    subtitle: 'Review concerns and keep the marketplace safe',
    body: Column(
      children: [
        if (widget.reportId == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: AdminFilters(
              values: [
                if (widget.userId != null || widget.productId != null) 'all',
                'pending',
                'resolved',
                'dismissed',
              ],
              selected: _status,
              onSelected: _changeStatus,
            ),
          ),
        if (_acting) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: AdminDataView<List<Map<String, dynamic>>>(
            requestKey: (
              _status,
              widget.userId,
              widget.productId,
              widget.reportId,
            ),
            errorTitle: 'Unable to load reports',
            load: _load,
            builder: (context, reports) => reports.isEmpty
                ? AdminEmpty(
                    widget.reportId != null
                        ? 'No reports found.'
                        : _status == 'pending'
                        ? 'Everything is clear. There are no reports waiting for review.'
                        : 'No reports found.',
                    title: _status == 'pending'
                        ? 'No pending reports'
                        : 'No cases found',
                    icon: Icons.task_alt,
                  )
                : AdminCollection(
                    maxColumns: widget.reportId != null ? 1 : 3,
                    minWidth: 320,
                    itemCount: reports.length,
                    itemBuilder: (context, index) => widget.reportId != null
                        ? _reportCard(reports[index])
                        : AdminReportCard(
                            report: reports[index],
                            onReview: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AdminReportsScreen(
                                  userId: widget.userId,
                                  productId: widget.productId,
                                  reportId: adminText(
                                    reports[index],
                                    'report_id|id',
                                    '',
                                  ),
                                  initialStatus: adminText(
                                    reports[index],
                                    'status|report_status',
                                    'pending',
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
          ),
        ),
      ],
    ),
  );
  Widget _reportCard(Map<String, dynamic> report) {
    final targetType = report['target_type']?.toString() ?? '';

    final reportId = adminText(report, 'report_id|id', '');
    final reportStatus = adminText(report, 'status|report_status', _status);

    final productId = report['product_id']?.toString();

    final reportedUserId = report['reported_user_id']?.toString();

    final productTitle = report['product_title']?.toString();

    final userName = report['reported_user_name']?.toString();
    final restriction = reportedUserId == null
        ? null
        : context.read<AdminProvider>().userStatusRestriction(
            reportedUserId,
            report['reported_user_role']?.toString(),
          );

    return AdminPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REPORT CASE',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColors.brandOf(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: targetType == 'listing'
                    ? AppColors.brandSoftOf(context)
                    : AppColors.gold.withValues(alpha: 0.15),
                child: Icon(
                  targetType == 'listing'
                      ? Icons.inventory_2_outlined
                      : Icons.person_outline,
                  color: targetType == 'listing'
                      ? AppColors.brandOf(context)
                      : AppColors.gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetType == 'listing'
                          ? productTitle ?? 'Reported Listing'
                          : userName ?? 'Reported User',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${targetType.toUpperCase()} • ${adminRelativeTime(adminValue(report, 'last_reported_at|created_at'))}',
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              AdminChip(reportStatus),
              if (productId != null)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AdminListingDetailScreen(productId: productId),
                    ),
                  ),
                  child: const Text('View Listing'),
                ),
              if (reportedUserId != null)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AdminUserDetailScreen(userId: reportedUserId),
                    ),
                  ),
                  child: const Text('View User'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: AppColors.borderOf(context)),
          AdminSectionHeader(
            targetType == 'listing' ? 'Reported listing' : 'Reported account',
            subtitle: 'Context for this moderation case',
          ),
          if (targetType == 'listing') ...[
            Text(
              productTitle ?? 'Reported Listing',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            if (adminValue(report, 'product_price|price') != null)
              Text(
                adminPrice(adminValue(report, 'product_price|price')),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            Text(
              'Seller: ${adminText(report, 'seller_name|reported_user_name')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else ...[
            Text(
              userName ?? 'Reported User',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (adminText(report, 'reported_user_email', '').isNotEmpty)
              Text(
                adminText(report, 'reported_user_email'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
          const SizedBox(height: 12),
          Text(
            '${adminText(report, 'report_count|reports_count', '1')} reports about this target',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          Divider(color: AppColors.borderOf(context)),
          const AdminSectionHeader('Report details'),
          if (adminText(
            report,
            'admin_note|moderator_note|resolution_note',
            '',
          ).isNotEmpty)
            Text(
              'Moderator note: ${adminText(report, 'admin_note|moderator_note|resolution_note')}',
            ),
          Text(
            'Reason',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            report['reason']?.toString() ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (report['details']?.toString().trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              report['details'].toString(),
              style: TextStyle(color: AppColors.textSecondaryOf(context)),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Reported by ${report['reporter_name'] ?? 'UM Student'}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          if (adminText(report, 'reporter_email', '').isNotEmpty)
            Text(
              adminText(report, 'reporter_email'),
              style: Theme.of(context).textTheme.bodySmall,
            ),

          if (reportStatus == 'pending') ...[
            const SizedBox(height: 24),
            Divider(color: AppColors.borderOf(context)),
            const AdminSectionHeader(
              'Moderation actions',
              subtitle: 'Choose a decision for this case',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _acting
                      ? null
                      : () => _runAction(
                          reportId: reportId,
                          action: 'dismiss',
                          title: 'Dismiss report',
                        ),
                  icon: const Icon(Icons.close),
                  label: const Text('Dismiss'),
                ),

                if (targetType == 'listing' && productId != null)
                  FilledButton.icon(
                    onPressed: _acting
                        ? null
                        : () => _runAction(
                            reportId: reportId,
                            action: 'hide_listing',
                            title: 'Hide listing',
                          ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: const Text('Hide Listing'),
                  ),

                if (reportedUserId != null)
                  FilledButton.icon(
                    onPressed: _acting || restriction != null
                        ? null
                        : () => _runAction(
                            reportId: reportId,
                            action: 'suspend_user',
                            title: 'Suspend user',
                          ),
                    style: FilledButton.styleFrom(),
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Suspend User'),
                  ),
              ],
            ),
          ],

          if (restriction != null) Text(restriction),

          if (reportStatus == 'resolved') ...[
            const SizedBox(height: 24),
            Divider(color: AppColors.borderOf(context)),
            const AdminSectionHeader('Moderation actions'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (targetType == 'listing' && productId != null)
                  OutlinedButton.icon(
                    onPressed: _acting
                        ? null
                        : () => _restoreTarget(productId: productId),
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restore Listing'),
                  ),

                if (reportedUserId != null)
                  OutlinedButton.icon(
                    onPressed: _acting || restriction != null
                        ? null
                        : () => _restoreTarget(userId: reportedUserId),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Restore User'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportNoteDialog extends StatefulWidget {
  final String title;
  const _ReportNoteDialog({required this.title});
  @override
  State<_ReportNoteDialog> createState() => _ReportNoteDialogState();
}

class _ReportNoteDialogState extends State<_ReportNoteDialog> {
  final _controller = TextEditingController();
  String _reason = 'No violation found';
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dismissing = widget.title == 'Dismiss report';
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dismissing
                  ? 'Dismiss this report without restricting the listing or user?'
                  : widget.title == 'Hide listing'
                  ? 'Hide this listing from the marketplace? Its history will be kept.'
                  : 'Suspend this account and restrict its marketplace access?',
            ),
            if (dismissing) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Dismissal reason',
                ),
                items: [
                  for (final reason in [
                    'No violation found',
                    'Insufficient evidence',
                    'Duplicate report',
                    'Issue already resolved',
                    'Report submitted by mistake',
                    'Other',
                  ])
                    DropdownMenuItem(
                      value: reason,
                      child: Text(reason, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => _reason = value!),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Moderator note',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final note = _controller.text.trim();
            Navigator.pop(
              context,
              dismissing ? '$_reason${note.isEmpty ? '' : ': $note'}' : note,
            );
          },
          style: dismissing
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
          child: Text(
            dismissing
                ? 'Dismiss'
                : widget.title == 'Hide listing'
                ? 'Hide Listing'
                : 'Suspend User',
          ),
        ),
      ],
    );
  }
}
