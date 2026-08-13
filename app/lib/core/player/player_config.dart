/// Configuration for the media_kit player tailored to IPTV streams.
///
/// IPTV providers often require custom headers, hardware decoding, and
/// protocol-specific options that are not needed for standard video playback.
///
/// Usage:
/// ```dart
/// final config = PlayerConfig(
///   hwdec: 'mediacodec',
///   userAgent: 'Mozilla/5.0',
///   referer: 'https://example.com',
/// );
/// await controller.open(url, config: config);
/// ```
class PlayerConfig {
  /// Enable hardware decoding (hwdec). Default: `"auto"`.
  ///
  /// Common values:
  /// - `"auto"` — let mpv decide (safe default)
  /// - `"mediacodec"` — Android MediaCodec
  /// - `"mediacodec-copy"` — MediaCodec with copy-back
  /// - `"nvdec"` — NVIDIA hardware decoding
  /// - `"none"` — software decoding only
  final String hwdec;

  /// Custom User-Agent header for HTTP streams.
  ///
  /// Many IPTV providers block default player headers. Setting this ensures
  /// the stream server accepts the request.
  final String? userAgent;

  /// Custom Referer header.
  ///
  /// Some providers validate the Referer to prevent hotlinking.
  final String? referer;

  /// Extra HTTP headers as key-value pairs.
  ///
  /// Used for `#EXTVLCOPT` or `#EXTHTTP` tags in M3U playlists. These are
  /// merged with [userAgent] and [referer] when building the final header map.
  final Map<String, String> extraHeaders;

  /// Protocol whitelist for HLS streams.
  ///
  /// Default: `"http,https,tcp,tls,crypto"`. Override if the stream uses
  /// additional protocols (e.g., `"udpv4"`).
  final String? protocolWhitelist;

  /// Additional MPV options applied directly to the underlying player.
  ///
  /// Keys are MPV property names (without the `--` prefix). Example:
  /// ```dart
  /// {'cache': 'yes', 'demuxer-max-bytes': '50MiB'}
  /// ```
  final Map<String, String> extraMpvOptions;

  const PlayerConfig({
    this.hwdec = 'auto',
    this.userAgent,
    this.referer,
    this.extraHeaders = const {},
    this.protocolWhitelist,
    this.extraMpvOptions = const {},
  });

  /// Default config for IPTV streams.
  ///
  /// Includes a common User-Agent string so that IPTV providers that check
  /// the header do not reject the request. Uses `hwdec=auto-safe` for
  /// broad hardware decoding support across devices (MKV, AVI, MP4, etc.).
  /// Sets `protocol-whitelist=*` so all protocols are accepted by ffmpeg's
  /// demuxer (HLS, TS, RTMP, UDP, file, etc.).
  static const defaultConfig = PlayerConfig(
    hwdec: 'auto-safe',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    protocolWhitelist: '*',
  );

  /// Config optimized for live TV streams.
  ///
  /// Uses `hwdec=auto-safe` for broad hardware decoding, `protocol-whitelist=*`
  /// so all transport protocols (HLS, TS, RTMP, UDP, etc.) are accepted, and a
  /// standard User-Agent to avoid being blocked by IPTV providers.
  static const liveTvConfig = PlayerConfig(
    hwdec: 'auto-safe',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    protocolWhitelist: '*',
  );

  /// Merges [userAgent], [referer], and [extraHeaders] into a single map
  /// suitable for [Media]'s `httpHeaders` parameter.
  ///
  /// Explicit [extraHeaders] entries take precedence over [userAgent] and
  /// [referer] if keys collide.
  Map<String, String> buildHttpHeaders() {
    final headers = <String, String>{};
    if (userAgent != null) {
      headers['User-Agent'] = userAgent!;
    }
    if (referer != null) {
      headers['Referer'] = referer!;
    }
    headers.addAll(extraHeaders);
    return headers;
  }

  /// Builds the complete set of MPV options from this config.
  ///
  /// Always includes `hwdec`. Adds `protocolWhitelist` and any
  /// [extraMpvOptions] entries.
  Map<String, String> buildMpvOptions() {
    final options = <String, String>{
      'hwdec': hwdec,
      'vo': 'gpu',
    };
    if (protocolWhitelist != null) {
      options['protocol-whitelist'] = protocolWhitelist!;
    }
    options.addAll(extraMpvOptions);
    return options;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerConfig &&
          hwdec == other.hwdec &&
          userAgent == other.userAgent &&
          referer == other.referer &&
          _mapEquals(extraHeaders, other.extraHeaders) &&
          protocolWhitelist == other.protocolWhitelist &&
          _mapEquals(extraMpvOptions, other.extraMpvOptions);

  @override
  int get hashCode => Object.hash(
        hwdec,
        userAgent,
        referer,
        Object.hashAll(extraHeaders.entries),
        protocolWhitelist,
        Object.hashAll(extraMpvOptions.entries),
      );

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
