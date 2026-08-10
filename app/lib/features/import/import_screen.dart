import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/data/database.dart';
import '../../core/data/m3u_parser.dart';
import '../../core/theme/app_colors.dart';

/// Playlist import screen.
///
/// Users can add M3U playlists by URL, view imported playlists, and remove them.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => ImportScreenState();
}

@visibleForTesting
class ImportScreenState extends State<ImportScreen> {
  final TextEditingController _urlController = TextEditingController();
  final _db = AppDatabase();
  List<Playlist> _playlists = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data operations
  // ---------------------------------------------------------------------------

  Future<void> _loadPlaylists() async {
    final playlists = await _db.select(_db.playlists).get();
    if (mounted) {
      setState(() => _playlists = playlists);
    }
  }

  Future<void> _addPlaylist() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Please enter a URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 30),
          );
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final result = M3uParser.parse(response.body);

      if (result.totalItems == 0) {
        throw Exception('No items found in playlist');
      }

      // Create playlist record.
      final playlistId = await _db.into(_db.playlists).insert(
            PlaylistsCompanion.insert(
              name: 'Playlist ${_playlists.length + 1}',
              url: url,
              type: 'remote',
              lastSyncedAt: drift.Value(DateTime.now()),
            ),
          );

      // Batch insert channels.
      for (final ch in result.channels) {
        await _db.into(_db.channels).insert(
              ChannelsCompanion.insert(
                playlistId: playlistId,
                name: ch.name,
                logo: drift.Value(ch.logo),
                url: ch.url,
                groupTitle: drift.Value(ch.groupTitle),
                tvgName: drift.Value(ch.tvgName),
              ),
            );
      }

      // Batch insert VOD items.
      for (final vod in result.vodItems) {
        await _db.into(_db.vodItems).insert(
              VodItemsCompanion.insert(
                playlistId: playlistId,
                title: vod.title,
                poster: drift.Value(vod.poster),
                url: vod.url,
                groupTitle: drift.Value(vod.groupTitle),
              ),
            );
      }

      // Batch insert series + episodes.
      for (final s in result.series) {
        final seriesId = await _db.into(_db.tvSeries).insert(
              TvSeriesCompanion.insert(
                playlistId: playlistId,
                title: s.title,
                poster: drift.Value(s.poster),
              ),
            );
        for (final ep in s.episodes) {
          await _db.into(_db.episodes).insert(
                EpisodesCompanion.insert(
                  seriesId: seriesId,
                  season: ep.season,
                  episode: ep.episode,
                  title: ep.title,
                  url: ep.url,
                  thumbnail: drift.Value(ep.thumbnail),
                ),
              );
        }
      }

      // Batch insert radio stations.
      for (final radio in result.radioStations) {
        await _db.into(_db.radioStations).insert(
              RadioStationsCompanion.insert(
                playlistId: playlistId,
                name: radio.name,
                logo: drift.Value(radio.logo),
                url: radio.url,
              ),
            );
      }

      _urlController.clear();
      await _loadPlaylists();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${result.totalItems} items '
              '(${result.channels.length} channels, '
              '${result.vodItems.length} movies, '
              '${result.series.length} series, '
              '${result.radioStations.length} radio)',
            ),
            backgroundColor: AppColors.bgSurface,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Import failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removePlaylist(Playlist playlist) async {
    // Delete child records first (foreign key constraints).
    await (_db.delete(_db.channels)
          ..where((t) => t.playlistId.equals(playlist.id)))
        .go();
    await (_db.delete(_db.vodItems)
          ..where((t) => t.playlistId.equals(playlist.id)))
        .go();
    await (_db.delete(_db.radioStations)
          ..where((t) => t.playlistId.equals(playlist.id)))
        .go();

    // Delete episodes via series.
    final seriesIds = await (_db.select(_db.tvSeries)
          ..where((t) => t.playlistId.equals(playlist.id)))
        .get();
    for (final s in seriesIds) {
      await (_db.delete(_db.episodes)
            ..where((t) => t.seriesId.equals(s.id)))
          .go();
    }
    await (_db.delete(_db.tvSeries)
          ..where((t) => t.playlistId.equals(playlist.id)))
        .go();

    // Delete the playlist itself.
    await (_db.delete(_db.playlists)
          ..where((t) => t.id.equals(playlist.id)))
        .go();

    await _loadPlaylists();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Import Playlists',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: FocusTraversalGroup(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -- URL input ------------------------------------------------
              TextField(
                controller: _urlController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'https://example.com/playlist.m3u',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        )
                      : null,
                ),
                onSubmitted: (_) => _addPlaylist(),
              ),
              const SizedBox(height: 12),

              // -- Add button -----------------------------------------------
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addPlaylist,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isLoading ? 'Importing...' : 'Add Playlist',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // -- Error message --------------------------------------------
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ],

              const SizedBox(height: 24),

              // -- Imported playlists header ---------------------------------
              const Text(
                'Imported Playlists',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // -- Playlist list ---------------------------------------------
              Expanded(
                child: _playlists.isEmpty
                    ? const Center(
                        child: Text(
                          'No playlists imported yet.\nAdd a playlist URL above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = _playlists[index];
                          return _buildPlaylistTile(playlist);
                        },
                      ),
              ),

              // -- Skip button (navigate to home) ---------------------------
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.bgSurface),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Skip for now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(Playlist playlist) {
    return Card(
      color: AppColors.bgElevated,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(
          Icons.playlist_play,
          color: AppColors.accentPrimary,
          size: 32,
        ),
        title: Text(
          playlist.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          playlist.url,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.select) {
              _confirmRemove(playlist);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _confirmRemove(playlist),
          ),
        ),
      ),
    );
  }

  void _confirmRemove(Playlist playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Remove Playlist',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove "${playlist.name}" and all its content?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _removePlaylist(playlist);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
