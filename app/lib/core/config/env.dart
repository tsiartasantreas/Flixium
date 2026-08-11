/// Reads build-time config supplied via `--dart-define`.
///
/// Centralizes env access so secrets never leak into widgets. The Supabase
/// anon key is safe to ship; the service-role key MUST NEVER appear here.
class Env {
  Env._();

  // Supabase project URL — public knowledge, safe to hardcode.
  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zosckkklctvrsjqjmyiv.supabase.co',
  );

  // Supabase preshareable key — safe to ship in client apps.
  // This replaces the old JWT-based anon key format.
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_ntuO3AUCB1XfdHpBWJwSxQ_q9CRlLFK',
  );

  static String get supabaseUrl {
    if (_supabaseUrl.isEmpty) {
      throw StateError(
        'SUPABASE_URL not set. Run with --dart-define=SUPABASE_URL=...',
      );
    }
    return _supabaseUrl;
  }

  static String get supabaseAnonKey {
    if (_supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY not set. Run with --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    return _supabaseAnonKey;
  }

  /// True when both are configured. Lets the app run a placeholder in CI / first
  /// boot before Supabase wiring exists.
  static bool get isConfigured =>
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;
}
