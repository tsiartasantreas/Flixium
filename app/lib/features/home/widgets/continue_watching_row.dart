import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'continue_watching_card.dart';

/// A row displaying Continue Watching items with progress indicators.
///
/// Only visible when there are items with saved watch progress. Each card
/// shows a 16:9 thumbnail, a progress bar, and optional subtitle.
class ContinueWatchingRow extends StatelessWidget {
  const ContinueWatchingRow({
    super.key,
    required this.items,
    this.isTv = false,
  });

  final List<ContinueWatchingItem> items;

  /// Whether this is a TV layout (enables D-pad focus).
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -- Section header -------------------------------------------------
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Continue Watching',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // -- Horizontal scrollable row --------------------------------------
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ContinueWatchingCard(
                title: item.title,
                subtitle: item.subtitle,
                imageUrl: item.imageUrl,
                progress: item.progress,
                onTap: item.onTap,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A continue watching item for use in [ContinueWatchingRow].
class ContinueWatchingItem {
  const ContinueWatchingItem({
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.progress,
    required this.onTap,
  });

  final String title;

  /// Optional subtitle (e.g. "S1:E3 - Episode Title" for series).
  final String? subtitle;

  final String? imageUrl;

  /// Playback progress as a value between 0.0 and 1.0.
  final double progress;

  final VoidCallback onTap;
}
