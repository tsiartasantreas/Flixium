import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Manages a foreground service so downloads and playlist imports continue
/// even when the user switches away from the app.
///
/// Usage:
/// 1. Call [initialize] once at app startup.
/// 2. Call [incrementTaskCount] before starting a download/import batch.
/// 3. Call [decrementTaskCount] once all background work is complete.
///
/// The foreground service shows an ongoing notification, which is the standard
/// Android mechanism for keeping a process alive during user-initiated work.
class BackgroundDownloadService {
  BackgroundDownloadService._();

  static final BackgroundDownloadService instance =
      BackgroundDownloadService._();

  bool _isRunning = false;
  int _activeTaskCount = 0;

  /// Whether the foreground service is currently active.
  bool get isRunning => _isRunning;

  /// Call once at app startup to configure the foreground task defaults.
  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'iflixify_download_channel',
        channelName: 'Download Service',
        channelDescription:
            'Keeps downloads and playlist imports running in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Starts the foreground service if not already running.
  ///
  /// Each caller should pair this with a matching [decrementTaskCount] when
  /// its work completes.
  Future<void> incrementTaskCount({
    String notificationText = 'Downloading content...',
  }) async {
    _activeTaskCount++;

    if (!_isRunning) {
      await _startForegroundService(notificationText);
    } else {
      // Update notification text to reflect current activity.
      await FlutterForegroundTask.updateService(
        notificationTitle: 'iFlixify',
        notificationText: notificationText,
      );
    }
  }

  /// Signals that one background task has completed.
  ///
  /// When no tasks remain, the foreground service is stopped.
  Future<void> decrementTaskCount({
    String notificationText = 'Finishing up...',
  }) async {
    _activeTaskCount = (_activeTaskCount - 1).clamp(0, 999);

    if (_activeTaskCount == 0 && _isRunning) {
      await _stopForegroundService();
    } else if (_isRunning) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'iFlixify',
        notificationText: notificationText,
      );
    }
  }

  /// Stops the foreground service immediately regardless of task count.
  ///
  /// Use this for error recovery or when the user explicitly cancels all work.
  Future<void> forceStop() async {
    _activeTaskCount = 0;
    if (_isRunning) {
      await _stopForegroundService();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _startForegroundService(String notificationText) async {
    // Request notification permission on Android 13+.
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 1,
      notificationTitle: 'iFlixify',
      notificationText: notificationText,
      callback: _startCallback,
    );

    if (result is ServiceRequestSuccess) {
      _isRunning = true;
      debugPrint('[BackgroundDownloadService] Foreground service started.');
    } else {
      debugPrint(
        '[BackgroundDownloadService] Failed to start foreground service: '
        '${(result as ServiceRequestFailure).error}',
      );
    }
  }

  Future<void> _stopForegroundService() async {
    await FlutterForegroundTask.stopService();
    _isRunning = false;
    debugPrint('[BackgroundDownloadService] Foreground service stopped.');
  }

  /// Called by the foreground task plugin in a background isolate.
  ///
  /// We only need the service to stay alive -- all actual download logic
  /// remains in the main isolate. This callback simply keeps the Dart VM
  /// from tearing down the process.
  @pragma('vm:entry-point')
  static void _startCallback() {
    FlutterForegroundTask.setTaskHandler(_DownloadTaskHandler());
  }
}

/// Minimal task handler that keeps the foreground service alive.
///
/// Real download work is done in the main isolate; this isolate exists only
/// because Android requires a foreground service to have an ongoing callback.
class _DownloadTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[DownloadTaskHandler] Service started at $timestamp '
        '(starter: $starter)');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op. The service stays alive; actual work runs in the main isolate.
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('[DownloadTaskHandler] Service destroyed at $timestamp');
  }

  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('[DownloadTaskHandler] Notification button pressed: $id');
    if (id == 'stop') {
      BackgroundDownloadService.instance.forceStop();
    }
  }

  @override
  void onNotificationPressed() {
    // User tapped the notification -- bring the app to front.
    debugPrint('[DownloadTaskHandler] Notification pressed');
  }
}
