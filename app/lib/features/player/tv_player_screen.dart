import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/player/player_controller.dart';
import '../../core/theme/app_colors.dart';

/// Full-screen TV / Fire TV player with D-pad controls.
///
/// - **Left / Right** arrows: seek +/- 10 s
/// - **Select / Enter / Space**: toggle play / pause
/// - **Back**: exit the player
///
/// Controls are visible by default and auto-hide after 5 seconds.
/// No touch-specific interactions are provided.
class TvPlayerScreen extends StatefulWidget {
  const TvPlayerScreen({
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

              // -- D-pad hint (fades with controls) --------------------------
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
              // -- Top: title -----------------------------------------------
              _buildTopBar(),

              const Spacer(),

              // -- Center: large play/pause indicator -----------------------
              _buildCenterIndicator(ctrl),

              // -- Bottom: seek bar + timestamps + D-pad hints --------------
              if (!widget.isLive) _buildSeekBar(ctrl),
              const SizedBox(height: 8),
              if (!widget.isLive) _buildDpadHints(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterIndicator(PlayerController ctrl) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Container(
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
        );
      },
    );
  }

  Widget _buildSeekBar(PlayerController ctrl) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Text(
                ctrl.positionText,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    activeTrackColor: AppColors.accentPrimary,
                    inactiveTrackColor: AppColors.bgSurface,
                    thumbColor: AppColors.accentPrimary,
                    thumbShape:
                        RoundSliderThumbShape(enabledThumbRadius: 8),
                    trackHeight: 4,
                    overlayShape:
                        RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: ctrl.seekFraction,
                    onChanged: ctrl.seekFractionally,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                ctrl.durationText,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
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
