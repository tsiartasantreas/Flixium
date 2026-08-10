import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/database.dart';
import '../../core/theme/app_colors.dart';
import '../browse/browse_screen.dart';
import '../detail/detail_screen.dart';
import '../import/import_screen.dart';
import 'widgets/content_row.dart';

/// Main home screen displaying content organized by type.
///
/// Shows horizontal scrollable rows for Live TV, Movies, Series, and Radio.
/// Displays an empty state with an import button if no playlists exist.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

@visibleForTesting
class HomeScreenState extends State<HomeScreen> {
  final _db = AppDatabase();
  List<ContentRow> _rows = [];
  bool _isEmpty = true;
  bool _isLoading = true;

  bool get _isTv =>
      Platform.isLinux ||
      (Platform.isAndroid &&
          MediaQueryData.fromView(
                      WidgetsBinding.instance.platformDispatcher.views.first)
                  .size
                  .shortestSide >
              960);

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when returning from import screen.
    _loadContent();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadContent() async {
    final playlists = await _db.select(_db.playlists).get();
    if (playlists.isEmpty) {
      if (mounted) {
        setState(() {
          _isEmpty = true;
          _isLoading = false;
        });
      }
      return;
    }

    final channels = await _db.select(_db.channels).get();
    final vodItems = await _db.select(_db.vodItems).get();
    final series = await _db.select(_db.tvSeries).get();
    final radioStations = await _db.select(_db.radioStations).get();

    if (mounted) {
      final rows = <ContentRow>[];

      if (channels.isNotEmpty) {
        rows.add(ContentRow(
          label: 'Live TV',
          isTv: _isTv,
          items: channels.take(20).map((ch) {
            return ContentItem(
              title: ch.name,
              imageUrl: ch.logo,
              onTap: () => _navigateToDetail(
                id: ch.id,
                title: ch.name,
                imageUrl: ch.logo,
                url: ch.url,
                groupTitle: ch.groupTitle,
                contentType: 'live',
              ),
            );
          }).toList(),
          onSeeAll: () => _navigateToBrowse('live', 'Live TV'),
        ));
      }

      if (vodItems.isNotEmpty) {
        rows.add(ContentRow(
          label: 'Movies',
          isTv: _isTv,
          items: vodItems.take(20).map((vod) {
            return ContentItem(
              title: vod.title,
              imageUrl: vod.poster,
              onTap: () => _navigateToDetail(
                id: vod.id,
                title: vod.title,
                imageUrl: vod.poster,
                url: vod.url,
                groupTitle: vod.groupTitle,
                contentType: 'vod',
              ),
            );
          }).toList(),
          onSeeAll: () => _navigateToBrowse('vod', 'Movies'),
        ));
      }

      if (series.isNotEmpty) {
        rows.add(ContentRow(
          label: 'Series',
          isTv: _isTv,
          items: series.take(20).map((s) {
            return ContentItem(
              title: s.title,
              imageUrl: s.poster,
              onTap: () => _navigateToDetail(
                id: s.id,
                title: s.title,
                imageUrl: s.poster,
                url: '',
                contentType: 'series',
              ),
            );
          }).toList(),
          onSeeAll: () => _navigateToBrowse('series', 'Series'),
        ));
      }

      if (radioStations.isNotEmpty) {
        rows.add(ContentRow(
          label: 'Radio',
          isTv: _isTv,
          items: radioStations.take(20).map((radio) {
            return ContentItem(
              title: radio.name,
              imageUrl: radio.logo,
              onTap: () => _navigateToDetail(
                id: radio.id,
                title: radio.name,
                imageUrl: radio.logo,
                url: radio.url,
                contentType: 'radio',
              ),
            );
          }).toList(),
          onSeeAll: () => _navigateToBrowse('radio', 'Radio'),
        ));
      }

      setState(() {
        _rows = rows;
        _isEmpty = rows.isEmpty;
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _navigateToDetail({
    required int id,
    required String title,
    String? imageUrl,
    required String url,
    String? groupTitle,
    required String contentType,
  }) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          id: id,
          title: title,
          imageUrl: imageUrl,
          url: url,
          groupTitle: groupTitle,
          contentType: contentType,
        ),
      ),
    )
        .then((_) {
      // Reload content in case data changed.
      _loadContent();
    });
  }

  void _navigateToBrowse(String contentType, String title) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => BrowseScreen(
          contentType: contentType,
          title: title,
        ),
      ),
    )
        .then((_) => _loadContent());
  }

  void _navigateToImport() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(builder: (_) => const ImportScreen()),
    )
        .then((_) => _loadContent());
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
        title: const Text(
          'Flixium',
          style: TextStyle(
            color: AppColors.accentPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.select) {
                _navigateToImport();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.textPrimary),
              onPressed: _navigateToImport,
              tooltip: 'Import Playlist',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentPrimary,
              ),
            )
          : _isEmpty
              ? _buildEmptyState()
              : _buildContentRows(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_add,
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Content Yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Import an M3U playlist to start\nwatching live TV, movies, and series.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _navigateToImport,
                icon: const Icon(Icons.playlist_add, size: 20),
                label: const Text(
                  'Import Playlist',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentRows() {
    return FocusTraversalGroup(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _rows.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _rows[index],
          );
        },
      ),
    );
  }
}
