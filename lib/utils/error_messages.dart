/// Centralized, user-friendly error messages.
///
/// Maps raw exceptions / strings thrown by providers or Supabase into short,
/// human-readable copy that is safe to show in a SnackBar.
library;

String friendlyError(Object e) {
  final raw = e.toString().replaceFirst('Exception: ', '');

  if (raw.contains('Invalid login credentials')) {
    return 'Incorrect email or password.';
  }
  if (raw.contains('User already registered')) {
    return 'This email is already registered. Please sign in.';
  }
  if (raw.contains('Email not confirmed')) {
    return 'Please confirm your email first. Check your inbox for the code.';
  }
  if (raw.toLowerCase().contains('rate limit') ||
      raw.toLowerCase().contains('security purposes')) {
    return 'Please wait a moment before trying again.';
  }
  if (raw.toLowerCase().contains('token has expired') ||
      raw.toLowerCase().contains('invalid token') ||
      raw.toLowerCase().contains('invalid or expired')) {
    return 'That code is invalid or expired. Please request a new one.';
  }
  if (raw.contains('Only University of Mindanao') ||
      raw.contains('@umindanao.edu.ph')) {
    return 'Only University of Mindanao emails are allowed.';
  }
  if (raw.contains('You must be signed in') ||
      raw.contains('You must be logged in')) {
    return 'You must be signed in to do that.';
  }
  if (raw.toLowerCase().contains('password should be at least') ||
      raw.toLowerCase().contains('at least 6 characters')) {
    return 'Password must be at least 6 characters.';
  }
  if (raw.toLowerCase().contains('network') ||
      raw.toLowerCase().contains('connection') ||
      raw.toLowerCase().contains('timed out') ||
      raw.toLowerCase().contains('failed host lookup') ||
      raw.toLowerCase().contains('socket')) {
    return 'Network error. Please check your connection and try again.';
  }
  if (raw.trim().isEmpty) {
    return 'Something went wrong. Please try again.';
  }
  return raw;
}
