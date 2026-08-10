/// Parses M3U / M3U8 playlists into structured channel, VOD, series,
/// and radio data suitable for insertion into the Drift schema.
class M3uParser {
  const M3uParser._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Parses [content] (the full text of an .m3u / .m3u8 file) and returns a
  /// classified [M3uResult].
  static M3uResult parse(String content) {
    final lines = content.split('\n');
    final raw = <_RawItem>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXTINF:')) continue;

      final attrs = _parseExtinf(line);

      // The stream URL is the next non-empty, non-comment line.
      // Stop searching if we hit another EXTINF (orphan item with no URL).
      String? url;
      for (var j = i + 1; j < lines.length; j++) {
        final candidate = lines[j].trim();
        if (candidate.startsWith('#EXTINF:')) break;
        if (candidate.isNotEmpty && !candidate.startsWith('#')) {
          url = candidate;
          break;
        }
      }
      if (url == null || url.isEmpty) continue;

      raw.add(_RawItem(
        name: attrs.name,
        logo: attrs.logo,
        url: url,
        groupTitle: attrs.groupTitle,
        tvgName: attrs.tvgName,
        catchup: attrs.catchup,
        catchupSource: attrs.catchupSource,
      ));
    }

    return _classify(raw);
  }

  // ---------------------------------------------------------------------------
  // EXTINF parsing
  // ---------------------------------------------------------------------------

  static _ExtinfAttrs _parseExtinf(String line) {
    final groupTitle = _extractQuotedAttr(line, 'group-title');
    final logo = _extractQuotedAttr(line, 'tvg-logo');
    final tvgName = _extractQuotedAttr(line, 'tvg-name');
    final catchup = _extractQuotedAttr(line, 'catchup');
    final catchupSource = _extractQuotedAttr(line, 'catchup-source');

    // The display name follows the last comma.
    final nameMatch = RegExp(r',\s*(.+)$').firstMatch(line);
    final name = nameMatch?.group(1)?.trim() ?? '';

    return _ExtinfAttrs(
      name: name,
      logo: logo,
      groupTitle: groupTitle,
      tvgName: tvgName,
      catchup: catchup,
      catchupSource: catchupSource,
    );
  }

  /// Extracts the value of a quoted attribute (`attr="value"`).
  static String? _extractQuotedAttr(String line, String attr) {
    final match = RegExp('$attr="([^"]*)"').firstMatch(line);
    return match?.group(1);
  }

  // ---------------------------------------------------------------------------
  // Classification
  // ---------------------------------------------------------------------------

  static M3uResult _classify(List<_RawItem> items) {
    final channels = <M3uChannel>[];
    final vodItems = <M3uVodItem>[];
    final seriesMap = <String, M3uSeries>{};
    final radioStations = <M3uRadioStation>[];

    for (final item in items) {
      final group = item.groupTitle ?? '';
      final name = item.name;

      // --- Radio ---------------------------------------------------------------
      if (_isRadio(group, name)) {
        radioStations.add(M3uRadioStation(
          name: name,
          logo: item.logo,
          url: item.url,
        ));
        continue;
      }

      // --- Series (S01E01 / Season X - Episode Y) -----------------------------
      final seriesInfo = _extractSeriesInfo(name);
      if (seriesInfo != null) {
        final title = seriesInfo.title;
        seriesMap.putIfAbsent(
          title,
          () => M3uSeries(title: title, poster: item.logo, episodes: []),
        );
        seriesMap[title]!.episodes.add(M3uEpisode(
          season: seriesInfo.season,
          episode: seriesInfo.episode,
          title: name,
          url: item.url,
          thumbnail: item.logo,
        ));
        continue;
      }

      // --- VOD / Movie --------------------------------------------------------
      if (_isVod(group)) {
        vodItems.add(M3uVodItem(
          title: name,
          poster: item.logo,
          url: item.url,
          groupTitle: item.groupTitle,
        ));
        continue;
      }

      // --- Default: live channel -----------------------------------------------
      channels.add(M3uChannel(
        name: name,
        logo: item.logo,
        url: item.url,
        groupTitle: item.groupTitle,
        tvgName: item.tvgName,
        catchup: item.catchup,
        catchupSource: item.catchupSource,
      ));
    }

    return M3uResult(
      channels: channels,
      vodItems: vodItems,
      series: seriesMap.values.toList(),
      radioStations: radioStations,
    );
  }

  static bool _isRadio(String group, String name) {
    final g = group.toLowerCase();
    final n = name.toLowerCase();
    return g.contains('radio') || n.contains('radio');
  }

  static bool _isVod(String group) {
    final g = group.toLowerCase();
    return g.contains('movie') || g.contains('vod') || g.contains('film');
  }

  // ---------------------------------------------------------------------------
  // Series detection
  // ---------------------------------------------------------------------------

  /// Matches "S01E01", "s02e10", etc.
  static final _sxxexx = RegExp(r'[Ss](\d+)[Ee](\d+)');

  /// Matches "Season 1 - Episode 3" or "Season 01 – Episode 02".
  static final _seasonEpisode = RegExp(
    r'[Ss]eason\s+(\d+)\s*[-–]\s*[Ee]pisode\s+(\d+)',
  );

  static _SeriesInfo? _extractSeriesInfo(String name) {
    // Try SxxExx first (more common in IPTV playlists).
    var match = _sxxexx.firstMatch(name);
    if (match != null) {
      return _SeriesInfo(
        title: _cleanSeriesTitle(name, match.start),
        season: int.parse(match.group(1)!),
        episode: int.parse(match.group(2)!),
      );
    }

    // Try "Season X - Episode Y".
    match = _seasonEpisode.firstMatch(name);
    if (match != null) {
      return _SeriesInfo(
        title: _cleanSeriesTitle(name, match.start),
        season: int.parse(match.group(1)!),
        episode: int.parse(match.group(2)!),
      );
    }

    return null;
  }

  /// Strips common separators (`, `, ` - `, ` | `, ` (`) from the tail of the
  /// series title so `"Breaking Bad - S01E01"` becomes `"Breaking Bad"`.
  static String _cleanSeriesTitle(String name, int splitIndex) {
    var title = name.substring(0, splitIndex).trim();
    // Remove trailing separators.
    final trailingMatch = RegExp(r'\s*[-–|,]+$').firstMatch(title);
    if (trailingMatch != null) {
      title = title.substring(0, trailingMatch.start);
    }
    return title.trim();
  }
}

