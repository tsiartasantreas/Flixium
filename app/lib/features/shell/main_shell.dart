import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../browse/browse_screen.dart';
import '../favorites/favorites_screen.dart';
import '../home/home_screen.dart';
import '../offline/offline_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import 'mobile_nav.dart';
import 'tv_left_rail.dart';

/// Root navigation shell that switches between mobile and TV layouts.
///
/// Mobile layout: six-tab bottom navigation bar.
/// TV layout: eight-item left vertical rail.
/// TV mode is detected via screen shortest side exceeding 960 px on Android
/// or always on Linux.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _mobileIndex = 0;
  int _tvIndex = 0;

  bool get _isTv =>
      Platform.isLinux ||
      (Platform.isAndroid &&
          MediaQueryData.fromView(
                      WidgetsBinding.instance.platformDispatcher.views.first)
                  .size
                  .shortestSide >
              600);

  void _onTabChanged(int index) {
    setState(() {
      if (_isTv) {
        _tvIndex = index;
      } else {
        _mobileIndex = index;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Content builders for each tab
  // ---------------------------------------------------------------------------

  Widget _buildMobileTab(int index) {
    switch (index) {
      case 0: // Home
        return const HomeScreen();
      case 1: // Live TV
        return const BrowseScreen(contentType: 'live', title: 'Live TV');
      case 2: // Movies
        return const BrowseScreen(contentType: 'vod', title: 'Movies');
      case 3: // Series
        return const BrowseScreen(contentType: 'series', title: 'Series');
      case 4: // Radio
        return const BrowseScreen(contentType: 'radio', title: 'Radio');
      case 5: // Downloads
        return const OfflineScreen();
      default:
        return const HomeScreen();
    }
  }

  Widget _buildTvTab(int index) {
    switch (index) {
      case 0: // Home
        return const HomeScreen();
      case 1: // Series
        return const BrowseScreen(contentType: 'series', title: 'Series');
      case 2: // Movies
        return const BrowseScreen(contentType: 'vod', title: 'Movies');
      case 3: // Live TV
        return const BrowseScreen(contentType: 'live', title: 'Live TV');
      case 4: // Radio
        return const BrowseScreen(contentType: 'radio', title: 'Radio');
      case 5: // My List
        return const FavoritesScreen();
      case 6: // Search
        return const SearchScreen();
      case 7: // Downloads
        return const OfflineScreen();
      default:
        return const HomeScreen();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isTv) {
      return _buildTvLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Column(
        children: [
          // Top bar with settings access.
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 8,
              16,
              8,
            ),
            decoration: const BoxDecoration(
              color: AppColors.bgBase,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.person_outline,
                    color: AppColors.textSecondary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Tab content.
          Expanded(
            child: IndexedStack(
              index: _mobileIndex,
              children: [
                _buildMobileTab(0),
                _buildMobileTab(1),
                _buildMobileTab(2),
                _buildMobileTab(3),
                _buildMobileTab(4),
                _buildMobileTab(5),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: MobileNav(
        currentIndex: _mobileIndex,
        onTap: _onTabChanged,
      ),
    );
  }

  Widget _buildTvLayout() {
    return FocusTraversalGroup(
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          // Handle global Back button on TV remote to exit the app gracefully.
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.goBack) {
            // Let the system handle back navigation.
            return KeyEventResult.ignored;
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          backgroundColor: AppColors.bgBase,
          body: Row(
            children: [
              TvLeftRail(
                currentIndex: _tvIndex,
                onTap: _onTabChanged,
              ),
              Expanded(
                child: _buildTvTab(_tvIndex),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

