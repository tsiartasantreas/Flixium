import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_theme.dart';

/// Netflix-style [ThemeData] configuration.
///
/// Provides a complete dark theme matching Netflix's visual language:
/// - Near-black backgrounds via [AppColors]
/// - Custom typography (bold headings, regular body)
/// - Rounded card shapes
/// - Slider / seek bar styling
/// - No default Material accent colours
class NetflixTheme {
  NetflixTheme._();

  // ---------------------------------------------------------------------------
  // Text Theme
  // ---------------------------------------------------------------------------

  static const String _fontFamily = 'sans-serif';

  static const TextTheme _textTheme = TextTheme(
    // Headlines — bold, condensed feel
    headlineLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      letterSpacing: -0.3,
    ),
    headlineSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),

    // Titles
    titleLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),

    // Body — regular weight
    bodyLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      height: 1.4,
    ),
    bodyMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
      height: 1.4,
    ),
    bodySmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
      height: 1.3,
    ),

    // Labels
    labelLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      letterSpacing: 0.5,
    ),
    labelMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
    labelSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
      letterSpacing: 0.5,
    ),
  );

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------

  /// The complete Netflix-style dark theme.
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: _fontFamily,

      // Colours
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentPrimary,
        onPrimary: AppColors.textPrimary,
        secondary: AppColors.accentHover,
        onSecondary: AppColors.textPrimary,
        surface: AppColors.bgSurface,
        onSurface: AppColors.textPrimary,
        error: Colors.redAccent,
        onError: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.bgBase,
      canvasColor: AppColors.bgBase,
      cardColor: AppColors.bgElevated,
      dividerColor: AppColors.bgSurface,

      // Text
      textTheme: _textTheme,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgBase,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.bgElevated,
        elevation: AppTheme.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Button (Play button)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.bgBase,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // Outlined Button (My List button)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.bgSurface.withValues(alpha: 0.7),
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.textSecondary, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // Icon Button
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
        ),
      ),

      // Slider / Seek bar — Netflix-style
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.textPrimary,
        inactiveTrackColor: AppColors.bgSurface,
        thumbColor: AppColors.textPrimary,
        overlayColor: AppColors.textPrimary.withValues(alpha: 0.15),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        trackHeight: 3,
        trackShape: const RoundedRectSliderTrackShape(),
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accentPrimary,
        linearTrackColor: AppColors.bgSurface,
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgBase,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ListTile (for menus, settings, etc.)
      listTileTheme: const ListTileThemeData(
        tileColor: AppColors.bgElevated,
        textColor: AppColors.textPrimary,
        subtitleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgElevated,
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgSurface,
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Splash / Highlight
      splashFactory: InkSparkle.splashFactory,
      splashColor: AppColors.textPrimary.withValues(alpha: 0.1),
      highlightColor: AppColors.textPrimary.withValues(alpha: 0.05),

      // Material / Target
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  // ---------------------------------------------------------------------------
  // System UI overlay style
  // ---------------------------------------------------------------------------

  /// System UI overlay style for the Netflix dark theme.
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bgBase,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}
