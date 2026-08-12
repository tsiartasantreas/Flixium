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

  /// Plot / overview description.
  TextColumn get description => text().nullable()();

  /// Rating (e.g. "7.5", "PG-13").
  TextColumn get rating => text().nullable()();

  /// Genre(s) (e.g. "Action, Comedy").
  TextColumn get genre => text().nullable()();

  /// Cast (comma-separated names).
  TextColumn get cast => text().nullable()();

  /// Director name(s).
  TextColumn get director => text().nullable()();

  /// Release date (e.g. "2024-01-15").
  TextColumn get releaseDate => text().nullable()();

  /// Country of origin (e.g. "United States of America").
  TextColumn get country => text().nullable()();

  /// YouTube trailer video ID or URL.
  TextColumn get youtubeTrailer => text().nullable()();

  /// Backdrop / fanart image URLs (JSON array of strings).
  TextColumn get backdropPath => text().nullable()();

  /// TMDB identifier.
  IntColumn get tmdbId => integer().nullable()();

  /// Duration string (e.g. "01:42:00").
  TextColumn get duration => text().nullable()();

  /// Whether the content is adult-only ("0" or "1").
  TextColumn get isAdult => text().nullable()();
}
