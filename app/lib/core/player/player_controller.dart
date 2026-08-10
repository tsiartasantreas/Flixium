import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
      notifyListeners();
    });
    _bufferingSub = _player.stream.buffering.listen((b) {
      _isBuffering = b;
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

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;

  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<bool> _bufferingSub;

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

  // ---------------------------------------------------------------------------
  // Public API — playback controls
  // ---------------------------------------------------------------------------

  /// Open a media URL (video, live stream, or audio-only).
  Future<void> open(String url) => _player.open(Media(url));

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
    _positionSub.cancel();
    _durationSub.cancel();
    _playingSub.cancel();
    _bufferingSub.cancel();
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
