import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../detail/detail_screen.dart';
import '../favorites/favorites_screen.dart';
import '../home/home_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import 'bottom_tab_bar.dart';
import 'left_rail_nav.dart';

/// Adaptive navigation shell that switches between mobile bottom tabs and
/// TV left-rail navigation based on device form factor.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  bool _isTv(BuildContext context) =>
      Platform.isLinux ||
      (Platform.isAndroid &&
          MediaQuery.of(context).size.shortestSide > 960);

  /// Mobile tabs: Home, Series, Movies, Live, Radio.
  List<TabDef> get _mobileTabs => const [
        TabDef(icon: Icons.home_rounded, label: 'Home'),
        TabDef(icon: Icons.live_tv_rounded, label: 'Series'),
        TabDef(icon: Icons.movie_rounded, label: 'Movies'),
        TabDef(icon: Icons.tv_rounded, label: 'Live'),
        TabDef(icon: Icons.radio_rounded, label: 'Radio'),
      ];

  /// TV rail items: Home, Series, Movies, Live TV, Radio, My List, Search, Settings.
  List<RailItemDef> get _tvRailItems => const [
        RailItemDef(icon: Icons.home_rounded, label: 'Home'),
        RailItemDef(icon: Icons.live_tv_rounded, label: 'Series'),
        RailItemDef(icon: Icons.movie_rounded, label: 'Movies'),
        RailItemDef(icon: Icons.tv_rounded, label: 'Live TV'),
        RailItemDef(icon: Icons.radio_rounded, label: 'Radio'),
        RailItemDef(icon: Icons.favorite_rounded, label: 'My List'),
        RailItemDef(icon: Icons.search_rounded, label: 'Search'),
        RailItemDef(icon: Icons.settings_rounded, label: 'Settings'),
      ];

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildTabContent() {
    switch (_selectedIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const _FilteredBrowseView(contentType: 'series', title: 'Series');
      case 2:
        return const _FilteredBrowseView(contentType: 'vod', title: 'Movies');
      case 3:
        return const _FilteredBrowseView(contentType: 'live', title: 'Live TV');
      case 4:
        return const _FilteredBrowseView(contentType: 'radio', title: 'Radio');
      default:
        return const HomeScreen();
    }
  }

  Widget _buildRailContent() {
    switch (_selectedIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const _FilteredBrowseView(contentType: 'series', title: 'Series');
      case 2:
        return const _FilteredBrowseView(contentType: 'vod', title: 'Movies');
      case 3:
        return const _FilteredBrowseView(contentType: 'live', title: 'Live TV');
      case 4:
        return const _FilteredBrowseView(contentType: 'radio', title: 'Radio');
      case 5:
        return const FavoritesScreen();
      case 6:
        return const SearchScreen();
      case 7:
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTv = _isTv(context);

    if (isTv) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Row(
          children: [
            LeftRailNav(
              selectedIndex: _selectedIndex,
              items: _tvRailItems,
              onItemTap: _onTabSelected,
            ),
            Expanded(child: _buildRailContent()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: _buildTabContent(),
      bottomNavigationBar: BottomTabBar(
        selectedIndex: _selectedIndex,
        tabs: _mobileTabs,
        onTap: _onTabSelected,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inline filtered browse view (avoids modifying existing BrowseScreen).
// ---------------------------------------------------------------------------

/// Displays a grid of content filtered by type, embedded directly in the
/// navigation shell without route-based navigation.
class _FilteredBrowseView extends StatefulWidget {
  const _FilteredBrowseView({
    required this.contentType,
    required this.title,
  });

  final String contentType;
  final String title;

  @override
  State<_FilteredBrowseView> createState() => _FilteredBrowseViewState();
}

class _FilteredBrowseViewState extends State<_FilteredBrowseView> {
  final _db = AppDatabase();
  List<_BrowseItem> _allItems = [];
  List<_BrowseItem> _filteredItems = [];
  List<String> _groups = [];
  String? _selectedGroup;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No-op: content is loaded in initState.
  }

  Future<void> _loadItems() async {
    final items = <_BrowseItem>[];

    switch (widget.contentType) {
      case 'live':
        final channels = await _db.select(_db.channels).get();
        for (final ch in channels) {
          items.add(_BrowseItem(
            id: ch.id,
            title: ch.name,
            imageUrl: ch.logo,
            url: ch.url,
            groupTitle: ch.groupTitle,
            contentType: 'live',
          ));
        }
        break;
      case 'vod':
        final vodItems = await _db.select(_db.vodItems).get();
        for (final vod in vodItems) {
          items.add(_BrowseItem(
            id: vod.id,
            title: vod.title,
            imageUrl: vod.poster,
            url: vod.url,
            groupTitle: vod.groupTitle,
            contentType: 'vod',
          ));
        }
        break;
      case 'series':
        final series = await _db.select(_db.tvSeries).get();
        for (final s in series) {
          items.add(_BrowseItem(
            id: s.id,
            title: s.title,
            imageUrl: s.poster,
            url: '',
            groupTitle: null,
            contentType: 'series',
          ));
        }
        break;
      case 'radio':
        final stations = await _db.select(_db.radioStations).get();
        for (final radio in stations) {
          items.add(_BrowseItem(
            id: radio.id,
            title: radio.name,
            imageUrl: radio.logo,
            url: radio.url,
            groupTitle: null,
            contentType: 'radio',
          ));
        }
        break;
    }

    final groupSet = <String>{};
    for (final item in items) {
      if (item.groupTitle != null && item.groupTitle!.isNotEmpty) {
        groupSet.add(item.groupTitle!);
      }
    }

    if (mounted) {
      setState(() {
        _allItems = items;
        _filteredItems = items;
        _groups = groupSet.toList()..sort();
        _isLoading = false;
      });
    }
  }

  void _filterByGroup(String? group) {
    setState(() {
      _selectedGroup = group;
      _filteredItems = group == null
          ? _allItems
          : _allItems
              .where((item) => item.groupTitle == group)
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgElevated,
        title: Text(
          widget.title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentPrimary,
              ),
            )
          : Column(
              children: [
                if (_groups.isNotEmpty) _buildGroupChips(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filteredItems.length} items',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppTheme.captionSize,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No items in this category.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppTheme.bodySize,
                            ),
                          ),
                        )
                      : FocusTraversalGroup(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.55,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                              return _buildItemCard(_filteredItems[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildGroupChips() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _buildChip('All', null),
          for (final group in _groups) _buildChip(group, group),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String? group) {
    final isSelected = _selectedGroup == group;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.select) {
            _filterByGroup(group);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => _filterByGroup(group),
          selectedColor: AppColors.accentPrimary,
          backgroundColor: AppColors.bgSurface,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          checkmarkColor: AppColors.textPrimary,
          side: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildItemCard(_BrowseItem item) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.select) {
          _navigateToDetail(item);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => _navigateToDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius:
                      BorderRadius.circular(AppTheme.cardBorderRadius),
                ),
                clipBehavior: Clip.antiAlias,
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTheme.cardTitleSize,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (item.groupTitle != null && item.groupTitle!.isNotEmpty)
              Text(
                item.groupTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTheme.captionSize,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(Icons.movie, color: AppColors.bgSurface, size: 40),
    );
  }

  void _navigateToDetail(_BrowseItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          id: item.id,
          title: item.title,
          imageUrl: item.imageUrl,
          url: item.url,
          groupTitle: item.groupTitle,
          contentType: item.contentType,
        ),
      ),
    );
  }
}

/// Internal model for browse items within the shell.
class _BrowseItem {
  const _BrowseItem({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.url,
    this.groupTitle,
    required this.contentType,
  });

  final int id;
  final String title;
  final String? imageUrl;
  final String url;
  final String? groupTitle;
  final String contentType;
}
