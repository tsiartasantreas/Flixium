import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/theme/app_theme.dart';

void main() {
  group('AppTheme spacing tokens', () {
    test('cardBorderRadius matches Netflix (4.0)', () {
      expect(AppTheme.cardBorderRadius, 4.0);
    });

    test('rowSpacing matches Netflix (16.0)', () {
      expect(AppTheme.rowSpacing, 16.0);
    });

    test('cardSpacing matches Netflix (8.0)', () {
      expect(AppTheme.cardSpacing, 8.0);
    });

    test('horizontalPadding matches Netflix (16.0)', () {
      expect(AppTheme.horizontalPadding, 16.0);
    });
  });

  group('AppTheme card dimensions', () {
    test('posterAspectRatio is 2:3', () {
      expect(AppTheme.posterAspectRatio, closeTo(2 / 3, 0.001));
    });

    test('thumbnailAspectRatio is 16:9', () {
      expect(AppTheme.thumbnailAspectRatio, closeTo(16 / 9, 0.001));
    });

    test('mobile card dimensions maintain 2:3 ratio', () {
      const ratio = AppTheme.cardHeight / AppTheme.cardWidth;
      expect(ratio, closeTo(3 / 2, 0.001));
    });

    test('TV card dimensions maintain 2:3 ratio', () {
      const ratio = AppTheme.tvCardHeight / AppTheme.tvCardWidth;
      expect(ratio, closeTo(3 / 2, 0.001));
    });

    test('TV cards are larger than mobile cards', () {
      expect(AppTheme.tvCardWidth, greaterThan(AppTheme.cardWidth));
      expect(AppTheme.tvCardHeight, greaterThan(AppTheme.cardHeight));
    });
  });

  group('AppTheme typography tokens', () {
    test('hero title sizes are positive', () {
      expect(AppTheme.heroTitleSize, greaterThan(0));
      expect(AppTheme.heroTitleSizeTv, greaterThan(0));
    });

    test('TV hero title is larger than mobile', () {
      expect(AppTheme.heroTitleSizeTv, greaterThan(AppTheme.heroTitleSize));
    });

    test('row header sizes are positive', () {
      expect(AppTheme.rowHeaderSize, greaterThan(0));
      expect(AppTheme.rowHeaderSizeTv, greaterThan(0));
    });

    test('TV row header is larger than mobile', () {
      expect(AppTheme.rowHeaderSizeTv, greaterThan(AppTheme.rowHeaderSize));
    });

    test('card title, body, and caption sizes are positive', () {
      expect(AppTheme.cardTitleSize, greaterThan(0));
      expect(AppTheme.bodySize, greaterThan(0));
      expect(AppTheme.captionSize, greaterThan(0));
    });
  });

  group('AppTheme animation tokens', () {
    test('card focus duration is 200ms', () {
      expect(AppTheme.cardFocusDuration, const Duration(milliseconds: 200));
    });

    test('card focus scale is 1.08', () {
      expect(AppTheme.cardFocusScale, 1.08);
    });

    test('card hover dim is 0.6', () {
      expect(AppTheme.cardHoverDim, 0.6);
    });

    test('hero crossfade duration is 800ms', () {
      expect(AppTheme.heroCrossfadeDuration, const Duration(milliseconds: 800));
    });

    test('control hide delays are sensible', () {
      expect(AppTheme.controlHideDelay, const Duration(seconds: 3));
      expect(AppTheme.tvControlHideDelay, const Duration(seconds: 5));
    });
  });

  group('AppTheme elevation tokens', () {
    test('card elevation is positive', () {
      expect(AppTheme.cardElevation, greaterThan(0));
    });

    test('focused elevation is greater than resting', () {
      expect(AppTheme.cardElevationFocused, greaterThan(AppTheme.cardElevation));
    });
  });
}
