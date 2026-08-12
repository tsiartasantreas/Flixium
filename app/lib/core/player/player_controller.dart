import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iflixify/core/player/player_config.dart';

/// Wraps [media_kit]'s [Player] for the Flixium video/audio surface.
///
/// Exposes reactive state via [ChangeNotifier] so both mobile and TV player
/// screens can rebuild on position / playback / buffering changes.
///
/// Usage:
/// ```dart
/// await PlayerController.ensureInitialized();
/// final ctrl = PlayerController();
/// await ctrl.open('https://stream.example.com/live.m3u8');
/// // …
/// ctrl.dispose();
/// ```
class PlayerController extends ChangeNotifier {
  /// Create a standalone controller (default) or supply an existing [Player]
  /// for tests that need to mock the underlying playback engine.
  PlayerController({Player? player}) {
    _player = player ?? Player();
    _videoController = VideoController(_player);
    _positionSub = _player.stream.position.listen((p) {
      _position = p;
      notifyListeners();
    });
    _durationSub = _player.stream.duration.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _playingSub = _player.stream.playing.listen((p) {
      _isPlaying = p;
      if (p) {
        // Playback started -- cancel the startup timeout.
        _timeoutTimer?.cancel();
      }
      notifyListeners();
    });
    _bufferingSub = _player.stream.buffering.listen((b) {
      _isBuffering = b;
      notifyListeners();
    });
    _errorSub = _player.stream.error.listen((msg) {
      _error = msg;
      _timeoutTimer?.cancel();
      notifyListeners();
    });
  }

  /// Call once before first use. Must run after
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  static Future<void> ensureInitialized() async {
    MediaKit.ensureInitialized();
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  late final Player _player;
  late final VideoController _videoController;

  /// Current player configuration, updated on each [open] call.
  PlayerConfig _currentConfig = PlayerConfig.defaultConfig;

  /// Returns the configuration active on the current stream.
  PlayerConfig get currentConfig => _currentConfig;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;

  /// Last error message from the player, if any.
  String? _error;

  /// Stored for [retry].
  String? _lastUrl;
  PlayerConfig? _lastConfig;

  /// Fires if playback does not start within the timeout window.
  Timer? _timeoutTimer;

  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<bool> _bufferingSub;
  late final StreamSubscription<String> _errorSub;

  // ---------------------------------------------------------------------------
  // Public API — read-only properties
  // ---------------------------------------------------------------------------

  /// The underlying [Player] instance (for [VideoController] creation, etc.).
  Player get player => _player;

  /// The [VideoController] to pass to [Video] widgets.
  VideoController get videoController => _videoController;

  /// Current playback position.
  Duration get position => _position;

  /// Total duration of the current media.
  Duration get duration => _duration;

  /// Whether playback is active.
  bool get isPlaying => _isPlaying;

  /// Whether the player is currently buffering.
  bool get isBuffering => _isBuffering;

  /// True when duration is known and positive (not live).
  bool get hasDuration => _duration > Duration.zero;

  /// Formatted position string `mm:ss`.
  String get positionText => _formatDuration(_position);

  /// Formatted duration string `mm:ss` or `"LIVE"` when unknown.
  String get durationText =>
      _duration > Duration.zero ? _formatDuration(_duration) : 'LIVE';

  /// Seek fraction in [0, 1] — useful for seek-bar sliders.
  double get seekFraction {
    if (_duration <= Duration.zero) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Non-null when the current stream has failed.
  String? get error => _error;

  /// Convenience flag for UI layers.
  bool get hasError => _error != null;

  // ---------------------------------------------------------------------------
  // Public API — playback controls
  // ---------------------------------------------------------------------------

  /// Open a media URL (video, live stream, or audio-only).
  ///
  /// When [config] is provided, its HTTP headers are applied to the
  /// underlying [Media] object. MPV options (hwdec, protocol-whitelist, etc.)
  /// are stored in [currentConfig] for use by platform-specific code.
  ///
  /// If the stream does not begin playback within 15 seconds an error is set
  /// automatically. Call [retry] to re-open the same URL.
  Future<void> open(String url, {PlayerConfig? config}) async {
    // Clear any previous error.
    _error = null;
    _lastUrl = url;
    _lastConfig = config ?? PlayerConfig.defaultConfig;
    _currentConfig = _lastConfig!;

    final headers = _currentConfig.buildHttpHeaders();
    final media = Media(
      url,
      httpHeaders: headers.isNotEmpty ? headers : null,
    );

    try {
      await _player.open(media);
    } catch (e) {
      _error = 'Failed to open stream: $e';
      notifyListeners();
      return;
    }

    // Start a timeout -- if playback never begins, surface an error.
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!_isPlaying && _error == null) {
        _error =
            'Stream timed out. The channel may be offline or unreachable.';
        notifyListeners();
      }
    });
  }

  /// Re-open the last stream URL (e.g. after an error).
  Future<void> retry() async {
    if (_lastUrl != null) {
      await open(_lastUrl!, config: _lastConfig);
    }
  }

  /// Start or resume playback.
  void play() => _player.play();

  /// Pause playback.
  void pause() => _player.pause();

  /// Toggle between play and pause.
  void togglePlay() => _isPlaying ? pause() : play();

  /// Seek to [position].
  Future<void> seek(Duration position) => _player.seek(position);

  /// Seek by [offset] relative to the current position.
  Future<void> seekBy(Duration offset) =>
      _player.seek(_position + offset);

  /// Seek to a fraction [0, 1] of the total duration.
  Future<void> seekFractionally(double fraction) {
    if (_duration <= Duration.zero) return Future.value();
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * fraction).round(),
    );
    return seek(target);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _playingSub.cancel();
    _bufferingSub.cancel();
    _errorSub.cancel();
    _player.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}
