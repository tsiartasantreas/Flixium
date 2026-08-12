/// Data classes for the Xtream Codes API.
library;

/// Parses a JSON value that may be an int or a String into an int.
///
/// Xtream APIs frequently return numeric fields (ids, episode numbers, etc.)
/// as quoted strings (e.g. `"id": "123"`). Dart's `json.decode` turns those
/// into [String] objects, so a hard `as int` cast fails.  This helper accepts
/// both representations and returns `fallback` when the value is null or
/// cannot be parsed.
int _parseInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Server information returned by the Xtream Codes login endpoint.
class XtreamServerInfo {
  const XtreamServerInfo({
    required this.name,
    required this.url,
    required this.port,
    required this.https,
    required this.serverProtocol,
    required this.rtmpPort,
    required this.timezone,
    required this.connectionUrl,
    required this.portRtmp,
  });

  factory XtreamServerInfo.fromJson(Map<String, dynamic> json) {
    return XtreamServerInfo(
      name: json['server_name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      port: json['port'] as String? ?? '',
      https: json['https'] as String? ?? '',
      serverProtocol: json['server_protocol'] as String? ?? '',
      rtmpPort: json['rtmp_port'] as String? ?? '',
      timezone: json['timezone'] as String? ?? '',
      connectionUrl: json['url'] as String? ?? '',
      portRtmp: json['rtmp_port'] as String? ?? '',
    );
  }

  final String name;
  final String url;
  final String port;
  final String https;
  final String serverProtocol;
  final String rtmpPort;
  final String timezone;
  final String connectionUrl;
  final String portRtmp;
}

/// A category (VOD, series, or live).
class XtreamCategory {
  const XtreamCategory({
    required this.id,
    required this.name,
  });

  factory XtreamCategory.fromJson(Map<String, dynamic> json) {
    return XtreamCategory(
      id: json['category_id'] as String? ?? '',
      name: json['category_name'] as String? ?? '',
    );
  }

  final String id;
  final String name;
}

/// A VOD or live stream item.
class XtreamStream {
  const XtreamStream({
    required this.num,
    required this.name,
    required this.streamType,
    required this.streamId,
    this.streamIcon,
    this.rating,
    this.added,
    this.categoryId,
    this.containerExtension,
    this.epgChannelId,
  });

  factory XtreamStream.fromJson(Map<String, dynamic> json) {
    // VOD streams use 'vod_id' while live streams use 'stream_id'.
    // Try both so the correct ID is always captured.
    final resolvedStreamId = _parseInt(
      json['stream_id'] ?? json['vod_id'] ?? json['movie_id'],
    );
    return XtreamStream(
      num: _parseInt(json['num']),
      name: json['name'] as String? ?? '',
      streamType: json['stream_type'] as String? ?? '',
      streamId: resolvedStreamId,
      streamIcon: json['stream_icon'] as String?,
      rating: json['rating'] as String?,
      added: json['added'] as String?,
      categoryId: json['category_id'] as String?,
      containerExtension: json['container_extension'] as String?,
      epgChannelId: json['epg_channel_id'] as String?,
    );
  }

  final int num;
  final String name;
  final String streamType;
  final int streamId;
  final String? streamIcon;
  final String? rating;
  final String? added;
  final String? categoryId;
  final String? containerExtension;
  final String? epgChannelId;
}

/// A series item.
class XtreamSeries {
  const XtreamSeries({
    required this.num,
    required this.name,
    required this.seriesId,
    this.cover,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.backdropPath,
  });

  factory XtreamSeries.fromJson(Map<String, dynamic> json) {
    return XtreamSeries(
      num: _parseInt(json['num']),
      name: json['name'] as String? ?? '',
      seriesId: _parseInt(json['series_id']),
      cover: json['cover'] as String?,
      plot: json['plot'] as String?,
      cast: json['cast'] as String?,
      director: json['director'] as String?,
      genre: json['genre'] as String?,
      releaseDate: json['releaseDate'] as String?,
      rating: json['rating'] as String?,
      backdropPath: _parseBackdropPath(json['backdrop_path']),
    );
  }

  final int num;
  final String name;
  final int seriesId;
  final String? cover;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final String? rating;
  final List<String>? backdropPath;

  static List<String>? _parseBackdropPath(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .toList();
    }
    return null;
  }
}

/// Detailed series information including seasons and episodes.
class XtreamSeriesInfo {
  const XtreamSeriesInfo({
    required this.seasons,
    required this.episodes,
  });

  factory XtreamSeriesInfo.fromJson(Map<String, dynamic> json) {
    final seasonsRaw = json['seasons'] as List<dynamic>? ?? [];
    final seasons = seasonsRaw
        .whereType<Map<String, dynamic>>()
        .map((s) => XtreamSeason.fromJson(s))
        .toList();

    final episodesRaw = json['episodes'];
    final episodes = <int, List<XtreamEpisode>>{};
    if (episodesRaw is Map) {
      for (final entry in episodesRaw.entries) {
        final key = entry.key;
        final seasonNum = int.tryParse('$key');
        if (seasonNum == null) continue;
        final episodeList = (entry.value as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => XtreamEpisode.fromJson(e))
            .toList();
        episodes[seasonNum] = episodeList;
      }
    }

    return XtreamSeriesInfo(
      seasons: seasons,
      episodes: episodes,
    );
  }

  final List<XtreamSeason> seasons;
  final Map<int, List<XtreamEpisode>> episodes;
}

/// A season entry within series info.
class XtreamSeason {
  const XtreamSeason({
    required this.seasonNumber,
    required this.name,
  });

  factory XtreamSeason.fromJson(Map<String, dynamic> json) {
    return XtreamSeason(
      seasonNumber: _parseInt(json['season_number']),
      name: json['name'] as String? ?? '',
    );
  }

  final int seasonNumber;
  final String name;
}

/// A single episode within a season.
class XtreamEpisode {
  const XtreamEpisode({
    required this.id,
    required this.episodeNum,
    required this.title,
    required this.containerExtension,
    this.info,
  });

  factory XtreamEpisode.fromJson(Map<String, dynamic> json) {
    return XtreamEpisode(
      id: _parseInt(json['id']),
      episodeNum: _parseInt(json['episode_num']),
      title: json['title'] as String? ?? '',
      containerExtension: json['container_extension'] as String? ?? '',
      info: json['info'] as Map<String, dynamic>?,
    );
  }

  final int id;
  final int episodeNum;
  final String title;
  final String containerExtension;
  final Map<String, dynamic>? info;
}
