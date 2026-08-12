import 'package:drift/drift.dart' as drift;

import 'database.dart';

/// Service for managing user favourites (bookmarks) in the local database.
///
/// Provides CRUD operations for the [Favorites] table with convenience
/// methods for toggling and checking favourite status.
///
/// Usage:
/// ```dart
/// final service = FavoritesService();
/// await service.addToFavorites(
///   contentId: 'vod:42',
///   contentType: 'vod',
///   title: 'Inception',
///   poster: 'https://...',
///   url: 'http://...',
/// );
/// final isFav = await service.isFavorite('vod:42');
/// ```
class FavoritesService {
  FavoritesService({AppDatabase? database}) : _db = database ?? AppDatabase();

  final AppDatabase _db;

  /// Adds an item to favourites.
  ///
  /// If the item is already favourited (same [contentId]), the existing
  /// record is updated with the latest title/poster/url.
  Future<void> addToFavorites({
    required String contentId,
    required String contentType,
    String? title,
    String? poster,
    String? url,
  }) async {
    await _db.into(_db.favorites).insertOnConflictUpdate(
          FavoritesCompanion.insert(
            contentId: contentId,
            contentType: contentType,
            title: drift.Value(title),
            poster: drift.Value(poster),
            url: drift.Value(url),
            addedAt: DateTime.now(),
          ),
        );
  }

  /// Removes an item from favourites by its [contentId].
  Future<void> removeFromFavorites(String contentId) async {
    await (_db.delete(_db.favorites)
          ..where((t) => t.contentId.equals(contentId)))
        .go();
  }

  /// Returns `true` if the item with [contentId] is in favourites.
  Future<bool> isFavorite(String contentId) async {
    final count = await (_db.selectOnly(_db.favorites)
          ..addColumns([_db.favorites.contentId.count()])
          ..where(_db.favorites.contentId.equals(contentId)))
        .getSingle();
    return (count.read(_db.favorites.contentId.count()) ?? 0) > 0;
  }

  /// Toggles favourite status: removes if present, adds if not.
  ///
  /// Returns `true` if the item is now favourited, `false` if removed.
  Future<bool> toggleFavorite({
    required String contentId,
    required String contentType,
    String? title,
    String? poster,
    String? url,
  }) async {
    if (await isFavorite(contentId)) {
      await removeFromFavorites(contentId);
      return false;
    } else {
      await addToFavorites(
        contentId: contentId,
        contentType: contentType,
        title: title,
        poster: poster,
        url: url,
      );
      return true;
    }
  }

  /// Returns all favourites ordered by most recently added.
  Future<List<Favorite>> getFavorites() async {
    return (_db.select(_db.favorites)
          ..orderBy([(t) => drift.OrderingTerm.desc(t.addedAt)]))
        .get();
  }

  /// Returns favourites filtered by [contentType], ordered by most recently
  /// added.
  Future<List<Favorite>> getFavoritesByType(String contentType) async {
    return (_db.select(_db.favorites)
          ..where((t) => t.contentType.equals(contentType))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.addedAt)]))
        .get();
  }
}
