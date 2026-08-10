import 'package:drift/drift.dart';

/// An EPG (Electronic Programme Guide) entry for a channel.
///
/// Note: [channelId] is a string-based external ID (from the EPG provider),
/// not the integer primary key of the local [Channels] table.
@DataClassName('EpgProgramme')
class EpgProgrammes extends Table {
  /// External channel ID from the EPG source (e.g. "BBC.ONE.HD").
  TextColumn get channelId => text()();

  DateTimeColumn get start => dateTime()();
  DateTimeColumn get stop => dateTime()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {channelId, start};
}
