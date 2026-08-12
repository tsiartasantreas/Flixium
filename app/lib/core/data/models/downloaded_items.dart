import 'package:drift/drift.dart';

/// Tracks media content downloaded for offline playback.
@DataClassName('DownloadedItem')
class DownloadedItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Unique content identifier (matches the contentId used throughout the app).
  TextColumn get contentId => text()();

  /// Human-readable title (e.g. "Breaking Bad S01E01").
  TextColumn get title => text()();

  /// Absolute path to the downloaded file on disk.
  TextColumn get filePath => text()();

  /// File size in bytes.
  IntColumn get fileSize => integer()();

  /// When the download completed.
  DateTimeColumn get downloadedAt => dateTime()();

  /// Content category: `"movie"`, `"series"`, `"radio"`, or `"live"`.
  TextColumn get contentType => text()();

  /// Optional poster / thumbnail URL for display in the downloads grid.
  TextColumn get thumbnailUrl => text().nullable()();

  /// Optional URL for streaming (stored so we can re-download or share).
  TextColumn get streamUrl => text().nullable()();

  /// Download status: `"pending"`, `"downloading"`, `"completed"`, `"failed"`.
  /// Defaults to `"completed"` for backward compatibility.
  TextColumn get status => text().withDefault(const Constant('completed'))();

  /// Download progress fraction (0.0 to 1.0). Defaults to 0.0.
  RealColumn get progress => real().withDefault(const Constant(0.0))();
}
