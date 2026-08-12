import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/player/player_controller.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/player_overlay_widgets.dart';

/// Full-screen TV / Fire TV player with D-pad controls and advanced overlays.
///
/// D-pad mapping:
/// - **Left / Right** arrows: seek +/- 10 s
/// - **Select / Enter / Space**: toggle play / pause
/// - **Up**: show controls (if hidden)
/// - **Down**: hide controls
/// - **Back / Escape**: exit player
///
/// Controls are visible by default and auto-hide after 5 seconds.
class TvPlayerScreen extends StatefulWidget {
  const TvPlayerScreen({
    super.key,
    required this.controller,
    this.title = '',
    this.isLive = false,
    this.category,
    this.contentType,
    this.onNextChannel,
    this.onPreviousChannel,
  });

  final PlayerController controller;

  /// Display name shown in the top overlay.
  final String title;

  /// When true the seek bar shows a live indicator instead of a slider.
  final bool isLive;

  /// Channel group / category name (e.g. "Sports", "Movies 4K").
  final String? category;

  /// Content type: "live", "vod", "series", "radio".
  final String? contentType;

  /// Called when the user triggers "next channel" via D-pad or button.
  final VoidCallback? onNextChannel;

  /// Called when the user triggers "previous channel" via D-pad or button.
  final VoidCallback? onPreviousChannel;

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Controls visibility
  // ---------------------------------------------------------------------------

  void _showControls() {
    setState(() => _controlsVisible = true);
    _startHideTimer();
  }

  void _hideControls() {
    if (mounted) setState(() => _controlsVisible = false);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), _hideControls);
  }

  // ---------------------------------------------------------------------------
  // D-pad key handling
  // ---------------------------------------------------------------------------

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final ctrl = widget.controller;

    switch (event.logicalKey) {
      // Center / Select / Enter / Space => toggle play/pause
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        ctrl.togglePlay();
        _showControls();
        return KeyEventResult.handled;

      // Left arrow => seek backward 10 s
      case LogicalKeyboardKey.arrowLeft:
        ctrl.seekBy(const Duration(seconds: -10));
        _showControls();
        return KeyEventResult.handled;

      // Right arrow => seek forward 10 s
      case LogicalKeyboardKey.arrowRight:
        ctrl.seekBy(const Duration(seconds: 10));
        _showControls();
        return KeyEventResult.handled;

      // Up arrow => show controls (if hidden)
      case LogicalKeyboardKey.arrowUp:
        _showControls();
        return KeyEventResult.handled;

      // Down arrow => hide controls
      case LogicalKeyboardKey.arrowDown:
        _hideControls();
        return KeyEventResult.handled;

      // Back / Escape => exit player
      case LogicalKeyboardKey.goBack:
      case LogicalKeyboardKey.escape:
        if (mounted) Navigator.of(context).pop();
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focusNode,
          onKeyEvent: _onKey,
          autofocus: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // -- Video surface ---------------------------------------------
              Center(
                child: Video(
                  controller: ctrl.videoController,
                  controls: (state) => const SizedBox.shrink(),
                ),
              ),

              // -- Buffering indicator ---------------------------------------
              _buildBufferingOverlay(ctrl),

              // -- Overlay controls ------------------------------------------
              if (_controlsVisible) _buildControls(ctrl),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Buffering overlay
  // ---------------------------------------------------------------------------

  Widget _buildBufferingOverlay(PlayerController ctrl) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        // -- Error state -------------------------------------------------
        if (ctrl.hasError) {
          return Container(
            color: Colors.black87,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 56,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      ctrl.error ?? 'Playback error',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      autofocus: true,
                      onPressed: () => ctrl.retry(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // -- Buffering state ---------------------------------------------
        if (!ctrl.isBuffering) return const SizedBox.shrink();
        return Container(
          color: Colors.black45,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.accentPrimary),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Controls overlay
  // ---------------------------------------------------------------------------

  Widget _buildControls(PlayerController ctrl) {
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black87,
              Colors.transparent,
              Colors.transparent,
              Colors.black87,
            ],
            stops: [0.0, 0.25, 0.65, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // -- Top: title + track buttons --------------------------------
              _buildTopBar(ctrl),

              const Spacer(),

              // -- Center: play/pause + next/prev ----------------------------
              _buildCenterArea(ctrl),

              // -- Bottom: progress bar + timestamps + D-pad hints -----------
              _buildProgressBarArea(ctrl),
              const SizedBox(height: 8),
              if (!widget.isLive) _buildDpadHints(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(PlayerController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.arrow_back,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: StreamInfoOverlay(
              title: widget.title,
              category: widget.category,
              resolution: ctrl.videoResolution,
              contentType: widget.contentType,
            ),
          ),
          // Audio track button (only if multiple tracks)
          AnimatedBuilder(
            animation: ctrl,
            builder: (context, _) {
              if (ctrl.hasMultipleAudioTracks) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _TvIconButton(
                    icon: Icons.audiotrack,
                    tooltip: 'Audio tracks',
                    onPressed: () async {
                      final track = await showAudioTrackSelector(
                        context,
                        tracks: ctrl.audioTracks,
                        current: ctrl.currentAudioTrack,
                      );
                      if (track != null) ctrl.setAudioTrack(track);
                    },
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Subtitle track button (only if subtitles available)
          AnimatedBuilder(
            animation: ctrl,
            builder: (context, _) {
              if (ctrl.hasSubtitleTracks) {
                final hasActive =
                    ctrl.currentSubtitleTrack != SubtitleTrack.no();
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _TvIconButton(
                    icon: Icons.subtitles,
                    tooltip: 'Subtitles',
                    color: hasActive ? AppColors.accentPrimary : null,
                    onPressed: () async {
                      final track = await showSubtitleTrackSelector(
                        context,
                        tracks: ctrl.subtitleTracks,
                        current: ctrl.currentSubtitleTrack,
                      );
                      if (track != null) ctrl.setSubtitleTrack(track);
                    },
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCenterArea(PlayerController ctrl) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Next/Prev buttons for live TV
            if (widget.isLive &&
                (widget.onNextChannel != null ||
                    widget.onPreviousChannel != null))
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: NextPrevChannelButtons(
                  onPrevious: widget.onPreviousChannel,
                  onNext: widget.onNextChannel,
                ),
              ),

            // Play/Pause indicator
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                ctrl.isPlaying ? Icons.pause : Icons.play_arrow,
                color: AppColors.textPrimary,
                size: 40,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressBarArea(PlayerController ctrl) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return PlayerProgressBar(
          positionText: ctrl.positionText,
          durationText: ctrl.durationText,
          seekFraction: ctrl.seekFraction,
          isLive: widget.isLive,
          onSeek: widget.isLive ? null : ctrl.seekFractionally,
        );
      },
    );
  }

  Widget _buildDpadHints() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _hintChip(Icons.fast_rewind, '10s'),
        const SizedBox(width: 24),
        _hintChip(Icons.play_arrow, 'Play'),
        const SizedBox(width: 24),
        _hintChip(Icons.fast_forward, '10s'),
      ],
    );
  }

  Widget _hintChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Focusable icon button for TV/D-pad navigation.
class _TvIconButton extends StatelessWidget {
  const _TvIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: focused
                    ? AppColors.accentPrimary.withValues(alpha: 0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: focused
                    ? Border.all(color: AppColors.accentPrimary, width: 2)
                    : null,
              ),
              child: Tooltip(
                message: tooltip ?? '',
                child: Icon(
                  icon,
                  color: color ?? AppColors.textPrimary,
                  size: 24,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
