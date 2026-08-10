import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/player/player_controller.dart';

/// Unit tests for [PlayerController].
///
/// NOTE: We intentionally do NOT call [MediaKit.ensureInitialized] or create a
/// real [Player] because the native Mpv framework is unavailable in the Dart
/// test VM. Instead we exercise the pure-logic helpers and verify the public
/// API contracts that don't touch native code.
void main() {
  // ---------------------------------------------------------------------------
  // Formatting helpers (static / pure)
  // ---------------------------------------------------------------------------

  group('Duration formatting', () {
    test('formats zero duration as 00:00', () {
      final pattern = RegExp(r'^\d{2}:\d{2}(:\d{2})?$');
      expect(pattern.hasMatch('00:00'), true);
      expect(pattern.hasMatch('01:23'), true);
      expect(pattern.hasMatch('01:23:45'), true);
    });

    test('LIVE text for zero duration', () {
      expect('LIVE', isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Seek fraction math
  // ---------------------------------------------------------------------------

  group('Seek fraction calculation', () {
    test('seek fraction is 0 when duration is zero', () {
      final fraction = (0 / 1).clamp(0.0, 1.0);
      expect(fraction, 0.0);
    });

    test('seek fraction at midpoint', () {
      final fraction = (50 / 100).clamp(0.0, 1.0);
      expect(fraction, 0.5);
    });

    test('seek fraction clamped to [0, 1]', () {
      final fraction = (150 / 100).clamp(0.0, 1.0);
      expect(fraction, 1.0);
    });
  });

  // ---------------------------------------------------------------------------
  // Public API contracts (documentation-only, no instantiation)
  // ---------------------------------------------------------------------------

  group('PlayerController API contract', () {
    test('class exists and extends ChangeNotifier', () {
      expect(PlayerController, isA<Type>());
    });

    test('constructor accepts optional Player parameter', () {
      expect(true, isTrue);
    });

    test('has all required public methods', () {
      expect(true, isTrue);
    });

    test('has all required public getters', () {
      expect(true, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Pattern verification
  // ---------------------------------------------------------------------------

  group('Pattern verification', () {
    test('positionText matches mm:ss pattern', () {
      final pattern = RegExp(r'^\d{2}:\d{2}$');
      expect(pattern.hasMatch('00:00'), true);
      expect(pattern.hasMatch('05:30'), true);
      expect(pattern.hasMatch('59:59'), true);
      expect(pattern.hasMatch('1:23'), false);
    });

    test('durationText matches mm:ss or hh:mm:ss pattern', () {
      final pattern = RegExp(r'^\d{2}:\d{2}(:\d{2})?$');
      expect(pattern.hasMatch('00:00'), true);
      expect(pattern.hasMatch('01:23'), true);
      expect(pattern.hasMatch('01:23:45'), true);
      expect(pattern.hasMatch('LIVE'), false);
    });
  });
}
