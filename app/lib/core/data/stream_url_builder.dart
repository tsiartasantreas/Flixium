import 'package:iflixify/core/player/player_config.dart';

/// Utility to construct [PlayerConfig] from M3U playlist attributes and
/// Xtream Codes API credentials.
///
/// M3U playlists often carry per-stream HTTP headers via `#EXTVLCOPT`
/// and `#EXTHTTP` tags. This builder extracts those into a [PlayerConfig]
/// that the player can apply when opening the stream.
class StreamUrlBuilder {
  const StreamUrlBuilder._();

  /// Build a [PlayerConfig] from M3U item attributes.
  ///
  /// Recognised attribute keys (case-insensitive):
  /// - `http-user-agent` or `user-agent` → [PlayerConfig.userAgent]
  /// - `http-referrer` or `referer` → [PlayerConfig.referer]
  /// - `http-header` or `headers` → extra HTTP headers (format: `"Key: Value"`,
  ///   `"Key: Value"`)
  /// - `http-header-key-value` → extra HTTP headers as `"key=value"` pairs
  /// - `hwdec` → [PlayerConfig.hwdec]
  /// - `protocol-whitelist` → [PlayerConfig.protocolWhitelist]
  ///
  /// Returns [PlayerConfig.defaultConfig] when [attributes] is empty.
  static PlayerConfig fromM3uAttributes(Map<String, String> attributes) {
    if (attributes.isEmpty) {
      return PlayerConfig.defaultConfig;
    }

    final lower = <String, String>{};
    for (final entry in attributes.entries) {
      lower[entry.key.toLowerCase()] = entry.value;
    }

    // -- User-Agent --
    final userAgent = lower['http-user-agent'] ?? lower['user-agent'];

    // -- Referer --
    final referer = lower['http-referrer'] ?? lower['referer'];

    // -- Extra headers from #EXTHTTP (JSON object) --
    final extraHeaders = <String, String>{};
    final rawHeaders = lower['http-header'] ?? lower['headers'];
    if (rawHeaders != null && rawHeaders.isNotEmpty) {
      _parseHeaderLines(rawHeaders, extraHeaders);
    }

    // -- Key-value header pairs --
    final kvHeaders = lower['http-header-key-value'];
    if (kvHeaders != null && kvHeaders.isNotEmpty) {
      for (final pair in kvHeaders.split(',')) {
        final trimmed = pair.trim();
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx > 0) {
          extraHeaders[trimmed.substring(0, eqIdx).trim()] =
              trimmed.substring(eqIdx + 1).trim();
        }
      }
    }

    // -- HWDEC --
    final hwdec = lower['hwdec'] ?? 'auto';

    // -- Protocol whitelist --
    final protocolWhitelist = lower['protocol-whitelist'];

    return PlayerConfig(
      hwdec: hwdec,
      userAgent: userAgent,
      referer: referer,
      extraHeaders: extraHeaders,
      protocolWhitelist: protocolWhitelist,
    );
  }

  /// Build a [PlayerConfig] for Xtream Codes API streams.
  ///
  /// Xtream Codes servers typically require a User-Agent that includes
  /// the provider identifier. If [providerName] is omitted, a generic
  /// User-Agent is used.
  static PlayerConfig forXtream(
    String username,
    String password, {
    String? providerName,
    String? baseUrl,
  }) {
    final agent = providerName != null
        ? '$providerName/1.0 (Linux;Android)'
        : 'Mozilla/5.0 (Linux;Android)';

    final headers = <String, String>{
      'User-Agent': agent,
    };

    if (baseUrl != null) {
      headers['Referer'] = baseUrl;
    }

    return PlayerConfig(
      hwdec: 'auto',
      userAgent: agent,
      referer: baseUrl,
      extraHeaders: headers,
    );
  }

  /// Parse header lines separated by `\n` or `\r\n`.
  static void _parseHeaderLines(
    String raw,
    Map<String, String> target,
  ) {
    final lines = raw.split(RegExp(r'[\n\r]+'));
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final colonIdx = trimmed.indexOf(':');
      if (colonIdx > 0) {
        final key = trimmed.substring(0, colonIdx).trim();
        final value = trimmed.substring(colonIdx + 1).trim();
        if (key.isNotEmpty) {
          target[key] = value;
        }
      }
    }
  }
}
