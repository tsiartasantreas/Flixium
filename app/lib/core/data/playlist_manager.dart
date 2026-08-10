import 'package:drift/drift.dart' as drift;

import '../entitlement/entitlement_service.dart';
import 'database.dart';

/// Manages multiple M3U playlists.
///
/// Free users are limited to one playlist. Pro users can add multiple
/// playlists. The entitlement check is performed before mutations.
class PlaylistManager {
  PlaylistManager({
    AppDatabase? database,
    EntitlementService? entitlementService,
  })  : _db = database ?? AppDatabase(),
        _entitlement = entitlementService ?? EntitlementService();

  final AppDatabase _db;
  final EntitlementService _entitlement;

  /// Maximum playlists allowed for free users.
  static const int freePlaylistLimit = 1;

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Returns all playlists sorted by creation (rowid).
  Future<List<Playlist>> getPlaylists() async {
    return _db.select(_db.playlists).get();
  }

  /// Returns the count of playlists.
  Future<int> getPlaylistCount() async {
    final playlists = await _db.select(_db.playlists).get();
    return playlists.length;
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Adds a new playlist with the given [name] and [url].
  ///
  /// Checks entitlement: free users cannot exceed [freePlaylistLimit].
  /// Throws [StateError] if the free limit is reached.
  Future<Playlist> addPlaylist(String name, String url) async {
    final isPro = await _entitlement.getTier() == 'pro';
    if (!isPro) {
      final count = await getPlaylistCount();
      if (count >= freePlaylistLimit) {
        throw StateError(
          'Free users can only have $freePlaylistLimit playlist. '
          'Upgrade to Pro for unlimited playlists.',
        );
      }
    }

    final id = await _db.into(_db.playlists).insert(
          PlaylistsCompanion.insert(
            name: name,
            url: url,
            type: 'remote',
            lastSyncedAt: drift.Value(DateTime.now()),
          ),
        );

    return (_db.select(_db.playlists)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Deletes the playlist with [playlistId] and all its associated content.
  Future<void> deletePlaylist(int playlistId) async {
    // Delete child records first (foreign key constraints).
    await (_db.delete(_db.channels)
          ..where((t) => t.playlistId.equals(playlistId)))
        .go();
    await (_db.delete(_db.vodItems)
          ..where((t) => t.playlistId.equals(playlistId)))
        .go();
    await (_db.delete(_db.radioStations)
          ..where((t) => t.playlistId.equals(playlistId)))
        .go();

    // Delete episodes via series.
    final seriesIds = await (_db.select(_db.tvSeries)
          ..where((t) => t.playlistId.equals(playlistId)))
        .get();
    for (final s in seriesIds) {
      await (_db.delete(_db.episodes)
            ..where((t) => t.seriesId.equals(s.id)))
          .go();
    }
    await (_db.delete(_db.tvSeries)
          ..where((t) => t.playlistId.equals(playlistId)))
        .go();

    // Delete the playlist itself.
    final deleted = await (_db.delete(_db.playlists)
          ..where((t) => t.id.equals(playlistId)))
        .go();

    if (deleted == 0) {
      throw StateError('Playlist $playlistId not found');
    }
  }

  /// Renames the playlist with [playlistId] to [newName].
  Future<void> renamePlaylist(int playlistId, String newName) async {
    final updated = await (_db.update(_db.playlists)
          ..where((t) => t.id.equals(playlistId)))
        .write(PlaylistsCompanion(
      name: drift.Value(newName),
    ));

    if (updated == 0) {
      throw StateError('Playlist $playlistId not found');
    }
  }
}
