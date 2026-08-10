import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/database.dart';
import '../../core/theme/app_colors.dart';
import '../detail/detail_screen.dart';

/// TV-guide style EPG (Electronic Programme Guide) grid.
///
/// Displays channels vertically with their programmes arranged on a
/// horizontal time axis. A red vertical line marks the current time.
/// Supports D-pad navigation for TV (up/down between channels,
/// left/right between time slots).
class EpgScreen extends StatefulWidget {
  const EpgScreen({super.key, this.database});

  /// Database instance — injectable for testing.
  final AppDatabase? database;

  @override
  State<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends State<EpgScreen> {
  AppDatabase? _db;
  List<_ChannelRow> _channels = [];
  bool _isLoading = true;

  /// Duration of each time-slot in the grid.
  static const Duration _slotDuration = Duration(minutes: 30);

  /// Width of each time-slot cell in logical pixels.
  static const double _slotWidth = 200.0;

  /// Width of the channel-name sidebar.
  static const double _channelColumnWidth = 160.0;

  /// Height of each channel row.
  static const double _rowHeight = 80.0;

  /// Height of the time-header row.
  static const double _headerHeight = 40.0;

  final ScrollController _timeScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();

  bool get _isTv =>
      Platform.isLinux ||
      (Platform.isAndroid &&
          MediaQueryData.fromView(
                      WidgetsBinding.instance.platformDispatcher.views.first)
                  .size
                  .shortestSide >
              960);

  @override
  void initState() {
    super.initState();
    _db = widget.database;
    _loadEpgData();
  }

  @override
  void dispose() {
    _timeScrollController.dispose();
    _channelScrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadEpgData() async {
    setState(() => _isLoading = true);

    if (_db == null) {
      if (mounted) {
        setState(() {
          _channels = [];
          _isLoading = false;
        });
      }
      return;
    }

    // Fetch all EPG programmes.
    final programmes = await (_db!.select(_db!.epgProgrammes)
          ..orderBy([
            (t) => drift.OrderingTerm.asc(t.channelId),
            (t) => drift.OrderingTerm.asc(t.start),
          ]))
        .get();

    // Group programmes by channelId and build channel rows.
    final Map<String, List<EpgProgramme>> grouped = {};
    for (final p in programmes) {
      grouped.putIfAbsent(p.channelId, () => []).add(p);
    }

    // Also fetch channel names/logos from the Channels table.
    final channels = await (_db!.select(_db!.channels)
          ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
        .get();

    // Build a lookup from tvgName -> channel info.
    final Map<String, Channel> channelLookup = {};
    for (final c in channels) {
      final tvgName = c.tvgName;
      if (tvgName != null && tvgName.isNotEmpty) {
        channelLookup[tvgName] = c;
      }
      // Also index by name for fallback matching.
      channelLookup[c.name] = c;
    }

    final rows = <_ChannelRow>[];
    for (final entry in grouped.entries) {
      final channelId = entry.key;
      final channelProgrammes = entry.value;

      // Try to match to a Channel record.
      final channel = channelLookup[channelId];

      rows.add(_ChannelRow(
        channelId: channelId,
        channelName: channel?.name ?? channelId,
        logoUrl: channel?.logo,
        programmes: channelProgrammes,
      ));
    }

    // Sort by channel name.
    rows.sort((a, b) => a.channelName.compareTo(b.channelName));

    if (mounted) {
      setState(() {
        _channels = rows;
        _isLoading = false;
      });

      // Scroll to current time after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentTime();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Scrolling
  // ---------------------------------------------------------------------------

  void _scrollToCurrentTime() {
    if (!_timeScrollController.hasClients) return;

    final now = DateTime.now();
    // Calculate the start of the grid (one slot before now).
    final gridStart = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour - 1,
    );

    final offset = now.difference(gridStart).inMinutes / _slotDuration.inMinutes * _slotWidth;
    final clampedOffset = offset.clamp(
      0.0,
      _timeScrollController.position.maxScrollExtent,
    );
    _timeScrollController.jumpTo(clampedOffset);
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  void _onProgrammeTap(EpgProgramme programme) {
    // Find the channel's stream URL.
    final channelRow = _channels.firstWhere(
      (c) => c.channelId == programme.channelId,
      orElse: () => _ChannelRow(
        channelId: programme.channelId,
        channelName: programme.channelId,
        programmes: [],
      ),
    );

    // Navigate to detail with programme info.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          id: programme.channelId.hashCode,
          title: programme.title,
          imageUrl: channelRow.logoUrl,
          url: '', // EPG programmes don't have direct stream URLs
          groupTitle: 'EPG',
          contentType: 'live',
        ),
      ),
    );
  }

  void _showProgrammeDetail(EpgProgramme programme) {
    final now = DateTime.now();
    final isLive = programme.start.isBefore(now) && programme.stop.isAfter(now);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Programme title
            Text(
              programme.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Time range
            Text(
              '${_formatTime(programme.start)} - ${_formatTime(programme.stop)}',
              style: TextStyle(
                color: isLive ? AppColors.accentPrimary : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: isLive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isLive) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Description
            if (programme.description != null &&
                programme.description!.isNotEmpty)
              Text(
                programme.description!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

            const SizedBox(height: 20),

            // Channel name
            Text(
              'Channel: ${programme.channelId}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  DateTime _timeSlotStart(int slotIndex, DateTime dayStart) {
    return dayStart.add(_slotDuration * slotIndex);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentPrimary),
      );
    }

    if (_channels.isEmpty) {
      return _buildEmptyState();
    }

    // Compute grid bounds.
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(hours: 24));
    final totalSlots = dayEnd.difference(dayStart).inMinutes ~/
        _slotDuration.inMinutes;

    // Find the "now" slot index.
    final nowSlot = now.difference(dayStart).inMinutes ~/
        _slotDuration.inMinutes;

    return Column(
      children: [
        // -- Time header ---------------------------------------------------
        _buildTimeHeader(dayStart, totalSlots, nowSlot),

        // -- Channel grid --------------------------------------------------
        Expanded(
          child: Row(
            children: [
              // Channel name column (fixed).
              _buildChannelColumn(),

              // Time-scrolling programme area.
              Expanded(
                child: _buildProgrammeGrid(
                  dayStart,
                  totalSlots,
                  nowSlot,
                  now,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.tv,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No EPG Data',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Programme guide data will appear here once loaded.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadEpgData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Time header
  // ---------------------------------------------------------------------------

  Widget _buildTimeHeader(
    DateTime dayStart,
    int totalSlots,
    int nowSlot,
  ) {
    return Container(
      height: _headerHeight,
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(
          bottom: BorderSide(color: AppColors.bgSurface, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Channel column placeholder (matches sidebar width).
          const SizedBox(
            width: _channelColumnWidth,
            child: Center(
              child: Text(
                'Channels',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Time slots.
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Sync scrolling between header and grid if needed.
                return false;
              },
              child: ListView.builder(
                controller: _timeScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: totalSlots,
                itemBuilder: (context, index) {
                  final slotTime = _timeSlotStart(index, dayStart);
                  final isNow = index == nowSlot;

                  return SizedBox(
                    width: _slotWidth,
                    child: Center(
                      child: Text(
                        _formatTime(slotTime),
                        style: TextStyle(
                          color: isNow
                              ? AppColors.accentPrimary
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isNow
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Channel name column (fixed)
  // ---------------------------------------------------------------------------

  Widget _buildChannelColumn() {
    return Container(
      width: _channelColumnWidth,
      decoration: const BoxDecoration(
        color: AppColors.bgBase,
        border: Border(
          right: BorderSide(color: AppColors.bgSurface, width: 0.5),
        ),
      ),
      child: ListView.builder(
        controller: _channelScrollController,
        padding: const EdgeInsets.only(top: _rowHeight), // offset for header
        itemCount: _channels.length,
        itemBuilder: (context, index) {
          final channel = _channels[index];
          return _buildChannelNameTile(channel);
        },
      ),
    );
  }

  Widget _buildChannelNameTile(_ChannelRow channel) {
    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.bgSurface, width: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Logo or placeholder icon.
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            child: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
                ? Image.network(
                    channel.logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildLogoPlaceholder(),
                  )
                : _buildLogoPlaceholder(),
          ),
          const SizedBox(width: 8),

          // Channel name.
          Expanded(
            child: Text(
              channel.channelName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return const Center(
      child: Icon(
        Icons.live_tv,
        color: AppColors.textSecondary,
        size: 16,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Programme grid
  // ---------------------------------------------------------------------------

  Widget _buildProgrammeGrid(
    DateTime dayStart,
    int totalSlots,
    int nowSlot,
    DateTime now,
  ) {
    return Column(
      children: [
        // Time header for the scrollable area.
        SizedBox(
          height: _headerHeight,
          child: ListView.builder(
            controller: _timeScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: totalSlots,
            itemBuilder: (context, index) {
              final slotTime = _timeSlotStart(index, dayStart);
              final isNow = index == nowSlot;

              return SizedBox(
                width: _slotWidth,
                child: Center(
                  child: Text(
                    _formatTime(slotTime),
                    style: TextStyle(
                      color: isNow
                          ? AppColors.accentPrimary
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight:
                          isNow ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Channel rows.
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _channels.length,
            itemBuilder: (context, rowIndex) {
              final channel = _channels[rowIndex];
              return _buildChannelRow(
                channel,
                dayStart,
                totalSlots,
                nowSlot,
                now,
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Single channel row with programmes
  // ---------------------------------------------------------------------------

  Widget _buildChannelRow(
    _ChannelRow channel,
    DateTime dayStart,
    int totalSlots,
    int nowSlot,
    DateTime now,
  ) {
    return Container(
      height: _rowHeight,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.bgSurface, width: 0.3),
        ),
      ),
      child: Stack(
        children: [
          // Background: programme cells.
          ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: totalSlots,
            itemBuilder: (context, slotIndex) {
              final slotStart = _timeSlotStart(slotIndex, dayStart);
              final slotEnd = slotStart.add(_slotDuration);

              // Find programmes that overlap this slot.
              final programme = channel.programmes.firstWhere(
                (p) => p.start.isBefore(slotEnd) && p.stop.isAfter(slotStart),
                orElse: () => EpgProgramme(
                  channelId: channel.channelId,
                  start: slotStart,
                  stop: slotEnd,
                  title: '',
                  description: null,
                ),
              );

              // Only render if this slot starts within the programme.
              final isStartSlot = slotStart.isAtSameMomentAs(programme.start) ||
                  (slotStart.isAfter(programme.start) &&
                      slotStart.difference(programme.start).inMinutes <
                          _slotDuration.inMinutes);

              if (!isStartSlot || programme.title.isEmpty) {
                // Empty slot.
                return SizedBox(
                  width: _slotWidth,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }

              // Calculate the width based on how many slots this programme spans.
              final endSlot =
                  (programme.stop.difference(dayStart).inMinutes / _slotDuration.inMinutes)
                      .ceil()
                      .clamp(slotIndex + 1, totalSlots);
              final spanSlots = endSlot - slotIndex;
              final cellWidth = _slotWidth * spanSlots;

              // Determine if this programme is currently live.
              final isLive = programme.start.isBefore(now) &&
                  programme.stop.isAfter(now);

              return GestureDetector(
                onTap: () => _onProgrammeTap(programme),
                onLongPress: () => _showProgrammeDetail(programme),
                child: Container(
                  width: cellWidth,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isLive
                        ? AppColors.accentPrimary.withValues(alpha: 0.2)
                        : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(3),
                    border: isLive
                        ? Border.all(
                            color: AppColors.accentPrimary.withValues(alpha: 0.5),
                            width: 1,
                          )
                        : null,
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _isTv
                      ? Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey ==
                                    LogicalKeyboardKey.select) {
                              _onProgrammeTap(programme);
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: _buildProgrammeContent(programme, isLive),
                        )
                      : _buildProgrammeContent(programme, isLive),
                ),
              );
            },
          ),

          // Current time indicator (red vertical line).
          if (nowSlot >= 0 && nowSlot < totalSlots)
            _buildCurrentTimeIndicator(dayStart, now),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Current time line
  // ---------------------------------------------------------------------------

  Widget _buildCurrentTimeIndicator(DateTime dayStart, DateTime now) {
    final minutesSinceStart = now.difference(dayStart).inMinutes;
    final offset = minutesSinceStart / _slotDuration.inMinutes * _slotWidth;

    return Positioned(
      left: offset,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        color: AppColors.accentPrimary,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Programme content
  // ---------------------------------------------------------------------------

  Widget _buildProgrammeContent(EpgProgramme programme, bool isLive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          programme.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isLive ? AppColors.accentHover : AppColors.textPrimary,
            fontSize: 12,
            fontWeight: isLive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),

        // Time range
        const SizedBox(height: 2),
        Text(
          '${_formatTime(programme.start)} - ${_formatTime(programme.stop)}',
          style: TextStyle(
            color: isLive
                ? AppColors.accentPrimary
                : AppColors.textSecondary,
            fontSize: 10,
          ),
        ),

        // Live indicator
        if (isLive) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accentPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Internal models
// ---------------------------------------------------------------------------

/// A single channel row in the EPG grid.
class _ChannelRow {
  const _ChannelRow({
    required this.channelId,
    required this.channelName,
    this.logoUrl,
    required this.programmes,
  });

  final String channelId;
  final String channelName;
  final String? logoUrl;
  final List<EpgProgramme> programmes;
}
