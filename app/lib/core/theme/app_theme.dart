/// Netflix-clone design tokens — spacing, sizing, typography, and animation.
///
/// Every value is tuned to match the Netflix mobile / TV experience.
/// Colors live in [AppColors]; this file provides layout and motion tokens.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Spacing (matching Netflix)
  // ---------------------------------------------------------------------------
  static const double cardBorderRadius = 4.0;
  static const double rowSpacing = 16.0;
  static const double cardSpacing = 8.0;
  static const double horizontalPadding = 16.0;

  // ---------------------------------------------------------------------------
  // Card dimensions (matching Netflix)
  // ---------------------------------------------------------------------------
  /// Poster aspect ratio for VOD items (2:3 portrait).
  static const double posterAspectRatio = 2 / 3;

  /// Thumbnail aspect ratio for Live TV and Radio (16:9 landscape).
  static const double thumbnailAspectRatio = 16 / 9;

  /// Mobile card width (portrait poster cards).
  static const double cardWidth = 130.0;

  /// Mobile card height (2:3 ratio of [cardWidth]).
  static const double cardHeight = 195.0;

  /// TV card width (larger for 10-foot experience).
  static const double tvCardWidth = 180.0;

  /// TV card height (2:3 ratio of [tvCardWidth]).
  static const double tvCardHeight = 270.0;

  // ---------------------------------------------------------------------------
  // Typography (matching Netflix)
  // ---------------------------------------------------------------------------
  /// Hero banner title size on mobile.
  static const double heroTitleSize = 34.0;

  /// Hero banner title size on TV (10-foot experience).
  static const double heroTitleSizeTv = 60.0;

  /// Row section header font size on mobile.
  static const double rowHeaderSize = 18.0;

  /// Row section header font size on TV.
  static const double rowHeaderSizeTv = 28.0;

  /// Card title font size.
  static const double cardTitleSize = 13.0;

  /// Body text font size.
  static const double bodySize = 14.0;

  /// Caption / label font size.
  static const double captionSize = 12.0;

  // ---------------------------------------------------------------------------
  // Animation (matching Netflix)
  // ---------------------------------------------------------------------------
  /// Duration for card focus/unfocus scale animation.
  static const Duration cardFocusDuration = Duration(milliseconds: 200);

  /// Scale factor when a card is focused (TV).
  static const double cardFocusScale = 1.08;

  /// Opacity applied to neighboring cards when one is focused (TV).
  static const double cardHoverDim = 0.6;

  /// Crossfade duration for the hero banner auto-rotation.
  static const Duration heroCrossfadeDuration = Duration(milliseconds: 800);

  /// Delay before hiding playback controls on mobile.
  static const Duration controlHideDelay = Duration(seconds: 3);

  /// Delay before hiding playback controls on TV.
  static const Duration tvControlHideDelay = Duration(seconds: 5);

  // ---------------------------------------------------------------------------
  // Elevation
  // ---------------------------------------------------------------------------
  /// Card shadow elevation in resting state.
  static const double cardElevation = 2.0;

  /// Card shadow elevation when focused.
  static const double cardElevationFocused = 8.0;
}
