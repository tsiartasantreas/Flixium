import 'package:drift/drift.dart' as drift;

import '../data/database.dart';
import '../data/xtream_api_client.dart';
import 'models/xtream_models.dart';

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
/// The playlist record must be created by the caller (e.g. via
/// [PlaylistManager]) so that credentials are encrypted and linked to the
/// correct user. This class only inserts content items (channels, VOD,
/// series, episodes) under the given [playlistId].
///
/// Usage:
/// ```dart
/// final importer = XtreamImporter(db: database);
/// await importer.import(
///   playlistId: 42,
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

  /// Imports content from the Xtream provider under the given [playlistId].
  ///
  /// [importTypes] controls which content types to import. Defaults to all
  /// supported types (Live, VOD, Series). Radio is not supported by the
  /// Xtream API and is always skipped.
  ///
  /// Returns an [XtreamImportResult] summarising what was imported.
  Future<XtreamImportResult> import({
    required int playlistId,
    required String baseUrl,
    required String username,
    required String password,
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
        // ignore: avoid_print
        print('[XtreamImport] Live categories: ${liveCategories.length}');

        // Fetch streams for all categories in parallel to speed up import.
        onProgress?.call(
          'Fetching live TV streams (${liveCategories.length} categories)...',
          completedTypes / enabledTypes,
        );
        final categoryStreams = await Future.wait(
          liveCategories.map((cat) async {
            try {
              final streams = await client.getLiveStreams(
                categoryId: int.tryParse(cat.id),
              );
              // ignore: avoid_print
              print('[XtreamImport] Live cat "${cat.name}" → ${streams.length} streams');
              return streams;
            } catch (e) {
              // ignore: avoid_print
              print('[XtreamImport] Live cat "${cat.name}" FAILED: $e');
              return <XtreamStream>[];
            }
          }),
        );

        // Insert streams into the database sequentially.
        for (var i = 0; i < liveCategories.length; i++) {
          final cat = liveCategories[i];
          final streams = categoryStreams[i];
          final typeProgress = completedTypes / enabledTypes;
          onProgress?.call(
            'Live: ${cat.name} (${i + 1}/${liveCategories.length})',
            typeProgress,
          );
          for (final stream in streams) {
            final streamUrl = client.getLiveStreamUrl(stream);
            // ignore: avoid_print
            print('[XtreamImport] LIVE "${stream.name}" → url=$streamUrl');
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
        completedTypes++;
      } catch (e) {
        // ignore: avoid_print
        print('[XtreamImport] Live TV FAILED: $e');
        lastError = 'Live TV: $e';
      }
    }

    // --- Import VOD -------------------------------------------------------
    if (types.contains(XtreamContentType.vod)) {
      final typeProgress = completedTypes / enabledTypes;
      onProgress?.call('Fetching movie categories...', typeProgress);
      try {
        final vodCategories = await client.getVodCategories();
        // ignore: avoid_print
        print('[XtreamImport] ====== VOD IMPORT START ======');
        // ignore: avoid_print
        print('[XtreamImport] VOD categories returned: ${vodCategories.length}');

        // Fetch streams for all VOD categories in parallel to speed up import.
        onProgress?.call(
          'Fetching movie streams (${vodCategories.length} categories)...',
          typeProgress,
        );
        final categoryStreams = await Future.wait(
          vodCategories.map((cat) async {
            try {
              final catId = int.tryParse(cat.id);
              // ignore: avoid_print
              print('[XtreamImport]   Fetching VOD streams for categoryId=$catId '
                  '(raw id="${cat.id}")...');
              final streams = await client.getVodStreams(categoryId: catId);
              // ignore: avoid_print
              print('[XtreamImport]   VOD cat "${cat.name}" → ${streams.length} streams');
              if (streams.isNotEmpty) {
                final first = streams.first;
                // ignore: avoid_print
                print('[XtreamImport]   First stream: name="${first.name}", '
                    'streamId=${first.streamId}, '
                    'containerExtension="${first.containerExtension}", '
                    'streamType="${first.streamType}", '
                    'categoryId="${first.categoryId}", '
                    'streamIcon="${first.streamIcon}"');
              }
              return streams;
            } catch (e, st) {
              // ignore: avoid_print
              print('[XtreamImport] VOD cat "${cat.name}" FAILED: $e');
              // ignore: avoid_print
              print('[XtreamImport] VOD cat stack trace: $st');
              return <XtreamStream>[];
            }
          }),
        );

        // Insert streams into the database sequentially.
        for (var i = 0; i < vodCategories.length; i++) {
          final cat = vodCategories[i];
          final streams = categoryStreams[i];
          final baseProgress = completedTypes / enabledTypes;
          onProgress?.call(
            'Movies: ${cat.name} (${i + 1}/${vodCategories.length})',
            baseProgress,
          );
          for (final stream in streams) {
            final streamUrl = client.getVodStreamUrl(stream);
            // ignore: avoid_print
            print('[XtreamImport]   VOD "${stream.name}" '
                '(streamId=${stream.streamId}, ext="${stream.containerExtension}") '
                '→ url=$streamUrl');
            await _db.into(_db.vodItems).insert(
                  VodItemsCompanion.insert(
                    playlistId: playlistId,
                    title: stream.name,
                    poster: drift.Value(stream.streamIcon),
                    url: streamUrl,
                    groupTitle: drift.Value(cat.name),
                    rating: drift.Value(stream.rating),
                  ),
                );
            totalVod++;
          }
        }
        // ignore: avoid_print
        print('[XtreamImport] ====== VOD IMPORT DONE: $totalVod movies ======');
        completedTypes++;
      } catch (e) {
        // ignore: avoid_print
        print('[XtreamImport] VOD FAILED: $e');
        lastError = 'Movies: $e';
      }
    }

    // --- Import Series ----------------------------------------------------
    if (types.contains(XtreamContentType.series)) {
      final typeProgress = completedTypes / enabledTypes;
      onProgress?.call('Fetching series list...', typeProgress);
      try {
        final seriesList = await client.getSeries();
        // ignore: avoid_print
        print('[XtreamImport] Series: ${seriesList.length}');

        // Fetch detailed info for all series in parallel to speed up import.
        onProgress?.call(
          'Fetching series details (${seriesList.length} series)...',
          typeProgress,
        );
        final seriesDetails = await Future.wait(
          seriesList.map((s) async {
            try {
              final info = await client.getSeriesInfo(s.seriesId);
              // ignore: avoid_print
              print('[XtreamImport] Series "${s.name}" (xid=${s.seriesId}): '
                  '${info.seasons.length} seasons, '
                  '${info.episodes.length} season-keys in episodes map');
              return info;
            } catch (e, st) {
              // ignore: avoid_print
              print('[XtreamImport] Series "${s.name}" (xid=${s.seriesId}) '
                  'detail FAILED: $e');
              // ignore: avoid_print
              print('[XtreamImport] Stack trace: $st');
              return null;
            }
          }),
        );

        // Insert series and episodes into the database sequentially.
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
                  description: drift.Value(s.plot),
                  rating: drift.Value(s.rating),
                  genre: drift.Value(s.genre),
                  cast: drift.Value(s.cast),
                  director: drift.Value(s.director),
                  releaseDate: drift.Value(s.releaseDate),
                ),
              );

          final info = seriesDetails[i];
          if (info != null) {
            var epCount = 0;
            for (final entry in info.episodes.entries) {
              final seasonNum = entry.key;
              for (final ep in entry.value) {
                final epUrl = client.getSeriesStreamUrl(
                  ep,
                  ep.containerExtension,
                );
                // ignore: avoid_print
                print('[XtreamImport] SERIES EP "${ep.title}" '
                    'S${seasonNum}E${ep.episodeNum} (epId=${ep.id}) '
                    '→ url=$epUrl');
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
                epCount++;
              }
            }
            // ignore: avoid_print
            print('[XtreamImport] Series "${s.name}" imported $epCount episodes');
          }
          totalSeries++;
        }
        completedTypes++;
      } catch (e) {
        // ignore: avoid_print
        print('[XtreamImport] Series FAILED: $e');
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
