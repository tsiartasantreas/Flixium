import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../detail/detail_screen.dart';

/// Search screen that searches across all content (channels, VOD, series).
///
/// Mobile: search bar at top with results grid below.
/// TV: D-pad navigable search bar + results grid.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _db = AppDatabase();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<_SearchResult> _results = [];
  bool _hasSearched = false;
  bool _isLoading = false;

  bool get _isTv =>
      Platform.isLinux ||
      (Platform.isAndroid &&
          MediaQuery.of(context).size.shortestSide > 960);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final q = query.toLowerCase();
    final results = <_SearchResult>[];

    // Search channels.
    final channels = await _db.select(_db.channels).get();
    for (final ch in channels) {
      if (ch.name.toLowerCase().contains(q) ||
          (ch.groupTitle != null && ch.groupTitle!.toLowerCase().contains(q))) {
        results.add(_SearchResult(
          id: ch.id,
          title: ch.name,
          imageUrl: ch.logo,
          url: ch.url,
          groupTitle: ch.groupTitle,
          contentType: 'live',
          typeLabel: 'Live TV',
        ));
      }
    }

    // Search VOD.
    final vodItems = await _db.select(_db.vodItems).get();
    for (final vod in vodItems) {
      if (vod.title.toLowerCase().contains(q) ||
          (vod.groupTitle != null &&
              vod.groupTitle!.toLowerCase().contains(q))) {
        results.add(_SearchResult(
          id: vod.id,
          title: vod.title,
          imageUrl: vod.poster,
          url: vod.url,
          groupTitle: vod.groupTitle,
          contentType: 'vod',
          typeLabel: 'Movie',
        ));
      }
    }

    // Search series.
    final series = await _db.select(_db.tvSeries).get();
    for (final s in series) {
      if (s.title.toLowerCase().contains(q)) {
        results.add(_SearchResult(
          id: s.id,
          title: s.title,
          imageUrl: s.poster,
          url: '',
          groupTitle: null,
          contentType: 'series',
          typeLabel: 'Series',
        ));
      }
    }

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _navigateToDetail(_SearchResult item) {
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Column(
        children: [
          // -- Search bar ---------------------------------------------------
          _buildSearchBar(),

          // -- Results count -----------------------------------------------
          if (_hasSearched && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_results.length} results found',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppTheme.captionSize,
                  ),
                ),
              ),
            ),

          // -- Results grid -------------------------------------------------
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentPrimary,
                    ),
                  )
                : !_hasSearched
                    ? _buildEmptyState()
                    : _results.isEmpty
                        ? _buildNoResults()
                        : _buildResultsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: AppTheme.horizontalPadding,
        right: AppTheme.horizontalPadding,
        bottom: 8,
      ),
      color: AppColors.bgElevated,
      child: Focus(
        focusNode: _searchFocusNode,
        onKeyEvent: (node, event) {
          // On TV, allow typing to start search.
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.select) {
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search channels, movies, series...',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _results = [];
                        _hasSearched = false;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.bgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius + 4),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius + 4),
              borderSide: const BorderSide(
                color: AppColors.accentPrimary,
                width: 2,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: _performSearch,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_rounded,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            'Search Everything',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Find live channels, movies, and series.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppTheme.bodySize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Results',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Try a different search term.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppTheme.bodySize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid() {
    return FocusTraversalGroup(
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          return _buildResultCard(_results[index]);
        },
      ),
    );
  }

  Widget _buildResultCard(_SearchResult item) {
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
            // Poster / thumbnail.
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

            // Title.
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

            // Type label.
            Text(
              item.typeLabel,
              style: const TextStyle(
                color: AppColors.accentPrimary,
                fontSize: AppTheme.captionSize,
                fontWeight: FontWeight.w500,
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
}

/// Internal search result model.
class _SearchResult {
  const _SearchResult({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.url,
    this.groupTitle,
    required this.contentType,
    required this.typeLabel,
  });

  final int id;
  final String title;
  final String? imageUrl;
  final String url;
  final String? groupTitle;
  final String contentType;
  final String typeLabel;
}
