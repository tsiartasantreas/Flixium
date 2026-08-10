import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Singleton wrapper around the Supabase Flutter client.
///
/// Call [initialize] once at app startup (before any Supabase interaction).
/// After that, use [client] or [auth] to access Supabase services.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  /// Initializes the Supabase Flutter SDK with credentials from [Env].
  ///
  /// Safe to call multiple times -- only the first call has an effect.
  static Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
    _initialized = true;
  }

  /// The Supabase client instance.
  ///
  /// Throws if [initialize] has not been called.
  static SupabaseClient get client => Supabase.instance.client;

  /// Convenience accessor for the GoTrue (auth) client.
  static GoTrueClient get auth => client.auth;

  /// Whether Supabase has been initialized.
  static bool get isInitialized => _initialized;

  /// Exposed for testing -- allows resetting the initialized flag.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
  }
}
