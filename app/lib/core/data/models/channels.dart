import 'package:drift/drift.dart';

import 'playlists.dart';

/// A live-TV channel parsed from an M3U playlist.
@DataClassName('Channel')
class Channels extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// References [Playlists.id].
  IntColumn get playlistId => integer().references(Playlists, #id)();

  /// Display name (e.g. "BBC One HD").
  TextColumn get name => text()();

  /// Channel logo URL (`tvg-logo`).
  TextColumn get logo => text().nullable()();

  /// Stream URL.
  TextColumn get url => text()();

  /// M3U `group-title` (e.g. "Sports", "Entertainment").
  TextColumn get groupTitle => text().nullable()();

  /// M3U `tvg-name` (EPG matching key).
  TextColumn get tvgName => text().nullable()();
}
