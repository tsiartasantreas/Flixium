import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'netflix_card.dart';

/// A Netflix-style horizontal scrollable row with section header.
///
/// Displays a bold section title, optional "See All" chevron, and a
/// horizontally scrollable list of [NetflixCard] items with peek (the next
/// card is partially visible).
///
/// On TV, supports D-pad navigation between cards within the row.
class NetflixRow extends StatefulWidget {
  const NetflixRow({
    super.key,
    required this.label,
    required this.items,
    this.isTv = false,
    this.onSeeAll,
  });

  /// Section header label (e.g. "Live TV", "Movies").
  final String label;

  /// List of content items to display horizontally.
  final List<NetflixRowItem> items;

  /// Whether this row uses TV layout (D-pad navigation, larger cards).
  final bool isTv;

  /// Callback when the "See All" header is tapped.
  final VoidCallback? onSeeAll;

  @override
  State<NetflixRow> createState() => _NetflixRowState();
}

class _NetflixRowState extends State<NetflixRow> {
  final ScrollController _scrollController = ScrollController();
  bool _showSeeAll = false;

  bool get _isTv =>
      widget.isTv ||
      Platform.isLinux ||
      (Platform.isAndroid &&
          MediaQueryData.fromView(
                      WidgetsBinding.instance.platformDispatcher.views.first)
                  .size
                  .shortestSide >
              960);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onCardFocusChanged(bool focused) {
    if (focused && !_showSeeAll) {
      setState(() => _showSeeAll = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerSize =
        _isTv ? AppTheme.rowHeaderSizeTv : AppTheme.rowHeaderSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -- Section header -------------------------------------------------
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppTheme.horizontalPadding),
          child: Row(
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: headerSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (widget.onSeeAll != null)
                AnimatedOpacity(
                  opacity: _showSeeAll || !_isTv ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: widget.onSeeAll,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: _isTv ? 16.0 : 14.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                          size: _isTv ? 24.0 : 20.0,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.cardSpacing),

        // -- Horizontal scrollable row --------------------------------------
        SizedBox(
          height: _isTv ? AppTheme.tvCardHeight + 40 : AppTheme.cardHeight + 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.horizontalPadding),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return NetflixCard(
                title: item.title,
                imageUrl: item.imageUrl,
                isTv: _isTv,
                contentType: item.contentType,
                onTap: item.onTap,
                onFocusChanged: _onCardFocusChanged,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A content item for use in [NetflixRow].
class NetflixRowItem {
  const NetflixRowItem({
    required this.title,
    this.imageUrl,
    this.contentType = 'vod',
    required this.onTap,
  });

  /// Title text for the card.
  final String title;

  /// URL of the poster or thumbnail image.
  final String? imageUrl;

  /// Content type: 'vod', 'live', or 'radio'. Controls aspect ratio.
  final String contentType;

  /// Callback when the card is tapped or selected.
  final VoidCallback onTap;
}
