import 'package:drift/drift.dart';

import 'database.dart';
import 'xmltv_parser.dart';

/// Batch-writes parsed XMLTV data into the Drift [EpgProgrammes] table.
///
/// Uses Drift's batch API for efficient bulk inserts, and
/// [InsertMode.insertOrReplace] to gracefully handle duplicate
/// `(channelId, start)` primary keys.
class EpgWriter {
  /// Inserts programmes from a parsed XMLTV result into the database.
  ///
  /// [database] is the Drift [AppDatabase] instance.
  /// [result] is the output of [XmltvParser.parse] or [XmltvParser.parseGzip].
  ///
  /// Returns the number of programmes written.
  static Future<int> write(
    AppDatabase database,
    XmltvParseResult result,
  ) async {
    if (result.programmes.isEmpty) return 0;

    var count = 0;
    await database.batch((batch) {
      for (final p in result.programmes) {
        batch.insert(
          database.epgProgrammes,
          EpgProgrammesCompanion.insert(
            channelId: p.channelId,
            start: p.start,
            stop: p.stop,
            title: p.title,
            description: Value(p.description),
          ),
          mode: InsertMode.insertOrReplace,
        );
        count++;
      }
    });

    return count;
  }
}
