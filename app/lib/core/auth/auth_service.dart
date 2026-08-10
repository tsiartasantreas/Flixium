import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_client.dart';

/// Result of a sign-in or sign-up operation.
///
/// Exactly one of [user] or [error] will be non-null.
class AuthResult {
  const AuthResult({this.user, this.error});

  /// The authenticated user on success.
  final User? user;

  /// A human-readable error message on failure.
  final String? error;

  /// Whether the operation succeeded.
  bool get isSuccess => user != null;
}

/// Thin wrapper around Supabase GoTrue authentication.
///
/// All Supabase auth interactions in the app should go through this service
/// so that the rest of the codebase is decoupled from the GoTrue API shape.
class AuthService {
  // ignore: prefer_initializing_formals
  AuthService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    if (SupabaseService.isInitialized) return SupabaseService.client;
    return null;
  }

  GoTrueClient? get _auth => _supabase?.auth;

  // ---------------------------------------------------------------------------
  // Current user
  // ---------------------------------------------------------------------------

  /// The currently signed-in user, or `null`.
  User? get currentUser => _auth?.currentUser;

  // ---------------------------------------------------------------------------
  // Auth state stream
  // ---------------------------------------------------------------------------

  /// A stream that emits the current [User] (or `null`) whenever the auth
  /// state changes (sign-in, sign-out, token refresh, etc.).
  Stream<User?> get authStateChanges {
    if (_auth == null) return const Stream.empty();
    return _auth!.onAuthStateChange.map((data) => data.session?.user);
  }

  // ---------------------------------------------------------------------------
  // Sign up
  // ---------------------------------------------------------------------------

  /// Creates a new account with [email] and [password].
  Future<AuthResult> signUp(String email, String password) async {
    if (_auth == null) {
      return const AuthResult(error: 'Supabase is not initialized.');
    }
    try {
      final response = await _auth!.signUp(
        email: email,
        password: password,
      );
      if (response.user != null) {
        return AuthResult(user: response.user);
      }
      return const AuthResult(error: 'Sign up failed. Please try again.');
    } on AuthException catch (e) {
      return AuthResult(error: e.message);
    } catch (e) {
      return AuthResult(error: 'Unexpected error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Sign in
  // ---------------------------------------------------------------------------

  /// Signs in with [email] and [password].
  Future<AuthResult> signIn(String email, String password) async {
    if (_auth == null) {
      return const AuthResult(error: 'Supabase is not initialized.');
    }
    try {
      final response = await _auth!.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        return AuthResult(user: response.user);
      }
      return const AuthResult(error: 'Sign in failed. Please try again.');
    } on AuthException catch (e) {
      return AuthResult(error: e.message);
    } catch (e) {
      return AuthResult(error: 'Unexpected error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth?.signOut();
  }
}
