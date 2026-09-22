import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _user;
  String? _profileName;
  String? _authMessage;

  User? get user => _user;
  String? get profileName => _profileName;
  String? get authMessage => _authMessage;

  AuthService() {
    _supabase.auth.onAuthStateChange.listen(
      (data) async {
        final session = data.session;

        if (session != null) {
          final user = session.user;

          // 🔒 Enforce @umindanao.edu.ph for ALL sign-in methods,
          // including Google SSO.
          if (user?.email == null || !isUMEmail(user!.email!)) {
            await _supabase.auth.signOut();
            _user = null;
            _profileName = null;
            // Surface a message the UI can display.
            _authMessage =
                'Only University of Mindanao (@umindanao.edu.ph) '
                'accounts are allowed.';
            notifyListeners();
            return;
          }

          // ── 1. Set the user and notify IMMEDIATELY ────────────
          // The UI transitions to MainScreen right away. The
          // profile-name fetch below is a background nicety and
          // must NOT block the login flow.
          _authMessage = null;
          _user = user;
          notifyListeners();

          // ── 2. Hydrate the profile name in the background ─────
          try {
            final profile = await _supabase
                .from('profiles')
                .select('name')
                .eq('id', user.id)
                .maybeSingle();
            _profileName = profile?['name'];
            notifyListeners();
          } catch (e) {
            debugPrint('Profile fetch failed (non-blocking): $e');
            _profileName = null;
          }
        } else {
          _user = null;
          _profileName = null;
          notifyListeners();
        }
      },
      onError: (error, stackTrace) {
        debugPrint('Auth state error: $error');
      },
    );
  }

  /// Called by the UI once it has shown [authMessage].
  void clearAuthMessage() {
    _authMessage = null;
  }

  bool isUMEmail(String email) => email.endsWith('@umindanao.edu.ph');

  // ============================================================
  // SIGN UP (email/password)
  // ============================================================
  Future<void> signUp(String email, String password, {String? name}) async {
    final trimmedEmail = email.trim();
    final trimmedName = name?.trim();

    if (!isUMEmail(trimmedEmail)) {
      throw 'Only University of Mindanao emails are allowed.';
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
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered')) {
        return;
      }
      throw _friendlyAuthError(e.message);
    } on String {
      rethrow;
    } catch (e) {
      throw 'Something went wrong while creating your account. Please try again.';
    }
  }

  // ============================================================
  // SIGN IN (email/password)
  // ============================================================
  Future<void> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // ============================================================
  // GOOGLE SSO
  // ============================================================
  /// Signs the user in via Google OAuth through Supabase.
  /// The result is delivered back through the deep link
  /// `io.supabase.umcampus-marketplace://login-callback`, and the
  /// onAuthStateChange listener above will enforce the UM domain.
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
      // Result is handled by the onAuthStateChange listener.
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } catch (e) {
      throw 'Failed to sign in with Google. Please try again.';
    }
  }

  // ============================================================
  // OTP (signup + login flows)
  // ============================================================
  Future<void> sendEmailOtp(String email, {String? name}) async {
    final trimmedEmail = email.trim();
    if (!isUMEmail(trimmedEmail)) {
      throw 'Only University of Mindanao emails are allowed.';
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
        email: email.trim(),
        token: token.trim(),
      );
      // Auth state listener will fetch profile automatically.
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } catch (e) {
      throw 'Invalid or expired code. Please request a new one.';
    }
  }

  Future<void> resendEmailOtp(String email) => sendEmailOtp(email);

  Future<void> updateProfileName(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw 'You must be logged in.';
    final trimmedName = name.trim();
    await _supabase
        .from('profiles')
        .update({'name': trimmedName})
        .eq('id', user.id);
    _profileName = trimmedName;
    notifyListeners();
  }

  // ============================================================
  // FORGOT PASSWORD (RESET VIA OTP)
  // ============================================================
  Future<void> sendPasswordResetOtp(String email) async {
    final trimmedEmail = email.trim();
    if (!isUMEmail(trimmedEmail)) {
      throw 'Only University of Mindanao emails are allowed.';
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
        email: email.trim(),
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
  // CHANGE PASSWORD (LOGGED-IN USER)
  // ============================================================
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw 'You must be logged in.';
    if (user.email == null) throw 'No email associated with this account.';

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
    _profileName = null;
  }

  // ============================================================
  // ERROR MESSAGING
  // ============================================================
  String _friendlyAuthError(String? message) {
    if (message == null) return 'Authentication failed. Please try again.';

    if (message.contains('Invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (message.contains('User already registered')) {
      return 'This email is already registered. Please sign in.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Please confirm your email first. Check your inbox for the verification code.';
    }
    if (message.contains('Anonymous sign-ins are disabled')) {
      return 'Please sign in with your UM email and password.';
    }
    if (message.contains('Only @umindanao.edu.ph emails are allowed')) {
      return 'Only University of Mindanao emails are allowed.';
    }
    if (message.toLowerCase().contains('rate limit') ||
        message.toLowerCase().contains('security purposes')) {
      return 'Please wait a moment before trying again.';
    }
    if (message.toLowerCase().contains('token has expired') ||
        message.toLowerCase().contains('invalid token')) {
      return 'That code is invalid or expired. Please request a new one.';
    }
    if (message.contains('New password should be different')) {
      return 'New password must be different from the old one.';
    }
    if (message.contains('Password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (message.contains('same as the old password')) {
      return 'New password must be different from the current one.';
    }

    return message;
  }
}
