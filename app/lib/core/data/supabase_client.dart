import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Singleton wrapper around the Supabase Flutter client.
///
/// Call [initialize] once at app startup or lazily when the user signs in.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  /// Initializes the Supabase Flutter SDK with credentials from [Env].
  ///
  /// Safe to call multiple times -- only the first call has an effect.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      // ignore: avoid_print
      print('[SupabaseService] Initializing with URL: ${Env.supabaseUrl}');
      // ignore: deprecated_member_use
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
      _initialized = true;
      // ignore: avoid_print
      print('[SupabaseService] Initialized successfully');
    } catch (e, st) {
      // ignore: avoid_print
      print('[SupabaseService] initialize failed: $e\n$st');
      rethrow;
    }
  }

  /// The Supabase client instance.
  ///
  /// Throws if [initialize] has not been called.
  static SupabaseClient get client => Supabase.instance.client;

  /// Convenience accessor for the GoTrue (auth) client.
  static GoTrueClient get auth => client.auth;

  /// Whether Supabase has been initialized.
  static bool get isInitialized => _initialized;

  /// Resets the initialized flag so that [initialize] can be called again.
  ///
  /// Use this when the Supabase client is in a bad state (e.g. after sign-out
  /// followed by a failed sign-in that corrupts the auth state). The next
  /// call to [initialize] will create a fresh client.
  static void reset() {
    _initialized = false;
  }

  /// Exposed for testing -- allows resetting the initialized flag.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
  }
}
