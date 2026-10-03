import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String dedicatedAdminEmail = 'alexissecuya@gmail.com';

  StreamSubscription<AuthState>? _authSubscription;

  bool _disposed = false;

  User? _user;

  String? _profileName;

  String? _authMessage;

  User? get user => _user;

  String? get profileName => _profileName;

  String? get authMessage => _authMessage;

  bool get isAuthenticated => _user != null;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  AuthService() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen(
      (data) async {
        if (_disposed) {
          return;
        }

        final session = data.session;

        if (session == null) {
          _user = null;
          _profileName = null;

          notifyListeners();

          return;
        }

        await _handleSignedInUser(session.user);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Auth state error: $error');
      },
    );

    final currentUser = _supabase.auth.currentUser;

    if (currentUser != null) {
      Future.microtask(() => _handleSignedInUser(currentUser));
    }
  }

  // ============================================================
  // EMAIL RULES
  // ============================================================

  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  bool isUMEmail(String email) {
    return _normalizeEmail(email).endsWith('@umindanao.edu.ph');
  }

  bool isDedicatedAdminEmail(String email) {
    return _normalizeEmail(email) == dedicatedAdminEmail;
  }

  /// Emails that may attempt to LOGIN.
  ///
  /// Normal students = UM email.
  /// Dedicated administrator = approved Gmail.
  bool isAllowedLoginEmail(String email) {
    return isUMEmail(email) || isDedicatedAdminEmail(email);
  }

  // ============================================================
  // HANDLE SIGNED-IN USER
  // ============================================================

  Future<void> _handleSignedInUser(User user) async {
    if (_disposed) {
      return;
    }

    final email = _normalizeEmail(user.email ?? '');

    Map<String, dynamic>? profile;

    try {
      final data = await _supabase
          .from('profiles')
          .select('''
            id,
            name,
            email,
            role,
            account_status
            ''')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        profile = Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint('Profile fetch failed: $e');
    }

    if (_disposed) {
      return;
    }

    final role = profile?['role']?.toString().toLowerCase() ?? 'user';

    final accountStatus =
        profile?['account_status']?.toString().toLowerCase() ?? 'active';

    // ==========================================================
    // SUSPENDED ACCOUNT
    // ==========================================================

    if (accountStatus == 'suspended') {
      await _rejectCurrentSession(
        'Your account has been suspended. '
        'Please contact the marketplace administrator.',
      );

      return;
    }

    // ==========================================================
    // NORMAL UM ACCOUNT
    // ==========================================================

    if (isUMEmail(email)) {
      _acceptUser(user: user, profile: profile);

      return;
    }

    // ==========================================================
    // DEDICATED NON-UM ADMIN ACCOUNT
    //
    // The Gmail address alone does NOT give admin access.
    // Database role must still be admin/moderator.
    // ==========================================================

    if (isDedicatedAdminEmail(email)) {
      final isStaff = role == 'admin' || role == 'moderator';

      if (isStaff && accountStatus == 'active') {
        _acceptUser(user: user, profile: profile);

        return;
      }

      await _rejectCurrentSession(
        'This account is not authorized as an administrator.',
      );

      return;
    }

    // ==========================================================
    // OTHER NON-UM EMAILS
    // ==========================================================

    await _rejectCurrentSession(
      'Only University of Mindanao accounts '
      'or an authorized administrator account are allowed.',
    );
  }

  // ============================================================
  // ACCEPT USER
  // ============================================================

  void _acceptUser({
    required User user,
    required Map<String, dynamic>? profile,
  }) {
    if (_disposed) {
      return;
    }

    _authMessage = null;

    _user = user;

    final name = profile?['name']?.toString().trim();

    _profileName = name != null && name.isNotEmpty ? name : null;

    notifyListeners();
  }

  // ============================================================
  // REJECT SESSION
  // ============================================================

  Future<void> _rejectCurrentSession(String message) async {
    _user = null;
    _profileName = null;
    _authMessage = message;

    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Sign-out after rejected login failed: $e');
    }

    if (!_disposed) {
      notifyListeners();
    }
  }

  // ============================================================
  // AUTH MESSAGE
  // ============================================================

  void clearAuthMessage() {
    _authMessage = null;
  }

  // ============================================================
  // SIGN UP
  //
  // IMPORTANT:
  // Admin Gmail CANNOT sign itself up through the app.
  //
  // Signup stays UM-only.
  // ============================================================

  Future<void> signUp(String email, String password, {String? name}) async {
    final trimmedEmail = _normalizeEmail(email);

    final trimmedName = name?.trim();

    if (!isUMEmail(trimmedEmail)) {
      throw 'Only University of Mindanao emails are allowed to register.';
    }

    try {
      final response = await _supabase.auth.signUp(
        email: trimmedEmail,
        password: password,
        data: {'name': trimmedName},
      );

      final user = response.user;

      if (user != null && trimmedName != null && trimmedName.isNotEmpty) {
        await _supabase
            .from('profiles')
            .update({'name': trimmedName})
            .eq('id', user.id);
      }

      if (user != null && user.emailConfirmedAt != null) {
        await _supabase.auth.signOut();

        throw 'This email is already registered. Please sign in.';
      }

      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();

      if (message.contains('already registered')) {
        return;
      }

      throw _friendlyAuthError(e.message);
    } on String {
      rethrow;
    } catch (e) {
      throw 'Something went wrong while creating your account. '
          'Please try again.';
    }
  }

  // ============================================================
  // SIGN IN
  // ============================================================

  Future<void> signIn(String email, String password) async {
    final trimmedEmail = _normalizeEmail(email);

    if (!isAllowedLoginEmail(trimmedEmail)) {
      throw 'Only UM accounts or the authorized administrator '
          'account can sign in.';
    }

    try {
      await _supabase.auth.signInWithPassword(
        email: trimmedEmail,
        password: password.trim(),
      );

      // Final authorization is handled by
      // _handleSignedInUser().
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } on String {
      rethrow;
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // ============================================================
  // GOOGLE SSO
  //
  // UM Google users are allowed.
  //
  // alexissecuya@gmail.com is also allowed ONLY when its
  // profiles.role is admin/moderator.
  // ============================================================

  Future<void> signInWithGoogle() async {
    try {
      final String redirectUrl = kIsWeb
          ? Uri.base.origin
          : 'io.supabase.umcampus-marketplace://login-callback';

      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        scopes: 'email profile openid',
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } catch (e) {
      throw 'Failed to sign in with Google. Please try again.';
    }
  }

  // ============================================================
  // EMAIL OTP
  // ============================================================

  Future<void> sendEmailOtp(String email, {String? name}) async {
    final trimmedEmail = _normalizeEmail(email);

    if (!isAllowedLoginEmail(trimmedEmail)) {
      throw 'Only UM accounts or the authorized administrator '
          'account are allowed.';
    }

    try {
      await _supabase.auth.signInWithOtp(
        email: trimmedEmail,
        data: name != null ? {'name': name.trim()} : null,
      );
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } on String {
      rethrow;
    } catch (e) {
      throw 'Failed to send code. Please try again.';
    }
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      await _supabase.auth.verifyOTP(
        type: OtpType.email,
        email: _normalizeEmail(email),
        token: token.trim(),
      );
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } catch (e) {
      throw 'Invalid or expired code. Please request a new one.';
    }
  }

  Future<void> resendEmailOtp(String email) {
    return sendEmailOtp(email);
  }

  // ============================================================
  // UPDATE PROFILE NAME
  // ============================================================

  Future<void> updateProfileName(String name) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw 'You must be logged in.';
    }

    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw 'Please enter a valid name.';
    }

    await _supabase
        .from('profiles')
        .update({'name': trimmedName})
        .eq('id', user.id);

    _profileName = trimmedName;

    notifyListeners();
  }

  // ============================================================
  // PASSWORD RESET
  //
  // Also supports the dedicated admin Gmail.
  // ============================================================

  Future<void> sendPasswordResetOtp(String email) async {
    final trimmedEmail = _normalizeEmail(email);

    if (!isAllowedLoginEmail(trimmedEmail)) {
      throw 'Only UM accounts or the authorized administrator '
          'account are allowed.';
    }

    try {
      await _supabase.auth.resetPasswordForEmail(trimmedEmail);
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } on String {
      rethrow;
    } catch (e) {
      throw 'Failed to send reset code. Please try again.';
    }
  }

  Future<void> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    try {
      await _supabase.auth.verifyOTP(
        type: OtpType.recovery,
        email: _normalizeEmail(email),
        token: token.trim(),
      );
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } catch (e) {
      throw 'Invalid or expired code. Please request a new one.';
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword.trim()),
      );
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } catch (e) {
      throw 'Failed to update password. Please try again.';
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw 'You must be logged in.';
    }

    if (user.email == null) {
      throw 'No email associated with this account.';
    }

    try {
      await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: currentPassword.trim(),
      );

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword.trim()),
      );
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } catch (e) {
      throw 'Failed to change password. Please try again.';
    }
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() async {
    await _supabase.auth.signOut();

    _user = null;
    _profileName = null;
  }

  // ============================================================
  // FRIENDLY ERRORS
  // ============================================================

  String _friendlyAuthError(String? message) {
    if (message == null) {
      return 'Authentication failed. Please try again.';
    }

    final lower = message.toLowerCase();

    if (lower.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }

    if (lower.contains('user already registered')) {
      return 'This email is already registered. Please sign in.';
    }

    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email first. Check your inbox.';
    }

    if (lower.contains('anonymous sign-ins are disabled')) {
      return 'Please sign in with your email and password.';
    }

    if (lower.contains('rate limit') || lower.contains('security purposes')) {
      return 'Please wait a moment before trying again.';
    }

    if (lower.contains('token has expired') ||
        lower.contains('invalid token')) {
      return 'That code is invalid or expired. '
          'Please request a new one.';
    }

    if (lower.contains('new password should be different')) {
      return 'New password must be different from the old one.';
    }

    if (lower.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    }

    if (lower.contains('same as the old password')) {
      return 'New password must be different from the current one.';
    }

    return message;
  }

  // ============================================================
  // NOTIFY / DISPOSE
  // ============================================================

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;

    _authSubscription?.cancel();

    super.dispose();
  }
}
