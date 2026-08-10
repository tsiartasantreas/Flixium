import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A wrapper that applies Netflix-style focus / hover animations to its child.
///
/// Animations:
/// - Scale 1.0 -> 1.08 on focus (200 ms ease-out).
/// - Drop shadow on focus.
/// - Accent-colored ring on focus.
/// - Dims neighboring cards when focused (caller handles neighbor opacity).
class AnimatedFocus extends StatefulWidget {
  const AnimatedFocus({
    super.key,
    required this.child,
    this.onFocusChanged,
    this.isTv = false,
  });

  /// The child widget to wrap with focus animations.
  final Widget child;

  /// Called when focus state changes, with `true` when focused.
  final ValueChanged<bool>? onFocusChanged;

  /// Whether this widget is on a TV (enables focus ring and dimming).
  final bool isTv;

  @override
  State<AnimatedFocus> createState() => _AnimatedFocusState();
}

class _AnimatedFocusState extends State<AnimatedFocus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _shadowAnimation;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.cardFocusDuration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: AppTheme.cardFocusScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _shadowAnimation = Tween<double>(
      begin: AppTheme.cardElevation,
      end: AppTheme.cardElevationFocused,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange(bool hasFocus) {
    setState(() => _hasFocus = hasFocus);
    if (hasFocus) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onFocusChanged?.call(hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: _onFocusChange,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = _scaleAnimation.value;
          final elevation = _shadowAnimation.value;

          return AnimatedScale(
            scale: scale,
            duration: AppTheme.cardFocusDuration,
            curve: Curves.easeOut,
            child: Container(
              decoration: _hasFocus && widget.isTv
                  ? BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppTheme.cardBorderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentPrimary.withValues(alpha: 0.4),
                          blurRadius: elevation * 2,
                          spreadRadius: elevation * 0.5,
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.accentPrimary,
                        width: 2.0,
                      ),
                    )
                  : _hasFocus
                      ? BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppTheme.cardBorderRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: elevation * 2,
                              spreadRadius: elevation * 0.3,
                            ),
                          ],
                        )
                      : null,
              child: widget.child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
