import 'package:drift/drift.dart';

/// Represents an M3U playlist source (local file or remote URL).
@DataClassName('Playlist')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// User-visible name (e.g. "My IPTV Provider").
  TextColumn get name => text()();

  /// M3U source URL or local file path.
  TextColumn get url => text()();

  /// `local` or `remote`.
  TextColumn get type => text()();

  /// When the playlist was last fetched / re-imported.
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}
