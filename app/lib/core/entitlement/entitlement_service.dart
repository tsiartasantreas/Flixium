import 'package:supabase/supabase.dart';

import '../auth/auth_service.dart';
import '../data/supabase_client.dart';

// Parameter names intentionally differ from field names (client vs _client),
// so the initializer list is the correct pattern here.
// ignore_for_file: prefer_initializing_formals

/// Checks the current user's subscription tier by querying the Supabase
/// `profiles` table.
///
/// The tier is cached locally after the first fetch and can be explicitly
/// refreshed via [refreshTier]. On app start the caller should invoke
/// [refreshTier] so the cache is up-to-date.
class EntitlementService {
  EntitlementService({
    SupabaseClient? client,
    AuthService? authService,
  })  : _client = client,
        _authService = authService;

  final SupabaseClient? _client;
  final AuthService? _authService;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  /// Cached tier value. Defaults to `'free'` (anonymous / no profile).
  String _tier = 'free';

  /// Whether the profile row indicates admin.
  bool _isAdmin = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the current user's tier string (e.g. `"free"`, `"pro"`).
  ///
  /// Returns the cached value if available; otherwise queries Supabase.
  Future<String> getTier() async {
    if (_tier != 'free') return _tier;
    await refreshTier();
    return _tier;
  }

  /// Whether the current user has a pro subscription.
  bool get isPro => _tier == 'pro';

  /// Whether no user is currently signed in.
  bool get isAnonymous {
    final user = _authService?.currentUser ??
        (SupabaseService.isInitialized
            ? SupabaseService.client.auth.currentUser
            : null);
    return user == null;
  }

  /// Whether the current user is an admin (from `profiles.is_admin`).
  bool get isAdmin => _isAdmin;

  /// Re-fetches the tier (and admin status) from Supabase.
  ///
  /// Call this on app start and after auth state changes.
  Future<void> refreshTier() async {
    final user = _authService?.currentUser ??
        (SupabaseService.isInitialized
            ? SupabaseService.client.auth.currentUser
            : null);
    if (user == null) {
      _tier = 'free';
      _isAdmin = false;
      return;
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select('tier, is_admin')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        _tier = (response['tier'] as String?) ?? 'free';
        _isAdmin = response['is_admin'] as bool? ?? false;
      } else {
        _tier = 'free';
        _isAdmin = false;
      }
    } catch (_) {
      // On network / RLS errors, keep the cached tier.
    }
  }
}
