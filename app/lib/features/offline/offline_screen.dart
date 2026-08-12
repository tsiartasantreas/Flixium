import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/data/database.dart';
import '../../core/data/offline_download_service.dart';
import '../../core/player/player_controller.dart';
import '../../core/theme/app_colors.dart';
import '../player/player_screen.dart';
import '../player/tv_player_screen.dart';

/// Netflix-style "Downloads" screen showing locally stored content.
///
/// Displays a grid of downloaded items with thumbnails, titles, and file sizes.
/// Shows active and queued downloads with progress indicators.
/// Supports tap-to-play and long-press-to-delete.
class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  final _downloadService = OfflineDownloadService.instance;
  List<DownloadedItem> _items = [];
  Map<String, DownloadProgress> _activeDownloads = {};
  bool _isLoading = true;
  StreamSubscription<Map<String, DownloadProgress>>? _progressSub;

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
    _loadItems();
    _listenToProgress();
  }

  void _listenToProgress() {
    // Load initial state.
    _activeDownloads = _downloadService.currentProgress;

    _progressSub = _downloadService.progressStream.listen((progressMap) {
      if (!mounted) return;

      // Check if any download just completed -- refresh the DB list.
      final hasNewCompleted = progressMap.values.any((p) =>
          p.state == DownloadState.completed &&
          (_activeDownloads[p.contentId]?.state != DownloadState.completed));

      setState(() {
        _activeDownloads = progressMap;
      });

      if (hasNewCompleted) {
        _loadItems();
      }
    });
  }

  Future<void> _loadItems() async {
    final items = await _downloadService.getDownloadedItems();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  void _playItem(DownloadedItem item) {
    final controller = PlayerController();
    controller.open(item.filePath);

    final playerScreen = _isTv
        ? TvPlayerScreen(
            controller: controller,
            title: item.title,
          )
        : PlayerScreen(
            controller: controller,
            title: item.title,
          );

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => playerScreen))
        .then((_) => controller.dispose());
  }

  Future<void> _deleteItem(DownloadedItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Delete Download',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove "${item.title}" from your downloads?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _downloadService.deleteDownload(item.contentId);
      await _loadItems();
    }
  }

  void _cancelActiveDownload(String contentId) {
    _downloadService.cancelDownload(contentId);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Returns active downloads (queued or currently downloading), excluding
  /// completed/failed/cancelled.
  List<DownloadProgress> get _inProgressDownloads {
    return _activeDownloads.values
        .where((p) =>
            p.state == DownloadState.queued ||
            p.state == DownloadState.downloading)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Downloads',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentPrimary,
              ),
            )
          : _items.isEmpty && _inProgressDownloads.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
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
              Icons.download_done_outlined,
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Downloads Yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Download movies and series to watch offline',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.explore),
                label: const Text('Browse Content'),
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

  Widget _buildContent() {
    final totalSize = _items.fold<int>(0, (sum, item) => sum + item.fileSize);
    final active = _inProgressDownloads;

    return CustomScrollView(
      slivers: [
        // -- Storage usage banner ------------------------------------------
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.bgElevated,
            child: Row(
              children: [
                const Icon(
                  Icons.storage,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_items.length} downloads  \u00B7  ${_formatFileSize(totalSize)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),

        // -- Active downloads section -------------------------------------
        if (active.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
              child: Text(
                'Downloading (${active.length})',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildActiveDownloadTile(active[index]),
              childCount: active.length,
            ),
          ),
        ],

        // -- Completed downloads grid -------------------------------------
        if (_items.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _isTv ? 5 : 3,
                childAspectRatio: 0.55,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildDownloadCard(_items[index]),
                childCount: _items.length,
              ),
            ),
          )
        else if (active.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Completed downloads will appear here',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveDownloadTile(DownloadProgress progress) {
    final isQueued = progress.state == DownloadState.queued;

    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: isQueued ? null : (progress.progress > 0 ? progress.progress : null),
              strokeWidth: 3,
              color: AppColors.accentPrimary,
              backgroundColor: AppColors.bgSurface,
            ),
            if (!isQueued)
              Text(
                '${(progress.progress * 100).toInt()}%',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Icon(
                Icons.hourglass_bottom,
                color: AppColors.textSecondary,
                size: 16,
              ),
          ],
        ),
      ),
      title: Text(
        progress.title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isQueued ? 'Queued...' : 'Downloading...',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
        onPressed: () => _cancelActiveDownload(progress.contentId),
      ),
    );
  }

  Widget _buildDownloadCard(DownloadedItem item) {
    return GestureDetector(
      onTap: () => _playItem(item),
      onLongPress: () => _deleteItem(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Thumbnail ----------------------------------------------------
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster image (if available).
                  if (item.thumbnailUrl != null &&
                      item.thumbnailUrl!.isNotEmpty)
                    Image.network(
                      item.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholderIcon(item.contentType),
                    )
                  else
                    _buildPlaceholderIcon(item.contentType),

                  // Play overlay icon.
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                    ),
                  ),

                  // Content type badge.
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.contentType.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // -- Title --------------------------------------------------------
          Text(
            item.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // -- File size ----------------------------------------------------
          Text(
            _formatFileSize(item.fileSize),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon(String contentType) {
    IconData icon;
    switch (contentType) {
      case 'movie':
        icon = Icons.movie;
        break;
      case 'series':
        icon = Icons.tv;
        break;
      case 'radio':
        icon = Icons.radio;
        break;
      default:
        icon = Icons.play_circle_outline;
    }

    return Center(
      child: Icon(
        icon,
        color: AppColors.bgElevated,
        size: 48,
      ),
    );
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    // Do NOT close the download service -- it's a singleton.
    super.dispose();
  }
}
