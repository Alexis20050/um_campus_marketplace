import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _user;

  User? get user => _user;

  AuthService() {
    // Listen to auth state changes (login, logout, session refresh, email confirm)
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  // Check if email is from University of Mindanao
  bool isUMEmail(String email) => email.endsWith('@umindanao.edu.ph');

  // Sign up with email/password, restricted to UM emails
  Future<void> signUp(String email, String password) async {
    if (!isUMEmail(email)) {
      throw 'Only University of Mindanao emails are allowed.';
    }
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        // Add your app's deep link if you have one configured.
        // For now, leave it commented out.
        // emailRedirectTo: 'com.example.um_campus_marketplace://login-callback',
      );
      // Do NOT insert profiles here. A database trigger will handle it automatically.
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Sign in with email/password
  Future<void> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Resend confirmation email (if email confirmation is enabled)
  Future<void> resendConfirmationEmail(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
        // emailRedirectTo: 'com.example.um_campus_marketplace://login-callback',
      );
    } on AuthException catch (e) {
      throw _friendlyAuthError(e.message);
    } catch (e) {
      throw 'Failed to resend email. Please try again.';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Convert raw Supabase auth error to user-friendly message
  String _friendlyAuthError(String? message) {
    if (message == null) return 'Authentication failed.';
    // Map common Supabase error messages to friendlier text
    if (message.contains('Invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (message.contains('User already registered')) {
      return 'This email is already registered. Please sign in.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Please confirm your email first. Check your inbox for the verification link.';
    }
    if (message.contains('Anonymous sign-ins are disabled')) {
      return 'Please sign in with your UM email and password.';
    }
    if (message.contains('Only @umindanao.edu.ph emails are allowed')) {
      return 'Only University of Mindanao emails are allowed.';
    }
    return message;
  }
}
