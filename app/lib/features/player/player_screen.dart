import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/player/player_controller.dart';
import '../../core/theme/app_colors.dart';

/// Full-screen mobile video player with overlay controls.
///
/// Controls auto-hide after 3 seconds of inactivity. Tap to show/hide.
/// Back button hides controls first, then exits the player.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.controller,
    this.title = '',
    this.isLive = false,
  });

  final PlayerController controller;

  /// Display name shown in the top overlay.
  final String title;

  /// When true the seek bar is hidden and duration shows "LIVE".
  final bool isLive;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  // Keyboard shortcut focus node (for external keyboards / BT remotes).
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
    _hideTimer = Timer(const Duration(seconds: 3), _hideControls);
  }

  void _onScreenTap() {
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

                // -- Overlay controls ----------------------------------------
                if (_controlsVisible) _buildControls(ctrl),
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
              // -- Top bar: back + title -------------------------------------
              _buildTopBar(),

              // -- Spacer ---------------------------------------------------
              const Spacer(),

              // -- Center: play / pause -------------------------------------
              _buildCenterButton(ctrl),

              // -- Bottom: seek bar + timestamps -----------------------------
              if (!widget.isLive) _buildSeekBar(ctrl),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterButton(PlayerController ctrl) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return GestureDetector(
          onTap: ctrl.togglePlay,
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
        );
      },
    );
  }

  Widget _buildSeekBar(PlayerController ctrl) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Current position
              Text(
                ctrl.positionText,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),

              // Slider
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    activeTrackColor: AppColors.accentPrimary,
                    inactiveTrackColor: AppColors.bgSurface,
                    thumbColor: AppColors.accentPrimary,
                    thumbShape:
                        RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    overlayShape:
                        RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: ctrl.seekFraction,
                    onChanged: ctrl.seekFractionally,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Duration
              Text(
                ctrl.durationText,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
