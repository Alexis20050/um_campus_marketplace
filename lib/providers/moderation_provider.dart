import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ModerationProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  // ============================================================
  // HELPERS
  // ============================================================

  User _requireUser() {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw StateError('You must be signed in to perform this action.');
    }

    return user;
  }

  String? _cleanDetails(String? details) {
    final value = details?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  void _setBusy(bool value) {
    if (_busy == value) return;

    _busy = value;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;

    _error = null;
    notifyListeners();
  }

  // ============================================================
  // REPORT LISTING
  // ============================================================

  Future<String> reportListing({
    required String productId,
    required String reason,
    String? details,
  }) async {
    final user = _requireUser();

    final cleanedProductId = productId.trim();
    final cleanedReason = reason.trim();

    if (cleanedProductId.isEmpty) {
      throw ArgumentError('Invalid product.');
    }

    if (cleanedReason.isEmpty) {
      throw ArgumentError('Please select a report reason.');
    }

    _setBusy(true);
    _error = null;

    try {
      // Prevent reporting own listing at provider level as well.
      final product = await _supabase
          .from('products')
          .select('seller_id')
          .eq('id', cleanedProductId)
          .maybeSingle();

      if (product == null) {
        throw StateError('This listing is no longer available.');
      }

      final sellerId = product['seller_id']?.toString();

      if (sellerId == user.id) {
        throw StateError('You cannot report your own listing.');
      }

      final result = await _supabase.rpc(
        'report_listing',
        params: {
          'p_product_id': cleanedProductId,
          'p_reason': cleanedReason,
          'p_details': _cleanDetails(details),
        },
      );

      return result?.toString() ?? 'Report submitted';
    } catch (e) {
      _error = _friendlyError(e);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  // ============================================================
  // REPORT USER
  // ============================================================

  Future<String> reportUser({
    required String userId,
    required String reason,
    String? details,
  }) async {
    final currentUser = _requireUser();

    final cleanedUserId = userId.trim();

    final cleanedReason = reason.trim();

    if (cleanedUserId.isEmpty) {
      throw ArgumentError('Invalid user.');
    }

    if (currentUser.id == cleanedUserId) {
      throw StateError('You cannot report yourself.');
    }

    if (cleanedReason.isEmpty) {
      throw ArgumentError('Please select a report reason.');
    }

    _setBusy(true);
    _error = null;

    try {
      final result = await _supabase.rpc(
        'report_user',
        params: {
          // Keep this exact parameter name.
          'p_user_id': cleanedUserId,
          'p_reason': cleanedReason,
          'p_details': _cleanDetails(details),
        },
      );

      return result?.toString() ?? 'Report submitted';
    } catch (e) {
      _error = _friendlyError(e);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  // ============================================================
  // BLOCK USER
  // ============================================================

  Future<void> blockUser(String userId) async {
    final currentUser = _requireUser();

    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      throw ArgumentError('Invalid user.');
    }

    if (currentUser.id == cleanedUserId) {
      throw StateError('You cannot block yourself.');
    }

    _setBusy(true);
    _error = null;

    try {
      await _supabase.rpc('block_user', params: {'p_user_id': cleanedUserId});

      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  // ============================================================
  // UNBLOCK USER
  // ============================================================

  Future<void> unblockUser(String userId) async {
    _requireUser();

    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      throw ArgumentError('Invalid user.');
    }

    _setBusy(true);
    _error = null;

    try {
      await _supabase.rpc('unblock_user', params: {'p_user_id': cleanedUserId});

      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  // ============================================================
  // CHECK BLOCK STATUS
  // ============================================================

  Future<bool> isBlocked(String userId) async {
    final currentUser = _supabase.auth.currentUser;

    if (currentUser == null) {
      return false;
    }

    final cleanedUserId = userId.trim();

    if (cleanedUserId.isEmpty) {
      return false;
    }

    if (currentUser.id == cleanedUserId) {
      return false;
    }

    try {
      final result = await _supabase
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', currentUser.id)
          .eq('blocked_id', cleanedUserId)
          .maybeSingle();

      return result != null;
    } catch (e) {
      debugPrint('isBlocked failed: $e');

      return false;
    }
  }

  // ============================================================
  // FRIENDLY ERRORS
  // ============================================================

  String _friendlyError(Object error) {
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();

      if (message.contains('duplicate') || message.contains('already')) {
        return 'You have already submitted this action.';
      }

      if (message.contains('permission') ||
          message.contains('policy') ||
          message.contains('rls')) {
        return 'You are not allowed to perform this action.';
      }

      return error.message;
    }

    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }
}
