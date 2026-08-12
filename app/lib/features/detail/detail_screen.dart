import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/database.dart';
import '../../core/data/offline_download_service.dart';
import '../../core/player/player_controller.dart';
import '../../core/theme/app_colors.dart';
import '../player/player_screen.dart';
import '../player/tv_player_screen.dart';
import 'widgets/download_button.dart';
import 'widgets/episode_download_button.dart';

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
  final _downloadService = OfflineDownloadService.instance;
  List<_EpisodeItem> _episodes = [];
  bool _isLoadingEpisodes = false;
  EpgProgramme? _currentProgramme;
  EpgProgramme? _nextProgramme;

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
    if (_isLive) {
      _loadEpgData();
    }
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadEpisodes() async {
    setState(() => _isLoadingEpisodes = true);

    try {
      final episodes = await (_db.select(_db.episodes)
            ..where((t) => t.seriesId.equals(widget.id))
            ..orderBy([
              (t) => drift.OrderingTerm.asc(t.season),
              (t) => drift.OrderingTerm.asc(t.episode),
            ]))
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
    } catch (e) {
      // ignore: avoid_print
      print('[DetailScreen] Failed to load episodes: $e');
      if (mounted) {
        setState(() {
          _episodes = [];
          _isLoadingEpisodes = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // EPG data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadEpgData() async {
    try {
      // Look up the channel's tvgName for EPG matching.
      final channel = await (_db.select(_db.channels)
            ..where((t) => t.id.equals(widget.id)))
          .getSingleOrNull();
      if (channel == null) return;

      // Build list of possible EPG channel IDs to match.
      final matchIds = <String>[];
      if (channel.tvgName != null && channel.tvgName!.isNotEmpty) {
        matchIds.add(channel.tvgName!);
      }
      matchIds.add(channel.name);

      final now = DateTime.now();

      // Query all programmes for matching channel IDs, ordered by start.
      final programmes = await (_db.select(_db.epgProgrammes)
            ..where((t) => t.channelId.isIn(matchIds))
            ..orderBy([(t) => drift.OrderingTerm.asc(t.start)]))
          .get();

      if (programmes.isEmpty) return;

      // Find the current programme (start <= now < stop).
      EpgProgramme? current;
      EpgProgramme? next;
      for (final p in programmes) {
        if (p.start.isBefore(now) && p.stop.isAfter(now)) {
          current = p;
        } else if (p.start.isAfter(now) && current != null) {
          next = p;
          break;
        }
      }

      // If we found current but not next, look for the programme right after.
      if (current != null && next == null) {
        for (final p in programmes) {
          if (p.start.isAfter(current.stop)) {
            next = p;
            break;
          }
        }
      }

      // If no current programme found, find the next upcoming one.
      if (current == null) {
        for (final p in programmes) {
          if (p.start.isAfter(now)) {
            next = p;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _currentProgramme = current;
          _nextProgramme = next;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('[DetailScreen] Failed to load EPG data: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Channel navigation (live TV — next/prev in same group)
  // ---------------------------------------------------------------------------

  /// Cache of channels in the same group as the current live channel, ordered
  /// by name.  Loaded lazily on first play of a live channel.
  List<Channel>? _siblingChannels;
  int _currentChannelIndex = -1;

  /// Load channels in the same group as the current channel, determine the
  /// current channel's index, and cache the result.
  Future<void> _ensureSiblingChannels() async {
    if (_siblingChannels != null) return;
    if (widget.groupTitle == null || widget.groupTitle!.isEmpty) return;

    try {
      // First get the current channel to find its playlistId.
      final currentChannel = await (_db.select(_db.channels)
            ..where((t) => t.id.equals(widget.id)))
          .getSingleOrNull();
      if (currentChannel == null) return;

      // Get all channels in the same group from the same playlist.
      final channels = await (_db.select(_db.channels)
            ..where((t) =>
                t.playlistId.equals(currentChannel.playlistId) &
                t.groupTitle.equals(widget.groupTitle!))
            ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
          .get();

      _siblingChannels = channels;
      _currentChannelIndex =
          channels.indexWhere((c) => c.id == widget.id);
    } catch (e) {
      // ignore: avoid_print
      print('[DetailScreen] Failed to load sibling channels: $e');
      _siblingChannels = [];
    }
  }

  void _playNextChannel() {
    if (_siblingChannels == null || _siblingChannels!.isEmpty) return;
    final nextIndex = _currentChannelIndex + 1;
    if (nextIndex >= _siblingChannels!.length) return; // Already last.
    final next = _siblingChannels![nextIndex];
    _currentChannelIndex = nextIndex;
    // Pop the current player and play the next channel.
    Navigator.of(context).pop();
    _playContent(next.url, next.name, isLive: true);
  }

  void _playPreviousChannel() {
    if (_siblingChannels == null || _siblingChannels!.isEmpty) return;
    final prevIndex = _currentChannelIndex - 1;
    if (prevIndex < 0) return; // Already first.
    final prev = _siblingChannels![prevIndex];
    _currentChannelIndex = prevIndex;
    Navigator.of(context).pop();
    _playContent(prev.url, prev.name, isLive: true);
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  Future<void> _playContent(
    String url,
    String title, {
    bool isLive = false,
    String? contentId,
  }) async {
    // ignore: avoid_print
    print('[DetailScreen] Playing: title="$title", url=$url, isLive=$isLive, contentType=${widget.contentType}');

    // If a contentId is provided, check for a local download first.
    String playbackUrl = url;
    if (contentId != null) {
      final localPath = await _downloadService.getLocalPath(contentId);
      if (localPath != null && await File(localPath).exists()) {
        playbackUrl = localPath;
      }
    }

    // ignore: avoid_print
    print('[DetailScreen] Resolved playback URL: $playbackUrl');

    if (!mounted) return;

    // For live TV, pre-load sibling channels for next/prev navigation.
    VoidCallback? onNext;
    VoidCallback? onPrevious;
    if (isLive) {
      await _ensureSiblingChannels();
      if (_siblingChannels != null && _siblingChannels!.isNotEmpty) {
        if (_currentChannelIndex < _siblingChannels!.length - 1) {
          onNext = _playNextChannel;
        }
        if (_currentChannelIndex > 0) {
          onPrevious = _playPreviousChannel;
        }
      }
    }

    if (!mounted) return;

    final controller = PlayerController();
    controller.open(playbackUrl);

    final playerScreen = _isTv
        ? TvPlayerScreen(
            controller: controller,
            title: title,
            isLive: isLive,
            category: widget.groupTitle,
            contentType: widget.contentType,
            onNextChannel: onNext,
            onPreviousChannel: onPrevious,
          )
        : PlayerScreen(
            controller: controller,
            title: title,
            isLive: isLive,
            category: widget.groupTitle,
            contentType: widget.contentType,
            onNextChannel: onNext,
            onPreviousChannel: onPrevious,
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

                    // -- Play + Download buttons --------------------------------
                    if (widget.url.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
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
                                      contentId:
                                          '${widget.contentType}_${widget.id}',
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
                                    contentId:
                                        '${widget.contentType}_${widget.id}',
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
                          ),
                          if (!_isLive) ...[
                            const SizedBox(width: 12),
                            DownloadButton(
                              contentId: '${widget.contentType}_${widget.id}',
                              title: widget.title,
                              url: widget.url,
                              contentType: widget.contentType,
                              thumbnailUrl: widget.imageUrl,
                              onPlayOffline: () => _playContent(
                                widget.url,
                                widget.title,
                                isLive: _isLive,
                                contentId:
                                    '${widget.contentType}_${widget.id}',
                              ),
                            ),
                          ],
                        ],
                      ),

                    // -- EPG Programme Guide (live channels) -----------------
                    if (_isLive &&
                        (_currentProgramme != null ||
                            _nextProgramme != null)) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Programme Guide',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_currentProgramme != null)
                        _buildEpgTile(
                          _currentProgramme!,
                          isLive: true,
                        ),
                      if (_nextProgramme != null) ...[
                        const SizedBox(height: 8),
                        _buildEpgTile(
                          _nextProgramme!,
                          isLive: false,
                        ),
                      ],
                    ],

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
    final episodeContentId = 'series_ep_${episode.id}';
    return Card(
      color: AppColors.bgElevated,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.select) {
            _playContent(
              episode.url,
              episode.title,
              contentId: episodeContentId,
            );
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EpisodeDownloadButton(
                contentId: episodeContentId,
                title: 'S${episode.season}E${episode.episode} - ${episode.title}',
                url: episode.url,
                thumbnailUrl: episode.thumbnail,
                onPlayOffline: () => _playContent(
                  episode.url,
                  episode.title,
                  contentId: episodeContentId,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.play_circle_outline,
                color: AppColors.accentPrimary,
                size: 28,
              ),
            ],
          ),
          onTap: () => _playContent(
            episode.url,
            episode.title,
            contentId: episodeContentId,
          ),
        ),
      ),
    );
  }

  Widget _buildEpgTile(EpgProgramme programme, {required bool isLive}) {
    final startH = programme.start.hour.toString().padLeft(2, '0');
    final startM = programme.start.minute.toString().padLeft(2, '0');
    final stopH = programme.stop.hour.toString().padLeft(2, '0');
    final stopM = programme.stop.minute.toString().padLeft(2, '0');
    final timeRange = '$startH:$startM - $stopH:$stopM';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLive
            ? AppColors.accentPrimary.withValues(alpha: 0.15)
            : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: isLive
            ? Border.all(
                color: AppColors.accentPrimary.withValues(alpha: 0.4),
                width: 1,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Header row: label + time ------------------------------------
          Row(
            children: [
              if (isLive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NOW',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEXT',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                timeRange,
                style: TextStyle(
                  color: isLive
                      ? AppColors.accentPrimary
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // -- Programme title ---------------------------------------------
          Text(
            programme.title,
            style: TextStyle(
              color: isLive ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 16,
              fontWeight: isLive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),

          // -- Description -------------------------------------------------
          if (programme.description != null &&
              programme.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                programme.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
        ],
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
