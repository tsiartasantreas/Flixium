import 'package:supabase/supabase.dart';

import '../config/env.dart';

/// Singleton wrapper around the pure Dart Supabase client.
///
/// Uses the pure Dart `supabase` package (no native plugins) to avoid
/// crashes from `supabase_flutter`'s `app_links` native dependency on
/// Android 16.
///
/// Call [initialize] once at app startup or lazily when the user signs in.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;
  static SupabaseClient? _client;

  /// Initializes the pure Dart Supabase client with credentials from [Env].
  ///
  /// Safe to call multiple times -- only the first call has an effect.
  static Future<void> initialize() async {
    if (_initialized) return;
    _client = SupabaseClient(
      Env.supabaseUrl,
      Env.supabaseAnonKey,
    );
    _initialized = true;
  }

  /// The Supabase client instance.
  ///
  /// Throws if [initialize] has not been called.
  static SupabaseClient get client {
    if (_client == null) {
      throw StateError('SupabaseService not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Convenience accessor for the GoTrue (auth) client.
  static GoTrueClient get auth => client.auth;

  /// Whether Supabase has been initialized.
  static bool get isInitialized => _initialized;

  /// Exposed for testing -- allows resetting the initialized flag.
  static void resetForTesting() {
    _initialized = false;
    _client = null;
  }
}
