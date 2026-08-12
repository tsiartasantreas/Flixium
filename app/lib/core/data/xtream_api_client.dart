import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/xtream_models.dart';

/// Client for the Xtream Codes IPTV API.
///
/// Xtream Codes exposes a JSON API at
/// `{base_url}/player_api.php?username={user}&password={pass}`.
class XtreamApiClient {
  XtreamApiClient({
    required this.baseUrl,
    required this.username,
    required this.password,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String username;
  final String password;
  final http.Client _client;

  // ---------------------------------------------------------------------------
  // Server info
  // ---------------------------------------------------------------------------

  /// Fetches server information (name, URL, ports, protocol, etc.).
  Future<XtreamServerInfo> getServerInfo() async {
    final json = await _get('');
    final serverInfo = json['server_info'] as Map<String, dynamic>?;
    if (serverInfo == null) {
      throw const XtreamApiException('No server_info in response');
    }
    return XtreamServerInfo.fromJson(serverInfo);
  }

  // ---------------------------------------------------------------------------
  // VOD
  // ---------------------------------------------------------------------------

  /// Fetches VOD (movie) categories.
  Future<List<XtreamCategory>> getVodCategories() async {
    // ignore: avoid_print
    print('[XtreamAPI] getVodCategories() — calling API...');
    final json = await _get('&action=get_vod_categories');
    // ignore: avoid_print
    print('[XtreamAPI] getVodCategories() response keys: ${json.keys.toList()}, '
        'sample values: ${json.map((k, v) => MapEntry(k, v is List ? 'List(${v.length})' : v.runtimeType))}');

    // Find the actual list data and log its first item's keys.
    final dynamic rawList = json['_list'] ?? json['categories'] ??
        json['vod_categories'] ?? json['movie_categories'] ??
        json['movies_categories'] ?? json['data'] ?? json['items'] ??
        _findFirstListValue(json);

    if (rawList is List && rawList.isNotEmpty) {
      final firstItem = rawList.first;
      if (firstItem is Map) {
        // ignore: avoid_print
        print('[XtreamAPI] getVodCategories() first item keys: '
            '${firstItem.keys.toList()}');
        // Log the category ID and name fields.
        final possibleIdKeys = ['category_id', 'id', 'cat_id', 'CategoryId'];
        for (final key in possibleIdKeys) {
          if (firstItem.containsKey(key)) {
            // ignore: avoid_print
            print('[XtreamAPI]   → $key = ${firstItem[key]}');
          }
        }
        final possibleNameKeys = ['category_name', 'name', 'cat_name', 'CategoryName'];
        for (final key in possibleNameKeys) {
          if (firstItem.containsKey(key)) {
            // ignore: avoid_print
            print('[XtreamAPI]   → $key = ${firstItem[key]}');
          }
        }
      }
    }

    final result = _parseCategoryList(json);
    // ignore: avoid_print
    print('[XtreamAPI] getVodCategories() parsed ${result.length} categories');
    if (result.isNotEmpty) {
      // ignore: avoid_print
      print('[XtreamAPI] getVodCategories() first parsed: id="${result.first.id}", '
          'name="${result.first.name}"');
    }
    if (result.isEmpty) {
      // ignore: avoid_print
      print('[XtreamAPI] WARNING: getVodCategories() returned 0 categories! '
          'Raw keys: ${json.keys.toList()}, value types: '
          '${json.map((k, v) => MapEntry(k, v.runtimeType))}');
      // Log all values for debugging.
      for (final entry in json.entries) {
        // ignore: avoid_print
        print('[XtreamAPI]   key="${entry.key}" → type=${entry.runtimeType}, '
            'value=${entry.value is List ? "List(${(entry.value as List).length})" : entry.value.toString().length > 200 ? "${entry.value.toString().substring(0, 200)}..." : entry.value}');
      }
    }
    return result;
  }

  /// Fetches VOD streams, optionally filtered by [categoryId].
  Future<List<XtreamStream>> getVodStreams({int? categoryId}) async {
    const action = '&action=get_vod';
    final catParam = categoryId != null ? '&category_id=$categoryId' : '';
    // ignore: avoid_print
    print('[XtreamAPI] getVodStreams(categoryId=$categoryId) — calling API...');
    final json = await _get('$action$catParam');
    // ignore: avoid_print
    print('[XtreamAPI] getVodStreams($categoryId) response keys: ${json.keys.toList()}, '
        'sample values: ${json.map((k, v) => MapEntry(k, v is List ? 'List(${v.length})' : v.runtimeType))}');

    // Find the actual list data (could be under any key).
    final dynamic rawList = json['_list'] ??
        json['stream'] ?? json['streams'] ?? json['movies'] ??
        json['movie'] ?? json['vod'] ?? json['video'] ??
        json['vod_list'] ?? json['movie_list'] ?? json['data'] ??
        json['items'] ?? json['list'] ??
        _findFirstListValue(json);

    if (rawList is List && rawList.isNotEmpty) {
      final firstItem = rawList.first;
      if (firstItem is Map) {
        // ignore: avoid_print
        print('[XtreamAPI] getVodStreams($categoryId) first item keys: '
            '${firstItem.keys.toList()}');
        // Log the ID field — critical for VOD URL building.
        final possibleIdKeys = ['stream_id', 'vod_id', 'movie_id', 'id'];
        for (final key in possibleIdKeys) {
          if (firstItem.containsKey(key)) {
            // ignore: avoid_print
            print('[XtreamAPI]   → $key = ${firstItem[key]}');
          }
        }
        // Log container extension.
        if (firstItem.containsKey('container_extension')) {
          // ignore: avoid_print
          print('[XtreamAPI]   → container_extension = ${firstItem['container_extension']}');
        }
      }
    }

    final result = _parseStreamList(json);
    // ignore: avoid_print
    print('[XtreamAPI] getVodStreams($categoryId) parsed ${result.length} streams');
    if (result.isNotEmpty) {
      final first = result.first;
      // ignore: avoid_print
      print('[XtreamAPI] getVodStreams($categoryId) first parsed stream: '
          'name="${first.name}", streamId=${first.streamId}, '
          'containerExtension="${first.containerExtension}"');
    }
    if (result.isEmpty) {
      // ignore: avoid_print
      print('[XtreamAPI] WARNING: getVodStreams($categoryId) returned 0 streams! '
          'Raw keys: ${json.keys.toList()}, body types: ${json.map((k, v) => MapEntry(k, v.runtimeType))}');
      // Log all values for debugging.
      for (final entry in json.entries) {
        // ignore: avoid_print
        print('[XtreamAPI]   key="${entry.key}" → type=${entry.runtimeType}, '
            'value=${entry.value is List ? "List(${(entry.value as List).length})" : entry.value.toString().length > 200 ? "${entry.value.toString().substring(0, 200)}..." : entry.value}');
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Series
  // ---------------------------------------------------------------------------

  /// Fetches series categories.
  Future<List<XtreamCategory>> getSeriesCategories() async {
    final json = await _get('&action=get_series_categories');
    return _parseCategoryList(json);
  }

  /// Fetches series, optionally filtered by [categoryId].
  Future<List<XtreamSeries>> getSeries({int? categoryId}) async {
    const action = '&action=get_series';
    final catParam = categoryId != null ? '&category_id=$categoryId' : '';
    final json = await _get('$action$catParam');
    return _parseSeriesList(json);
  }

  /// Fetches detailed series information including seasons and episodes.
  Future<XtreamSeriesInfo> getSeriesInfo(int seriesId) async {
    final json = await _get('&action=get_series_info&series_id=$seriesId');
    // ignore: avoid_print
    print('[XtreamAPI] getSeriesInfo($seriesId) response keys: ${json.keys.toList()}');
    final episodesRaw = json['episodes'];
    // ignore: avoid_print
    print('[XtreamAPI] episodes field type: ${episodesRaw?.runtimeType}, '
        'isMap: ${episodesRaw is Map}, '
        'seasons field type: ${json['seasons']?.runtimeType}');
    if (episodesRaw is Map) {
      // ignore: avoid_print
      print('[XtreamAPI] episodes season keys: ${episodesRaw.keys.toList()}');
      for (final entry in episodesRaw.entries) {
        final eps = entry.value;
        // ignore: avoid_print
        print('[XtreamAPI]   season ${entry.key}: '
            '${(eps is List) ? eps.length : "not a List"} episodes');
        if (eps is List && eps.isNotEmpty) {
          final first = eps.first;
          // ignore: avoid_print
          print('[XtreamAPI]     first ep keys: '
              '${(first is Map) ? first.keys.toList() : first.runtimeType}');
        }
      }
    }
    return XtreamSeriesInfo.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Live
  // ---------------------------------------------------------------------------

  /// Fetches live TV categories.
  Future<List<XtreamCategory>> getLiveCategories() async {
    final json = await _get('&action=get_live_categories');
    return _parseCategoryList(json);
  }

  /// Fetches live streams, optionally filtered by [categoryId].
  Future<List<XtreamStream>> getLiveStreams({int? categoryId}) async {
    const action = '&action=get_live_streams';
    final catParam = categoryId != null ? '&category_id=$categoryId' : '';
    final json = await _get('$action$catParam');
    return _parseStreamList(json);
  }

  // ---------------------------------------------------------------------------
  // Stream URL builders
  // ---------------------------------------------------------------------------

  /// Builds the playback URL for a VOD stream.
  String getVodStreamUrl(XtreamStream stream) {
    final ext = stream.containerExtension?.isNotEmpty == true
        ? stream.containerExtension!
        : 'mp4';
    final url = '$baseUrl/movie/$username/$password/${stream.streamId}.$ext';
    // ignore: avoid_print
    print('[XtreamAPI] VOD URL: $url (containerExtension=${stream.containerExtension})');
    return url;
  }

  /// Builds the playback URL for a series episode.
  String getSeriesStreamUrl(
    XtreamEpisode episode,
    String containerExtension,
  ) {
    final ext = containerExtension.isNotEmpty ? containerExtension : 'mp4';
    final url = '$baseUrl/series/$username/$password/${episode.id}.$ext';
    // ignore: avoid_print
    print('[XtreamAPI] Series URL: $url (episodeId=${episode.id}, ext=$ext)');
    return url;
  }

  /// Builds the playback URL for a live stream.
  ///
  /// Uses `containerExtension` from the API response when available,
  /// otherwise defaults to `ts` (the standard Xtream live stream format).
  String getLiveStreamUrl(XtreamStream stream) {
    final ext = stream.containerExtension?.isNotEmpty == true
        ? stream.containerExtension!
        : 'ts';
    final url = '$baseUrl/live/$username/$password/${stream.streamId}.$ext';
    // ignore: avoid_print
    print('[XtreamAPI] Live URL: $url (streamType=${stream.streamType}, containerExtension=${stream.containerExtension})');
    return url;
  }

  // ---------------------------------------------------------------------------
  // HTTP helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _get(String actionSuffix) async {
    final uri = Uri.parse(
      '$baseUrl/player_api.php?username=$username&password=$password$actionSuffix',
    );
    // ignore: avoid_print
    print('[XtreamAPI] GET $uri');
    final response = await _client.get(uri);
    // ignore: avoid_print
    print('[XtreamAPI] ← ${response.statusCode} (${response.body.length} bytes)');
    if (response.statusCode != 200) {
      // ignore: avoid_print
      print('[XtreamAPI] ERROR body (first 500 chars): '
          '${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      throw XtreamApiException(
        'HTTP ${response.statusCode} for $uri',
      );
    }
    try {
      // Log a truncated preview of the raw body for debugging.
      final bodyPreview = response.body.length > 500
          ? '${response.body.substring(0, 500)}...'
          : response.body;
      // ignore: avoid_print
      print('[XtreamAPI] Response preview (first 500 chars): $bodyPreview');

      final dynamic body = json.decode(response.body);
      if (body is List<dynamic>) {
        // Some Xtream endpoints return arrays. Wrap in a synthetic key so
        // callers can still iterate the result.
        // ignore: avoid_print
        print('[XtreamAPI] Response is a List (${body.length} items) — wrapping');
        if (body.isNotEmpty) {
          // ignore: avoid_print
          print('[XtreamAPI]   first item keys: '
              '${body.first is Map ? (body.first as Map).keys.toList() : body.first.runtimeType}');
        }
        return <String, dynamic>{'_list': body};
      }
      if (body is! Map<String, dynamic>) {
        throw XtreamApiException(
          'Response is ${body.runtimeType}, expected Map or List',
        );
      }
      // ignore: avoid_print
      print('[XtreamAPI] Response keys: ${body.keys.toList()}');
      return body;
    } on XtreamApiException {
      rethrow;
    } on FormatException catch (e) {
      // ignore: avoid_print
      print('[XtreamAPI] JSON parse error: ${e.message}');
      // ignore: avoid_print
      print('[XtreamAPI] Raw body (first 500 chars): '
          '${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      throw XtreamApiException('Invalid JSON: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Parsers
  // ---------------------------------------------------------------------------

  List<XtreamCategory> _parseCategoryList(Map<String, dynamic> json) {
    // The key varies across Xtream providers: 'categories' for VOD/series,
    // 'available_channels' for live, 'vod_categories'/'movie_categories'/
    // 'movies_categories' for VOD-specific responses, or '_list' if the API
    // returned a raw JSON array.
    final list = json['_list'] as List<dynamic>? ??
        json['categories'] as List<dynamic>? ??
        json['available_channels'] as List<dynamic>? ??
        json['vod_categories'] as List<dynamic>? ??
        json['movie_categories'] as List<dynamic>? ??
        json['movies_categories'] as List<dynamic>? ??
        json['series_categories'] as List<dynamic>? ??
        json['category_list'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        json['items'] as List<dynamic>? ??
        _findFirstListValue(json) ??
        [];
    // ignore: avoid_print
    print('[XtreamAPI] parseCategoryList → ${list.length} items '
        '(keys: ${json.keys.toList()})');
    if (list.isEmpty && json.isNotEmpty) {
      // ignore: avoid_print
      print('[XtreamAPI] WARNING: parseCategoryList found no list in keys: '
          '${json.keys.toList()}, value types: '
          '${json.map((k, v) => MapEntry(k, v.runtimeType))}');
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(XtreamCategory.fromJson)
        .toList();
  }

  List<XtreamStream> _parseStreamList(Map<String, dynamic> json) {
    // The key varies across Xtream providers: 'stream'/'streams' for live,
    // 'movies'/'movie'/'vod'/'video'/'vod_streams' for VOD, or '_list' if
    // the API returned a raw JSON array. Try all known variants.
    final list = json['_list'] as List<dynamic>? ??
        json['stream'] as List<dynamic>? ??
        json['streams'] as List<dynamic>? ??
        json['movies'] as List<dynamic>? ??
        json['movie'] as List<dynamic>? ??
        json['vod'] as List<dynamic>? ??
        json['video'] as List<dynamic>? ??
        json['vod_streams'] as List<dynamic>? ??
        json['vod_list'] as List<dynamic>? ??
        json['movie_list'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        json['items'] as List<dynamic>? ??
        json['list'] as List<dynamic>? ??
        _findFirstListValue(json) ??
        [];
    // ignore: avoid_print
    print('[XtreamAPI] parseStreamList → ${list.length} items '
        '(keys: ${json.keys.toList()})');
    return list
        .whereType<Map<String, dynamic>>()
        .map(XtreamStream.fromJson)
        .toList();
  }

  /// Scans all values in [json] and returns the first [List<dynamic>] found,
  /// or `null` if none of the values is a list.  Used as a last-resort
  /// fallback when the API returns the data under an unexpected key.
  List<dynamic>? _findFirstListValue(Map<String, dynamic> json) {
    for (final value in json.values) {
      if (value is List<dynamic> && value.isNotEmpty) {
        // ignore: avoid_print
        print('[XtreamAPI] _findFirstListValue: found list with '
            '${value.length} items');
        return value;
      }
    }
    return null;
  }

  List<XtreamSeries> _parseSeriesList(Map<String, dynamic> json) {
    final list = json['_list'] as List<dynamic>? ??
        json['series'] as List<dynamic>? ??
        json['series_list'] as List<dynamic>? ??
        [];
    // ignore: avoid_print
    print('[XtreamAPI] parseSeriesList → ${list.length} items '
        '(keys: ${json.keys.toList()})');
    return list
        .whereType<Map<String, dynamic>>()
        .map(XtreamSeries.fromJson)
        .toList();
  }

  /// Closes the underlying HTTP client.
  void close() {
    _client.close();
  }
}

/// Exception thrown when the Xtream Codes API returns an error.
class XtreamApiException implements Exception {
  const XtreamApiException(this.message);

  final String message;

  @override
  String toString() => 'XtreamApiException: $message';
}
