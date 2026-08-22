import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Base number of devices every user may activate, before any purchased
  /// device license extension packs.
  static const int baseDeviceLimit = 5;

  /// Cached device limit (base + purchased extensions). `null` until the
  /// first refresh.
  int? _cachedDeviceLimit;

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

  /// Whether the current user may use Pro features (Pro tier or admin).
  ///
  /// Convenience helper for gating Continue Watching / Up Next, cross-device
  /// sync, multi-user profiles, and other Pro-only features. Anonymous and
  /// free users get `false`.
  Future<bool> get canUseProFeatures async =>
      (await getTier()) == 'pro' || isAdmin;

  /// The maximum number of devices the current user may activate.
  ///
  /// [baseDeviceLimit] (5) plus the sum of `additional_devices` from the
  /// user's purchased `device_license_extensions` packs ($3.99 per +5).
  /// Returns [baseDeviceLimit] when not signed in or on network / RLS
  /// errors. Cached and refreshed with the same pattern as the tier (see
  /// [refreshTier]).
  Future<int> get deviceLimit async {
    if (_cachedDeviceLimit != null) return _cachedDeviceLimit!;
    final user = _authService?.currentUser ??
        (SupabaseService.isInitialized
            ? SupabaseService.client.auth.currentUser
            : null);
    if (user == null) return baseDeviceLimit;
    await _refreshDeviceLimit(user.id);
    return _cachedDeviceLimit ?? baseDeviceLimit;
  }

  /// Re-fetches the tier (and admin status) and the device limit from
  /// Supabase.
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
      _cachedDeviceLimit = baseDeviceLimit;
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

    await _refreshDeviceLimit(user.id);
  }

  /// Re-fetches the device limit for [userId] (base + purchased device
  /// license extension packs).
  ///
  /// On error the cached value is kept, defaulting to the base limit.
  Future<void> _refreshDeviceLimit(String userId) async {
    try {
      final response = await _supabase
          .from('device_license_extensions')
          .select('additional_devices')
          .eq('user_id', userId);

      var total = baseDeviceLimit;
      for (final row in response) {
        final additional = row['additional_devices'] as int?;
        if (additional != null && additional > 0) {
          total += additional;
        }
      }
      _cachedDeviceLimit = total;
    } catch (_) {
      // On network / RLS errors, keep the cached limit (base if none yet).
      _cachedDeviceLimit ??= baseDeviceLimit;
    }
  }
}
