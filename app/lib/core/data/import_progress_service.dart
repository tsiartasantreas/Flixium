import 'dart:async';

import 'package:flutter/foundation.dart';

import 'database.dart';
import 'playlist_manager.dart';
import 'xtream_importer.dart';

/// Tracks background import progress so the UI can display it without
/// blocking navigation.
///
/// Use [ImportProgressService.instance] to access the singleton. Call
/// [startXtreamImport] or [startM3uImport] to kick off a background import,
/// then listen to [progressNotifier] for UI updates.
class ImportProgressService {
  ImportProgressService._();

  static final ImportProgressService instance = ImportProgressService._();

  /// Notifier the UI can listen to for progress updates.
  /// `null` means no import is running.
  final ValueNotifier<ImportProgress?> progressNotifier =
      ValueNotifier<ImportProgress?>(null);

  /// Whether an import is currently running.
  bool get isImporting => progressNotifier.value != null &&
      !progressNotifier.value!.isComplete;

  /// Starts a background Xtream import. The import continues even if the
  /// caller navigates away.
  Future<void> startXtreamImport({
    required AppDatabase db,
    required PlaylistManager playlistManager,
    required int playlistId,
    required String baseUrl,
    required String username,
    required String password,
    required Set<XtreamContentType> importTypes,
  }) async {
    // Set initial progress state.
    progressNotifier.value = ImportProgress(
      playlistName: '$username@$baseUrl',
      message: 'Starting import...',
      progress: 0.0,
      isComplete: false,
    );

    final importer = XtreamImporter(db: db);
    try {
      final result = await importer.import(
        playlistId: playlistId,
        baseUrl: baseUrl,
        username: username,
        password: password,
        importTypes: importTypes,
        onProgress: (message, progress) {
          progressNotifier.value = ImportProgress(
            playlistName: '$username@$baseUrl',
            message: message,
            progress: progress,
            isComplete: false,
          );
        },
      );

      // Mark as complete.
      progressNotifier.value = ImportProgress(
        playlistName: '$username@$baseUrl',
        message: 'Import complete',
        progress: 1.0,
        isComplete: true,
        channels: result.channels,
        vodItems: result.vodItems,
        series: result.series,
        radio: result.radio,
        error: result.error,
      );
    } catch (e) {
      progressNotifier.value = ImportProgress(
        playlistName: '$username@$baseUrl',
        message: 'Import failed: $e',
        progress: 0.0,
        isComplete: true,
        error: e.toString(),
      );
    } finally {
      importer.close();
    }
  }

  /// Clears the completed import state (call after the user dismisses the
  /// progress banner).
  void clear() {
    progressNotifier.value = null;
  }
}

/// Immutable snapshot of the current import progress.
class ImportProgress {
  const ImportProgress({
    required this.playlistName,
    required this.message,
    required this.progress,
    required this.isComplete,
    this.channels = 0,
    this.vodItems = 0,
    this.series = 0,
    this.radio = 0,
    this.error,
  });

  final String playlistName;
  final String message;
  final double progress;
  final bool isComplete;
  final int channels;
  final int vodItems;
  final int series;
  final int radio;
  final String? error;

  int get totalItems => channels + vodItems + series + radio;
  bool get hasError => error != null;
}
