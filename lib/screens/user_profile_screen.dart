import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_service.dart';
import '../providers/message_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
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

  // Segment control: show only active listings by default; the user
  // can toggle to see sold items too.
  bool _showSold = false;

  @override
  void initState() {
    super.initState();
    _name = widget.initialName ?? '';
    _email = widget.initialEmail ?? '';
    _loadProfile();
  }

  // ────────────────────────────────────────────────────────────
  // DATA
  // ────────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    try {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      final profile = await productProvider.fetchProfileById(widget.userId);

      if (!mounted) return;
      setState(() {
        final fetchedName = (profile?['name'] as String?)?.trim();
        if (fetchedName != null && fetchedName.isNotEmpty) {
          _name = fetchedName;
        }
        _email = profile?['email'] ?? _email;
        _joinedAt = profile?['created_at'];
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

  String _displayName() {
    if (_name.isNotEmpty) return _name;
    if (_email.contains('@')) {
      final localPart = _email.split('@').first;
      final words = localPart.split(RegExp(r'[._]+'));
      return words
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' ');
    }
    return 'UM Student';
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
  Future<void> _messageSeller(List<Product> sellerProducts) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final messageProvider = Provider.of<MessageProvider>(
      context,
      listen: false,
    );

    final currentUserId = authService.user?.id;
    if (currentUserId == null) {
      _showSnack('You need to sign in to send a message.');
      return;
    }
    if (currentUserId == widget.userId) {
      _showSnack('You cannot message yourself.');
      return;
    }
    if (sellerProducts.isEmpty) {
      _showSnack('This seller has no listings yet.');
      return;
    }

    final activeProducts = sellerProducts.where((p) => !p.isSold).toList();
    final candidates = activeProducts.isNotEmpty
        ? activeProducts
        : sellerProducts;

    // Single listing: skip the picker and open directly.
    if (candidates.length == 1) {
      await _openConversation(candidates.first, messageProvider);
      return;
    }

    // Multiple: let the buyer pick.
    final chosen = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          _ListingPickerSheet(sellerName: _displayName(), products: candidates),
    );

    if (chosen == null) return;
    await _openConversation(chosen, messageProvider);
  }

  Future<void> _openConversation(
    Product product,
    MessageProvider messageProvider,
  ) async {
    setState(() => _startingChat = true);
    try {
      final conversationId = await messageProvider.getOrCreateConversation(
        productId: product.id,
        sellerId: widget.userId,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: conversationId),
        ),
      );
    } catch (e) {
      _showSnack('Failed to start chat: $e');
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copyEmail() async {
    if (_email.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _email));
    _showSnack('Email copied to clipboard');
  }

  // ────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final authService = Provider.of<AuthService>(context, listen: false);
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
                    .where((p) => !p.isSold)
                    .toList();
                final soldProducts = allProducts
                    .where((p) => p.isSold)
                    .toList();
                final waiting =
                    snapshot.connectionState == ConnectionState.waiting;

                final visibleProducts = _showSold
                    ? soldProducts
                    : activeProducts;

                return ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    // ── Header (banner + avatar card) ──────
                    _buildHeader(
                      displayName: displayName,
                      email: _email,
                      joinDate: joinDate,
                      onEmailTap: _copyEmail,
                    ),

                    const SizedBox(height: 16),

                    // ── Stats ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Active Listings',
                              value: waiting ? '—' : '${activeProducts.length}',
                              icon: Icons.storefront_outlined,
                              color: AppColors.brandOf(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
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

                    // ── Message Seller ──────────────────────
                    if (!isSelf)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: (_startingChat || waiting)
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
                                : const Icon(Icons.chat_bubble_outline),
                            label: Text(
                              _startingChat
                                  ? 'Starting chat...'
                                  : 'Message Seller',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandOf(context),
                              foregroundColor: Colors.white,
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

                    // ── Segment toggle: Active / Sold ───────
                    if (!waiting && allProducts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _SegmentToggle(
                          showSold: _showSold,
                          activeCount: activeProducts.length,
                          soldCount: soldProducts.length,
                          onChanged: (showSold) =>
                              setState(() => _showSold = showSold),
                        ),
                      ),

                    if (!waiting && allProducts.isNotEmpty)
                      const SizedBox(height: 12),

                    // ── Listing header ──────────────────────
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

                    // ── Listings ────────────────────────────
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
                      ...visibleProducts.map((p) => ProductCard(product: p)),
                  ],
                );
              },
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
              // Avatar with a subtle ring
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
                // Tappable email — copies to clipboard
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

  // ────────────────────────────────────────────────────────────
  // ERROR / EMPTY STATES
  // ────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────
// SEGMENT TOGGLE (Active / Sold)
// ─────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────
// LISTING PICKER SHEET
// ─────────────────────────────────────────────────────────────
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
      builder: (ctx, scrollController) => Column(
        children: [
          // Drag handle
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

          // Header
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

          // Listing rows
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              itemCount: products.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.borderOf(context)),
              itemBuilder: (ctx, i) {
                final p = products[i];
                final img = p.imageUrls.isNotEmpty ? p.imageUrls.first : null;

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
                      child: img != null
                          ? Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.surfaceAltOf(context),
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: AppColors.textTertiaryOf(context),
                                ),
                              ),
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
                    p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '₱${p.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppColors.brandOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiaryOf(context),
                  ),
                  onTap: () => Navigator.pop(ctx, p),
                );
              },
            ),
          ),
        ],
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
