import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';

/// Callback for tracking download progress.
typedef DownloadProgressCallback = void Function(double progress);

/// Represents the current state of a single download.
enum DownloadState { queued, downloading, completed, failed, cancelled }

/// Progress information for a download in the queue.
class DownloadProgress {
  const DownloadProgress({
    required this.contentId,
    required this.title,
    required this.contentType,
    required this.state,
    this.progress = 0.0,
    this.error,
    this.thumbnailUrl,
  });

  final String contentId;
  final String title;
  final String contentType;
  final DownloadState state;
  final double progress;
  final String? error;
  final String? thumbnailUrl;

  DownloadProgress copyWith({
    DownloadState? state,
    double? progress,
    String? error,
  }) {
    return DownloadProgress(
      contentId: contentId,
      title: title,
      contentType: contentType,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      thumbnailUrl: thumbnailUrl,
    );
  }
}

/// A task waiting in the download queue.
class _DownloadTask {
  const _DownloadTask({
    required this.contentId,
    required this.url,
    required this.title,
    required this.contentType,
    this.thumbnailUrl,
  });

  final String contentId;
  final String url;
  final String title;
  final String contentType;
  final String? thumbnailUrl;
}

/// Singleton download service that persists across widget lifecycles.
///
/// Downloads are queued and processed sequentially. Progress is broadcast via
/// a stream so any widget (DownloadButton, OfflineScreen, etc.) can observe
/// state changes without owning the service.
///
/// Files are stored under `<documents>/flixium_downloads/` and tracked in the
/// [DownloadedItems] Drift table.
class OfflineDownloadService {
  OfflineDownloadService._internal({
    required this._db,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static OfflineDownloadService? _instance;

  /// Returns the shared singleton instance.
  ///
  /// On first call, creates the instance with a fresh [AppDatabase].
  static OfflineDownloadService get instance {
    _instance ??= OfflineDownloadService._internal(db: AppDatabase());
    return _instance!;
  }

  /// For testing: inject a custom database and optional HTTP client.
  static OfflineDownloadService createForTesting({
    required AppDatabase db,
    http.Client? client,
  }) {
    _instance = OfflineDownloadService._internal(db: db, client: client);
    return _instance!;
  }

  /// Resets the singleton (for testing only).
  static void resetInstance() {
    _instance?._client.close();
    _instance = null;
  }

  final AppDatabase _db;
  final http.Client _client;

  // Queue and active-download bookkeeping.
  final Queue<_DownloadTask> _queue = Queue();
  final Map<String, StreamSubscription<dynamic>> _activeSubscriptions = {};
  bool _isProcessing = false;

  // Progress broadcast: every subscriber gets the latest state for all downloads.
  final _progressController =
      StreamController<Map<String, DownloadProgress>>.broadcast();
  final Map<String, DownloadProgress> _progressMap = {};

  /// Stream of all current download progress states, keyed by contentId.
  ///
  /// Emits the full map on every change so subscribers always have the latest
  /// snapshot.
  Stream<Map<String, DownloadProgress>> get progressStream =>
      _progressController.stream;

  /// Current snapshot of all download progress states.
  Map<String, DownloadProgress> get currentProgress =>
      Map.unmodifiable(_progressMap);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Enqueues a download. Returns immediately; the download will start when
  /// the queue reaches it.
  ///
  /// If the content is already downloaded or already in the queue, this is a
  /// no-op.
  void enqueueDownload({
    required String contentId,
    required String url,
    required String title,
    required String contentType,
    String? thumbnailUrl,
  }) {
    // Already downloaded?
    if (_progressMap[contentId]?.state == DownloadState.completed) return;
    // Already queued or downloading?
    if (_progressMap.containsKey(contentId) &&
        _progressMap[contentId]!.state != DownloadState.failed &&
        _progressMap[contentId]!.state != DownloadState.cancelled) {
      return;
    }

    _progressMap[contentId] = DownloadProgress(
      contentId: contentId,
      title: title,
      contentType: contentType,
      thumbnailUrl: thumbnailUrl,
      state: DownloadState.queued,
    );
    _emitProgress();

    _queue.add(_DownloadTask(
      contentId: contentId,
      url: url,
      title: title,
      contentType: contentType,
      thumbnailUrl: thumbnailUrl,
    ));

    _processQueue();
  }

  /// Downloads content from [url] and stores it locally.
  ///
  /// This is the legacy synchronous API kept for backward compatibility.
  /// Prefer [enqueueDownload] for new code.
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

    _activeSubscriptions[contentId] = subscription;

    await completer.future;
    _activeSubscriptions.remove(contentId);

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

  /// Cancels an in-progress or queued download.
  void cancelDownload(String contentId) {
    // Remove from queue if still queued.
    _queue.removeWhere((t) => t.contentId == contentId);

    // Cancel active stream if downloading.
    final sub = _activeSubscriptions.remove(contentId);
    sub?.cancel();

    if (_progressMap.containsKey(contentId)) {
      _progressMap[contentId] =
          _progressMap[contentId]!.copyWith(state: DownloadState.cancelled);
      _emitProgress();
    }

    // If we cancelled the active one, process next.
    if (!_isProcessing) {
      _processQueue();
    }
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

    // Clean up progress map.
    _progressMap.remove(contentId);
    _emitProgress();
  }

  /// Returns `true` if the content is already downloaded.
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
  // Queue Processing
  // ---------------------------------------------------------------------------

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final task = _queue.removeFirst();

      // Skip if cancelled while queued.
      if (_progressMap[task.contentId]?.state == DownloadState.cancelled) {
        continue;
      }

      _progressMap[task.contentId] = _progressMap[task.contentId]!.copyWith(
        state: DownloadState.downloading,
        progress: 0.0,
      );
      _emitProgress();

      try {
        await _executeDownload(task);
        _progressMap[task.contentId] = _progressMap[task.contentId]!.copyWith(
          state: DownloadState.completed,
          progress: 1.0,
        );
      } on Exception catch (e) {
        _progressMap[task.contentId] = _progressMap[task.contentId]!.copyWith(
          state: DownloadState.failed,
          error: e.toString(),
        );
      }
      _emitProgress();
    }

    _isProcessing = false;
  }

