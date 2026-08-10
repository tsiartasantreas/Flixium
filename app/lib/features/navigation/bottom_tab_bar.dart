import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Netflix-style bottom tab bar for mobile navigation.
///
/// Dark background with icons + text labels. Active tab shows an accent
/// underline indicator. Fixed at the bottom of the screen.
class BottomTabBar extends StatelessWidget {
  const BottomTabBar({
    super.key,
    required this.selectedIndex,
    required this.tabs,
    required this.onTap,
  });

  /// Currently selected tab index.
  final int selectedIndex;

  /// Tab definitions to display.
  final List<TabDef> tabs;

  /// Callback when a tab is tapped.
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(
          top: BorderSide(color: AppColors.bgSurface, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(tabs.length, (index) {
              return Expanded(
                child: _TabItem(
                  tab: tabs[index],
                  isSelected: index == selectedIndex,
                  onTap: () => onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// A single tab item in the bottom bar.
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final TabDef tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.select) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab.icon,
              color: isSelected
                  ? AppColors.accentPrimary
                  : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: AppTheme.cardFocusDuration,
              width: isSelected ? 20 : 0,
              height: 2,
              decoration: const BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.all(Radius.circular(1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Definition for a single tab in the bottom bar.
class TabDef {
  const TabDef({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}
