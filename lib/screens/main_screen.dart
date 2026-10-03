import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_service.dart';
import '../providers/message_provider.dart';
import '../theme/app_theme.dart';
import 'conversation_list_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'post_product_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const int _homeTab = 0;

  int _currentIndex = _homeTab;

  /// Held so we can stop the unread stream on dispose / sign-out.
  MessageProvider? _messageProvider;
  bool _unreadListenerActive = false;

  /// Memoized so PostProductScreen doesn't rebuild when the shell does.
  late final VoidCallback _onPostSuccess = () => _goToTab(_homeTab);

  @override
  void initState() {
    super.initState();
    // Defer until after the first frame so `context.read` is safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startUnreadListener();
    });
  }

  @override
  void dispose() {
    _stopUnreadListener();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // UNREAD LISTENER LIFECYCLE
  // ────────────────────────────────────────────────────────────
  void _startUnreadListener() {
    if (_unreadListenerActive) return;
    final provider = context.read<MessageProvider>();
    provider.startUnreadListener();
    _messageProvider = provider;
    _unreadListenerActive = true;
  }

  void _stopUnreadListener() {
    if (!_unreadListenerActive) return;
    _messageProvider?.stopUnreadListener();
    _messageProvider = null;
    _unreadListenerActive = false;
  }

  // ────────────────────────────────────────────────────────────
  // NAVIGATION
  // ────────────────────────────────────────────────────────────
  void _goToTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  // ────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Rebuild only when the auth flag flips.
    final isAuthenticated = context.select<AuthService, bool>(
      (auth) => auth.isAuthenticated,
    );

    if (!isAuthenticated) {
      // User signed out mid-session — drop the subscription and bail.
      _stopUnreadListener();
      return const LoginScreen();
    }

    // Rebuild only when the unread total actually changes, not for
    // every MessageProvider notification (outgoing status, etc.).
    final unread = context.select<MessageProvider, int>((m) => m.unreadTotal);

    return PopScope(
      // On any non-Home tab, back returns to Home instead of quitting.
      canPop: _currentIndex == _homeTab,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goToTab(_homeTab);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundOf(context),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(onSell: () => _goToTab(1)),
            PostProductScreen(onPostSuccess: _onPostSuccess),
            const ConversationListScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(unread),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // BOTTOM NAV
  // ────────────────────────────────────────────────────────────
  Widget _buildBottomNav(int unread) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 8,
            color: AppColors.shadowOf(context),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _goToTab,
        backgroundColor: AppColors.surfaceOf(context),
        indicatorColor: AppColors.brandSoftOf(context),
        elevation: 0,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Explore',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'Sell',
          ),
          NavigationDestination(
            icon: _MessagesIcon(unread: unread, filled: false),
            selectedIcon: _MessagesIcon(unread: unread, filled: true),
            label: 'Messages',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MESSAGES ICON WITH BADGE
// ─────────────────────────────────────────────────────────────
class _MessagesIcon extends StatelessWidget {
  final int unread;
  final bool filled;

  const _MessagesIcon({required this.unread, required this.filled});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      filled ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
    );

    if (unread <= 0) return icon;

    return Semantics(
      label: '$unread unread message${unread == 1 ? '' : 's'}',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.surfaceOf(context),
                  width: 2,
                ),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
