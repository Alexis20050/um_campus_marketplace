import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/admin_provider.dart';
import '../theme/app_theme.dart';
import '../utils/admin_data.dart';
import '../screens/admin_search_screen.dart';

/// Shared page chrome, scoped to administration so public screens keep their theme.
class AdminPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget body;
  final Widget? search;
  final bool showGlobalSearch;
  final bool refreshable;
  const AdminPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.search,
    this.showGlobalSearch = true,
    this.refreshable = true,
  });
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _refresh = ValueNotifier<int>(0);
  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.backgroundOf(context),
    body: SafeArea(
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              border: Border(
                bottom: BorderSide(color: AppColors.borderOf(context)),
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (Navigator.canPop(context)) ...[
                            IconButton(
                              tooltip: 'Back',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -.5,
                                      ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.showGlobalSearch)
                            IconButton.outlined(
                              tooltip: 'Search users and listings',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AdminSearchScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.search, size: 20),
                            ),
                          if (widget.showGlobalSearch) const SizedBox(width: 8),
                          if (widget.refreshable)
                            IconButton.outlined(
                              tooltip: 'Refresh ${widget.title.toLowerCase()}',
                              onPressed: () => _refresh.value++,
                              icon: const Icon(Icons.refresh, size: 20),
                            ),
                        ],
                      ),
                      if (widget.search != null) ...[
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: widget.search!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: _AdminRefreshScope(
                  notifier: _refresh,
                  child: widget.body,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AdminRefreshScope extends InheritedNotifier<ValueNotifier<int>> {
  const _AdminRefreshScope({required super.notifier, required super.child});
}

/// Requests start in lifecycle callbacks. A generation discards stale responses.
class AdminDataView<T> extends StatefulWidget {
  final Future<T> Function(AdminProvider) load;
  final Widget Function(BuildContext, T) builder;
  final Object? requestKey;
  final String errorTitle;
  const AdminDataView({
    super.key,
    required this.load,
    required this.builder,
    this.requestKey,
    this.errorTitle = 'Unable to load this view',
  });
  @override
  State<AdminDataView<T>> createState() => _AdminDataViewState<T>();
}

class _AdminDataViewState<T> extends State<AdminDataView<T>> {
  AdminProvider? _provider;
  int? _revision;
  int? _refreshRevision;
  int _generation = 0;
  bool _busy = true;
  bool _hasData = false;
  T? _data;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<AdminProvider>(context);
    final refresh = context
        .dependOnInheritedWidgetOfExactType<_AdminRefreshScope>()
        ?.notifier
        ?.value;
    if (_provider != provider ||
        _revision != provider.revision ||
        _refreshRevision != refresh) {
      final changedProvider = _provider != provider;
      _provider = provider;
      _revision = provider.revision;
      _refreshRevision = refresh;
      _start(clear: changedProvider);
    }
  }

  @override
  void didUpdateWidget(covariant AdminDataView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestKey != widget.requestKey) _start(clear: true);
  }

  Future<void> _start({bool clear = false}) async {
    final generation = ++_generation;
    final provider = _provider!;
    final load = widget.load;
    _busy = true;
    _error = null;
    if (clear) {
      _hasData = false;
      _data = null;
    }
    try {
      // Provider methods may notify listeners, so defer until after the lifecycle.
      final data = await Future<T>.microtask(() async {
        if (!mounted || generation != _generation) {
          throw StateError('Request cancelled.');
        }
        if (!await provider.isStaff()) {
          throw StateError('Staff access required.');
        }
        return load(provider);
      });
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _hasData = true;
        _busy = false;
      });
    } catch (error, stack) {
      if (!mounted || generation != _generation) return;
      debugPrint('Admin load failed: $error');
      debugPrintStack(stackTrace: stack, maxFrames: 6);
      setState(() {
        _error = error;
        _busy = false;
      });
    }
  }

  Future<void> _refresh() {
    late Future<void> request;
    setState(() {
      request = _start();
    });
    return request;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && !_hasData) {
      return AdminError(
        error: _error!,
        title: widget.errorTitle,
        onRetry: _refresh,
      );
    }
    if (!_hasData) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _busy,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: widget.builder(context, _data as T),
            ),
          ),
        ),
        if (_busy)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              semanticsLabel: 'Refreshing',
            ),
          ),
        if (_error != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: AppColors.surfaceOf(context),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.dangerTextOf(context),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.errorTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(onPressed: _refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String adminActionError(Object error) {
  debugPrint('Admin action failed: $error');
  return error is StateError || error is ArgumentError
      ? AdminProvider.friendlyError(error)
      : 'Could not complete this action. Please try again.';
}

class AdminError extends StatelessWidget {
  final Object error;
  final String title;
  final VoidCallback onRetry;
  const AdminError({
    super.key,
    required this.error,
    required this.onRetry,
    this.title = 'Unable to load this view',
  });
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: AppColors.dangerTextOf(context),
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            error is StateError
                ? AdminProvider.friendlyError(error)
                : 'Something went wrong while loading marketplace data. Please try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class AdminEmpty extends StatelessWidget {
  final String message;
  final String? title;
  final IconData icon;
  final bool scrollable;
  const AdminEmpty(
    this.message, {
    super.key,
    this.icon = Icons.search_off,
    this.scrollable = true,
    this.title,
  });
  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: AppColors.textSecondaryOf(context)),
          const SizedBox(height: 12),
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
          ],
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
    return scrollable
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [content],
          )
        : content;
  }
}

