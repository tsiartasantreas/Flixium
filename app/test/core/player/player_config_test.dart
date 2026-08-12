import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/player/player_config.dart';

void main() {
  group('PlayerConfig defaults', () {
    test('default config has hwdec auto', () {
      const config = PlayerConfig();
      expect(config.hwdec, 'auto');
    });

    test('default config has no userAgent', () {
      const config = PlayerConfig();
      expect(config.userAgent, isNull);
    });

    test('default config has no referer', () {
      const config = PlayerConfig();
      expect(config.referer, isNull);
    });

    test('default config has empty extraHeaders', () {
      const config = PlayerConfig();
      expect(config.extraHeaders, isEmpty);
    });

    test('default config has no protocolWhitelist', () {
      const config = PlayerConfig();
      expect(config.protocolWhitelist, isNull);
    });

    test('default config has empty extraMpvOptions', () {
      const config = PlayerConfig();
      expect(config.extraMpvOptions, isEmpty);
    });
  });

  group('PlayerConfig static configs', () {
    test('defaultConfig is a const instance', () {
      expect(PlayerConfig.defaultConfig, isA<PlayerConfig>());
      expect(PlayerConfig.defaultConfig.hwdec, 'auto-safe');
    });

    test('defaultConfig has wildcard protocol whitelist', () {
      expect(PlayerConfig.defaultConfig.protocolWhitelist, '*');
    });

    test('liveTvConfig has hardware decoding', () {
      expect(PlayerConfig.liveTvConfig.hwdec, 'auto-safe');
    });

    test('liveTvConfig has no custom headers', () {
      expect(PlayerConfig.liveTvConfig.userAgent, isNull);
      expect(PlayerConfig.liveTvConfig.referer, isNull);
    });
  });

  group('PlayerConfig.buildHttpHeaders', () {
    test('returns empty map when no headers configured', () {
      const config = PlayerConfig();
      expect(config.buildHttpHeaders(), isEmpty);
    });

    test('includes User-Agent when set', () {
      const config = PlayerConfig(userAgent: 'TestAgent/1.0');
      final headers = config.buildHttpHeaders();
      expect(headers['User-Agent'], 'TestAgent/1.0');
    });

    test('includes Referer when set', () {
      const config = PlayerConfig(referer: 'https://example.com');
      final headers = config.buildHttpHeaders();
      expect(headers['Referer'], 'https://example.com');
    });

    test('includes extraHeaders', () {
      const config = PlayerConfig(
        extraHeaders: {'X-Custom': 'value'},
      );
      final headers = config.buildHttpHeaders();
      expect(headers['X-Custom'], 'value');
    });

    test('merges all header sources', () {
      const config = PlayerConfig(
        userAgent: 'Agent',
        referer: 'https://ref.com',
        extraHeaders: {'X-Foo': 'bar'},
      );
      final headers = config.buildHttpHeaders();
      expect(headers.length, 3);
      expect(headers['User-Agent'], 'Agent');
      expect(headers['Referer'], 'https://ref.com');
      expect(headers['X-Foo'], 'bar');
    });

    test('extraHeaders override default headers on key collision', () {
      const config = PlayerConfig(
        userAgent: 'DefaultAgent',
        extraHeaders: {'User-Agent': 'OverrideAgent'},
      );
      final headers = config.buildHttpHeaders();
      expect(headers['User-Agent'], 'OverrideAgent');
    });
  });

  group('PlayerConfig.buildMpvOptions', () {
    test('always includes hwdec', () {
      const config = PlayerConfig();
      final options = config.buildMpvOptions();
      expect(options['hwdec'], 'auto');
    });

    test('includes protocolWhitelist when set', () {
      const config = PlayerConfig(
        protocolWhitelist: 'http,https,tcp',
      );
      final options = config.buildMpvOptions();
      expect(options['protocol-whitelist'], 'http,https,tcp');
    });

    test('includes extraMpvOptions', () {
      const config = PlayerConfig(
        extraMpvOptions: {'cache': 'yes'},
      );
      final options = config.buildMpvOptions();
      expect(options['cache'], 'yes');
    });

    test('merges all option sources', () {
      const config = PlayerConfig(
        hwdec: 'nvdec',
        protocolWhitelist: 'http,https',
        extraMpvOptions: {'demuxer-max-bytes': '50MiB'},
      );
      final options = config.buildMpvOptions();
      expect(options['hwdec'], 'nvdec');
      expect(options['protocol-whitelist'], 'http,https');
      expect(options['demuxer-max-bytes'], '50MiB');
    });
  });

  group('PlayerConfig equality', () {
    test('equal configs are equal', () {
      const a = PlayerConfig(hwdec: 'mediacodec');
      const b = PlayerConfig(hwdec: 'mediacodec');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('configs with different hwdec are not equal', () {
      const a = PlayerConfig(hwdec: 'auto');
      const b = PlayerConfig(hwdec: 'nvdec');
      expect(a, isNot(equals(b)));
    });

    test('configs with different headers are not equal', () {
      const a = PlayerConfig(userAgent: 'A');
      const b = PlayerConfig(userAgent: 'B');
      expect(a, isNot(equals(b)));
    });

    test('identical config is identical', () {
      const config = PlayerConfig(hwdec: 'mediacodec');
      expect(identical(config, config), isTrue);
    });
  });

  group('PlayerConfig custom construction', () {
    test('can construct with all fields', () {
      const config = PlayerConfig(
        hwdec: 'nvdec',
        userAgent: 'MyAgent',
        referer: 'https://ref.com',
        extraHeaders: {'X-Key': 'val'},
        protocolWhitelist: 'http,https,udpv4',
        extraMpvOptions: {'cache': 'yes'},
      );
      expect(config.hwdec, 'nvdec');
      expect(config.userAgent, 'MyAgent');
      expect(config.referer, 'https://ref.com');
      expect(config.extraHeaders, {'X-Key': 'val'});
      expect(config.protocolWhitelist, 'http,https,udpv4');
      expect(config.extraMpvOptions, {'cache': 'yes'});
    });
  });
}
