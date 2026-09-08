import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _user;
  String? _profileName;

  User? get user => _user;
  String? get profileName => _profileName;

  AuthService() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      _user = data.session?.user;

      if (_user != null) {
        try {
          final profile = await _supabase
              .from('profiles')
              .select('name')
              .eq('id', _user!.id)
              .maybeSingle();
          _profileName = profile?['name'];
        } catch (_) {
          _profileName = null;
        }
      } else {
        _profileName = null;
      }

      notifyListeners();
    });
  }

  bool isUMEmail(String email) => email.endsWith('@umindanao.edu.ph');

  /// Creates the account only. Does NOT send the OTP — that is a
  /// separate, non-blocking step (see [sendEmailOtp]) so a slow or
  /// failed email never prevents the user from reaching the PIN screen.
  ///
  /// If the email already exists but hasn't completed verification yet
  /// (e.g. a previous signup attempt succeeded but the OTP email step
  /// failed or timed out), this treats it as a soft "already started"
  /// case rather than a hard block — the caller should still move on
  /// to the OTP screen and try sending/resending a code.
  ///
  /// Only throws when the email genuinely belongs to a fully confirmed,
  /// pre-existing account.
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

      // If Supabase returned a user but they're already confirmed,
      // this really is a duplicate, fully-registered account.
      if (user != null && user.emailConfirmedAt != null) {
        await _supabase.auth.signOut();
        throw 'This email is already registered. Please sign in.';
      }

      // New account, or an existing-but-unconfirmed one that Supabase
      // returned without error (common when "Confirm email" resend
      // is allowed) — sign out and let the caller proceed to the OTP
      // screen either way.
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      // Supabase's own "already registered" error can fire even for
      // unconfirmed accounts depending on project settings. Since we
      // can't verify confirmation status client-side in that case,
      // treat it as soft: let the user proceed to the OTP screen and
      // try to get a code, rather than hard-blocking their retry.
      if (msg.contains('already registered')) {
        return;
      }
      throw _friendlyAuthError(e.message);
    } on String {
      rethrow; // our own thrown messages above, already clean
    } catch (e) {
      throw 'Something went wrong while creating your account. Please try again.';
    }
  }

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

  /// Send OTP (initial send or resend) — used by both signup and login flows.
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
      // Auth state listener will fetch profile automatically
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } catch (e) {
      throw 'Invalid or expired code. Please request a new one.';
    }
  }

  /// Alias kept for readability at call sites.
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

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _profileName = null;
  }

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

    return message;
  }
}
