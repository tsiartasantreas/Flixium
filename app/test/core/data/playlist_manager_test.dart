import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/data/database.dart';
import 'package:iflixify/core/data/playlist_manager.dart';
import 'package:iflixify/core/entitlement/entitlement_service.dart';
import 'package:mocktail/mocktail.dart';

class MockEntitlementService extends Mock implements EntitlementService {}

void main() {
  late AppDatabase db;
  late MockEntitlementService mockEntitlement;
  late PlaylistManager manager;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockEntitlement = MockEntitlementService();
    manager = PlaylistManager(
      database: db,
      entitlementService: mockEntitlement,
    );

    // Default: free tier.
    when(() => mockEntitlement.getTier()).thenAnswer((_) async => 'free');
  });

  tearDown(() async {
    await db.close();
  });

  group('PlaylistManager', () {
    test('getPlaylists returns empty list initially', () async {
      final playlists = await manager.getPlaylists();
      expect(playlists, isEmpty);
    });

    test('getPlaylistCount returns 0 initially', () async {
      final count = await manager.getPlaylistCount();
      expect(count, 0);
    });

    test('addPlaylist creates a playlist for free user (under limit)',
        () async {
      final playlist = await manager.addPlaylist(
        'My Playlist',
        'http://example.com/playlist.m3u',
      );

      expect(playlist.id, isPositive);
      expect(playlist.name, 'My Playlist');
      expect(playlist.url, 'http://example.com/playlist.m3u');
      expect(playlist.type, 'remote');
      expect(playlist.lastSyncedAt, isNotNull);
    });

    test('addPlaylist throws for free user exceeding limit', () async {
      // Add one playlist (the limit for free users).
      await manager.addPlaylist('First', 'http://example.com/1.m3u');

      // Attempt to add a second -- should throw.
      expect(
        () => manager.addPlaylist('Second', 'http://example.com/2.m3u'),
        throwsA(isA<StateError>()),
      );
    });

    test('addPlaylist allows multiple playlists for pro user', () async {
      when(() => mockEntitlement.getTier()).thenAnswer((_) async => 'pro');

      await manager.addPlaylist('First', 'http://example.com/1.m3u');
      await manager.addPlaylist('Second', 'http://example.com/2.m3u');

      final count = await manager.getPlaylistCount();
      expect(count, 2);
    });

    test('deletePlaylist removes a playlist', () async {
      final playlist = await manager.addPlaylist(
        'To Delete',
        'http://example.com/delete.m3u',
      );

      await manager.deletePlaylist(playlist.id);

      final playlists = await manager.getPlaylists();
      expect(playlists, isEmpty);
    });

    test('deletePlaylist throws for non-existent playlist', () async {
      expect(
        () => manager.deletePlaylist(999),
        throwsA(isA<StateError>()),
      );
    });

    test('deletePlaylist removes associated channels', () async {
      final playlist = await manager.addPlaylist(
        'With Channels',
        'http://example.com/channels.m3u',
      );

      // Insert a channel associated with the playlist.
      await db.into(db.channels).insert(
            ChannelsCompanion.insert(
              playlistId: playlist.id,
              name: 'Test Channel',
              url: 'http://stream.example.com/test',
            ),
          );

      // Verify channel exists.
      final channelsBefore = await (db.select(db.channels)
            ..where((t) => t.playlistId.equals(playlist.id)))
          .get();
      expect(channelsBefore.length, 1);

      // Delete playlist.
      await manager.deletePlaylist(playlist.id);

      // Verify channel is also deleted.
      final channelsAfter = await (db.select(db.channels)
            ..where((t) => t.playlistId.equals(playlist.id)))
          .get();
      expect(channelsAfter, isEmpty);
    });

    test('renamePlaylist changes the playlist name', () async {
      final playlist = await manager.addPlaylist(
        'Old Name',
        'http://example.com/rename.m3u',
      );

      await manager.renamePlaylist(playlist.id, 'New Name');

      final playlists = await manager.getPlaylists();
      final renamed = playlists.firstWhere((p) => p.id == playlist.id);
      expect(renamed.name, 'New Name');
    });

    test('renamePlaylist throws for non-existent playlist', () async {
      expect(
        () => manager.renamePlaylist(999, 'New Name'),
        throwsA(isA<StateError>()),
      );
    });

    test('freePlaylistLimit constant is 1', () {
      expect(PlaylistManager.freePlaylistLimit, 1);
    });

  });
}
