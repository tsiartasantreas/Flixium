import 'package:drift/drift.dart';

/// Represents an M3U playlist source (local file or remote URL).
@DataClassName('Playlist')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// User-visible name (e.g. "My IPTV Provider").
  TextColumn get name => text()();

  /// M3U source URL or local file path.
  /// Stored encrypted (AES-256-CBC) when the user is authenticated.
  TextColumn get url => text()();

  /// `local` or `remote`.
  TextColumn get type => text()();

  /// When the playlist was last fetched / re-imported.
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  /// Supabase user UUID. Null for anonymous / guest playlists.
  TextColumn get userId => text().nullable()();

  /// Xtream Codes username (encrypted). Null for standard M3U playlists.
  TextColumn get username => text().nullable()();

  /// Xtream Codes password (encrypted). Null for standard M3U playlists.
  TextColumn get password => text().nullable()();
}
