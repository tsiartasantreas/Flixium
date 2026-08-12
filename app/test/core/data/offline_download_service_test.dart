import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/data/database.dart';
import 'package:iflixify/core/data/offline_download_service.dart';

void main() {
  late AppDatabase db;
  late OfflineDownloadService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = OfflineDownloadService.createForTesting(db: db);
  });

  tearDown(() async {
    OfflineDownloadService.resetInstance();
    await db.close();
  });

  group('isDownloaded', () {
    test('returns false when content is not downloaded', () async {
      final result = await service.isDownloaded('nonexistent_123');
      expect(result, isFalse);
    });

    test('returns true after inserting a download record', () async {
      // Insert a fake record directly.
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'movie_42',
              title: 'Test Movie',
              filePath: '/tmp/test.mp4',
              fileSize: 1024000,
              downloadedAt: DateTime.now(),
              contentType: 'movie',
            ),
          );

      final result = await service.isDownloaded('movie_42');
      expect(result, isTrue);
    });

    test('returns false for different content ID', () async {
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'movie_42',
              title: 'Test Movie',
              filePath: '/tmp/test.mp4',
              fileSize: 1024000,
              downloadedAt: DateTime.now(),
              contentType: 'movie',
            ),
          );

      final result = await service.isDownloaded('movie_99');
      expect(result, isFalse);
    });
  });

  group('getDownloadedItems', () {
    test('returns empty list when no items', () async {
      final items = await service.getDownloadedItems();
      expect(items, isEmpty);
    });

    test('returns all items ordered by downloadedAt descending', () async {
      // Insert items with different timestamps.
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'older',
              title: 'Older Movie',
              filePath: '/tmp/older.mp4',
              fileSize: 500000,
              downloadedAt: DateTime(2025, 1, 1),
              contentType: 'movie',
            ),
          );
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'newer',
              title: 'Newer Movie',
              filePath: '/tmp/newer.mp4',
              fileSize: 750000,
              downloadedAt: DateTime(2025, 6, 15),
              contentType: 'movie',
            ),
          );

      final items = await service.getDownloadedItems();
      expect(items.length, 2);
      // Newer first.
      expect(items.first.contentId, 'newer');
      expect(items.last.contentId, 'older');
    });
  });

  group('getDownloadedByType', () {
    test('filters items by content type', () async {
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'm1',
              title: 'Movie 1',
              filePath: '/tmp/m1.mp4',
              fileSize: 1000000,
              downloadedAt: DateTime(2025, 1, 1),
              contentType: 'movie',
            ),
          );
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 's1',
              title: 'Series 1',
              filePath: '/tmp/s1.mp4',
              fileSize: 2000000,
              downloadedAt: DateTime(2025, 1, 2),
              contentType: 'series',
            ),
          );
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'm2',
              title: 'Movie 2',
              filePath: '/tmp/m2.mp4',
              fileSize: 1500000,
              downloadedAt: DateTime(2025, 1, 3),
              contentType: 'movie',
            ),
          );

      final movies = await service.getDownloadedByType('movie');
      expect(movies.length, 2);
      expect(movies.every((i) => i.contentType == 'movie'), isTrue);

      final series = await service.getDownloadedByType('series');
      expect(series.length, 1);
      expect(series.first.contentId, 's1');
    });

    test('returns empty list for non-existent type', () async {
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'm1',
              title: 'Movie 1',
              filePath: '/tmp/m1.mp4',
              fileSize: 1000000,
              downloadedAt: DateTime.now(),
              contentType: 'movie',
            ),
          );

      final radio = await service.getDownloadedByType('radio');
      expect(radio, isEmpty);
    });
  });

  group('deleteDownload', () {
    test('removes database record for existing download', () async {
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'to_delete',
              title: 'Delete Me',
              filePath: '/tmp/delete_me.mp4',
              fileSize: 500000,
              downloadedAt: DateTime.now(),
              contentType: 'movie',
            ),
          );

      expect(await service.isDownloaded('to_delete'), isTrue);

      await service.deleteDownload('to_delete');

      expect(await service.isDownloaded('to_delete'), isFalse);
    });

    test('does nothing for non-existent content', () async {
      // Should not throw.
      await service.deleteDownload('nonexistent');
    });
  });

  group('cancelDownload', () {
    test('cancels an active download (no-op when nothing active)', () {
      // Should not throw.
      service.cancelDownload('not_downloading');
    });
  });

  group('getTotalDownloadSize', () {
    test('returns 0 when no items', () async {
      final size = await service.getTotalDownloadSize();
      expect(size, 0);
    });

    test('sums file sizes of all downloads', () async {
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'a',
              title: 'A',
              filePath: '/tmp/a',
              fileSize: 1000,
              downloadedAt: DateTime.now(),
              contentType: 'movie',
            ),
          );
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'b',
              title: 'B',
              filePath: '/tmp/b',
              fileSize: 2500,
              downloadedAt: DateTime.now(),
              contentType: 'movie',
            ),
          );

      final size = await service.getTotalDownloadSize();
      expect(size, 3500);
    });
  });

  group('getTotalDownloadSizeFormatted', () {
    test('formats bytes', () async {
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'tiny',
              title: 'Tiny',
              filePath: '/tmp/tiny',
              fileSize: 512,
              downloadedAt: DateTime.now(),
              contentType: 'movie',
            ),
          );

      final formatted = await service.getTotalDownloadSizeFormatted();
      expect(formatted, '512 B');
    });

    test('formats kilobytes', () async {
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'kb',
              title: 'KB',
              filePath: '/tmp/kb',
              fileSize: 5120,
              downloadedAt: DateTime.now(),
              contentType: 'movie',
            ),
          );

      final formatted = await service.getTotalDownloadSizeFormatted();
      expect(formatted, '5.0 KB');
    });

    test('formats megabytes', () async {
      await db.into(db.downloadedItems).insert(
            DownloadedItemsCompanion.insert(
              contentId: 'mb',
              title: 'MB',
              filePath: '/tmp/mb',
              fileSize: 5242880, // 5 MB
              downloadedAt: DateTime.now(),
              contentType: 'movie',
            ),
          );

      final formatted = await service.getTotalDownloadSizeFormatted();
      expect(formatted, '5.0 MB');
    });
  });
}
