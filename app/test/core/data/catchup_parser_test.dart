import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/data/catchup_parser.dart';

void main() {
  // Fixed timestamps for deterministic tests.
  //
  // 2024-06-15 18:00:00 UTC => unix 1718474400
  // 2024-06-15 19:30:00 UTC => unix 1718479800
  // Duration = 5400 seconds (1 h 30 min)
  final startTime = DateTime.utc(2024, 6, 15, 18, 0, 0);
  final endTime = DateTime.utc(2024, 6, 15, 19, 30, 0);

  // ---------------------------------------------------------------------------
  // hasCatchup
  // ---------------------------------------------------------------------------

  group('CatchupParser.hasCatchup', () {
    test('returns true for catchup="default"', () {
      expect(
        CatchupParser.hasCatchup({'catchup': 'default'}),
        isTrue,
      );
    });

    test('returns true for catchup="shift"', () {
      expect(
        CatchupParser.hasCatchup({'catchup': 'shift'}),
        isTrue,
      );
    });

    test('returns true when catchup-source is present', () {
      expect(
        CatchupParser.hasCatchup({'catchup-source': 'http://example.com'}),
        isTrue,
      );
    });

    test('returns false when no catchup attributes', () {
      expect(
        CatchupParser.hasCatchup({'tvg-name': 'ESPN'}),
        isFalse,
      );
    });

    test('returns false when catchup is "0"', () {
      expect(
        CatchupParser.hasCatchup({'catchup': '0'}),
        isFalse,
      );
    });

    test('returns false when catchup is empty string', () {
      expect(
        CatchupParser.hasCatchup({'catchup': ''}),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // generateCatchupUrl -- catchup-source templates
  // ---------------------------------------------------------------------------

  group('CatchupParser.generateCatchupUrl with catchup-source', () {
    test('resolves {utc}, {start}, {end}, {duration} placeholders', () {
      final url = CatchupParser.generateCatchupUrl(
        streamUrl: 'http://example.com/live/ch1.m3u8',
        attributes: {
          'catchup-source':
              'http://catchup.example.com/{utc}/{start}/{end}/{duration}',
        },
        startTime: startTime,
        endTime: endTime,
      );

      expect(url, isNotNull);
      // {utc} => unix timestamp of startTime
      expect(url, contains('1718474400'));
      // {duration} => 5400
      expect(url, contains('5400'));
      expect(
        url,
        'http://catchup.example.com/1718474400/1718474400/1718479800/5400',
      );
    });

    test('resolves YYYYMMDDHHMMSS format via time_format attribute', () {
      final url = CatchupParser.generateCatchupUrl(
        streamUrl: 'http://example.com/live/ch1.m3u8',
        attributes: {
          'catchup-source':
              'http://catchup.example.com/{start}/{end}',
          'time_format': 'YYYYMMDDHHMMSS',
        },
        startTime: startTime,
        endTime: endTime,
      );

      expect(url, isNotNull);
      expect(url, contains('20240615180000'));
      expect(url, contains('20240615193000'));
    });

    test('resolves YYYYMMDDHHMMSS format via catchup-type datetime', () {
      final url = CatchupParser.generateCatchupUrl(
        streamUrl: 'http://example.com/live/ch1.m3u8',
        attributes: {
          'catchup-source':
              'http://catchup.example.com/{start}/{end}',
          'catchup-type': 'datetime',
        },
        startTime: startTime,
        endTime: endTime,
      );

      expect(url, isNotNull);
      expect(url, contains('20240615180000'));
      expect(url, contains('20240615193000'));
    });

    test('resolves {start_date} and {end_date} placeholders with time_format', () {
      final url = CatchupParser.generateCatchupUrl(
        streamUrl: 'http://example.com/live/ch1.m3u8',
        attributes: {
          'catchup-source':
              'http://catchup.example.com/{start_date}/{end_date}',
          'time_format': 'YYYYMMDDHHMMSS',
        },
        startTime: startTime,
        endTime: endTime,
      );

      expect(url, isNotNull);
      expect(url, contains('20240615180000'));
      expect(url, contains('20240615193000'));
    });
  });

  // ---------------------------------------------------------------------------
  // generateCatchupUrl -- catchup="default" with tvg-id
  // ---------------------------------------------------------------------------

  group('CatchupParser.generateCatchupUrl with catchup="default"', () {
    test('builds URL from tvg-id and stream URL', () {
      final url = CatchupParser.generateCatchupUrl(
        streamUrl: 'http://example.com/live/1234.m3u8',
        attributes: {
          'catchup': 'default',
          'tvg-id': 'ESPN.us',
        },
        startTime: startTime,
        endTime: endTime,
      );

      expect(url, isNotNull);
      expect(url, contains('ESPN.us'));
      expect(url, contains('1718474400'));
      expect(url, contains('1718479800'));
    });

    test('returns null when tvg-id is missing', () {
      final url = CatchupParser.generateCatchupUrl(
        streamUrl: 'http://example.com/live/1234.m3u8',
        attributes: {'catchup': 'default'},
        startTime: startTime,
        endTime: endTime,
      );

      expect(url, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // generateCatchupUrl -- no catchup
  // ---------------------------------------------------------------------------

  group('CatchupParser.generateCatchupUrl with no catchup', () {
    test('returns null when no catchup attributes', () {
      final url = CatchupParser.generateCatchupUrl(
        streamUrl: 'http://example.com/live/ch1.m3u8',
        attributes: {'tvg-name': 'ESPN'},
        startTime: startTime,
        endTime: endTime,
      );

      expect(url, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  group('CatchupParser edge cases', () {
    test('empty catchup-source returns null', () {
      final url = CatchupParser.generateCatchupUrl(
        streamUrl: 'http://example.com/live/ch1.m3u8',
        attributes: {'catchup-source': ''},
        startTime: startTime,
        endTime: endTime,
      );

      // hasCatchup returns false for empty catchup-source
      expect(url, isNull);
    });

    test('stream URL with trailing slash is handled', () {
      final url = CatchupParser.generateCatchupUrl(
        streamUrl: 'http://example.com/live/ch1.m3u8/',
        attributes: {
          'catchup': 'default',
          'tvg-id': 'BBC.uk',
        },
        startTime: startTime,
        endTime: endTime,
      );

      expect(url, isNotNull);
      expect(url, contains('BBC.uk'));
    });
  });
}
