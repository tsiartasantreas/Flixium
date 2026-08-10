import 'package:drift/drift.dart';

import 'playlists.dart';

/// A radio station parsed from an M3U playlist.
@DataClassName('RadioStation')
class RadioStations extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// References [Playlists.id].
  IntColumn get playlistId => integer().references(Playlists, #id)();

  /// Station name.
  TextColumn get name => text()();

  /// Station logo URL.
  TextColumn get logo => text().nullable()();

  /// Stream URL.
  TextColumn get url => text()();
}
