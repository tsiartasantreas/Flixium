import 'package:drift/drift.dart';

import 'series.dart';

/// A single episode within a [TvSeries].
///
/// Drift auto-generates the data class as `EpisodeData`.
class Episodes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// References [TvSeries.id].
  IntColumn get seriesId => integer().references(TvSeries, #id)();

  /// Season number (1-based).
  IntColumn get season => integer()();

  /// Episode number within the season (1-based).
  IntColumn get episode => integer()();

  /// Episode title.
  TextColumn get title => text()();

  /// Stream URL.
  TextColumn get url => text()();

  /// Thumbnail / still URL.
  TextColumn get thumbnail => text().nullable()();
}
