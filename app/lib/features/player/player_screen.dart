import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/player/brightness_service.dart';
import '../../core/player/player_controller.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/player_overlay_widgets.dart';

/// Full-screen mobile video player with advanced overlay controls.
///
/// Features:
/// - Tap to show/hide controls (auto-hide after 5 s)
/// - Swipe left side up/down to adjust brightness
/// - Swipe right side up/down to adjust volume
/// - Next / previous channel buttons (live TV)
/// - Audio track selector
/// - Subtitle track selector
/// - Stream info overlay (title, category, resolution)
/// - Seek bar (VOD/series) or live indicator
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
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

  /// Called when the user taps the "next channel" button.
  final VoidCallback? onNextChannel;

  /// Called when the user taps the "previous channel" button.
  final VoidCallback? onPreviousChannel;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  // Keyboard shortcut focus node (for external keyboards / BT remotes).
  final FocusNode _focusNode = FocusNode();

  // -- Brightness / volume swipe state --------------------------------------
  double _brightness = 0.5;
  double _volumeFraction = 1.0;
  bool _showBrightnessIndicator = false;
  bool _showVolumeIndicator = false;
  Timer? _indicatorHideTimer;

  // Track whether the user is currently swiping (to suppress tap).
  bool _isSwiping = false;
  double _swipeStartY = 0;

  @override
  void initState() {
    super.initState();
    _startHideTimer();

    // Initialize brightness from service.
    BrightnessService.initialize().then((b) {
      if (mounted) setState(() => _brightness = b);
    });

    // Sync volume fraction from controller.
    _volumeFraction = widget.controller.volumeFraction;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _indicatorHideTimer?.cancel();
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

  void _onScreenTap() {
    if (_isSwiping) return; // Ignore taps that are actually swipes.
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  /// Back-button logic: hide controls first, exit only when already hidden.
  Future<bool> _onWillPop() async {
    if (_controlsVisible) {
      _hideControls();
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Brightness / Volume swipe gestures
  // ---------------------------------------------------------------------------

  void _onVerticalDragStart(DragStartDetails details) {
    _isSwiping = false;
    _swipeStartY = details.globalPosition.dy;
    _startHideTimer(); // Keep controls visible during swipe.
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLeftSide = details.globalPosition.dx < screenWidth / 2;

    // Calculate delta: swipe up = positive, swipe down = negative.
    final delta = (_swipeStartY - details.globalPosition.dy) / 200;
    _swipeStartY = details.globalPosition.dy;

    if (delta.abs() > 0.005) {
      _isSwiping = true;
    }

    if (isLeftSide) {
      // Brightness
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
      BrightnessService.setBrightness(_brightness);
      setState(() {
        _showBrightnessIndicator = true;
        _showVolumeIndicator = false;
      });
    } else {
      // Volume
      _volumeFraction = (_volumeFraction + delta).clamp(0.0, 1.0);
      widget.controller.setVolumeFraction(_volumeFraction);
      setState(() {
        _showVolumeIndicator = true;
        _showBrightnessIndicator = false;
      });
    }

    _resetIndicatorTimer();
    _startHideTimer(); // Reset auto-hide while user is swiping.
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    // Start fading the indicator after a short delay.
    _resetIndicatorTimer();
    _startHideTimer(); // Reset auto-hide after swipe ends.
  }

  void _resetIndicatorTimer() {
    _indicatorHideTimer?.cancel();
    _indicatorHideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showBrightnessIndicator = false;
          _showVolumeIndicator = false;
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Keyboard shortcuts (for external keyboards / BT remotes on phones)
  // ---------------------------------------------------------------------------

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final ctrl = widget.controller;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.select:
        ctrl.togglePlay();
        _showControls();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        ctrl.seekBy(const Duration(seconds: -10));
        _showControls();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        ctrl.seekBy(const Duration(seconds: 10));
        _showControls();
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
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focusNode,
          onKeyEvent: _onKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onScreenTap,
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // -- Video surface -------------------------------------------
                Center(
                  child: Video(
                    controller: ctrl.videoController,
                    controls: (state) => const SizedBox.shrink(),
                  ),
                ),

                // -- Loading spinner -----------------------------------------
                _buildBufferingOverlay(ctrl),

                // -- Brightness indicator (left side) ------------------------
                Positioned(
                  left: 40,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: AdjustIndicator(
                      icon: _brightness > 0.5
                          ? Icons.brightness_high
                          : _brightness > 0
                              ? Icons.brightness_low
                              : Icons.brightness_1,
                      value: _brightness,
                      visible: _showBrightnessIndicator,
                    ),
                  ),
                ),

                // -- Volume indicator (right side) ---------------------------
                Positioned(
                  right: 40,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: AdjustIndicator(
                      icon: _volumeFraction > 0.5
                          ? Icons.volume_up
                          : _volumeFraction > 0
                              ? Icons.volume_down
                              : Icons.volume_off,
                      value: _volumeFraction,
                      visible: _showVolumeIndicator,
                    ),
                  ),
                ),

                // -- Overlay controls ----------------------------------------
                IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: _buildControls(ctrl),
                ),
              ],
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ctrl.error ?? 'Playback error',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => ctrl.retry(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                        foregroundColor: AppColors.textPrimary,
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
      duration: const Duration(milliseconds: 250),
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
            stops: [0.0, 0.2, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // -- Top bar: back + title + track buttons ---------------------
              _buildTopBar(ctrl),

              // -- Spacer ---------------------------------------------------
              const Spacer(),

              // -- Center: play/pause + next/prev ----------------------------
              _buildCenterArea(ctrl),

              // -- Bottom: progress bar + timestamps -------------------------
              _buildProgressBarArea(ctrl),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(PlayerController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () {
              if (mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 4),
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
                return IconButton(
                  icon: const Icon(Icons.audiotrack,
                      color: AppColors.textPrimary),
                  tooltip: 'Audio tracks',
                  onPressed: () async {
                    final track = await showAudioTrackSelector(
                      context,
                      tracks: ctrl.audioTracks,
                      current: ctrl.currentAudioTrack,
                    );
                    if (track != null) ctrl.setAudioTrack(track);
                  },
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
                return IconButton(
                  icon: Icon(
                    Icons.subtitles,
                    color: hasActive
                        ? AppColors.accentPrimary
                        : AppColors.textPrimary,
                  ),
                  tooltip: 'Subtitles',
                  onPressed: () async {
                    final track = await showSubtitleTrackSelector(
                      context,
                      tracks: ctrl.subtitleTracks,
                      current: ctrl.currentSubtitleTrack,
                    );
                    if (track != null) ctrl.setSubtitleTrack(track);
                  },
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
                padding: const EdgeInsets.only(bottom: 16),
                child: NextPrevChannelButtons(
                  onPrevious: widget.onPreviousChannel,
                  onNext: widget.onNextChannel,
                ),
              ),

            // Play/Pause button
            GestureDetector(
              onTap: () {
                ctrl.togglePlay();
                _startHideTimer(); // Reset auto-hide on interaction.
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ctrl.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: AppColors.textPrimary,
                  size: 36,
                ),
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
          onSeek: widget.isLive
              ? null
              : (fraction) {
                  ctrl.seekFractionally(fraction);
                  _startHideTimer(); // Reset auto-hide on seek.
                },
        );
      },
    );
  }
}
