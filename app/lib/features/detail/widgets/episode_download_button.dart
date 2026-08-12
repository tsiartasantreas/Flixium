import 'package:flutter/material.dart';

import '../../../core/data/database.dart';
import '../../../core/data/offline_download_service.dart';
import '../../../core/theme/app_colors.dart';

/// A compact download button for episode list tiles.
///
/// Shows a cloud_download icon when idle, a small circular progress indicator
/// while downloading, and a checkmark when downloaded.
class EpisodeDownloadButton extends StatefulWidget {
  const EpisodeDownloadButton({
    super.key,
    required this.contentId,
    required this.title,
    required this.url,
    this.thumbnailUrl,
    this.onPlayOffline,
  });

  final String contentId;
  final String title;
  final String url;
  final String? thumbnailUrl;
  final VoidCallback? onPlayOffline;

  @override
  State<EpisodeDownloadButton> createState() => _EpisodeDownloadButtonState();
}

class _EpisodeDownloadButtonState extends State<EpisodeDownloadButton> {
  late final OfflineDownloadService _downloadService;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _downloadService = OfflineDownloadService(db: AppDatabase());
    _checkDownloaded();
  }

  Future<void> _checkDownloaded() async {
    final result = await _downloadService.isDownloaded(widget.contentId);
    if (mounted) {
      setState(() => _isDownloaded = result);
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    try {
      await _downloadService.downloadContent(
        contentId: widget.contentId,
        url: widget.url,
        title: widget.title,
        contentType: 'series',
        thumbnailUrl: widget.thumbnailUrl,
        onProgress: (p) {
          if (mounted) {
            setState(() => _progress = p);
          }
        },
      );
      if (mounted) {
        setState(() {
          _isDownloaded = true;
          _isDownloading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _cancelDownload() {
    _downloadService.cancelDownload(widget.contentId);
    setState(() {
      _isDownloading = false;
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isDownloading) {
      return GestureDetector(
        onTap: _cancelDownload,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  strokeWidth: 2.5,
                  color: AppColors.accentPrimary,
                  backgroundColor: AppColors.bgSurface,
                ),
              ),
              const Icon(
                Icons.close,
                color: AppColors.textPrimary,
                size: 14,
              ),
            ],
          ),
        ),
      );
    }

    if (_isDownloaded) {
      return GestureDetector(
        onTap: widget.onPlayOffline,
        child: const Icon(
          Icons.check_circle,
          color: AppColors.accentPrimary,
          size: 28,
        ),
      );
    }

    return GestureDetector(
      onTap: _startDownload,
      child: const Icon(
        Icons.cloud_download_outlined,
        color: AppColors.textSecondary,
        size: 28,
      ),
    );
  }

  @override
  void dispose() {
    _downloadService.close();
    super.dispose();
  }
}
