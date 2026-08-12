import 'dart:io';

import 'package:flutter/services.dart';

/// Controls screen brightness via a platform MethodChannel.
///
/// On Android this adjusts the current window's `screenBrightness` attribute.
/// On unsupported platforms the value is tracked locally but not applied to the
/// display — the visual overlay indicator still works.
class BrightnessService {
  BrightnessService._();

  static const _channel = MethodChannel('iflixify/brightness');

  /// Cached brightness value in the range [0.0, 1.0].
  /// Initialised lazily on first read.
  static double _brightness = 0.5;
  static bool _initialized = false;

  /// Current brightness value in [0.0, 1.0].
  static double get brightness => _brightness;

  /// Set screen brightness. [value] is clamped to [0.0, 1.0].
  static Future<void> setBrightness(double value) async {
    _brightness = value.clamp(0.0, 1.0);
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setBrightness', _brightness);
    } on MissingPluginException {
      // Plugin not registered — ignore gracefully.
    }
  }

  /// Read the current system brightness and cache it.
  static Future<double> initialize() async {
    if (_initialized) return _brightness;
    _initialized = true;
    if (!Platform.isAndroid) return _brightness;
    try {
      final result = await _channel.invokeMethod<double>('getBrightness');
      if (result != null) _brightness = result.clamp(0.0, 1.0);
    } on MissingPluginException {
      // Plugin not registered — use default.
    }
    return _brightness;
  }

  /// Adjust brightness by [delta] (positive = brighter, negative = dimmer).
  static Future<void> adjustBy(double delta) =>
      setBrightness(_brightness + delta);
}