class AdminChip extends StatelessWidget {
  final String label;
  const AdminChip(this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    final value = label.toLowerCase();
    final color = switch (value) {
      'hidden' || 'suspended' => AppColors.dangerTextOf(context),
      'active' || 'visible' || 'resolved' => AppColors.successOf(context),
      'pending' || 'reserved' =>
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.gold
            : const Color(0xFF805C00),
      'admin' =>
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.dangerTextOnDark
            : AppColors.maroon,
      'moderator' => Theme.of(context).colorScheme.onSurfaceVariant,
      'sold' =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFBAC7D2)
            : const Color(0xFF506579),
      _ => AppColors.textSecondaryOf(context),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class AdminPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const AdminPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        hoverColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: .035),
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class AdminSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const AdminSectionHeader(this.title, {super.key, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class AdminSection extends StatelessWidget {
  final String title;
  final Map<String, String> values;
  const AdminSection(this.title, this.values, {super.key});
  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final entry in values.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(color: AppColors.textSecondaryOf(context)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Natural-height rows keep cards readable with larger accessibility text.
class AdminGrid extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;
  final int maxColumns;
  const AdminGrid({
    super.key,
    required this.children,
    this.minWidth = 230,
    this.maxColumns = 4,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = ((constraints.maxWidth + 16) / (minWidth * scale + 16))
          .floor()
          .clamp(1, maxColumns);
      return Wrap(
        spacing: 16,
        children: [
          for (final child in children)
            SizedBox(
              width: (constraints.maxWidth - (columns - 1) * 16) / columns,
              child: child,
            ),
        ],
      );
    },
  );
}

/// Lazily builds responsive rows, with one vertical scrollable for the collection.
class AdminCollection extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minWidth;
  final int maxColumns;
  const AdminCollection({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minWidth = 420,
    this.maxColumns = 2,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = ((constraints.maxWidth - 32) / (minWidth * scale + 16))
          .floor()
          .clamp(1, maxColumns);
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: (itemCount / columns).ceil(),
        itemBuilder: (context, row) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var column = 0; column < columns; column++) ...[
              if (column > 0) const SizedBox(width: 16),
              Expanded(
                child: row * columns + column < itemCount
                    ? itemBuilder(context, row * columns + column)
                    : const SizedBox(),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String support;
  final IconData icon;
  final bool accent;
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.support = '',
    this.accent = false,
  });
  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: accent
                    ? AppColors.brandSoftOf(context)
                    : AppColors.surfaceAltOf(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 22,
                color: accent
                    ? Theme.of(context).colorScheme.primary
                    : AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        if (support.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(support, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}

class AdminUserAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  const AdminUserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 23,
  });
  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : '${parts.first.characters.first}${parts.length > 1 ? parts.last.characters.first : ''}'
              .toUpperCase();
    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * .62,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.dangerTextOnDark
              : AppColors.maroon,
        ),
      ),
    );
    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: AppColors.brandSoftOf(context),
        child: imageUrl?.trim().isNotEmpty == true
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class AdminSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ),
      );
}

