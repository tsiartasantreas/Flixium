import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iflixify/core/data/models/xtream_models.dart';
import 'package:iflixify/core/data/xtream_api_client.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  http.Client mockClient(Map<String, dynamic> responseBody) {
    return MockClient((request) async {
      return http.Response(
        json.encode(responseBody),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  http.Client mockClient404() {
    return MockClient((request) async {
      return http.Response('Not Found', 404);
    });
  }

  http.Client mockClientInvalid() {
    return MockClient((request) async {
      return http.Response('not json', 200);
    });
  }

  // ---------------------------------------------------------------------------
  // Server info
  // ---------------------------------------------------------------------------

  group('XtreamApiClient.getServerInfo', () {
    test('parses server info from response', () async {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com:8080',
        username: 'user1',
        password: 'pass1',
        client: mockClient({
          'server_info': {
            'server_name': 'My Server',
            'url': 'http://example.com',
            'port': '8080',
            'https': '0',
            'server_protocol': 'http',
            'rtmp_port': '1935',
            'timezone': 'UTC',
          },
          'user_info': {},
        }),
      );

      final info = await client.getServerInfo();
      expect(info.name, 'My Server');
      expect(info.url, 'http://example.com');
      expect(info.port, '8080');
      expect(info.https, '0');
      expect(info.serverProtocol, 'http');
      expect(info.rtmpPort, '1935');
      expect(info.timezone, 'UTC');
    });

    test('throws when server_info is missing', () async {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com',
        username: 'u',
        password: 'p',
        client: mockClient({'user_info': {}}),
      );

      expect(
        () => client.getServerInfo(),
        throwsA(isA<XtreamApiException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // VOD categories
  // ---------------------------------------------------------------------------

  group('XtreamApiClient.getVodCategories', () {
    test('parses category list', () async {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com',
        username: 'u',
        password: 'p',
        client: mockClient({
          'categories': [
            {'category_id': '1', 'category_name': 'Action'},
            {'category_id': '2', 'category_name': 'Comedy'},
          ],
        }),
      );

      final cats = await client.getVodCategories();
      expect(cats.length, 2);
      expect(cats[0].id, '1');
      expect(cats[0].name, 'Action');
      expect(cats[1].name, 'Comedy');
    });

    test('returns empty list when no categories', () async {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com',
        username: 'u',
        password: 'p',
        client: mockClient({}),
      );

      final cats = await client.getVodCategories();
      expect(cats, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // VOD streams
  // ---------------------------------------------------------------------------

  group('XtreamApiClient.getVodStreams', () {
    test('parses stream list', () async {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com',
        username: 'u',
        password: 'p',
        client: mockClient({
          'stream': [
            {
              'num': 1,
              'name': 'Big Movie',
              'stream_type': 'movie',
              'stream_id': 100,
              'stream_icon': 'http://icon.png',
              'rating': '8.5',
              'added': '1234567890',
              'category_id': '1',
              'container_extension': 'mp4',
            },
          ],
        }),
      );

      final streams = await client.getVodStreams();
      expect(streams.length, 1);
      expect(streams[0].name, 'Big Movie');
      expect(streams[0].streamId, 100);
      expect(streams[0].containerExtension, 'mp4');
    });
  });

  // ---------------------------------------------------------------------------
  // Series categories & series
  // ---------------------------------------------------------------------------

  group('XtreamApiClient.getSeriesCategories', () {
    test('parses series categories', () async {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com',
        username: 'u',
        password: 'p',
        client: mockClient({
          'categories': [
            {'category_id': '10', 'category_name': 'Drama'},
          ],
        }),
      );

      final cats = await client.getSeriesCategories();
      expect(cats.length, 1);
      expect(cats[0].name, 'Drama');
    });
  });

  group('XtreamApiClient.getSeries', () {
    test('parses series list', () async {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com',
        username: 'u',
        password: 'p',
        client: mockClient({
          'series': [
            {
              'num': 1,
              'name': 'Breaking Bad',
              'series_id': 42,
              'cover': 'http://cover.jpg',
              'plot': 'A chemistry teacher...',
              'cast': 'Bryan Cranston',
              'director': 'Vince Gilligan',
              'genre': 'Drama',
              'releaseDate': '2008',
              'rating': '9.5',
              'backdrop_path': ['http://back1.jpg'],
            },
          ],
        }),
      );

      final series = await client.getSeries();
      expect(series.length, 1);
      expect(series[0].name, 'Breaking Bad');
      expect(series[0].seriesId, 42);
      expect(series[0].cover, 'http://cover.jpg');
      expect(series[0].backdropPath, ['http://back1.jpg']);
    });
  });

  // ---------------------------------------------------------------------------
  // Series info
  // ---------------------------------------------------------------------------

  group('XtreamApiClient.getSeriesInfo', () {
    test('parses seasons and episodes', () async {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com',
        username: 'u',
        password: 'p',
        client: mockClient({
          'seasons': [
            {'season_number': 1, 'name': 'Season 1'},
            {'season_number': 2, 'name': 'Season 2'},
          ],
          'episodes': {
            '1': [
              {
                'id': 1001,
                'episode_num': 1,
                'title': 'Pilot',
                'container_extension': 'mp4',
                'info': {'movie_image': 'http://thumb.jpg'},
              },
            ],
            '2': [
              {
                'id': 2001,
                'episode_num': 1,
                'title': 'Season Premiere',
                'container_extension': 'mkv',
              },
            ],
          },
        }),
      );

      final info = await client.getSeriesInfo(42);
      expect(info.seasons.length, 2);
      expect(info.seasons[0].seasonNumber, 1);
      expect(info.seasons[1].name, 'Season 2');
      expect(info.episodes.length, 2);
      expect(info.episodes[1]!.length, 1);
      expect(info.episodes[1]!.first.title, 'Pilot');
      expect(info.episodes[2]!.first.containerExtension, 'mkv');
    });
  });

  // ---------------------------------------------------------------------------
  // Live categories & streams
  // ---------------------------------------------------------------------------

  group('XtreamApiClient.getLiveCategories', () {
    test('parses live categories', () async {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com',
        username: 'u',
        password: 'p',
        client: mockClient({
          'categories': [
            {'category_id': '5', 'category_name': 'Sports'},
          ],
        }),
      );

      final cats = await client.getLiveCategories();
      expect(cats.length, 1);
      expect(cats[0].name, 'Sports');
    });
  });

  group('XtreamApiClient.getLiveStreams', () {
    test('parses live streams with epg_channel_id', () async {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com',
        username: 'u',
        password: 'p',
        client: mockClient({
          'stream': [
            {
              'num': 1,
              'name': 'ESPN',
              'stream_type': 'live',
              'stream_id': 500,
              'stream_icon': 'http://espn.png',
              'epg_channel_id': 'ESPN.us',
              'added': '1234567890',
              'category_id': '5',
            },
          ],
        }),
      );

      final streams = await client.getLiveStreams(categoryId: 5);
      expect(streams.length, 1);
      expect(streams[0].epgChannelId, 'ESPN.us');
      expect(streams[0].streamId, 500);
    });
  });

  // ---------------------------------------------------------------------------
  // Stream URL builders
  // ---------------------------------------------------------------------------

  group('Stream URL builders', () {
    test('getVodStreamUrl builds correct URL', () {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com:8080',
        username: 'user1',
        password: 'pass1',
        client: mockClient({}),
      );

      const stream = XtreamStream(
        num: 1,
        name: 'Movie',
        streamType: 'movie',
        streamId: 100,
        containerExtension: 'mkv',
      );

      expect(
        client.getVodStreamUrl(stream),
        'http://example.com:8080/movie/user1/pass1/100.mkv',
      );
    });

    test('getSeriesStreamUrl builds correct URL', () {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com:8080',
        username: 'user1',
        password: 'pass1',
        client: mockClient({}),
      );

      const episode = XtreamEpisode(
        id: 2001,
        episodeNum: 1,
        title: 'Pilot',
        containerExtension: 'mp4',
      );

      expect(
        client.getSeriesStreamUrl(episode, 'mp4'),
        'http://example.com:8080/series/user1/pass1/2001.mp4',
      );
    });

    test('getLiveStreamUrl builds correct URL with m3u8', () {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com:8080',
        username: 'user1',
        password: 'pass1',
        client: mockClient({}),
      );

      const stream = XtreamStream(
        num: 1,
        name: 'ESPN',
        streamType: 'live',
        streamId: 500,
      );

      expect(
        client.getLiveStreamUrl(stream),
        'http://example.com:8080/live/user1/pass1/500.m3u8',
      );
    });

    test('getLiveStreamUrl builds correct URL with ts', () {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com:8080',
        username: 'user1',
        password: 'pass1',
        client: mockClient({}),
      );

      const stream = XtreamStream(
        num: 1,
        name: 'BBC',
        streamType: 'ts',
        streamId: 600,
      );

      expect(
        client.getLiveStreamUrl(stream),
        'http://example.com:8080/live/user1/pass1/600.ts',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Error handling
  // ---------------------------------------------------------------------------

  group('Error handling', () {
    test('throws on HTTP 404', () async {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com',
        username: 'u',
        password: 'p',
        client: mockClient404(),
      );

      expect(
        () => client.getServerInfo(),
        throwsA(isA<XtreamApiException>()),
      );
    });

    test('throws on invalid JSON response', () async {
      final client = XtreamApiClient(
        baseUrl: 'http://example.com',
        username: 'u',
        password: 'p',
        client: mockClientInvalid(),
      );

      expect(
        () => client.getServerInfo(),
        throwsA(isA<XtreamApiException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Model parsing edge cases
  // ---------------------------------------------------------------------------

  group('Model edge cases', () {
    test('XtreamStream handles missing optional fields', () {
      final stream = XtreamStream.fromJson({
        'num': 1,
        'name': 'Test',
        'stream_type': 'live',
        'stream_id': 10,
      });

      expect(stream.streamIcon, isNull);
      expect(stream.rating, isNull);
      expect(stream.containerExtension, isNull);
      expect(stream.epgChannelId, isNull);
    });

    test('XtreamSeries handles null backdrop_path', () {
      final series = XtreamSeries.fromJson({
        'num': 1,
        'name': 'Show',
        'series_id': 1,
        'backdrop_path': null,
      });

      expect(series.backdropPath, isNull);
    });

    test('XtreamSeriesInfo handles empty episodes map', () {
      final info = XtreamSeriesInfo.fromJson({
        'seasons': [],
        'episodes': {},
      });

      expect(info.seasons, isEmpty);
      expect(info.episodes, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // close()
  // ---------------------------------------------------------------------------

  test('close() does not throw', () {
    final client = XtreamApiClient(
      baseUrl: 'http://example.com',
      username: 'u',
      password: 'p',
      client: mockClient({}),
    );
    expect(() => client.close(), returnsNormally);
  });
}
