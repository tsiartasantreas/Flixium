import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:iflixify/core/data/xmltv_parser.dart';

void main() {
  group('XmltvParser.parse', () {
    test('parses a minimal XMLTV document with channels and programmes', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv generator-info-name="test">
  <channel id="BBC1">
    <display-name>BBC One</display-name>
  </channel>
  <channel id="ITV">
    <display-name>ITV</display-name>
  </channel>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="BBC1">
    <title>BBC News</title>
    <desc>Latest news from around the world</desc>
  </programme>
  <programme start="20240101130000 +0000" stop="20240101140000 +0000" channel="ITV">
    <title>ITV Lunchtime News</title>
  </programme>
</tv>
''';
      final result = XmltvParser.parse(xml);

      expect(result.channels.length, 2);
      expect(result.channels[0].id, 'BBC1');
      expect(result.channels[0].displayName, 'BBC One');
      expect(result.channels[1].id, 'ITV');
      expect(result.channels[1].displayName, 'ITV');

      expect(result.programmes.length, 2);
      expect(result.programmes[0].channelId, 'BBC1');
      expect(result.programmes[0].title, 'BBC News');
      expect(result.programmes[0].description, 'Latest news from around the world');
      expect(result.programmes[1].channelId, 'ITV');
      expect(result.programmes[1].title, 'ITV Lunchtime News');
      expect(result.programmes[1].description, isNull);

      expect(result.totalItems, 4);
    });

    test('parses XMLTV date format correctly (UTC)', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="BBC1">
    <title>Test Show</title>
  </programme>
</tv>
''';
      final result = XmltvParser.parse(xml);

      final p = result.programmes.first;
      expect(p.start, DateTime.utc(2024, 1, 1, 12, 0, 0));
      expect(p.stop, DateTime.utc(2024, 1, 1, 13, 0, 0));
    });

    test('parses XMLTV date with positive timezone offset', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20240101120000 +0100" stop="20240101130000 +0100" channel="BBC1">
    <title>Test Show</title>
  </programme>
</tv>
''';
      final result = XmltvParser.parse(xml);

      final p = result.programmes.first;
      // +0100 means local time is 1 hour ahead of UTC,
      // so the UTC equivalent is 11:00.
      expect(p.start, DateTime.utc(2024, 1, 1, 11, 0, 0));
      expect(p.stop, DateTime.utc(2024, 1, 1, 12, 0, 0));
    });

    test('parses XMLTV date with negative timezone offset', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20240101120000 -0500" stop="20240101130000 -0500" channel="BBC1">
    <title>Test Show</title>
  </programme>
</tv>
''';
      final result = XmltvParser.parse(xml);

      final p = result.programmes.first;
      // -0500 means local time is 5 hours behind UTC,
      // so the UTC equivalent is 17:00.
      expect(p.start, DateTime.utc(2024, 1, 1, 17, 0, 0));
      expect(p.stop, DateTime.utc(2024, 1, 1, 18, 0, 0));
    });

    test('handles empty input', () {
      final result = XmltvParser.parse('');

      expect(result.channels, isEmpty);
      expect(result.programmes, isEmpty);
      expect(result.totalItems, 0);
    });

    test('handles whitespace-only input', () {
      final result = XmltvParser.parse('   \n  \t  ');

      expect(result.channels, isEmpty);
      expect(result.programmes, isEmpty);
    });

    test('handles XML with no channels or programmes', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv generator-info-name="empty"></tv>
''';
      final result = XmltvParser.parse(xml);

      expect(result.channels, isEmpty);
      expect(result.programmes, isEmpty);
    });

    test('skips programme with missing channel attribute', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000">
    <title>No Channel</title>
  </programme>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="BBC1">
    <title>Has Channel</title>
  </programme>
</tv>
''';
      final result = XmltvParser.parse(xml);

      expect(result.programmes.length, 1);
      expect(result.programmes.first.channelId, 'BBC1');
      expect(result.programmes.first.title, 'Has Channel');
    });

    test('skips programme with missing start or stop', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme channel="BBC1">
    <title>No Times</title>
  </programme>
  <programme start="20240101120000 +0000" channel="BBC1">
    <title>No Stop</title>
  </programme>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="BBC1">
    <title>Complete</title>
  </programme>
</tv>
''';
      final result = XmltvParser.parse(xml);

      expect(result.programmes.length, 1);
      expect(result.programmes.first.title, 'Complete');
    });

    test('skips programme with empty title', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="BBC1">
    <title></title>
  </programme>
</tv>
''';
      final result = XmltvParser.parse(xml);

      expect(result.programmes, isEmpty);
    });

    test('skips channel with missing id', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel><display-name>No ID Channel</display-name></channel>
  <channel id="CH1"><display-name>Has ID</display-name></channel>
</tv>
''';
      final result = XmltvParser.parse(xml);

      expect(result.channels.length, 1);
      expect(result.channels.first.id, 'CH1');
    });

    test('parses multiple programmes for the same channel', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="BBC1"><display-name>BBC One</display-name></channel>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="BBC1">
    <title>Show 1</title>
  </programme>
  <programme start="20240101130000 +0000" stop="20240101140000 +0000" channel="BBC1">
    <title>Show 2</title>
  </programme>
  <programme start="20240101140000 +0000" stop="20240101150000 +0000" channel="BBC1">
    <title>Show 3</title>
  </programme>
</tv>
''';
      final result = XmltvParser.parse(xml);

      expect(result.programmes.length, 3);
      expect(result.programmes[0].title, 'Show 1');
      expect(result.programmes[1].title, 'Show 2');
      expect(result.programmes[2].title, 'Show 3');
    });
  });

  group('XmltvParser.parseGzip', () {
    test('decompresses gzip bytes and parses XMLTV', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="BBC1"><display-name>BBC One</display-name></channel>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="BBC1">
    <title>Gzipped Show</title>
    <desc>This was gzipped</desc>
  </programme>
</tv>
''';
      final bytes = gzip.encode(utf8.encode(xml));
      final result = XmltvParser.parseGzip(bytes);

      expect(result.channels.length, 1);
      expect(result.channels.first.id, 'BBC1');
      expect(result.channels.first.displayName, 'BBC One');

      expect(result.programmes.length, 1);
      expect(result.programmes.first.title, 'Gzipped Show');
      expect(result.programmes.first.description, 'This was gzipped');
      expect(
        result.programmes.first.start,
        DateTime.utc(2024, 1, 1, 12, 0, 0),
      );
    });

    test('handles empty gzip data', () {
      final result = XmltvParser.parseGzip(gzip.encode(utf8.encode('')));

      expect(result.channels, isEmpty);
      expect(result.programmes, isEmpty);
    });
  });

  group('XmltvDate', () {
    test('parses standard UTC date', () {
      final dt = XmltvDate.tryParse('20240101120000 +0000');
      expect(dt, DateTime.utc(2024, 1, 1, 12, 0, 0));
    });

    test('parses date without space before timezone', () {
      final dt = XmltvDate.tryParse('20240101120000+0000');
      expect(dt, DateTime.utc(2024, 1, 1, 12, 0, 0));
    });

    test('returns null for too-short string', () {
      expect(XmltvDate.tryParse('2024'), isNull);
    });

    test('returns null for invalid digits', () {
      expect(XmltvDate.tryParse('XXXXXXXX120000 +0000'), isNull);
    });

    test('returns null for invalid timezone', () {
      expect(XmltvDate.tryParse('20240101120000 X000'), isNull);
    });
  });
}
