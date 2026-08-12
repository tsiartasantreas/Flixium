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

  /// Plot / overview description.
  TextColumn get description => text().nullable()();

  /// Rating (e.g. "8.2", "TV-MA").
  TextColumn get rating => text().nullable()();

  /// Genre(s) (e.g. "Drama, Thriller").
  TextColumn get genre => text().nullable()();

  /// Cast (comma-separated names).
  TextColumn get cast => text().nullable()();

  /// Director / creator name(s).
  TextColumn get director => text().nullable()();

  /// Release date (e.g. "2023-06-15").
  TextColumn get releaseDate => text().nullable()();
}
