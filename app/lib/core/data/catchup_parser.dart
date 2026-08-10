/// Standardises catchup / timeshift URL formats from M3U playlists into a
/// consistent playable URL.
///
/// Many IPTV providers use different template conventions for catchup URLs.
/// This parser normalises the common variants:
///
/// * Template URLs with `{utc}`, `{start}`, `{end}`, `{duration}` placeholders
/// * Templates using `YYYYMMDDHHMMSS` format
/// * Templates using Unix-timestamp format
/// * `catchup="default"` with `tvg-id` as channel reference
/// * `catchup-type="flv"` with an explicit URL template
class CatchupParser {
  const CatchupParser._();

  /// Returns `true` when the EXTINF attributes indicate catchup support.
  static bool hasCatchup(Map<String, String> attributes) {
    final catchup = attributes['catchup']?.toLowerCase();
    if (catchup != null && catchup.isNotEmpty && catchup != '0') {
      return true;
    }
    final catchupSource = attributes['catchup-source'] ?? '';
    return catchupSource.isNotEmpty;
  }

  /// Generates a catchup playback URL from an M3U item's attributes.
  ///
  /// Returns `null` when no catchup information is available.
  static String? generateCatchupUrl({
    required String streamUrl,
    required Map<String, String> attributes,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    if (!hasCatchup(attributes)) return null;

    // Determine the timestamp format from attributes.
    final format = _parseTimeFormat(attributes);

    // Prefer an explicit catchup-source / catchup URL template.
    final catchupSource = attributes['catchup-source'] ?? '';
    if (catchupSource.isNotEmpty) {
      return _resolveTemplate(
        catchupSource,
        startTime,
        endTime,
        format: format,
      );
    }

    // catchup="default" -- build a URL from tvg-id and the stream URL.
    final catchup = attributes['catchup']?.toLowerCase() ?? '';
    if (catchup == 'default') {
      final tvgId = attributes['tvg-id'] ?? '';
      if (tvgId.isEmpty) return null;

      // Derive base from streamUrl: everything before the last path segment.
      final base = _stripTrailingSlash(streamUrl).substring(
        0,
        _stripTrailingSlash(streamUrl).lastIndexOf('/'),
      );
      final startFmt = _formatTimestamp(
        startTime,
        format: format ?? _TimestampFormat.unix,
      );
      final endFmt = _formatTimestamp(
        endTime,
        format: format ?? _TimestampFormat.unix,
      );
      return '$base/$tvgId/$startFmt/$endFmt';
    }

    // If there is a catchup attribute but no source, try to derive from
    // the stream URL by appending common patterns.
    return null;
  }

  // ---------------------------------------------------------------------------
  // Template resolution
  // ---------------------------------------------------------------------------

  /// Resolves a catchup URL template by replacing known placeholders.
  ///
  /// Supported placeholders:
  /// * `{utc}` -- Unix timestamp of the start time
  /// * `{start}` / `{start_date}` -- formatted start time
  /// * `{end}` / `{end_date}` -- formatted end time
  /// * `{duration}` -- duration in seconds
  ///
  /// If [format] is provided, it overrides auto-detection.
  /// Otherwise the formatter detects whether the template uses Unix timestamps
  /// or the `YYYYMMDDHHMMSS` convention by inspecting literal digit sequences.
  static String _resolveTemplate(
    String template,
    DateTime start,
    DateTime end, {
    _TimestampFormat? format,
  }) {
    final duration = end.difference(start).inSeconds;

    // Use the explicit format, or auto-detect from the template content.
    final resolvedFormat = format ?? _detectFormat(template);

    final utc = start.millisecondsSinceEpoch ~/ 1000;
    final startFmt = _formatTimestamp(start, format: resolvedFormat);
    final endFmt = _formatTimestamp(end, format: resolvedFormat);

    return template
        .replaceAll('{utc}', '$utc')
        .replaceAll('{start_date}', startFmt)
        .replaceAll('{start}', startFmt)
        .replaceAll('{end_date}', endFmt)
        .replaceAll('{end}', endFmt)
        .replaceAll('{duration}', '$duration');
  }

  /// Parses the timestamp format from attributes.
  ///
  /// Recognises `time_format`, `time-format`, or `catchup-type` values:
  /// * `YYYYMMDDHHMMSS` / `datetime` / `date` => [dateTime]
  /// * Everything else (including absent) => `null` (auto-detect later)
  static _TimestampFormat? _parseTimeFormat(Map<String, String> attributes) {
    final value = (attributes['time_format'] ??
            attributes['time-format'] ??
            attributes['catchup-type'] ??
            '')
        .toLowerCase();
    if (value == 'yyyymmddhhmmss' || value == 'datetime' || value == 'date') {
      return _TimestampFormat.dateTime;
    }
    return null;
  }

  /// Heuristic: if the template contains digits that look like a date
  /// (14+ digits in a row), assume YYYYMMDDHHMMSS; otherwise Unix.
  static _TimestampFormat _detectFormat(String template) {
    final unixLike = RegExp(r'\d{10,}').firstMatch(template);
    final dateLike = RegExp(r'\d{14,}').firstMatch(template);
    if (dateLike != null &&
        (unixLike == null || dateLike.start < unixLike.start)) {
      return _TimestampFormat.dateTime;
    }
    return _TimestampFormat.unix;
  }

  static String _formatTimestamp(
    DateTime dt, {
    required _TimestampFormat format,
  }) {
    switch (format) {
      case _TimestampFormat.unix:
        return '${dt.millisecondsSinceEpoch ~/ 1000}';
      case _TimestampFormat.dateTime:
        return _yyyymmddhhmmss(dt);
    }
  }

  /// Formats a [DateTime] as `YYYYMMDDHHMMSS`.
  static String _yyyymmddhhmmss(DateTime dt) {
    return '${dt.year}'
        '${_pad2(dt.month)}'
        '${_pad2(dt.day)}'
        '${_pad2(dt.hour)}'
        '${_pad2(dt.minute)}'
        '${_pad2(dt.second)}';
  }

  static String _pad2(int n) => n < 10 ? '0$n' : '$n';

  static String _stripTrailingSlash(String url) {
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }
}

enum _TimestampFormat { unix, dateTime }
