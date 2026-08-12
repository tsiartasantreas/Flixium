import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'database.dart';

/// Callback for tracking download progress as a percentage (0.0 to 1.0).
typedef ProgressCallback = void Function(double progress);

/// High-level download service for offline viewing of movies and series.
///
/// Downloads video files to the device's app documents directory and tracks
/// state in the Drift [DownloadedItems] table.
///
/// Files are stored under `<documents>/flixium_downloads/`.
class DownloadService {
  DownloadService({
    required this._db,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final AppDatabase _db;
  final http.Client _client;
  final Map<String, StreamSubscription<dynamic>> _activeDownloads = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Starts downloading content from [url].
  ///
  /// - [url]   -- remote video/stream URL.
  /// - [title] -- display title for the download record.
  /// - [type]  -- content type: `"movie"`, `"series"`, etc.
  /// - [thumbnailUrl] -- optional poster image URL.
  /// - [onProgress]   -- called with progress fraction (0.0-1.0).
  ///
  /// Returns the database id of the inserted record on success.
  Future<int> startDownload(
    String url,
    String title,
    String type, {
    String? thumbnailUrl,
    ProgressCallback? onProgress,
  }) async {
    final contentId = '${type}_${title.hashCode.toRadixString(16)}';

    // Don't download twice.
    if (await isDownloaded(contentId)) {
      final existing = await (_db.select(_db.downloadedItems)
            ..where((t) => t.contentId.equals(contentId))
            ..limit(1))
          .getSingleOrNull();
      return existing?.id ?? -1;
    }

    final dir = await _getDownloadDirectory();
    final safeName = _safeFilename(contentId);
    final file = File('${dir.path}/$safeName');

    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw DownloadException(
        'HTTP ${response.statusCode} downloading $url',
      );
    }

    final contentLength = response.contentLength ?? 0;
    var received = 0;

    final sink = file.openWrite();
    final completer = Completer<void>();

    final subscription = response.stream.listen(
      (chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress?.call(received / contentLength);
        }
      },
      onDone: () async {
        await sink.close();
        completer.complete();
      },
      onError: (Object error) async {
        await sink.close();
        completer.completeError(error);
      },
    );

    _activeDownloads[contentId] = subscription;

    await completer.future;
    _activeDownloads.remove(contentId);

    final fileSize = await file.length();

    final id = await _db.into(_db.downloadedItems).insert(
          DownloadedItemsCompanion.insert(
            contentId: contentId,
            title: title,
            filePath: file.path,
            fileSize: fileSize,
            downloadedAt: DateTime.now(),
            contentType: type,
            thumbnailUrl: drift.Value(thumbnailUrl),
            streamUrl: drift.Value(url),
          ),
        );

    return id;
  }

  /// Cancels an in-progress download identified by [contentId].
  void cancelDownload(String contentId) {
    final sub = _activeDownloads.remove(contentId);
    sub?.cancel();
  }

  /// Deletes the downloaded file and its database record.
  Future<void> deleteDownload(String contentId) async {
    final item = await (_db.select(_db.downloadedItems)
          ..where((t) => t.contentId.equals(contentId)))
        .getSingleOrNull();

    if (item == null) return;

    final file = File(item.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    await (_db.delete(_db.downloadedItems)
          ..where((t) => t.id.equals(item.id)))
        .go();
  }

  /// Returns all downloaded items, newest first.
  Future<List<DownloadedItem>> getDownloads() async {
    return (_db.select(_db.downloadedItems)
          ..orderBy([(t) => drift.OrderingTerm.desc(t.downloadedAt)]))
        .get();
  }

  /// Returns `true` if content with [contentId] is already downloaded.
  Future<bool> isDownloaded(String contentId) async {
    final item = await (_db.select(_db.downloadedItems)
          ..where((t) => t.contentId.equals(contentId))
          ..limit(1))
        .getSingleOrNull();
    return item != null;
  }

  /// Returns the local file path for a downloaded item, or `null` if not
  /// downloaded.
  Future<String?> getLocalPath(String contentId) async {
    final item = await (_db.select(_db.downloadedItems)
          ..where((t) => t.contentId.equals(contentId))
          ..limit(1))
        .getSingleOrNull();
    return item?.filePath;
  }

  /// Returns total disk usage (bytes) of all downloads.
  Future<int> getTotalSize() async {
    final items = await getDownloads();
    return items.fold<int>(0, (sum, item) => sum + item.fileSize);
  }

  /// Returns total disk usage as a human-readable string.
  Future<String> getTotalSizeFormatted() async {
    return _formatBytes(await getTotalSize());
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Directory> _getDownloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dlDir = Directory('${appDir.path}/flixium_downloads');
    if (!await dlDir.exists()) {
      await dlDir.create(recursive: true);
    }
    return dlDir;
  }

  static String _safeFilename(String contentId) {
    final safe = contentId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '${safe}_${contentId.hashCode.toRadixString(16)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Releases HTTP client resources.
  void dispose() => _client.close();
}

/// Exception thrown when a download fails.
class DownloadException implements Exception {
  const DownloadException(this.message);
  final String message;

  @override
  String toString() => 'DownloadException: $message';
}