class AdminFilters extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;
  const AdminFilters({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text('${value[0].toUpperCase()}${value.substring(1)}'),
            selected: value == selected,
            onSelected: (_) => onSelected(value),
            showCheckmark: false,
            selectedColor: AppColors.brandSoftOf(context),
            labelStyle: TextStyle(
              fontWeight: value == selected ? FontWeight.w700 : FontWeight.w500,
              color: value == selected
                  ? AppColors.brandOf(context)
                  : AppColors.textSecondaryOf(context),
            ),
            side: BorderSide(
              color: value == selected
                  ? AppColors.brandOf(context).withValues(alpha: .25)
                  : AppColors.borderOf(context),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    ),
  );
}

class AdminActionButton extends StatefulWidget {
  final String label;
  final String message;
  final String? title;
  final String? successMessage;
  final bool destructive;
  final Future<void> Function() action;
  final String? disabledReason;
  const AdminActionButton({
    super.key,
    required this.label,
    required this.message,
    required this.action,
    this.disabledReason,
    this.title,
    this.successMessage,
    this.destructive = false,
  });
  @override
  State<AdminActionButton> createState() => _AdminActionButtonState();
}

class _AdminActionButtonState extends State<AdminActionButton> {
  bool _busy = false;
  ButtonStyle? get _style => widget.destructive
      ? FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        )
      : null;
  Future<void> _run() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.title ?? '${widget.label}?'),
          content: Text(widget.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: _style,
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.label),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      await widget.action();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(widget.successMessage ?? '${widget.label} completed.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(adminActionError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FilledButton.icon(
        style: _style,
        onPressed: _busy || widget.disabledReason != null ? null : _run,
        icon: Icon(
          widget.destructive ? Icons.shield_outlined : Icons.restore,
          size: 18,
        ),
        label: Text(_busy ? 'Please wait…' : widget.label),
      ),
      if (widget.disabledReason != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            widget.disabledReason!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ],
  );
}

class AdminListingCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  const AdminListingCard({super.key, required this.row, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final images = adminImages(row);
    return AdminPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              height: 96,
              child: AdminImage(url: images.isEmpty ? null : images.first),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adminText(row, 'title'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  adminPrice(row['price']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  adminText(row, 'seller_name'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AdminChip(adminMarketplaceStatus(row)),
                    AdminChip(adminVisibility(row)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${adminText(row, 'report_count|reports_count')} reports',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      adminDate(row['created_at']),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

class AdminListingTableRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  const AdminListingTableRow({
    super.key,
    required this.row,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final images = adminImages(row);
    return AdminPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: AdminImage(
                      url: images.isEmpty ? null : images.first,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminText(row, 'title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (adminText(row, 'category', '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          adminText(row, 'category'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              adminText(row, 'seller_name'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              adminPrice(row['price']),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AdminChip(adminMarketplaceStatus(row)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AdminChip(adminVisibility(row)),
            ),
          ),
          Expanded(
            child: Text(adminText(row, 'report_count|reports_count', '0')),
          ),
          Expanded(
            flex: 2,
            child: Text(
              adminDate(row['created_at']),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    );
  }
}

String adminVisibility(Map<String, dynamic> row) =>
    row['moderation_status'] == 'active'
    ? 'visible'
    : adminText(row, 'moderation_status');

class AdminImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const AdminImage({super.key, this.url, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    final placeholder = Center(
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: AppColors.textTertiaryOf(context),
      ),
    );
    return ColoredBox(
      color: AppColors.surfaceAltOf(context),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              fit: fit,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : placeholder,
            ),
    );
  }
}

class AdminReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onReview;
  const AdminReportCard({
    super.key,
    required this.report,
    required this.onReview,
  });
  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${adminText(report, 'target_type', 'marketplace').toUpperCase()} REPORT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            AdminChip(adminText(report, 'status|report_status', 'pending')),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          adminText(report, 'reason'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                adminText(report, 'product_title|reported_user_name'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (adminValue(report, 'product_price|price') != null) ...[
              const SizedBox(width: 8),
              Text(
                adminPrice(adminValue(report, 'product_price|price')),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        if (adminText(report, 'seller_name', '').isNotEmpty)
          Text(
            'Seller: ${adminText(report, 'seller_name')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'Reported by ${adminText(report, 'reporter_name', 'UM Student')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${adminText(report, 'report_count|reports_count', '1')} reports',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              adminRelativeTime(
                adminValue(report, 'last_reported_at|created_at'),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onReview,
          icon: const Icon(Icons.fact_check_outlined, size: 18),
          label: const Text('Review Report'),
        ),
      ],
    ),
  );
}
