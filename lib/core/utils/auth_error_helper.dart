import 'package:supabase_flutter/supabase_flutter.dart';

/// Formats raw error objects (such as network socket errors or Supabase AuthExceptions)
/// into clean, user-friendly messages for mobile display.
String formatAuthError(Object error) {
  if (error is AuthException) {
    // Specific friendly translations for common Supabase auth errors
    final msg = error.message;
    if (msg.contains('User already registered')) {
      return 'An account with this email already exists. Please log in instead.';
    }
    if (msg.contains('Password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('Invalid login credentials')) {
      return 'Invalid email or password. Please verify and try again.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Please confirm your email address before logging in.';
    }
    return msg;
  }

  final str = error.toString().toLowerCase();

  // Network / DNS / Host lookup / Socket errors
  if (str.contains('failed host lookup') ||
      str.contains('no address associated with hostname') ||
      str.contains('errno = 7') ||
      str.contains('socket') ||
      str.contains('clientexception') ||
      str.contains('authretryablefetchexception') ||
      str.contains('network') ||
      str.contains('connection refused') ||
      str.contains('timed out') ||
      str.contains('handshakeexception')) {
    return 'Unable to reach the server. Please check your internet connection and try again.';
  }

  return error.toString().replaceAll('Exception:', '').trim();
}
