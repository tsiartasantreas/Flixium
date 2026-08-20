import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_client.dart';
import 'profile_manager.dart';

/// Result of a sign-in or sign-up operation.
///
/// Exactly one of [user] or [error] will be non-null.
class AuthResult {
  const AuthResult({this.user, this.error});

  /// The authenticated user on success.
  final User? user;

  /// A human-readable error message on failure.
  final String? error;

  /// Whether the operation succeeded (user is authenticated).
  bool get isSuccess => user != null;
}

/// Thin wrapper around Supabase GoTrue authentication.
///
/// All Supabase auth interactions in the app should go through this service
/// so that the rest of the codebase is decoupled from the GoTrue API shape.
class AuthService {
  // ignore: prefer_initializing_formals
  AuthService({SupabaseClient? client, ProfileManager? profileManager}) : _client = client, _profileManager = profileManager;

  final SupabaseClient? _client;
  final ProfileManager? _profileManager;

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    if (SupabaseService.isInitialized) return SupabaseService.client;
    return null;
  }

  GoTrueClient? get _auth => _supabase?.auth;

  /// SharedPreferences key under which the signed-in user's email is cached
  /// so the app can restore its signed-in state across restarts.
  static const String cachedEmailKey = 'auth_user_email';

  /// Caches [email] in SharedPreferences. Errors are non-fatal.
  Future<void> _cacheEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cachedEmailKey, email);
    } catch (_) {
      // SharedPreferences failures must never break the auth flow.
    }
  }

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

  /// Creates a new account with [email], [password], and [name].
  ///
  /// Email confirmation is disabled — the user is auto-confirmed and
  /// signed in immediately after signup.
  Future<AuthResult> signUp(String email, String password, {required String name}) async {
    if (_auth == null) {
      return const AuthResult(error: 'Supabase is not initialized.');
    }
    try {
      final response = await _auth!.signUp(
        email: email,
        password: password,
        data: {'display_name': name},
      );
      if (response.user != null) {
        // Belt-and-braces: ensure a row exists in the cloud `profiles`
        // table. The `on_auth_user_created` DB trigger normally inserts
        // it, but if that trigger is not applied to the cloud DB the new
        // user would have no profile row (breaking tier/account lookups).
        await _ensureCloudProfile(
          userId: response.user!.id,
          email: response.user!.email ?? email,
          displayName: name,
        );

        // Create a local profile with the user's name.
        try {
          final pm = _profileManager ?? ProfileManager();
          await pm.createProfile(name);
        } catch (_) {
          // Profile creation failure is non-fatal.
        }

        // Persist the signed-in state so restarts keep the user logged in.
        await _cacheEmail(email);
        return AuthResult(user: response.user);
      }
      return const AuthResult(error: 'Sign up failed. Please try again.');
    } on AuthException catch (e) {
      return AuthResult(error: e.message);
    } catch (e) {
      return AuthResult(error: 'Unexpected error: $e');
    }
  }

  /// Ensures a row exists in the Supabase `profiles` table for [userId].
  ///
  /// The `on_auth_user_created` trigger normally handles this at signup
  /// time. This fallback covers the case where the trigger is missing on
  /// the cloud database: it first checks whether the row exists and, if
  /// absent, attempts an idempotent upsert on `id`. All errors are
  /// swallowed — a missing/denied profile write must never fail the
  /// signup itself (auth already succeeded at this point).
  Future<void> _ensureCloudProfile({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    final client = _supabase;
    if (client == null) return;
    // Only attempt with an authenticated session — without one the anon
    // role cannot read or write `profiles` (RLS).
    if (client.auth.currentSession == null) return;
    try {
      final existing = await client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (existing != null) return; // Trigger already handled it.
      await client.from('profiles').upsert({
        'id': userId,
        'email': email,
        'display_name': displayName,
        'tier': 'free',
      });
    } catch (_) {
      // Ignore — RLS may deny the write or the trigger may have raced us.
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
        // Persist the signed-in state so restarts keep the user logged in
        // (the Supabase session itself is persisted by the SDK).
        await _cacheEmail(email);
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
  ///
  /// Clears the cached email flag first (so the app can never get stuck
  /// showing a signed-in state) and then signs out of Supabase, which
  /// also invalidates the persisted session.
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cachedEmailKey);
    } catch (_) {
      // SharedPreferences failures must never block sign-out.
    }
    await _auth?.signOut();
  }
}
