import 'package:drift/drift.dart' as drift;

import '../data/database.dart';
import '../data/xtream_api_client.dart';

/// Callback for reporting import progress.
typedef ImportProgressCallback = void Function(String message, double progress);

/// Imports content from an Xtream Codes provider into the local Drift database.
///
/// Usage:
/// ```dart
/// final importer = XtreamImporter(db: database);
/// await importer.import(
///   baseUrl: 'http://provider:8080',
///   username: 'user',
///   password: 'pass',
///   onProgress: (msg, pct) => print('$msg ($pct)'),
/// );
/// ```
class XtreamImporter {
  XtreamImporter({
    required this._db,
    this._client,
  });

  final AppDatabase _db;
  XtreamApiClient? _client;

  /// Imports all content (Live, VOD, Series) from the Xtream provider.
  ///
  /// Returns an [XtreamImportResult] summarising what was imported.
  Future<XtreamImportResult> import({
    required String baseUrl,
    required String username,
    required String password,
    String? playlistName,
    ImportProgressCallback? onProgress,
  }) async {
    final client = _client ??
        XtreamApiClient(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
    _client = client;

    // Create playlist record.
    final playlistId = await _db.into(_db.playlists).insert(
          PlaylistsCompanion.insert(
            name: playlistName ?? '$username@$baseUrl',
            url: '$baseUrl/player_api.php?username=$username&password=$password',
            type: 'remote',
            lastSyncedAt: drift.Value(DateTime.now()),
          ),
        );

    var totalChannels = 0;
    var totalVod = 0;
    var totalSeries = 0;

    // --- Import Live TV ---------------------------------------------------
    onProgress?.call('Importing live TV channels...', 0.0);
    try {
      final liveCategories = await client.getLiveCategories();
      for (var i = 0; i < liveCategories.length; i++) {
        final cat = liveCategories[i];
        onProgress?.call(
          'Live: ${cat.name}',
          i / (liveCategories.length * 3),
        );
        final streams = await client.getLiveStreams(
          categoryId: int.tryParse(cat.id),
        );
        for (final stream in streams) {
          final streamUrl = client.getLiveStreamUrl(stream);
          await _db.into(_db.channels).insert(
                ChannelsCompanion.insert(
                  playlistId: playlistId,
                  name: stream.name,
                  logo: drift.Value(stream.streamIcon),
                  url: streamUrl,
                  groupTitle: drift.Value(cat.name),
                  tvgName: drift.Value(stream.epgChannelId),
                ),
              );
          totalChannels++;
        }
      }
    } catch (_) {
      // Provider may not support live categories -- continue.
    }

    // --- Import VOD -------------------------------------------------------
    onProgress?.call('Importing movies & VOD...', 0.33);
    try {
      final vodCategories = await client.getVodCategories();
      for (var i = 0; i < vodCategories.length; i++) {
        final cat = vodCategories[i];
        onProgress?.call(
          'VOD: ${cat.name}',
          0.33 + i / (vodCategories.length * 3),
        );
        final streams = await client.getVodStreams(
          categoryId: int.tryParse(cat.id),
        );
        for (final stream in streams) {
          final streamUrl = client.getVodStreamUrl(stream);
          await _db.into(_db.vodItems).insert(
                VodItemsCompanion.insert(
                  playlistId: playlistId,
                  title: stream.name,
                  poster: drift.Value(stream.streamIcon),
                  url: streamUrl,
                  groupTitle: drift.Value(cat.name),
                ),
              );
          totalVod++;
        }
      }
    } catch (_) {
      // Provider may not support VOD -- continue.
    }

    // --- Import Series ----------------------------------------------------
    onProgress?.call('Importing series...', 0.66);
    try {
      final seriesList = await client.getSeries();
      for (var i = 0; i < seriesList.length; i++) {
        final s = seriesList[i];
        onProgress?.call(
          'Series: ${s.name}',
          0.66 + i / (seriesList.length * 2),
        );

        final seriesId = await _db.into(_db.tvSeries).insert(
              TvSeriesCompanion.insert(
                playlistId: playlistId,
                title: s.name,
                poster: drift.Value(s.cover),
              ),
            );

        // Fetch detailed info (seasons & episodes).
        try {
          final info = await client.getSeriesInfo(s.seriesId);
          for (final entry in info.episodes.entries) {
            final seasonNum = entry.key;
            for (final ep in entry.value) {
              final epUrl = client.getSeriesStreamUrl(
                ep,
                ep.containerExtension,
              );
              await _db.into(_db.episodes).insert(
                    EpisodesCompanion.insert(
                      seriesId: seriesId,
                      season: seasonNum,
                      episode: ep.episodeNum,
                      title: ep.title,
                      url: epUrl,
                      thumbnail: drift.Value(s.cover),
                    ),
                  );
            }
          }
        } catch (_) {
          // Some series may fail to load details -- skip individual series.
        }
        totalSeries++;
      }
    } catch (_) {
      // Provider may not support series -- continue.
    }

    onProgress?.call('Import complete', 1.0);

    return XtreamImportResult(
      playlistId: playlistId,
      channels: totalChannels,
      vodItems: totalVod,
      series: totalSeries,
    );
  }

  /// Releases the underlying HTTP client.
  void close() => _client?.close();
}

/// Summary of what was imported from an Xtream provider.
class XtreamImportResult {
  const XtreamImportResult({
    required this.playlistId,
    required this.channels,
    required this.vodItems,
    required this.series,
  });

  /// The database ID of the created playlist record.
  final int playlistId;

  /// Number of live channels imported.
  final int channels;

  /// Number of VOD / movie items imported.
  final int vodItems;

  /// Number of series imported (each may have multiple episodes).
  final int series;

  int get totalItems => channels + vodItems + series;
}
