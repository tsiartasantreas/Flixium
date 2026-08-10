import 'package:flutter/material.dart';

/// Netflix-style animation constants and curves.
///
/// Centralises every duration and curve used by the design system so that
/// all motion is consistent across the app.
class NetflixAnimations {
  NetflixAnimations._();

  // ---------------------------------------------------------------------------
  // Durations
  // ---------------------------------------------------------------------------

  /// Scale animation when a card gains or loses focus (200 ms).
  static const Duration focusScale = Duration(milliseconds: 200);

  /// Horizontal row scroll-snap animation (300 ms).
  static const Duration rowScrollSnap = Duration(milliseconds: 300);

  /// Billboard / hero crossfade between featured items (800 ms).
  static const Duration billboardCrossfade = Duration(milliseconds: 800);

  /// Card hover / press scale animation on mobile (150 ms).
  static const Duration cardHover = Duration(milliseconds: 150);

  /// General fast transition for UI element state changes.
  static const Duration fast = Duration(milliseconds: 100);

  /// General medium transition for panel reveals.
  static const Duration medium = Duration(milliseconds: 250);

  /// Delay before hiding playback controls on mobile.
  static const Duration controlHideDelay = Duration(seconds: 3);

  /// Delay before hiding playback controls on TV.
  static const Duration tvControlHideDelay = Duration(seconds: 5);

  // ---------------------------------------------------------------------------
  // Curves
  // ---------------------------------------------------------------------------

  /// Smooth deceleration used for focus scale animations.
  static const Curve focusCurve = Curves.easeOut;

  /// Snap curve used for row scroll alignment.
  static const Curve scrollSnapCurve = Curves.easeInOut;

  /// Linear crossfade for billboard image transitions.
  static const Curve billboardCurve = Curves.linear;

  /// Gentle ease for card hover scale.
  static const Curve cardHoverCurve = Curves.easeOut;
}
