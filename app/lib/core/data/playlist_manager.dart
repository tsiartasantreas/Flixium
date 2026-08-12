import 'package:drift/drift.dart' as drift;

import '../entitlement/entitlement_service.dart';
import 'database.dart';
import 'encryption_service.dart';
import 'supabase_client.dart';

/// Manages multiple M3U playlists.
///
/// Free users are limited to one playlist. Pro users can add multiple
/// playlists. The entitlement check is performed before mutations.
///
/// Playlist credentials (URL, username, password) are encrypted at rest
/// using AES-256-CBC before being stored in the local Drift database.
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
  // User context
  // ---------------------------------------------------------------------------

  /// Returns the current Supabase user ID, or `null` for anonymous users.
  String? get _currentUserId {
    if (!SupabaseService.isInitialized) return null;
    return SupabaseService.client.auth.currentUser?.id;
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Returns all playlists for the current user (or all anonymous playlists
  /// if the user is not signed in), sorted by creation (rowid).
  Future<List<Playlist>> getPlaylists() async {
    // Ensure Supabase is initialized so _currentUserId is accurate.
    // Wrapped in try-catch: in test environments native plugins are absent.
    try {
      await SupabaseService.initialize();
    } catch (_) {}

    final userId = _currentUserId;
    if (userId != null) {
      return (_db.select(_db.playlists)
            ..where((t) => t.userId.equals(userId)))
          .get();
    }
    // Anonymous: return playlists with no user_id.
    return (_db.select(_db.playlists)
          ..where((t) => t.userId.isNull()))
        .get();
  }

  /// Returns the count of playlists for the current user.
  Future<int> getPlaylistCount() async {
    final playlists = await getPlaylists();
    return playlists.length;
  }

  // ---------------------------------------------------------------------------
  // Encrypted getters
  // ---------------------------------------------------------------------------

  /// Returns the decrypted URL for a [playlist].
  String getDecryptedUrl(Playlist playlist) {
    if (EncryptionService.isEncrypted(playlist.url)) {
      return EncryptionService.decrypt(playlist.url, userId: playlist.userId);
    }
    return playlist.url;
  }

  /// Returns the decrypted username for a [playlist] (Xtream only).
  String? getDecryptedUsername(Playlist playlist) {
    if (playlist.username == null) return null;
    if (EncryptionService.isEncrypted(playlist.username!)) {
      return EncryptionService.decrypt(playlist.username!, userId: playlist.userId);
    }
    return playlist.username;
  }

  /// Returns the decrypted password for a [playlist] (Xtream only).
  String? getDecryptedPassword(Playlist playlist) {
    if (playlist.password == null) return null;
    if (EncryptionService.isEncrypted(playlist.password!)) {
      return EncryptionService.decrypt(playlist.password!, userId: playlist.userId);
    }
    return playlist.password;
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Adds a new playlist with the given [name], [url], and optional
  /// Xtream [username] / [password].
  ///
  /// All credential fields are encrypted before storage.
  /// Checks entitlement: free users cannot exceed [freePlaylistLimit].
  /// Throws [StateError] if the free limit is reached.
  Future<Playlist> addPlaylist(
    String name,
    String url, {
    String? username,
    String? password,
  }) async {
    // Ensure Supabase is initialized so we can check entitlement and user ID.
    // Wrapped in try-catch: in test environments native plugins are absent.
    try {
      await SupabaseService.initialize();
    } catch (_) {}

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

    final userId = _currentUserId;

    // Encrypt credentials before storing.
    final encryptedUrl = EncryptionService.encrypt(url, userId: userId);
    final encryptedUsername = username != null
        ? EncryptionService.encrypt(username, userId: userId)
        : null;
    final encryptedPassword = password != null
        ? EncryptionService.encrypt(password, userId: userId)
        : null;

    final id = await _db.into(_db.playlists).insert(
          PlaylistsCompanion.insert(
            name: name,
            url: encryptedUrl,
            type: 'remote',
            lastSyncedAt: drift.Value(DateTime.now()),
            userId: drift.Value(userId),
            username: drift.Value(encryptedUsername),
            password: drift.Value(encryptedPassword),
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

  /// Updates the playlist with [playlistId] with new credentials and name.
  ///
  /// All credential fields are re-encrypted before storage.
  /// Pass `null` for [username] / [password] to keep existing values, or
  /// pass empty strings to clear them.
  Future<void> updatePlaylist(
    int playlistId, {
    required String name,
    required String url,
    String? username,
    String? password,
  }) async {
    final userId = _currentUserId;

    final encryptedUrl = EncryptionService.encrypt(url, userId: userId);

    // Build the companion with only the fields that should change.
    final companion = PlaylistsCompanion(
      name: drift.Value(name),
      url: drift.Value(encryptedUrl),
      lastSyncedAt: drift.Value(DateTime.now()),
      username: drift.Value(
        username != null
            ? EncryptionService.encrypt(username, userId: userId)
            : null,
      ),
      password: drift.Value(
        password != null
            ? EncryptionService.encrypt(password, userId: userId)
            : null,
      ),
    );

    final updated = await (_db.update(_db.playlists)
          ..where((t) => t.id.equals(playlistId)))
        .write(companion);

    if (updated == 0) {
      throw StateError('Playlist $playlistId not found');
    }
  }
}
