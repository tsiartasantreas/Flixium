import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/theme/app_colors.dart';
import 'package:iflixify/core/theme/netflix_theme.dart';

void main() {
  group('NetflixTheme.dark', () {
    late ThemeData theme;

    setUp(() {
      theme = NetflixTheme.dark;
    });

    test('is a dark theme', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('scaffold background is bgBase', () {
      expect(theme.scaffoldBackgroundColor, AppColors.bgBase);
    });

    test('canvas color is bgBase', () {
      expect(theme.canvasColor, AppColors.bgBase);
    });

    test('card color is bgElevated', () {
      expect(theme.cardColor, AppColors.bgElevated);
    });

    test('divider color is bgSurface', () {
      expect(theme.dividerColor, AppColors.bgSurface);
    });

    test('color scheme uses accent colors', () {
      expect(theme.colorScheme.primary, AppColors.accentPrimary);
      expect(theme.colorScheme.secondary, AppColors.accentHover);
    });

    test('color scheme surface is bgSurface', () {
      expect(theme.colorScheme.surface, AppColors.bgSurface);
    });

    test('color scheme background is dark', () {
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    group('text theme', () {
      test('headline large has bold weight', () {
        expect(
          theme.textTheme.headlineLarge!.fontWeight,
          anyOf(equals(FontWeight.w700), equals(FontWeight.w800)),
        );
      });

      test('headline large has white color', () {
        expect(theme.textTheme.headlineLarge!.color, AppColors.textPrimary);
      });

      test('body medium has secondary text color', () {
        expect(theme.textTheme.bodyMedium!.color, AppColors.textSecondary);
      });

      test('body small has secondary text color', () {
        expect(theme.textTheme.bodySmall!.color, AppColors.textSecondary);
      });

      test('title large has bold weight', () {
        expect(
          theme.textTheme.titleLarge!.fontWeight,
          anyOf(
            equals(FontWeight.w600),
            equals(FontWeight.w700),
            equals(FontWeight.w800),
          ),
        );
      });

      test('label large has white color', () {
        expect(theme.textTheme.labelLarge!.color, AppColors.textPrimary);
      });
    });

    group('elevated button theme', () {
      test('background is white', () {
        final style = theme.elevatedButtonTheme.style!;
        expect(
          style.backgroundColor!.resolve({WidgetState.focused}),
          AppColors.textPrimary,
        );
      });

      test('foreground is bgBase', () {
        final style = theme.elevatedButtonTheme.style!;
        expect(
          style.foregroundColor!.resolve({WidgetState.focused}),
          AppColors.bgBase,
        );
      });
    });

    group('outlined button theme', () {
      test('foreground is textPrimary', () {
        final style = theme.outlinedButtonTheme.style!;
        expect(
          style.foregroundColor!.resolve({WidgetState.focused}),
          AppColors.textPrimary,
        );
      });
    });

    group('slider theme', () {
      test('active track is white', () {
        expect(theme.sliderTheme.activeTrackColor, AppColors.textPrimary);
      });

      test('inactive track is bgSurface', () {
        expect(theme.sliderTheme.inactiveTrackColor, AppColors.bgSurface);
      });

      test('thumb is white', () {
        expect(theme.sliderTheme.thumbColor, AppColors.textPrimary);
      });

      test('track height is 3', () {
        expect(theme.sliderTheme.trackHeight, 3);
      });
    });

    group('app bar theme', () {
      test('background is bgBase', () {
        expect(theme.appBarTheme.backgroundColor, AppColors.bgBase);
      });

      test('foreground is textPrimary', () {
        expect(theme.appBarTheme.foregroundColor, AppColors.textPrimary);
      });

      test('elevation is 0', () {
        expect(theme.appBarTheme.elevation, 0);
      });

      test('title text style has bold weight', () {
        expect(
          theme.appBarTheme.titleTextStyle!.fontWeight,
          greaterThanOrEqualTo(FontWeight.w700),
        );
      });
    });

    group('dialog theme', () {
      test('background is bgElevated', () {
        expect(theme.dialogTheme.backgroundColor, AppColors.bgElevated);
      });

      test('title text style has bold weight', () {
        expect(
          theme.dialogTheme.titleTextStyle!.fontWeight,
          greaterThanOrEqualTo(FontWeight.w700),
        );
      });
    });

    group('snack bar theme', () {
      test('background is bgSurface', () {
        expect(theme.snackBarTheme.backgroundColor, AppColors.bgSurface);
      });

      test('is floating', () {
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      });
    });
  });

  group('NetflixTheme.systemOverlayStyle', () {
    test('status bar is transparent', () {
      expect(NetflixTheme.systemOverlayStyle.statusBarColor, Colors.transparent);
    });

    test('status bar brightness is dark', () {
      expect(
        NetflixTheme.systemOverlayStyle.statusBarBrightness,
        Brightness.dark,
      );
    });

    test('status bar icon brightness is light', () {
      expect(
        NetflixTheme.systemOverlayStyle.statusBarIconBrightness,
        Brightness.light,
      );
    });

    test('navigation bar color is bgBase', () {
      expect(
        NetflixTheme.systemOverlayStyle.systemNavigationBarColor,
        AppColors.bgBase,
      );
    });
  });
}
