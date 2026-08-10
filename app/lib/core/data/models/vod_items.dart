import 'package:drift/drift.dart';

import 'playlists.dart';

/// A standalone movie / VOD item parsed from an M3U playlist.
@DataClassName('VodItem')
class VodItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// References [Playlists.id].
  IntColumn get playlistId => integer().references(Playlists, #id)();

  /// Movie title.
  TextColumn get title => text()();

  /// Poster image URL (`tvg-logo`).
  TextColumn get poster => text().nullable()();

  /// Stream URL.
  TextColumn get url => text()();

  /// M3U `group-title` (e.g. "Movies 4K", "Action").
  TextColumn get groupTitle => text().nullable()();
}
