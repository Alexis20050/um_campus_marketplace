import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/auth_service.dart';
import '../providers/message_provider.dart';
import '../providers/moderation_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import '../widgets/report_dialog.dart';
import '../widgets/seller_rating_section.dart';
import '../widgets/stat_card.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? initialName;
  final String? initialEmail;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialName,
    this.initialEmail,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String _name = '';
  String _email = '';
  String? _joinedAt;

  bool _loading = true;
  String? _error;

  bool _startingChat = false;

  bool _isBlocked = false;
  bool _checkingBlock = true;
  bool _moderationBusy = false;

  // Segment control: show only active listings by default; the user
  // can toggle to see sold items too.
  bool _showSold = false;

  @override
  void initState() {
    super.initState();

    _name = widget.initialName ?? '';
    _email = widget.initialEmail ?? '';

    _loadProfile();
    _loadBlockStatus();
  }

  // ============================================================
  // DATA
  // ============================================================

  Future<void> _loadProfile() async {
    try {
      final productProvider = context.read<ProductProvider>();

      final profile = await productProvider.fetchProfileById(widget.userId);

      if (!mounted) return;

      setState(() {
        final fetchedName = (profile?['name'] as String?)?.trim();

        if (fetchedName != null && fetchedName.isNotEmpty) {
          _name = fetchedName;
        }

        _email = profile?['email']?.toString() ?? _email;

        _joinedAt = profile?['created_at']?.toString();

        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadBlockStatus() async {
    final auth = context.read<AuthService>();

    final currentUserId = auth.user?.id;

    if (currentUserId == null || currentUserId == widget.userId) {
      if (!mounted) return;

      setState(() {
        _checkingBlock = false;
        _isBlocked = false;
      });

      return;
    }

    try {
      final blocked = await context.read<ModerationProvider>().isBlocked(
        widget.userId,
      );

      if (!mounted) return;

      setState(() {
        _isBlocked = blocked;
        _checkingBlock = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _checkingBlock = false;
      });
    }
  }

  String _displayName() {
    if (_name.isNotEmpty) {
      return _name;
    }

    if (_email.contains('@')) {
      final localPart = _email.split('@').first;

      final words = localPart.split(RegExp(r'[._]+'));

      return words
          .where((word) => word.isNotEmpty)
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
    }

    return 'UM Student';
  }

  String _formatJoinDate(String? isoDate) {
    if (isoDate == null) {
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
  // REPORT / BLOCK
  // ============================================================

  Future<void> _reportUser() async {
    if (_moderationBusy) {
      return;
    }

    final report = await showReportDialog(
      context: context,
      title: 'Report User',
      description: _displayName(),
    );

    if (!mounted || report == null) {
      return;
    }

    final moderation = context.read<ModerationProvider>();

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _moderationBusy = true;
    });

    try {
      await moderation.reportUser(
        userId: widget.userId,
        reason: report.reason,
        details: report.details,
      );

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Report submitted for review.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not submit report: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _moderationBusy = false;
        });
      }
    }
  }

  Future<void> _toggleBlock() async {
    if (_moderationBusy || _checkingBlock) {
      return;
    }

    final displayName = _displayName();

    final willUnblock = _isBlocked;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            willUnblock ? 'Unblock $displayName?' : 'Block $displayName?',
          ),
          content: Text(
            willUnblock
                ? 'You will be able to message this user again.'
                : 'You will no longer be able to start a conversation with this user while they are blocked.',
          ),
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
                foregroundColor: willUnblock
                    ? AppColors.success
                    : AppColors.danger,
              ),
              child: Text(willUnblock ? 'Unblock' : 'Block'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    final moderation = context.read<ModerationProvider>();

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _moderationBusy = true;
    });

    try {
      if (willUnblock) {
        await moderation.unblockUser(widget.userId);
      } else {
        await moderation.blockUser(widget.userId);
      }

      if (!mounted) return;

      setState(() {
        _isBlocked = !willUnblock;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            willUnblock
                ? '$displayName has been unblocked.'
                : '$displayName has been blocked.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            willUnblock
                ? 'Could not unblock user: $e'
                : 'Could not block user: $e',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _moderationBusy = false;
        });
      }
    }
  }

  // ============================================================
  // CHAT ACTIONS
  // ============================================================

  Future<void> _messageSeller(List<Product> sellerProducts) async {
    final authService = context.read<AuthService>();

    final messageProvider = context.read<MessageProvider>();

    final currentUserId = authService.user?.id;

    if (currentUserId == null) {
      _showSnack('You need to sign in to send a message.');

      return;
    }

    if (currentUserId == widget.userId) {
      _showSnack('You cannot message yourself.');

      return;
    }

    if (_isBlocked) {
      _showSnack('Unblock this user before starting a conversation.');

      return;
    }

    if (sellerProducts.isEmpty) {
      _showSnack('This seller has no listings yet.');

      return;
    }

    final activeProducts = sellerProducts
        .where((product) => !product.isSold)
        .toList();

    final candidates = activeProducts.isNotEmpty
        ? activeProducts
        : sellerProducts;

    // Single listing: skip the picker and open directly.
    if (candidates.length == 1) {
      await _openConversation(candidates.first, messageProvider);

      return;
    }

    // Multiple listings: let the buyer choose which item.
    final chosen = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _ListingPickerSheet(
          sellerName: _displayName(),
          products: candidates,
        );
      },
    );

    if (!mounted || chosen == null) {
      return;
    }

    await _openConversation(chosen, messageProvider);
  }

  Future<void> _openConversation(
    Product product,
    MessageProvider messageProvider,
  ) async {
    if (_isBlocked) {
      _showSnack('Unblock this user before starting a conversation.');

      return;
    }

    setState(() {
      _startingChat = true;
    });

    try {
      final conversationId = await messageProvider.getOrCreateConversation(
        productId: product.id,
        sellerId: widget.userId,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: conversationId),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showSnack('Failed to start chat: $e');
    } finally {
      if (mounted) {
        setState(() {
          _startingChat = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyEmail() async {
    if (_email.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: _email));

    if (!mounted) return;

    _showSnack('Email copied to clipboard');
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();

    final authService = context.read<AuthService>();

    final isSelf = authService.user?.id == widget.userId;

    final displayName = _displayName();

    final joinDate = _formatJoinDate(_joinedAt);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Seller Profile'),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!isSelf)
            PopupMenuButton<String>(
              enabled: !_moderationBusy,
              icon: _moderationBusy
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.more_vert),
              onSelected: (value) async {
                switch (value) {
                  case 'report':
                    await _reportUser();
                    break;

                  case 'block':
                    await _toggleBlock();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: AppColors.danger),
                      SizedBox(width: 10),
                      Text('Report User'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(
                        _isBlocked
                            ? Icons.person_add_alt_1_outlined
                            : Icons.block_outlined,
                        color: _isBlocked
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                      const SizedBox(width: 10),
                      Text(_isBlocked ? 'Unblock User' : 'Block User'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : StreamBuilder<List<Product>>(
              stream: productProvider.sellerProductsStream(widget.userId),
              builder: (context, snapshot) {
                final allProducts = snapshot.data ?? [];

                final activeProducts = allProducts
                    .where((product) => !product.isSold)
                    .toList();

                final soldProducts = allProducts
                    .where((product) => product.isSold)
                    .toList();

                final waiting =
                    snapshot.connectionState == ConnectionState.waiting;

                final visibleProducts = _showSold
                    ? soldProducts
                    : activeProducts;

                return ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    // ======================================
                    // HEADER
                    // ======================================
                    _buildHeader(
                      displayName: displayName,
                      email: _email,
                      joinDate: joinDate,
                      onEmailTap: _copyEmail,
                    ),

                    const SizedBox(height: 16),

                    // ======================================
                    // BLOCK STATUS
                    // ======================================
                    if (!isSelf && _isBlocked)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.block_outlined,
                                color: AppColors.danger,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'You blocked this user. Messaging is disabled until you unblock them.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (!isSelf && _isBlocked) const SizedBox(height: 16),

                    // ======================================
                    // STATS
                    // ======================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Active Listings',
                              value: waiting ? '—' : '${activeProducts.length}',
                              icon: Icons.storefront_outlined,
                              color: AppColors.brandOf(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              label: 'Items Sold',
                              value: waiting ? '—' : '${soldProducts.length}',
                              icon: Icons.check_circle_outline,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ======================================
                    // MESSAGE SELLER
                    // ======================================
                    if (!isSelf)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed:
                                (_startingChat ||
                                    waiting ||
                                    _checkingBlock ||
                                    _isBlocked)
                                ? null
                                : () => _messageSeller(allProducts),
                            icon: _startingChat
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _isBlocked
                                        ? Icons.block_outlined
                                        : Icons.chat_bubble_outline,
                                  ),
                            label: Text(
                              _checkingBlock
                                  ? 'Checking...'
                                  : _isBlocked
                                  ? 'User Blocked'
                                  : _startingChat
                                  ? 'Starting chat...'
                                  : 'Message Seller',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandOf(context),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.surfaceAltOf(
                                context,
                              ),
                              disabledForegroundColor:
                                  AppColors.textSecondaryOf(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    SellerRatingSection(sellerId: widget.userId),

                    const SizedBox(height: 24),

                    // ======================================
                    // ACTIVE / SOLD TOGGLE
                    // ======================================
                    if (!waiting && allProducts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _SegmentToggle(
                          showSold: _showSold,
                          activeCount: activeProducts.length,
                          soldCount: soldProducts.length,
                          onChanged: (showSold) {
                            setState(() {
                              _showSold = showSold;
                            });
                          },
                        ),
                      ),

                    if (!waiting && allProducts.isNotEmpty)
                      const SizedBox(height: 12),

                    // ======================================
                    // LISTING HEADER
                    // ======================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _showSold ? 'Sold Items' : 'Active Listings',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!waiting)
                            Text(
                              '${visibleProducts.length}',
                              style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ======================================
                    // LISTINGS
                    // ======================================
                    if (waiting)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (visibleProducts.isEmpty)
                      _buildEmptyState(
                        icon: _showSold
                            ? Icons.history_outlined
                            : Icons.inventory_2_outlined,
                        title: _showSold
                            ? 'No sold items yet'
                            : 'No active listings',
                        subtitle: _showSold
                            ? '$displayName hasn\'t sold anything yet.'
                            : '$displayName hasn\'t posted anything for sale yet.',
                      )
                    else
                      ...visibleProducts.map(
                        (product) => ProductCard(product: product),
                      ),
                  ],
                );
              },
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
    required VoidCallback onEmailTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.brandOf(context).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.brandSoftOf(context),
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandOf(context),
                    ),
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
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onEmailTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 14,
                          color: AppColors.textSecondaryOf(context),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            email,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: AppColors.textTertiaryOf(context),
                        ),
                      ],
                    ),
                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR / EMPTY STATES
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),

            const SizedBox(height: 12),

            const Text(
              'Could not load profile',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 16),

            TextButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });

                _loadProfile();
                _loadBlockStatus();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppColors.textTertiaryOf(context)),

          const SizedBox(height: 12),

          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SEGMENT TOGGLE
// ============================================================

class _SegmentToggle extends StatelessWidget {
  final bool showSold;
  final int activeCount;
  final int soldCount;
  final ValueChanged<bool> onChanged;

  const _SegmentToggle({
    required this.showSold,
    required this.activeCount,
    required this.soldCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: _tab(
              context,
              label: 'Active',
              count: activeCount,
              selected: !showSold,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _tab(
              context,
              label: 'Sold',
              count: soldCount,
              selected: showSold,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context, {
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceOf(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.shadowOf(context),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? AppColors.brandOf(context)
                    : AppColors.textSecondaryOf(context),
              ),
            ),

            const SizedBox(width: 6),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.brandOf(context).withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.brandOf(context)
                      : AppColors.textTertiaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LISTING PICKER SHEET
// ============================================================

class _ListingPickerSheet extends StatelessWidget {
  final String sellerName;
  final List<Product> products;

  const _ListingPickerSheet({required this.sellerName, required this.products});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),

            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiaryOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Which item are you asking about?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Pick one of $sellerName\'s listings to start the chat.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Divider(height: 1, color: AppColors.borderOf(context)),

            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: products.length,
                separatorBuilder: (_, __) {
                  return Divider(height: 1, color: AppColors.borderOf(context));
                },
                itemBuilder: (ctx, index) {
                  final product = products[index];

                  final image = product.imageUrls.isNotEmpty
                      ? product.imageUrls.first
                      : null;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: image != null
                            ? Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return Container(
                                    color: AppColors.surfaceAltOf(context),
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: AppColors.textTertiaryOf(context),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: AppColors.surfaceAltOf(context),
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: AppColors.textTertiaryOf(context),
                                ),
                              ),
                      ),
                    ),
                    title: Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '₱${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppColors.brandOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiaryOf(context),
                    ),
                    onTap: () {
                      Navigator.pop(ctx, product);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
