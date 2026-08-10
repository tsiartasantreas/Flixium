import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/database.dart';
import '../../core/theme/app_colors.dart';
import '../detail/detail_screen.dart';

/// Category browse screen showing all items in a content type.
///
/// Displays a grid of items with optional group filtering.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({
    super.key,
    required this.contentType,
    required this.title,
  });

  /// Content type: "live", "vod", "series", or "radio".
  final String contentType;

  /// Display title for the app bar.
  final String title;

  @override
  State<BrowseScreen> createState() => BrowseScreenState();
}

@visibleForTesting
class BrowseScreenState extends State<BrowseScreen> {
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

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

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

    // Extract unique groups.
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

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _navigateToDetail(_BrowseItem item) {
    Navigator.of(context)
        .push(
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
    )
        .then((_) => _loadItems());
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentPrimary,
              ),
            )
          : Column(
              children: [
                // -- Group filter chips -------------------------------------
                if (_groups.isNotEmpty) _buildGroupChips(),

                // -- Item count ---------------------------------------------
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filteredItems.length} items',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                // -- Grid of items ------------------------------------------
                Expanded(
                  child: _filteredItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No items in this category.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
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
            // -- Poster / thumbnail ----------------------------------------
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(6),
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

            // -- Title -----------------------------------------------------
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            // -- Group tag --------------------------------------------------
            if (item.groupTitle != null && item.groupTitle!.isNotEmpty)
              Text(
                item.groupTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(
        Icons.movie,
        color: AppColors.bgSurface,
        size: 40,
      ),
    );
  }
}

/// Internal model for browse items.
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
