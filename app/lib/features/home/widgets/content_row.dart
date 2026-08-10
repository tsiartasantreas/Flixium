import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'content_card.dart';

/// A single row showing a label and horizontally scrollable content items.
///
/// Used on the home screen to display sections like "Live TV", "Movies", etc.
class ContentRow extends StatelessWidget {
  const ContentRow({
    super.key,
    required this.label,
    required this.items,
    this.isTv = false,
    this.onSeeAll,
  });

  /// Section header label (e.g. "Live TV").
  final String label;

  /// List of content items to display horizontally.
  final List<ContentItem> items;

  /// Whether this is a TV layout (enables D-pad focus).
  final bool isTv;

  /// Callback when the "See All" header is tapped.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -- Section header -------------------------------------------------
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      color: AppColors.accentPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // -- Horizontal scrollable row --------------------------------------
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ContentCard(
                title: item.title,
                imageUrl: item.imageUrl,
                isTv: isTv,
                onTap: item.onTap,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A content item for use in [ContentRow].
class ContentItem {
  const ContentItem({
    required this.title,
    this.imageUrl,
    required this.onTap,
  });

  final String title;
  final String? imageUrl;
  final VoidCallback onTap;
}
