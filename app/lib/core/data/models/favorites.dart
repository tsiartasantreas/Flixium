import 'package:drift/drift.dart';

/// A user bookmarked / favourited item.
///
/// Uses a polymorphic key: [contentId] encodes both the entity type
/// and its integer ID (e.g. `"channel:42"`, `"vod:7"`, `"series:19"`).
@DataClassName('Favorite')
class Favorites extends Table {
  /// Polymorphic ID, e.g. `"channel:42"`.
  TextColumn get contentId => text()();

  /// Entity type: `"channel"`, `"vod"`, or `"series"`.
  TextColumn get contentType => text()();

  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {contentId};
}
