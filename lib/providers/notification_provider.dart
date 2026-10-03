import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;

  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;

  List<Map<String, dynamic>> _notifications = [];

  int _unreadCount = 0;

  bool _disposed = false;

  String? _listeningUserId;

  // ============================================================
  // GETTERS
  // ============================================================

  List<Map<String, dynamic>> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _unreadCount;

  bool get hasUnread => _unreadCount > 0;

  SupabaseClient get client => _supabase;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  NotificationProvider() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((_) {
      startListening(restart: true);
    });

    startListening();
  }

  // ============================================================
  // REALTIME LISTENER
  // ============================================================

  void startListening({bool restart = false}) {
    if (_disposed) {
      return;
    }

    final userId = _supabase.auth.currentUser?.id;

    if (!restart &&
        _listeningUserId == userId &&
        _notificationSubscription != null) {
      return;
    }

    _notificationSubscription?.cancel();

    _notificationSubscription = null;

    _listeningUserId = userId;

    if (userId == null) {
      _notifications = [];
      _unreadCount = 0;

      notifyListeners();

      return;
    }

    _notificationSubscription = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            if (_disposed || _supabase.auth.currentUser?.id != userId) {
              return;
            }

            _notifications = rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList();

            _unreadCount = _notifications
                .where((row) => row['is_read'] != true)
                .length;

            notifyListeners();
          },
          onError: (Object error) {
            debugPrint('Notification listener failed: $error');
          },
        );
  }

  // ============================================================
  // MARK ONE READ
  // ============================================================

  Future<void> markAsRead(String notificationId) async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }

  // ============================================================
  // MARK ALL READ
  // ============================================================

  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refresh() async {
    startListening(restart: true);

    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  // ============================================================
  // ICON HELPER
  // ============================================================

  String labelForType(String type) {
    switch (type) {
      case 'reservation_created':
        return 'Reservation';

      case 'reservation_cancelled':
        return 'Reservation';

      case 'sale_completed':
        return 'Purchase';

      case 'seller_rated':
        return 'Rating';

      case 'report_reviewed':
        return 'Moderation';

      default:
        return 'Notification';
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _disposed = true;

    _authSubscription?.cancel();

    _notificationSubscription?.cancel();

    super.dispose();
  }
}
