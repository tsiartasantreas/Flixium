import 'package:test/test.dart';
import 'package:iflixify/core/data/m3u_url_parser.dart';

void main() {
  group('M3uUrlParser.parse', () {
    // ---------------------------------------------------------------------------
    // Xtream Codes URLs
    // ---------------------------------------------------------------------------

    group('Xtream Codes URLs', () {
      test('detects Xtream URL with username and password', () {
        final info = M3uUrlParser.parse(
          'http://provider:8080/get.php?username=user1&password=pass123',
        );

        expect(info.isXtream, isTrue);
        expect(info.isStandardM3u, isFalse);
        expect(info.type, M3uUrlType.xtream);
        expect(info.username, 'user1');
        expect(info.password, 'pass123');
      });

      test('extracts base URL without query parameters', () {
        final info = M3uUrlParser.parse(
          'http://provider:8080/get.php?username=u&password=pass',
        );

        expect(info.baseUrl, 'http://provider:8080');
      });

      test('extracts output parameter when present', () {
        final info = M3uUrlParser.parse(
          'http://provider:8080/get.php?username=u&password=pass&type=m3u_plus&output=ts',
        );

        expect(info.output, 'ts');
      });

      test('returns null output when not present', () {
        final info = M3uUrlParser.parse(
          'http://provider:8080/get.php?username=u&password=pass',
        );

        expect(info.output, isNull);
      });

      test('preserves the original URL', () {
        const url =
            'http://provider:8080/get.php?username=user&password=pass';
        final info = M3uUrlParser.parse(url);

        expect(info.url, url);
      });

      test('handles URL with additional query parameters', () {
        final info = M3uUrlParser.parse(
          'http://provider:8080/get.php?username=user&password=pass&type=m3u_plus&output=ts&c=1',
        );

        expect(info.isXtream, isTrue);
        expect(info.username, 'user');
        expect(info.password, 'pass');
      });

      test('trims whitespace from URL', () {
        final info = M3uUrlParser.parse(
          '  http://provider:8080/get.php?username=user&password=pass  ',
        );

        expect(info.isXtream, isTrue);
        expect(info.username, 'user');
        expect(info.password, 'pass');
      });

      test('handles URL with port number', () {
        final info = M3uUrlParser.parse(
          'http://provider:8080/player_api.php?username=user&password=pass',
        );

        expect(info.isXtream, isTrue);
        expect(info.baseUrl, 'http://provider:8080');
      });

      test('handles URL without explicit port', () {
        final info = M3uUrlParser.parse(
          'http://provider/get.php?username=user&password=pass',
        );

        expect(info.isXtream, isTrue);
        expect(info.baseUrl, 'http://provider');
      });
    });

    // ---------------------------------------------------------------------------
    // Standard M3U URLs
    // ---------------------------------------------------------------------------

    group('Standard M3U URLs', () {
      test('detects standard M3U URL without credentials', () {
        final info = M3uUrlParser.parse(
          'http://example.com/playlist.m3u',
        );

        expect(info.isXtream, isFalse);
        expect(info.isStandardM3u, isTrue);
        expect(info.type, M3uUrlType.standardM3u);
        expect(info.baseUrl, isNull);
        expect(info.username, isNull);
        expect(info.password, isNull);
      });

      test('detects M3U8 URL', () {
        final info = M3uUrlParser.parse(
          'https://example.com/live/stream.m3u8',
        );

        expect(info.isStandardM3u, isTrue);
      });

      test('handles URL with other query parameters (not credentials)', () {
        final info = M3uUrlParser.parse(
          'http://example.com/playlist.m3u?token=abc123',
        );

        expect(info.isStandardM3u, isTrue);
      });

      test('preserves the original URL for standard M3U', () {
        const url = 'https://cdn.example.com/playlist.m3u?token=xyz';
        final info = M3uUrlParser.parse(url);

        expect(info.url, url);
      });
    });

    // ---------------------------------------------------------------------------
    // Edge cases
    // ---------------------------------------------------------------------------

    group('Edge cases', () {
      test('URL with only username (no password) is standard M3U', () {
        final info = M3uUrlParser.parse(
          'http://provider:8080/get.php?username=user',
        );

        expect(info.isXtream, isFalse);
        expect(info.isStandardM3u, isTrue);
      });

      test('URL with only password (no username) is standard M3U', () {
        final info = M3uUrlParser.parse(
          'http://provider:8080/get.php?password=pass',
        );

        expect(info.isXtream, isFalse);
        expect(info.isStandardM3u, isTrue);
      });

      test('URL with empty username is still detected as Xtream', () {
        final info = M3uUrlParser.parse(
          'http://provider:8080/get.php?username=&password=pass',
        );

        // Both params are present, so it's classified as Xtream even if empty.
        expect(info.isXtream, isTrue);
        expect(info.username, '');
      });
    });

    // ---------------------------------------------------------------------------
    // isXtreamUrl convenience method
    // ---------------------------------------------------------------------------

    group('isXtreamUrl', () {
      test('returns true for Xtream URL', () {
        expect(
          M3uUrlParser.isXtreamUrl(
            'http://provider:8080/get.php?username=user&password=pass',
          ),
          isTrue,
        );
      });

      test('returns false for standard M3U URL', () {
        expect(
          M3uUrlParser.isXtreamUrl('http://example.com/playlist.m3u'),
          isFalse,
        );
      });
    });
  });
}
