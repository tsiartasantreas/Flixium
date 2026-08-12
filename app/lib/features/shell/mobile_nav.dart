import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Netflix-style bottom tab bar for mobile navigation.
///
/// Displays five tabs: Home, Live TV, Movies, Series, and Radio.
/// Selected tab uses [AppColors.accentPrimary]; unselected uses
/// [AppColors.textSecondary]. The bar sits above the system UI insets.
class MobileNav extends StatelessWidget {
  const MobileNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  /// The currently selected tab index (0–4).
  final int currentIndex;

  /// Called when the user taps a tab. The new index is passed.
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
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.accentPrimary,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.live_tv_outlined),
              activeIcon: Icon(Icons.live_tv),
              label: 'Live TV',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.movie_outlined),
              activeIcon: Icon(Icons.movie),
              label: 'Movies',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tv_outlined),
              activeIcon: Icon(Icons.tv),
              label: 'Series',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.radio_outlined),
              activeIcon: Icon(Icons.radio),
              label: 'Radio',
            ),
          ],
        ),
      ),
    );
  }
}
