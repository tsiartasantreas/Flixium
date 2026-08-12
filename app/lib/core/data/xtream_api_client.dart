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
    final json = await _get('&action=get_vod_categories');
    return _parseCategoryList(json);
  }

  /// Fetches VOD streams, optionally filtered by [categoryId].
  Future<List<XtreamStream>> getVodStreams({int? categoryId}) async {
    const action = '&action=get_vod';
    final catParam = categoryId != null ? '&category_id=$categoryId' : '';
    final json = await _get('$action$catParam');
    return _parseStreamList(json);
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
      throw XtreamApiException(
        'HTTP ${response.statusCode} for $uri',
      );
    }
    try {
      final dynamic body = json.decode(response.body);
      if (body is List<dynamic>) {
        // Some Xtream endpoints return arrays. Wrap in a synthetic key so
        // callers can still iterate the result.
        // ignore: avoid_print
        print('[XtreamAPI] Response is a List (${body.length} items) — wrapping');
        return <String, dynamic>{'_list': body};
      }
      if (body is! Map<String, dynamic>) {
        throw XtreamApiException(
          'Response is ${body.runtimeType}, expected Map or List',
        );
      }
      return body;
    } on XtreamApiException {
      rethrow;
    } on FormatException catch (e) {
      throw XtreamApiException('Invalid JSON: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Parsers
  // ---------------------------------------------------------------------------

  List<XtreamCategory> _parseCategoryList(Map<String, dynamic> json) {
    // The key varies: 'categories' for VOD/series, 'available_channels' for
    // live, or '_list' if the API returned a raw JSON array.
    final list = json['_list'] as List<dynamic>? ??
        json['categories'] as List<dynamic>? ??
        json['available_channels'] as List<dynamic>? ??
        [];
    // ignore: avoid_print
    print('[XtreamAPI] parseCategoryList → ${list.length} items');
    return list
        .whereType<Map<String, dynamic>>()
        .map(XtreamCategory.fromJson)
        .toList();
  }

  List<XtreamStream> _parseStreamList(Map<String, dynamic> json) {
    final list = json['_list'] as List<dynamic>? ??
        json['stream'] as List<dynamic>? ??
        json['streams'] as List<dynamic>? ??
        [];
    // ignore: avoid_print
    print('[XtreamAPI] parseStreamList → ${list.length} items');
    return list
        .whereType<Map<String, dynamic>>()
        .map(XtreamStream.fromJson)
        .toList();
  }

  List<XtreamSeries> _parseSeriesList(Map<String, dynamic> json) {
    final list = json['_list'] as List<dynamic>? ??
        json['series'] as List<dynamic>? ??
        [];
    // ignore: avoid_print
    print('[XtreamAPI] parseSeriesList → ${list.length} items');
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
