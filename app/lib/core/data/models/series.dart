import 'package:drift/drift.dart';

import 'playlists.dart';

/// A TV series (season/episode entries live in [Episodes]).
///
/// Drift auto-generates the data class as `TvSeriesData`.
class TvSeries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// References [Playlists.id].
  IntColumn get playlistId => integer().references(Playlists, #id)();

  /// Series title.
  TextColumn get title => text()();

  /// Poster image URL (`tvg-logo` from first episode entry).
  TextColumn get poster => text().nullable()();
}
