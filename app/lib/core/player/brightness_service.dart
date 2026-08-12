import 'package:screen_brightness/screen_brightness.dart';

/// Controls screen brightness using the `screen_brightness` package.
///
/// Works on Android and iOS without any custom native code.
/// On unsupported platforms the value is tracked locally but not applied to
/// the display -- the visual overlay indicator still works.
class BrightnessService {
  BrightnessService._();

  static final _screenBrightness = ScreenBrightness();

  /// Cached brightness value in the range [0.0, 1.0].
  /// Initialised lazily on first read.
  static double _brightness = 0.5;
  static bool _initialized = false;

  /// Current brightness value in [0.0, 1.0].
  static double get brightness => _brightness;

  /// Set screen brightness. [value] is clamped to [0.0, 1.0].
  static Future<void> setBrightness(double value) async {
    _brightness = value.clamp(0.0, 1.0);
    try {
      await _screenBrightness.setApplicationScreenBrightness(_brightness);
    } catch (_) {
      // Platform may not support brightness control (e.g. desktop).
    }
  }

  /// Read the current system brightness and cache it.
  static Future<double> initialize() async {
    if (_initialized) return _brightness;
    _initialized = true;
    try {
      final current = await _screenBrightness.application;
      _brightness = current.clamp(0.0, 1.0);
    } catch (_) {
      // Platform may not support brightness control -- use default.
    }
    return _brightness;
  }

  /// Reset the system brightness to the user's auto/preference level.
  static Future<void> resetBrightness() async {
    try {
      await _screenBrightness.resetApplicationScreenBrightness();
    } catch (_) {
      // Ignore on unsupported platforms.
    }
  }

  /// Adjust brightness by [delta] (positive = brighter, negative = dimmer).
  static Future<void> adjustBy(double delta) =>
      setBrightness(_brightness + delta);
}