  Future<void> _executeDownload(_DownloadTask task) async {
    // Double-check: don't download twice.
    if (await isDownloaded(task.contentId)) return;

    final dir = await _getDownloadDirectory();
    final safeName = _safeFilename(task.contentId);
    final file = File('${dir.path}/$safeName');

    final request = http.Request('GET', Uri.parse(task.url));
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw OfflineDownloadException(
        'HTTP ${response.statusCode} downloading ${task.url}',
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
          final p = received / contentLength;
          _progressMap[task.contentId] =
              _progressMap[task.contentId]!.copyWith(progress: p);
          _emitProgress();
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

    _activeSubscriptions[task.contentId] = subscription;

    await completer.future;
    _activeSubscriptions.remove(task.contentId);

    final fileSize = await file.length();

    // Insert record into database.
    await _db.into(_db.downloadedItems).insert(
          DownloadedItemsCompanion.insert(
            contentId: task.contentId,
            title: task.title,
            filePath: file.path,
            fileSize: fileSize,
            downloadedAt: DateTime.now(),
            contentType: task.contentType,
            thumbnailUrl: drift.Value(task.thumbnailUrl),
            streamUrl: drift.Value(task.url),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _emitProgress() {
    if (!_progressController.isClosed) {
      _progressController.add(Map.unmodifiable(_progressMap));
    }
  }

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

  /// Releases resources. Only call this on app shutdown.
  void dispose() {
    _client.close();
    _progressController.close();
    for (final sub in _activeSubscriptions.values) {
      sub.cancel();
    }
    _activeSubscriptions.clear();
  }
}

/// Exception thrown when an offline download fails.
class OfflineDownloadException implements Exception {
  const OfflineDownloadException(this.message);

  final String message;

  @override
  String toString() => 'OfflineDownloadException: $message';
}

