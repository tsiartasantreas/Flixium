import 'package:drift/drift.dart' as drift;

import '../data/database.dart';
import '../data/xtream_api_client.dart';

/// Callback for reporting import progress.
typedef ImportProgressCallback = void Function(String message, double progress);

/// Content types that can be imported from an Xtream provider.
enum XtreamContentType {
  live,
  vod,
  series,
  radio,
}

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

  /// Imports content from the Xtream provider.
  ///
  /// [importTypes] controls which content types to import. Defaults to all
  /// supported types (Live, VOD, Series). Radio is not supported by the
  /// Xtream API and is always skipped.
  ///
  /// Returns an [XtreamImportResult] summarising what was imported.
  Future<XtreamImportResult> import({
    required String baseUrl,
    required String username,
    required String password,
    String? playlistName,
    Set<XtreamContentType>? importTypes,
    ImportProgressCallback? onProgress,
  }) async {
    final types = importTypes ??
        {
          XtreamContentType.live,
          XtreamContentType.vod,
          XtreamContentType.series,
        };

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
    String? lastError;

    // Count how many content types are enabled for progress calculation.
    final enabledTypes = types.where((t) => t != XtreamContentType.radio).length;
    var completedTypes = 0;

    // --- Import Live TV ---------------------------------------------------
    if (types.contains(XtreamContentType.live)) {
      onProgress?.call('Fetching live TV categories...', 0.0);
      try {
        final liveCategories = await client.getLiveCategories();
        for (var i = 0; i < liveCategories.length; i++) {
          final cat = liveCategories[i];
          final typeProgress = completedTypes / enabledTypes;
          onProgress?.call(
            'Live: ${cat.name} (${i + 1}/${liveCategories.length})',
            typeProgress,
          );
          try {
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
          } catch (_) {
            // Skip individual category failures.
          }
        }
        completedTypes++;
      } catch (e) {
        lastError = 'Live TV: $e';
      }
    }

    // --- Import VOD -------------------------------------------------------
    if (types.contains(XtreamContentType.vod)) {
      final typeProgress = completedTypes / enabledTypes;
      onProgress?.call('Fetching movie categories...', typeProgress);
      try {
        final vodCategories = await client.getVodCategories();
        for (var i = 0; i < vodCategories.length; i++) {
          final cat = vodCategories[i];
          final baseProgress = completedTypes / enabledTypes;
          onProgress?.call(
            'Movies: ${cat.name} (${i + 1}/${vodCategories.length})',
            baseProgress,
          );
          try {
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
          } catch (_) {
            // Skip individual category failures.
          }
        }
        completedTypes++;
      } catch (e) {
        lastError = 'Movies: $e';
      }
    }

    // --- Import Series ----------------------------------------------------
    if (types.contains(XtreamContentType.series)) {
      final typeProgress = completedTypes / enabledTypes;
      onProgress?.call('Fetching series list...', typeProgress);
      try {
        final seriesList = await client.getSeries();
        for (var i = 0; i < seriesList.length; i++) {
          final s = seriesList[i];
          final baseProgress = completedTypes / enabledTypes;
          onProgress?.call(
            'Series: ${s.name} (${i + 1}/${seriesList.length})',
            baseProgress,
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
        completedTypes++;
      } catch (e) {
        lastError = 'Series: $e';
      }
    }

    // Radio is not supported by the Xtream API.
    onProgress?.call('Import complete', 1.0);

    return XtreamImportResult(
      playlistId: playlistId,
      channels: totalChannels,
      vodItems: totalVod,
      series: totalSeries,
      radio: 0,
      error: lastError,
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
    this.radio = 0,
    this.error,
  });

  /// The database ID of the created playlist record.
  final int playlistId;

  /// Number of live channels imported.
  final int channels;

  /// Number of VOD / movie items imported.
  final int vodItems;

  /// Number of series imported (each may have multiple episodes).
  final int series;

  /// Number of radio stations imported (always 0 for Xtream).
  final int radio;

  /// Non-null if one or more categories failed to import.
  final String? error;

  int get totalItems => channels + vodItems + series + radio;

  /// Whether any content was imported.
  bool get hasContent => totalItems > 0;

  /// Human-readable summary of imported counts.
  String get summary {
    final parts = <String>[];
    if (channels > 0) parts.add('$channels channels');
    if (vodItems > 0) parts.add('$vodItems movies');
    if (series > 0) parts.add('$series series');
    if (radio > 0) parts.add('$radio radio');
    return parts.isEmpty ? 'No items imported' : parts.join(', ');
  }
}
