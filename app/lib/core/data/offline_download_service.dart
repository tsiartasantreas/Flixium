import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';

/// Callback for tracking download progress.
typedef DownloadProgressCallback = void Function(double progress);

/// Manages offline media downloads using the app's documents directory.
///
/// Files are stored in `<documents>/flixium_downloads/` and tracked in the
/// [DownloadedItems] Drift table.
class OfflineDownloadService {
  OfflineDownloadService({
    required this._db,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final AppDatabase _db;
  final http.Client _client;
  final Map<String, StreamSubscription<dynamic>> _activeDownloads = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Downloads content from [url] and stores it locally.
  ///
  /// The file is saved under `<documents>/flixium_downloads/` with a safe
  /// filename derived from [contentId].  Progress is reported through
  /// [onProgress] if provided.
  Future<void> downloadContent({
    required String contentId,
    required String url,
    required String title,
    required String contentType,
    String? thumbnailUrl,
    DownloadProgressCallback? onProgress,
  }) async {
    // Don't download twice.
    if (await isDownloaded(contentId)) return;

    final dir = await _getDownloadDirectory();
    final safeName = _safeFilename(contentId);
    final file = File('${dir.path}/$safeName');

    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw OfflineDownloadException(
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

    // Insert record into database.
    await _db.into(_db.downloadedItems).insert(
          DownloadedItemsCompanion.insert(
            contentId: contentId,
            title: title,
            filePath: file.path,
            fileSize: fileSize,
            downloadedAt: DateTime.now(),
            contentType: contentType,
            thumbnailUrl: drift.Value(thumbnailUrl),
            streamUrl: drift.Value(url),
          ),
        );
  }

  /// Cancels an in-progress download.
  void cancelDownload(String contentId) {
    final sub = _activeDownloads.remove(contentId);
    sub?.cancel();
  }

  /// Returns all downloaded items, newest first.
  Future<List<DownloadedItem>> getDownloadedItems() async {
    final items = await (_db.select(_db.downloadedItems)
          ..orderBy([(t) => drift.OrderingTerm.desc(t.downloadedAt)]))
        .get();
    return items;
  }

  /// Returns downloaded items filtered by content type.
  Future<List<DownloadedItem>> getDownloadedByType(String contentType) async {
    final items = await (_db.select(_db.downloadedItems)
          ..where((t) => t.contentType.equals(contentType))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.downloadedAt)]))
        .get();
    return items;
  }

  /// Deletes the downloaded file and removes the database record.
  Future<void> deleteDownload(String contentId) async {
    final item = await (_db.select(_db.downloadedItems)
          ..where((t) => t.contentId.equals(contentId)))
        .getSingleOrNull();

    if (item == null) return;

    // Remove file from disk.
    final file = File(item.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    // Remove database record.
    await (_db.delete(_db.downloadedItems)
          ..where((t) => t.id.equals(item.id)))
        .go();
  }

  /// Returns `true` if the content is already downloaded.
  Future<bool> isDownloaded(String contentId) async {
    final item = await (_db.select(_db.downloadedItems)
          ..where((t) => t.contentId.equals(contentId))
          ..limit(1))
        .getSingleOrNull();
    return item != null;
  }

  /// Returns total disk usage (bytes) of all downloaded files.
  Future<int> getTotalDownloadSize() async {
    final items = await getDownloadedItems();
    return items.fold<int>(0, (sum, item) => sum + item.fileSize);
  }

  /// Returns a human-readable string for total download size.
  Future<String> getTotalDownloadSizeFormatted() async {
    final bytes = await getTotalDownloadSize();
    return _formatBytes(bytes);
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

  /// Creates a safe filename from [contentId], replacing non-alphanumeric
  /// characters with underscores and appending a hash to avoid collisions.
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

  /// Releases resources.
  void close() => _client.close();
}

/// Exception thrown when an offline download fails.
class OfflineDownloadException implements Exception {
  const OfflineDownloadException(this.message);

  final String message;

  @override
  String toString() => 'OfflineDownloadException: $message';
}
