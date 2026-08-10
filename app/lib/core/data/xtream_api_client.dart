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
    final ext = stream.containerExtension ?? 'mp4';
    return '$baseUrl/movie/$username/$password/${stream.streamId}.$ext';
  }

  /// Builds the playback URL for a series episode.
  String getSeriesStreamUrl(
    XtreamEpisode episode,
    String containerExtension,
  ) {
    return '$baseUrl/series/$username/$password/${episode.id}.$containerExtension';
  }

  /// Builds the playback URL for a live stream.
  String getLiveStreamUrl(XtreamStream stream) {
    final ext = stream.streamType.toLowerCase().contains('ts') ? 'ts' : 'm3u8';
    return '$baseUrl/live/$username/$password/${stream.streamId}.$ext';
  }

  // ---------------------------------------------------------------------------
  // HTTP helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _get(String actionSuffix) async {
    final uri = Uri.parse(
      '$baseUrl/player_api.php?username=$username&password=$password$actionSuffix',
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw XtreamApiException(
        'HTTP ${response.statusCode} for $uri',
      );
    }
    try {
      final body = json.decode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const XtreamApiException('Response is not a JSON object');
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
    // The key varies: 'categories' for VOD/series, 'available_channels' for live.
    final list = json['categories'] as List<dynamic>? ??
        json['available_channels'] as List<dynamic>? ??
        [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(XtreamCategory.fromJson)
        .toList();
  }

  List<XtreamStream> _parseStreamList(Map<String, dynamic> json) {
    final list = json['stream'] as List<dynamic>? ??
        json['streams'] as List<dynamic>? ??
        [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(XtreamStream.fromJson)
        .toList();
  }

  List<XtreamSeries> _parseSeriesList(Map<String, dynamic> json) {
    final list = json['series'] as List<dynamic>? ?? [];
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
