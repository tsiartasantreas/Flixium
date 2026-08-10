import 'package:test/test.dart';
import 'package:iflixify/core/data/m3u_parser.dart';

void main() {
  group('M3uParser.parse', () {
    test('parses a minimal M3U with a single live channel', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Sports" tvg-logo="http://logo.png" tvg-name="ESPN", ESPN HD
http://stream.example.com/espn
''';
      final result = M3uParser.parse(m3u);

      expect(result.channels.length, 1);
      expect(result.channels.first.name, 'ESPN HD');
      expect(result.channels.first.url, 'http://stream.example.com/espn');
      expect(result.channels.first.groupTitle, 'Sports');
      expect(result.channels.first.logo, 'http://logo.png');
      expect(result.channels.first.tvgName, 'ESPN');
      expect(result.vodItems, isEmpty);
      expect(result.series, isEmpty);
      expect(result.radioStations, isEmpty);
    });

    test('parses multiple channels across groups', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Entertainment", Channel One
http://stream.example.com/ch1
#EXTINF:-1 group-title="Sports", Sports Plus
http://stream.example.com/sports
#EXTINF:-1 group-title="Kids", Cartoon Zone
http://stream.example.com/kids
''';
      final result = M3uParser.parse(m3u);

      expect(result.channels.length, 3);
      expect(result.channels[0].name, 'Channel One');
      expect(result.channels[1].name, 'Sports Plus');
      expect(result.channels[2].name, 'Cartoon Zone');
    });

    test('classifies VOD items by group-title containing "Movies"', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Movies" tvg-logo="http://poster.jpg", Inception
http://stream.example.com/inception.mp4
#EXTINF:-1 group-title="Movies 4K", The Dark Knight
http://stream.example.com/dark-knight.mp4
''';
      final result = M3uParser.parse(m3u);

      expect(result.vodItems.length, 2);
      expect(result.vodItems[0].title, 'Inception');
      expect(result.vodItems[0].groupTitle, 'Movies');
      expect(result.vodItems[1].title, 'The Dark Knight');
      expect(result.channels, isEmpty);
    });

    test('classifies VOD items by group-title containing "Film"', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Films", Parasite
http://stream.example.com/parasite.mp4
''';
      final result = M3uParser.parse(m3u);

      expect(result.vodItems.length, 1);
      expect(result.vodItems[0].title, 'Parasite');
    });

    test('classifies VOD items by group-title containing "VOD"', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="VOD", Documentary Title
http://stream.example.com/doc.mp4
''';
      final result = M3uParser.parse(m3u);

      expect(result.vodItems.length, 1);
      expect(result.vodItems[0].title, 'Documentary Title');
    });

    test('detects series by SxxExx pattern and groups episodes', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Series", Breaking Bad S01E01
http://stream.example.com/bb-s01e01.mp4
#EXTINF:-1 group-title="Series", Breaking Bad S01E02
http://stream.example.com/bb-s01e02.mp4
#EXTINF:-1 group-title="Series", Breaking Bad S02E01
http://stream.example.com/bb-s02e01.mp4
''';
      final result = M3uParser.parse(m3u);

      expect(result.series.length, 1);
      expect(result.series.first.title, 'Breaking Bad');
      expect(result.series.first.episodes.length, 3);

      final ep1 = result.series.first.episodes[0];
      expect(ep1.season, 1);
      expect(ep1.episode, 1);
      expect(ep1.title, 'Breaking Bad S01E01');
      expect(ep1.url, 'http://stream.example.com/bb-s01e01.mp4');

      final ep3 = result.series.first.episodes[2];
      expect(ep3.season, 2);
      expect(ep3.episode, 1);
    });

    test('detects series by "Season X - Episode Y" pattern', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Series", Friends - Season 1 - Episode 1
http://stream.example.com/friends-s1e1.mp4
#EXTINF:-1 group-title="Series", Friends - Season 1 - Episode 2
http://stream.example.com/friends-s1e2.mp4
''';
      final result = M3uParser.parse(m3u);

      expect(result.series.length, 1);
      expect(result.series.first.title, 'Friends');
      expect(result.series.first.episodes.length, 2);

      expect(result.series.first.episodes[0].season, 1);
      expect(result.series.first.episodes[0].episode, 1);
      expect(result.series.first.episodes[1].season, 1);
      expect(result.series.first.episodes[1].episode, 2);
    });

    test('detects series by lowercase sxxexx pattern', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Series", The Office s01e01
http://stream.example.com/office-s01e01.mp4
''';
      final result = M3uParser.parse(m3u);

      expect(result.series.length, 1);
      expect(result.series.first.title, 'The Office');
      expect(result.series.first.episodes.first.season, 1);
      expect(result.series.first.episodes.first.episode, 1);
    });

    test('classifies radio stations by group-title containing "Radio"', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Radio", BBC Radio 1
http://stream.example.com/radio1
#EXTINF:-1 group-title="Radio Stations", Capital FM
http://stream.example.com/capital
''';
      final result = M3uParser.parse(m3u);

      expect(result.radioStations.length, 2);
      expect(result.radioStations[0].name, 'BBC Radio 1');
      expect(result.radioStations[1].name, 'Capital FM');
      expect(result.channels, isEmpty);
    });

    test('classifies radio stations by name containing "radio"', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Misc", Radio Jazz FM
http://stream.example.com/jazzfm
''';
      final result = M3uParser.parse(m3u);

      expect(result.radioStations.length, 1);
      expect(result.radioStations[0].name, 'Radio Jazz FM');
    });

    test('parses catchup attributes', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="UK" catchup="xc" catchup-source="http://epg.example.com/playlist/%s", BBC One
http://stream.example.com/bbc1
''';
      final result = M3uParser.parse(m3u);

      expect(result.channels.length, 1);
      expect(result.channels.first.catchup, 'xc');
      expect(result.channels.first.catchupSource,
          'http://epg.example.com/playlist/%s');
    });

    test('handles empty / blank lines between EXTINF and URL', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Test", Channel A

http://stream.example.com/a
''';
      final result = M3uParser.parse(m3u);

      expect(result.channels.length, 1);
      expect(result.channels.first.url, 'http://stream.example.com/a');
    });

    test('skips items with no URL', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Test", Orphan Channel
#EXTINF:-1 group-title="Test", Next Channel
http://stream.example.com/next
''';
      final result = M3uParser.parse(m3u);

      // The orphan has no URL line before the next EXTINF.
      expect(result.channels.length, 1);
      expect(result.channels.first.name, 'Next Channel');
    });

    test('returns empty result for empty input', () {
      final result = M3uParser.parse('');

      expect(result.channels, isEmpty);
      expect(result.vodItems, isEmpty);
      expect(result.series, isEmpty);
      expect(result.radioStations, isEmpty);
      expect(result.totalItems, 0);
    });

    test('returns empty result for header-only input', () {
      final result = M3uParser.parse('#EXTM3U\n');

      expect(result.totalItems, 0);
    });

    test('handles mixed content in a single playlist', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Entertainment", CNN Live
http://stream.example.com/cnn
#EXTINF:-1 group-title="Movies" tvg-logo="http://poster.jpg", Interstellar
http://stream.example.com/interstellar.mp4
#EXTINF:-1 group-title="Series", Stranger Things S01E01
http://stream.example.com/st-s01e01.mp4
#EXTINF:-1 group-title="Series", Stranger Things S01E02
http://stream.example.com/st-s01e02.mp4
#EXTINF:-1 group-title="Radio", Jazz FM
http://stream.example.com/jazzfm
''';
      final result = M3uParser.parse(m3u);

      expect(result.channels.length, 1);
      expect(result.channels.first.name, 'CNN Live');

      expect(result.vodItems.length, 1);
      expect(result.vodItems.first.title, 'Interstellar');
      expect(result.vodItems.first.poster, 'http://poster.jpg');

      expect(result.series.length, 1);
      expect(result.series.first.title, 'Stranger Things');
      expect(result.series.first.episodes.length, 2);

      expect(result.radioStations.length, 1);
      expect(result.radioStations.first.name, 'Jazz FM');

      expect(result.totalItems, 4);
    });

    test('strips trailing separator from series title', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Series", The Witcher - S01E01
http://stream.example.com/witcher.mp4
''';
      final result = M3uParser.parse(m3u);

      expect(result.series.length, 1);
      expect(result.series.first.title, 'The Witcher');
    });

    test('handles tvg-logo as poster for VOD items', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Movies" tvg-logo="http://poster.png", Avatar
http://stream.example.com/avatar.mp4
''';
      final result = M3uParser.parse(m3u);

      expect(result.vodItems.first.poster, 'http://poster.png');
    });

    test('handles tvg-logo as thumbnail for episodes', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Series" tvg-logo="http://thumb.jpg", Lost S01E01
http://stream.example.com/lost.mp4
''';
      final result = M3uParser.parse(m3u);

      expect(result.series.first.poster, 'http://thumb.jpg');
      expect(result.series.first.episodes.first.thumbnail, 'http://thumb.jpg');
    });

    test('series without group-title are still detected by name pattern', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 tvg-logo="http://logo.png", Game of Thrones S01E01
http://stream.example.com/got.mp4
''';
      final result = M3uParser.parse(m3u);

      expect(result.series.length, 1);
      expect(result.series.first.title, 'Game of Thrones');
    });

    test('items without a known group-title default to live channel', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1, Random Channel
http://stream.example.com/random
''';
      final result = M3uParser.parse(m3u);

      expect(result.channels.length, 1);
      expect(result.channels.first.name, 'Random Channel');
      expect(result.channels.first.groupTitle, isNull);
    });
  });
}
