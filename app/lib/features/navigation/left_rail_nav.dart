import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Netflix-style left vertical navigation rail for TV.
///
/// Fixed on the left side of the screen (~80px wide). Supports D-pad
/// up/down navigation. Active item has accent highlight + scale effect.
class LeftRailNav extends StatefulWidget {
  const LeftRailNav({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onItemTap,
  });

  /// Currently selected item index.
  final int selectedIndex;

  /// Rail item definitions.
  final List<RailItemDef> items;

  /// Callback when an item is tapped or selected via D-pad.
  final ValueChanged<int> onItemTap;

  @override
  State<LeftRailNav> createState() => _LeftRailNavState();
}

class _LeftRailNavState extends State<LeftRailNav> {
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.items.length; i++) {
      _focusNodes.add(FocusNode());
    }
  }

  @override
  void didUpdateWidget(LeftRailNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      for (final node in _focusNodes) {
        node.dispose();
      }
      _focusNodes.clear();
      for (var i = 0; i < widget.items.length; i++) {
        _focusNodes.add(FocusNode());
      }
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(
          right: BorderSide(color: AppColors.bgSurface, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Brand logo area.
          const SizedBox(height: 16),
          const Text(
            'F',
            style: TextStyle(
              color: AppColors.accentPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Navigation items.
          Expanded(
            child: FocusTraversalGroup(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final isSelected = index == widget.selectedIndex;
                  final focusNode = _focusNodes[index];

                  return _RailItem(
                    item: item,
                    isSelected: isSelected,
                    focusNode: focusNode,
                    onTap: () => widget.onItemTap(index),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single item in the left rail navigation.
class _RailItem extends StatefulWidget {
  const _RailItem({
    required this.item,
    required this.isSelected,
    required this.focusNode,
    required this.onTap,
  });

  final RailItemDef item;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_RailItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isSelected || widget.focusNode.hasFocus;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.select) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: isHighlighted ? AppTheme.cardFocusScale : 1.0,
            duration: AppTheme.cardFocusDuration,
            child: AnimatedContainer(
              duration: AppTheme.cardFocusDuration,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppColors.accentPrimary.withValues(alpha: 0.15)
                    : isHighlighted
                        ? AppColors.bgSurface.withValues(alpha: 0.5)
                        : Colors.transparent,
                borderRadius:
                    BorderRadius.circular(AppTheme.cardBorderRadius + 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.item.icon,
                    color: widget.isSelected
                        ? AppColors.accentPrimary
                        : isHighlighted
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.label,
                    style: TextStyle(
                      color: widget.isSelected
                          ? AppColors.accentPrimary
                          : isHighlighted
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight:
                          widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Definition for a single item in the left rail.
class RailItemDef {
  const RailItemDef({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}
