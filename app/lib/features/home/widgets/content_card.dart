import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// Individual content card showing thumbnail/poster and title.
///
/// Used in horizontal scrollable rows on the home screen.
class ContentCard extends StatelessWidget {
  const ContentCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.isTv = false,
    this.onTap,
  });

  final String title;
  final String? imageUrl;
  final bool isTv;
  final VoidCallback? onTap;

  bool get _isTv =>
      isTv ||
      Platform.isLinux ||
      (Platform.isAndroid &&
          MediaQueryData.fromView(
                      WidgetsBinding.instance.platformDispatcher.views.first)
                  .size
                  .shortestSide >
              960);

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Thumbnail / poster -----------------------------------------
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(height: 6),

            // -- Title ------------------------------------------------------
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    if (_isTv) {
      return Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.select) {
            onTap?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            return GestureDetector(
              onTap: onTap,
              child: FocusableActionDetector(
                onShowFocusHighlight: (focused) {
                  // Could add visual focus indicator here.
                },
                child: card,
              ),
            );
          },
        ),
      );
    }

    return card;
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
