import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/database.dart';
import '../../core/player/player_controller.dart';
import '../../core/theme/app_colors.dart';
import '../player/player_screen.dart';
import '../player/tv_player_screen.dart';

/// Content detail screen showing title, poster, and play button.
///
/// Supports live channels, VOD, series (with episodes), and radio.
class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.id,
    required this.title,
    this.imageUrl,
    required this.url,
    this.groupTitle,
    required this.contentType,
  });

  final int id;
  final String title;
  final String? imageUrl;
  final String url;
  final String? groupTitle;
  final String contentType;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _db = AppDatabase();
  List<_EpisodeItem> _episodes = [];
  bool _isLoadingEpisodes = false;

  bool get _isTv =>
      Platform.isLinux ||
      (Platform.isAndroid &&
          MediaQueryData.fromView(
                      WidgetsBinding.instance.platformDispatcher.views.first)
                  .size
                  .shortestSide >
              960);

  bool get _isLive => widget.contentType == 'live';
  bool get _isSeries => widget.contentType == 'series';

  @override
  void initState() {
    super.initState();
    if (_isSeries) {
      _loadEpisodes();
    }
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadEpisodes() async {
    setState(() => _isLoadingEpisodes = true);

    final episodes = await (_db.select(_db.episodes)
          ..where((t) => t.seriesId.equals(widget.id))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.season),
                     (t) => drift.OrderingTerm.asc(t.episode)]))
        .get();

    if (mounted) {
      setState(() {
        _episodes = episodes
            .map((ep) => _EpisodeItem(
                  id: ep.id,
                  season: ep.season,
                  episode: ep.episode,
                  title: ep.title,
                  url: ep.url,
                  thumbnail: ep.thumbnail,
                ))
            .toList();
        _isLoadingEpisodes = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  void _playContent(String url, String title, {bool isLive = false}) {
    final controller = PlayerController();
    controller.open(url);

    final playerScreen = _isTv
        ? TvPlayerScreen(
            controller: controller,
            title: title,
            isLive: isLive,
          )
        : PlayerScreen(
            controller: controller,
            title: title,
            isLive: isLive,
          );

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => playerScreen))
        .then((_) => controller.dispose());
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: CustomScrollView(
        slivers: [
          // -- App bar with poster background -------------------------------
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.bgElevated,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              background: widget.imageUrl != null &&
                      widget.imageUrl!.isNotEmpty
                  ? Image.network(
                      widget.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPosterPlaceholder(),
                    )
                  : _buildPosterPlaceholder(),
            ),
          ),

          // -- Content details ---------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -- Title -----------------------------------------------
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // -- Group tag -------------------------------------------
                    if (widget.groupTitle != null &&
                        widget.groupTitle!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.groupTitle!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // -- Content type badge ----------------------------------
                    _buildTypeBadge(),
                    const SizedBox(height: 20),

                    // -- Play button -----------------------------------------
                    if (widget.url.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey ==
                                    LogicalKeyboardKey.select) {
                              _playContent(
                                widget.url,
                                widget.title,
                                isLive: _isLive,
                              );
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: ElevatedButton.icon(
                            onPressed: () => _playContent(
                              widget.url,
                              widget.title,
                              isLive: _isLive,
                            ),
                            icon: const Icon(Icons.play_arrow, size: 24),
                            label: Text(
                              _isLive ? 'Watch Live' : 'Play',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPrimary,
                              foregroundColor: AppColors.textPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // -- Series episodes -------------------------------------
                    if (_isSeries) ...[
                      const SizedBox(height: 32),
                      const Text(
                        'Episodes',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingEpisodes)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentPrimary,
                          ),
                        )
                      else if (_episodes.isEmpty)
                        const Text(
                          'No episodes available.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        )
                      else
                        ..._episodes.map(_buildEpisodeTile),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge() {
    IconData icon;
    String label;
    Color color;

    switch (widget.contentType) {
      case 'live':
        icon = Icons.live_tv;
        label = 'Live TV';
        color = Colors.red;
        break;
      case 'vod':
        icon = Icons.movie;
        label = 'Movie';
        color = AppColors.accentPrimary;
        break;
      case 'series':
        icon = Icons.tv;
        label = 'Series';
        color = Colors.blue;
        break;
      case 'radio':
        icon = Icons.radio;
        label = 'Radio';
        color = Colors.green;
        break;
      default:
        icon = Icons.help_outline;
        label = 'Unknown';
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeTile(_EpisodeItem episode) {
    return Card(
      color: AppColors.bgElevated,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.select) {
            _playContent(episode.url, episode.title);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            child: episode.thumbnail != null && episode.thumbnail!.isNotEmpty
                ? Image.network(
                    episode.thumbnail!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(
                      Icons.movie,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  )
                : const Icon(
                    Icons.movie,
                    color: AppColors.textSecondary,
                    size: 24,
                  ),
          ),
          title: Text(
            'S${episode.season}E${episode.episode} - ${episode.title}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(
            Icons.play_circle_outline,
            color: AppColors.accentPrimary,
            size: 28,
          ),
          onTap: () => _playContent(episode.url, episode.title),
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      color: AppColors.bgSurface,
      child: const Center(
        child: Icon(
          Icons.movie,
          color: AppColors.bgElevated,
          size: 80,
        ),
      ),
    );
  }
}

/// Internal model for episodes.
class _EpisodeItem {
  const _EpisodeItem({
    required this.id,
    required this.season,
    required this.episode,
    required this.title,
    required this.url,
    this.thumbnail,
  });

  final int id;
  final int season;
  final int episode;
  final String title;
  final String url;
  final String? thumbnail;
}
