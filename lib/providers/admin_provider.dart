import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProvider extends ChangeNotifier {
  final SupabaseClient _supabase;

  AdminProvider({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  int _revision = 0;
  int get revision => _revision;
  Map<String, dynamic>? _latestDashboardStats;
  int? get pendingReportCount =>
      int.tryParse(_latestDashboardStats?['pending_reports']?.toString() ?? '');
  String? _staffUserId;
  String? _staffRole;
  String? get staffRole => _staffRole;

  void _changed() {
    _revision++;
    notifyListeners();
  }

  bool _isLoading = false;

  String? _error;

  bool? _staffCache;

  // ============================================================
  // GETTERS
  // ============================================================

  bool get isLoading => _isLoading;

  String? get error => _error;

  SupabaseClient get client => _supabase;

  // ============================================================
  // HELPERS
  // ============================================================

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;

    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;

    notifyListeners();
  }

  String _friendlyError(Object error) {
    return friendlyError(error);
  }

  static String friendlyError(Object error) {
    if (error is PostgrestException) {
      if (error.code == 'PGRST202') {
        return 'This admin operation is unavailable. Please check the installed RPC.';
      }
      return error.message;
    }

    if (error is StateError) return error.message.toString();
    if (error is ArgumentError) return error.message.toString();
    return 'Could not complete this request. Check your connection and try again.';
  }

  // ============================================================
  // IS STAFF
  // ============================================================

  Future<bool> isStaff({bool refresh = false}) async {
    final currentId = _supabase.auth.currentUser?.id;
    if (currentId == null) {
      clearStaffCache();
      return false;
    }
    if (!refresh && _staffCache != null && _staffUserId == currentId) {
      return _staffCache!;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;
      final profile = await _supabase
          .from('profiles')
          .select('role,account_status')
          .eq('id', user.id)
          .single();
      final result = await _supabase.rpc('current_user_is_staff');
      if (_supabase.auth.currentUser?.id != user.id) return false;
      _staffUserId = user.id;
      _staffRole = profile['role']?.toString();
      _staffCache =
          result == true &&
          profile['account_status'] == 'active' &&
          (profile['role'] == 'admin' || profile['role'] == 'moderator');

      return _staffCache!;
    } catch (e) {
      debugPrint('isStaff failed: $e');

      _staffCache = null;
      rethrow;
    }
  }

  // ============================================================
  // FETCH REPORTS
  // ============================================================

  Future<List<Map<String, dynamic>>> fetchReports({
    String status = 'pending',
  }) async {
    try {
      _setLoading(true);

      _setError(null);

      final result = await _supabase.rpc(
        'admin_reports',
        params: {'p_status': status},
      );

      if (result is! List) {
        return [];
      }

      return result
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (e) {
      debugPrint('fetchReports failed: $e');

      _setError(_friendlyError(e));

      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // DISMISS REPORT
  // ============================================================

  Future<void> dismissReport({required String reportId, String? note}) {
    return resolveReport(reportId: reportId, action: 'dismiss', note: note);
  }

  // ============================================================
  // HIDE LISTING
  // ============================================================

  Future<void> hideListing({required String reportId, String? note}) {
    return resolveReport(
      reportId: reportId,
      action: 'hide_listing',
      note: note,
    );
  }

  // ============================================================
  // SUSPEND USER
  // ============================================================

  Future<void> suspendUser({required String reportId, String? note}) {
    return resolveReport(
      reportId: reportId,
      action: 'suspend_user',
      note: note,
    );
  }

  // ============================================================
  // GENERIC RESOLVE
  // ============================================================

  Future<void> resolveReport({
    required String reportId,
    required String action,
    String? note,
  }) async {
    try {
      _setLoading(true);

      _setError(null);

      await _supabase.rpc(
        'admin_resolve_report',
        params: {
          'p_report_id': reportId,

          'p_action': action,

          'p_note': note?.trim().isEmpty == true ? null : note?.trim(),
        },
      );

      _changed();
    } catch (e) {
      debugPrint('resolveReport failed: $e');

      _setError(_friendlyError(e));

      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // RESTORE LISTING
  // ============================================================

  Future<void> restoreListing(String productId) async {
    try {
      _setLoading(true);

      await _supabase.rpc(
        'admin_restore_listing',
        params: {'p_product_id': productId},
      );

      _changed();
    } catch (e) {
      _setError(_friendlyError(e));

      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // RESTORE USER
  // ============================================================

  Future<void> restoreUser(String userId) async {
    try {
      _setLoading(true);

      await _supabase.rpc('admin_restore_user', params: {'p_user_id': userId});

      _changed();
    } catch (e) {
      _setError(_friendlyError(e));

      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void clearStaffCache() {
    _staffCache = null;
    _staffUserId = null;
    _staffRole = null;
    _latestDashboardStats = null;
  }

  Future<dynamic> _request(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await _supabase.rpc(rpc, params: params);
    } catch (e) {
      _error = friendlyError(e);
      rethrow;
    }
  }

  List<Map<String, dynamic>> _rows(dynamic result) {
    if (result == null) return [];
    if (result is! List || result.any((row) => row is! Map)) {
      throw StateError('The server returned an unexpected admin response.');
    }
    return result.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Map<String, dynamic> _detail(dynamic result, String missing) {
    if (result is List) result = result.isEmpty ? null : result.first;
    if (result == null || (result is Map && result.isEmpty)) {
      throw StateError(missing);
    }
    if (result is! Map) {
      throw StateError('The server returned an unexpected admin response.');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final stats = _detail(
      await _request('admin_dashboard_stats'),
      'Dashboard statistics unavailable.',
    );
    _latestDashboardStats = stats;
    notifyListeners();
    return stats;
  }

  Future<List<Map<String, dynamic>>> fetchUsers({String? search}) async =>
      _rows(await _request('admin_users', {'p_search': _search(search)}));

  Future<Map<String, dynamic>> fetchUserDetail(String userId) async {
    final result = _detail(
      await _request('admin_user_detail', {'p_user_id': userId}),
      'User not found.',
    );
    // The installed RPC groups account fields and activity counts separately.
    // Keep accepting flat responses from earlier installations as well.
    if (!result.containsKey('profile') && !result.containsKey('stats')) {
      return result;
    }
    final profile = _detail(result['profile'], 'User not found.');
    final stats = result['stats'];
    if (stats is! Map) {
      throw StateError(
        'The server returned an unexpected admin activity response.',
      );
    }
    return {...result, ...Map<String, dynamic>.from(stats), ...profile};
  }

  Future<List<Map<String, dynamic>>> fetchUserListings(String userId) async =>
      _rows(await _request('admin_user_listings', {'p_user_id': userId}));

  Future<List<Map<String, dynamic>>> fetchListings({
    String? status,
    String? search,
  }) async => _rows(
    await _request('admin_all_listings', {
      'p_status': status == 'all' ? null : status,
      'p_search': _search(search),
    }),
  );

  Future<Map<String, dynamic>> fetchListingDetail(String productId) async {
    final result = _detail(
      await _request('admin_listing_detail', {'p_product_id': productId}),
      'Listing not found.',
    );
    final row = Map<String, dynamic>.of(result);
    // Support grouped RPC responses while retaining flat installations.
    for (final key in ['stats', 'listing', 'product']) {
      if (!result.containsKey(key)) continue;
      final value = result[key];
      if (key == 'stats') {
        if (value == null) continue;
        if (value is! Map) {
          throw StateError(
            'The server returned unexpected listing statistics.',
          );
        }
        row.addAll(Map<String, dynamic>.from(value));
        continue;
      }
      row.addAll(_detail(value, 'Listing not found.'));
    }
    // Namespace related accounts so their IDs and names cannot overwrite
    // the product's ID, title, or creation date.
    for (final key in ['seller', 'reserved_buyer']) {
      final value = result[key];
      if (value == null) continue;
      if (value is! Map) {
        throw StateError(
          'The server returned unexpected listing account data.',
        );
      }
      for (final entry in Map<String, dynamic>.from(value).entries) {
        row['${key}_${entry.key}'] = entry.value;
      }
    }
    return row;
  }

  Future<List<Map<String, dynamic>>> fetchReportsForUser(String userId) async =>
      _rows(await _request('admin_reports_for_user', {'p_user_id': userId}));

  Future<List<Map<String, dynamic>>> fetchReportsForListing(
    String productId,
  ) async => _rows(
    await _request('admin_reports_for_listing', {'p_product_id': productId}),
  );

  String? _search(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  String? userStatusRestriction(String userId, String? role) {
    if (userId == _supabase.auth.currentUser?.id) {
      return 'You cannot change your own account status.';
    }
    if (role == 'admin') {
      return 'Administrator accounts cannot be suspended from this console.';
    }
    if (_staffRole == 'moderator' && role == 'moderator') {
      return 'Moderators cannot change another moderator’s account status.';
    }
    return null;
  }

  Future<void> setUserStatus({
    required String userId,
    required String status,
  }) async {
    if (!['active', 'suspended'].contains(status)) {
      throw ArgumentError('Invalid account status.');
    }
    final restriction = userStatusRestriction(userId, null);
    if (restriction != null) throw StateError(restriction);
    await _request('admin_set_user_status', {
      'p_user_id': userId,
      'p_status': status,
    });
    _changed();
  }

  Future<void> setListingVisibility({
    required String productId,
    required String status,
  }) async {
    if (!['active', 'hidden'].contains(status)) {
      throw ArgumentError('Invalid listing status.');
    }
    await _request('admin_set_listing_visibility', {
      'p_product_id': productId,
      'p_status': status,
    });
    _changed();
  }
}
