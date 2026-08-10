/// Parses M3U / Xtream Codes URLs to extract connection credentials.
///
/// Supports two URL formats:
/// - **Xtream Codes**: URLs containing `username` and `password` query params
///   (e.g. `http://provider:8080/get.php?username=XXX&password=YYY`).
/// - **Standard M3U**: Any other URL pointing to an M3U/M3U8 playlist file.
library;

/// The detected type of a playlist URL.
enum M3uUrlType {
  /// An Xtream Codes API endpoint (has username/password params).
  xtream,

  /// A standard M3U/M3U8 playlist URL.
  standardM3u,
}

/// The result of parsing a playlist URL.
class M3uUrlInfo {
  const M3uUrlInfo({
    required this.type,
    required this.url,
    this.baseUrl,
    this.username,
    this.password,
    this.output,
  });

  /// Detected URL type.
  final M3uUrlType type;

  /// The original URL.
  final String url;

  /// Base URL without query parameters (Xtream only).
  final String? baseUrl;

  /// Xtream username (Xtream only).
  final String? username;

  /// Xtream password (Xtream only).
  final String? password;

  /// Output format preference, e.g. `ts` or `m3u8` (Xtream only).
  final String? output;

  /// Whether this is an Xtream Codes URL.
  bool get isXtream => type == M3uUrlType.xtream;

  /// Whether this is a standard M3U URL.
  bool get isStandardM3u => type == M3uUrlType.standardM3u;
}

/// Utility class for parsing and detecting playlist URL formats.
class M3uUrlParser {
  const M3uUrlParser._();

  /// Parses [url] and returns an [M3uUrlInfo] describing its type and
  /// extracted credentials.
  ///
  /// A URL is classified as Xtream if it contains both `username` and
  /// `password` query parameters.
  static M3uUrlInfo parse(String url) {
    final trimmed = url.trim();
    final uri = Uri.parse(trimmed);
    final params = uri.queryParameters;

    final hasUsername = params.containsKey('username');
    final hasPassword = params.containsKey('password');

    if (hasUsername && hasPassword) {
      // Reconstruct base URL (scheme + host + port + path, no query).
      final baseUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
      );

      return M3uUrlInfo(
        type: M3uUrlType.xtream,
        url: trimmed,
        baseUrl: baseUri.toString(),
        username: params['username']!,
        password: params['password']!,
        output: params['output'],
      );
    }

    return M3uUrlInfo(
      type: M3uUrlType.standardM3u,
      url: trimmed,
    );
  }

  /// Returns `true` if [url] appears to be an Xtream Codes URL.
  static bool isXtreamUrl(String url) => parse(url).isXtream;
}
