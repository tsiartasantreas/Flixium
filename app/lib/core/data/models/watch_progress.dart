import 'package:drift/drift.dart';

/// Playback resume position (Pro-only feature).
///
/// Uses the same polymorphic key scheme as [Favorites].
///
/// Drift auto-generates the data class as `WatchProgressEntryData`.
class WatchProgressEntry extends Table {
  /// Polymorphic content key, e.g. `"channel:42"`.
  TextColumn get contentId => text()();

  /// Playback position in milliseconds.
  IntColumn get positionMs => integer()();

  /// Total duration in milliseconds.
  IntColumn get durationMs => integer()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {contentId};
}
