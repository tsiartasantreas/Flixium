import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

/// Parses XMLTV (Electronic Programme Guide) XML into structured data.
///
/// Supports both raw XML strings and gzip-compressed byte data (`.xml.gz`).
/// Uses DOM-based parsing via the `xml` package for simplicity in Phase 1.
class XmltvParser {
  const XmltvParser._();

  /// Parses an XMLTV [xmlString] and returns a structured [XmltvParseResult].
  static XmltvParseResult parse(String xmlString) {
    if (xmlString.trim().isEmpty) {
      return const XmltvParseResult(
        channels: [],
        programmes: [],
      );
    }

    final document = XmlDocument.parse(xmlString);
    final channels = _parseChannels(document);
    final programmes = _parseProgrammes(document);

    return XmltvParseResult(
      channels: channels,
      programmes: programmes,
    );
  }

  /// Decompresses gzip bytes and parses the resulting XMLTV content.
  ///
  /// Use this for `.xml.gz` EPG files downloaded from providers.
  static XmltvParseResult parseGzip(List<int> bytes) {
    final decompressed = gzip.decode(bytes);
    final xmlString = utf8.decode(decompressed);
    return parse(xmlString);
  }

  // ---------------------------------------------------------------------------
  // Channel parsing
  // ---------------------------------------------------------------------------

  static List<XmltvChannel> _parseChannels(XmlDocument document) {
    final channels = <XmltvChannel>[];
    for (final element in document.findAllElements('channel')) {
      final id = element.getAttribute('id') ?? '';
      if (id.isEmpty) continue;

      final displayName = _findChildText(element, 'display-name') ?? '';
      channels.add(XmltvChannel(id: id, displayName: displayName));
    }
    return channels;
  }

  // ---------------------------------------------------------------------------
  // Programme parsing
  // ---------------------------------------------------------------------------

  static List<XmltvProgramme> _parseProgrammes(XmlDocument document) {
    final programmes = <XmltvProgramme>[];
    for (final element in document.findAllElements('programme')) {
      final channelId = element.getAttribute('channel') ?? '';
      if (channelId.isEmpty) continue;

      final startStr = element.getAttribute('start') ?? '';
      final stopStr = element.getAttribute('stop') ?? '';
      if (startStr.isEmpty || stopStr.isEmpty) continue;

      final start = XmltvDate.tryParse(startStr);
      final stop = XmltvDate.tryParse(stopStr);
      if (start == null || stop == null) continue;

      final title = _findChildText(element, 'title') ?? '';
      if (title.isEmpty) continue;

      final description = _findChildText(element, 'desc');

      programmes.add(XmltvProgramme(
        channelId: channelId,
        start: start,
        stop: stop,
        title: title,
        description: description,
      ));
    }
    return programmes;
  }

  /// Finds the first child element with the given [name] and returns its text.
  static String? _findChildText(XmlElement parent, String name) {
    final child = parent.findAllElements(name).firstOrNull;
    if (child == null) return null;
    final text = child.innerText.trim();
    return text.isEmpty ? null : text;
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// The result of parsing an XMLTV document.
class XmltvParseResult {
  const XmltvParseResult({
    required this.channels,
    required this.programmes,
  });

  final List<XmltvChannel> channels;
  final List<XmltvProgramme> programmes;

  int get totalItems => channels.length + programmes.length;
}

/// A channel entry from the XMLTV `<channel>` element.
class XmltvChannel {
  const XmltvChannel({
    required this.id,
    required this.displayName,
  });

  final String id;
  final String displayName;
}

/// A programme entry from the XMLTV `<programme>` element.
class XmltvProgramme {
  const XmltvProgramme({
    required this.channelId,
    required this.start,
    required this.stop,
    required this.title,
    this.description,
  });

  final String channelId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? description;
}

/// Helper for parsing XMLTV date strings.
///
/// XMLTV dates use the format `YYYYMMDDHHmmss +ZZZZ` (or `YYYYMMDDHHmmss ZZZZ`).
/// Examples:
///   `20240101120000 +0000`
///   `20240101120000 +0100`
///   `20241231235959 -0500`
class XmltvDate {
  const XmltvDate._();

  /// Parses an XMLTV date string into a [DateTime], or returns `null` on failure.
  static DateTime? tryParse(String value) {
    final trimmed = value.trim();
    // Minimum length: 14 digits + space + sign + 4 digits = 20 chars.
    if (trimmed.length < 19) return null;

    final year = int.tryParse(trimmed.substring(0, 4));
    final month = int.tryParse(trimmed.substring(4, 6));
    final day = int.tryParse(trimmed.substring(6, 8));
    final hour = int.tryParse(trimmed.substring(8, 10));
    final minute = int.tryParse(trimmed.substring(10, 12));
    final second = int.tryParse(trimmed.substring(12, 14));
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }

    // Parse timezone offset: "+0000", "-0500", etc.
    final tzPart = trimmed.substring(14).trim();
    final tzMatch = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(tzPart);
    if (tzMatch == null) return null;

    final sign = tzMatch.group(1) == '+' ? 1 : -1;
    final tzHours = int.tryParse(tzMatch.group(2) ?? '') ?? 0;
    final tzMinutes = int.tryParse(tzMatch.group(3) ?? '') ?? 0;
    final offsetMinutes = sign * (tzHours * 60 + tzMinutes);

    return DateTime.utc(year, month, day, hour, minute, second)
        .subtract(Duration(minutes: offsetMinutes));
  }
}
