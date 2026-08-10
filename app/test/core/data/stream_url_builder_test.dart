import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/data/stream_url_builder.dart';
import 'package:iflixify/core/player/player_config.dart';

void main() {
  group('StreamUrlBuilder.fromM3uAttributes', () {
    test('returns default config for empty attributes', () {
      final config = StreamUrlBuilder.fromM3uAttributes({});
      expect(config, PlayerConfig.defaultConfig);
    });

    test('extracts http-user-agent', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'http-user-agent': 'Mozilla/5.0 (Linux; Android)',
      });
      expect(config.userAgent, 'Mozilla/5.0 (Linux; Android)');
    });

    test('extracts user-agent (fallback key)', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'user-agent': 'CustomAgent',
      });
      expect(config.userAgent, 'CustomAgent');
    });

    test('http-user-agent takes precedence over user-agent', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'user-agent': 'Lower',
        'http-user-agent': 'Higher',
      });
      expect(config.userAgent, 'Higher');
    });

    test('extracts http-referrer', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'http-referrer': 'https://example.com',
      });
      expect(config.referer, 'https://example.com');
    });

    test('extracts referer (fallback key)', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'referer': 'https://fallback.com',
      });
      expect(config.referer, 'https://fallback.com');
    });

    test('http-referrer takes precedence over referer', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'referer': 'https://lower.com',
        'http-referrer': 'https://higher.com',
      });
      expect(config.referer, 'https://higher.com');
    });

    test('extracts http-header as newline-separated headers', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'http-header': 'X-Channel-Id: 123\nX-Token: abc',
      });
      expect(config.extraHeaders['X-Channel-Id'], '123');
      expect(config.extraHeaders['X-Token'], 'abc');
    });

    test('extracts headers (fallback key)', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'headers': 'Accept: application/json',
      });
      expect(config.extraHeaders['Accept'], 'application/json');
    });

    test('handles Windows-style line endings in headers', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'http-header': 'X-A: 1\r\nX-B: 2',
      });
      expect(config.extraHeaders['X-A'], '1');
      expect(config.extraHeaders['X-B'], '2');
    });

    test('extracts http-header-key-value pairs', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'http-header-key-value': 'X-Id=123,X-Secret=abc',
      });
      expect(config.extraHeaders['X-Id'], '123');
      expect(config.extraHeaders['X-Secret'], 'abc');
    });

    test('extracts hwdec', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'hwdec': 'mediacodec',
      });
      expect(config.hwdec, 'mediacodec');
    });

    test('defaults hwdec to auto when not specified', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'user-agent': 'Test',
      });
      expect(config.hwdec, 'auto');
    });

    test('extracts protocol-whitelist', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'protocol-whitelist': 'http,https,tcp,tls,crypto,udpv4',
      });
      expect(
        config.protocolWhitelist,
        'http,https,tcp,tls,crypto,udpv4',
      );
    });

    test('handles case-insensitive attribute keys', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'HTTP-USER-AGENT': 'CaseInsensitive',
      });
      expect(config.userAgent, 'CaseInsensitive');
    });

    test('merges extra headers with userAgent and referer', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'http-user-agent': 'Agent',
        'http-referrer': 'https://ref.com',
        'http-header': 'X-Custom: value',
      });
      expect(config.userAgent, 'Agent');
      expect(config.referer, 'https://ref.com');
      expect(config.extraHeaders['X-Custom'], 'value');
    });

    test('ignores malformed header lines', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'http-header': 'Valid: yes\nNoColonHere\n:empty-key',
      });
      expect(config.extraHeaders['Valid'], 'yes');
      expect(config.extraHeaders.containsKey('NoColonHere'), isFalse);
    });

    test('ignores empty header lines', () {
      final config = StreamUrlBuilder.fromM3uAttributes({
        'http-header': '\n\nX-Keep: yes\n\n',
      });
      expect(config.extraHeaders['X-Keep'], 'yes');
    });
  });

  group('StreamUrlBuilder.forXtream', () {
    test('creates config with generic user-agent', () {
      final config = StreamUrlBuilder.forXtream('user1', 'pass1');
      expect(config.userAgent, 'Mozilla/5.0 (Linux;Android)');
    });

    test('creates config with provider-specific user-agent', () {
      final config = StreamUrlBuilder.forXtream(
        'user1',
        'pass1',
        providerName: 'MyProvider',
      );
      expect(config.userAgent, 'MyProvider/1.0 (Linux;Android)');
    });

    test('sets referer from baseUrl', () {
      final config = StreamUrlBuilder.forXtream(
        'user1',
        'pass1',
        baseUrl: 'http://provider.example.com',
      );
      expect(config.referer, 'http://provider.example.com');
    });

    test('has no referer when baseUrl is null', () {
      final config = StreamUrlBuilder.forXtream('user1', 'pass1');
      expect(config.referer, isNull);
    });

    test('sets extraHeaders with User-Agent', () {
      final config = StreamUrlBuilder.forXtream('user1', 'pass1');
      expect(config.extraHeaders['User-Agent'], config.userAgent);
    });

    test('sets extraHeaders with Referer when baseUrl provided', () {
      final config = StreamUrlBuilder.forXtream(
        'user1',
        'pass1',
        baseUrl: 'http://example.com',
      );
      expect(config.extraHeaders['Referer'], 'http://example.com');
    });

    test('defaults to auto hwdec', () {
      final config = StreamUrlBuilder.forXtream('user1', 'pass1');
      expect(config.hwdec, 'auto');
    });

    test('buildHttpHeaders includes User-Agent and Referer', () {
      final config = StreamUrlBuilder.forXtream(
        'user1',
        'pass1',
        providerName: 'Test',
        baseUrl: 'http://test.com',
      );
      final headers = config.buildHttpHeaders();
      expect(headers['User-Agent'], 'Test/1.0 (Linux;Android)');
      expect(headers['Referer'], 'http://test.com');
    });
  });
}
