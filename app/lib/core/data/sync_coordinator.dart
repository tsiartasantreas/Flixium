import 'dart:async';

import '../entitlement/entitlement_service.dart';
import 'favorites_service.dart';
import 'playlist_sync_service.dart';
import 'supabase_client.dart';
import 'watch_progress_service.dart';

/// Coordinates two-way cloud sync across local persistence services
/// (favourites, watch progress, playlists).
///
/// Use [maybeFullSync] after sign-in and on app open for returning users; it
/// is a safe no-op when Supabase is unavailable or nobody is signed in.
///
/// Usage:
/// ```dart
/// unawaited(SyncCoordinator.maybeFullSync());
/// ```
class SyncCoordinator {
  SyncCoordinator._() {
    _watchProgressService = WatchProgressService(
      entitlementService: _entitlementService,
    );
  }

  /// Shared singleton instance.
  static final SyncCoordinator instance = SyncCoordinator._();

  /// Guards against overlapping syncs (the coordinator is fire-and-forget
  /// from several places: login, app open, settings refresh).
  static bool _syncing = false;

  final FavoritesService _favoritesService = FavoritesService();
  final EntitlementService _entitlementService = EntitlementService();
  late final WatchProgressService _watchProgressService;

  /// Runs [fullSync] only when Supabase is initialized and a user is signed
  /// in; otherwise returns immediately.
  static Future<void> maybeFullSync() async {
    if (!SupabaseService.isInitialized) return;
    if (SupabaseService.client.auth.currentUser == null) return;
    await instance.fullSync();
  }

  /// Pushes local favourites, watch progress, and playlists to the cloud,
  /// then merges cloud rows back into the local database.
  ///
  /// Favourites sync for any signed-in user; watch-progress and playlist
  /// sync are Pro-only and gated internally by [WatchProgressService] and
  /// [PlaylistSyncService] respectively. All errors are logged
  /// and swallowed — sync must never disrupt the UI flow that triggered it.
  Future<void> fullSync() async {
    if (_syncing) return; // A sync is already in flight.
    _syncing = true;
    try {
      // Refresh the tier cache so the Pro-gated watch-progress sync can run.
      await _entitlementService.refreshTier();

      // Push local state first so newly-added items exist in the cloud,
      // then pull remote changes (merge-only; nothing local is deleted).
      await _favoritesService.syncToCloud();
      await _favoritesService.syncFromCloud();

      await _watchProgressService.syncToCloud();
      await _watchProgressService.syncFromCloud();

      await PlaylistSyncService.instance.syncToCloud();
      await PlaylistSyncService.instance.syncFromCloud();
    } catch (e) {
      // ignore: avoid_print
      print('[SyncCoordinator] fullSync failed: $e');
    } finally {
      _syncing = false;
    }
  }
}