/// The result of parsing an M3U playlist.
class M3uResult {
  const M3uResult({
    required this.channels,
    required this.vodItems,
    required this.series,
    required this.radioStations,
  });

  final List<M3uChannel> channels;
  final List<M3uVodItem> vodItems;
  final List<M3uSeries> series;
  final List<M3uRadioStation> radioStations;

  int get totalItems => channels.length + vodItems.length + series.length + radioStations.length;
}

// ---------------------------------------------------------------------------
// Parsed item types
// ---------------------------------------------------------------------------

/// A live-TV channel.
class M3uChannel {
  const M3uChannel({
    required this.name,
    this.logo,
    required this.url,
    this.groupTitle,
    this.tvgName,
    this.catchup,
    this.catchupSource,
  });

  final String name;
  final String? logo;
  final String url;
  final String? groupTitle;
  final String? tvgName;
  final String? catchup;
  final String? catchupSource;
}

/// A standalone VOD / movie entry.
class M3uVodItem {
  const M3uVodItem({
    required this.title,
    this.poster,
    required this.url,
    this.groupTitle,
  });

  final String title;
  final String? poster;
  final String url;
  final String? groupTitle;
}

/// A TV series with its episodes.
class M3uSeries {
  const M3uSeries({
    required this.title,
    this.poster,
    required this.episodes,
  });

  final String title;
  final String? poster;
  final List<M3uEpisode> episodes;
}

/// A single episode within a [M3uSeries].
class M3uEpisode {
  const M3uEpisode({
    required this.season,
    required this.episode,
    required this.title,
    required this.url,
    this.thumbnail,
  });

  final int season;
  final int episode;
  final String title;
  final String url;
  final String? thumbnail;
}

/// A radio station.
class M3uRadioStation {
  const M3uRadioStation({
    required this.name,
    this.logo,
    required this.url,
  });

  final String name;
  final String? logo;
  final String url;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

class _ExtinfAttrs {
  const _ExtinfAttrs({
    required this.name,
    this.logo,
    this.groupTitle,
    this.tvgName,
    this.catchup,
    this.catchupSource,
  });

  final String name;
  final String? logo;
  final String? groupTitle;
  final String? tvgName;
  final String? catchup;
  final String? catchupSource;
}

class _RawItem {
  const _RawItem({
    required this.name,
    this.logo,
    required this.url,
    this.groupTitle,
    this.tvgName,
    this.catchup,
    this.catchupSource,
  });

  final String name;
  final String? logo;
  final String url;
  final String? groupTitle;
  final String? tvgName;
  final String? catchup;
  final String? catchupSource;
}

class _SeriesInfo {
  const _SeriesInfo({
    required this.title,
    required this.season,
    required this.episode,
  });

  final String title;
  final int season;
  final int episode;
}
