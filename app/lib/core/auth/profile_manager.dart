import 'package:drift/drift.dart' as drift;
import 'package:iflixify/core/data/database.dart';

/// Manages local user profiles for multi-user support.
///
/// Each profile has a display name, optional Supabase user linkage,
/// an avatar color, and an active flag.
class ProfileManager {
  final AppDatabase _db;

  ProfileManager({AppDatabase? database}) : _db = database ?? AppDatabase();

  /// Get all profiles, ordered by creation date.
  Future<List<UserProfile>> getProfiles() async {
    final query = _db.select(_db.userProfiles)
      ..orderBy([(t) => drift.OrderingTerm.asc(t.createdAt)]);
    return query.get();
  }

  /// Get the currently active profile.
  Future<UserProfile?> getActiveProfile() async {
    final query = _db.select(_db.userProfiles)
      ..where((t) => t.isActive.equals(true));
    return query.getSingleOrNull();
  }

  /// Create a new profile. If it's the first profile, it becomes active.
  Future<UserProfile> createProfile(String displayName, {int? avatarColor}) async {
    final count = await getProfileCount();
    final isFirst = count == 0;

    final id = await _db.into(_db.userProfiles).insert(
      UserProfilesCompanion.insert(
        displayName: displayName,
        avatarColor: avatarColor ?? _defaultAvatarColor(count),
        createdAt: DateTime.now(),
        isActive: drift.Value(isFirst),
      ),
    );

    return (_db.select(_db.userProfiles)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Switch the active profile.
  Future<void> switchProfile(int profileId) async {
    // Deactivate all profiles
    await (_db.update(_db.userProfiles)
      ..where((t) => t.isActive.equals(true)))
        .write(const UserProfilesCompanion(isActive: drift.Value(false)));

    // Activate the selected profile
    await (_db.update(_db.userProfiles)
      ..where((t) => t.id.equals(profileId)))
        .write(const UserProfilesCompanion(isActive: drift.Value(true)));
  }

  /// Delete a profile (cannot delete the active one).
  Future<void> deleteProfile(int profileId) async {
    final active = await getActiveProfile();
    if (active?.id == profileId) {
      throw StateError('Cannot delete the active profile. Switch first.');
    }
    await (_db.delete(_db.userProfiles)..where((t) => t.id.equals(profileId)))
        .go();
  }

  /// Update a profile's display name.
  Future<void> updateProfile(int profileId, {String? displayName}) async {
    await (_db.update(_db.userProfiles)..where((t) => t.id.equals(profileId)))
        .write(UserProfilesCompanion(displayName: drift.Value(displayName ?? '')));
  }

  /// Get total profile count.
  Future<int> getProfileCount() async {
    final query = _db.select(_db.userProfiles);
    final results = await query.get();
    return results.length;
  }

  /// Ensure at least one profile exists (auto-create "Profile 1").
  Future<void> ensureDefaultProfile() async {
    final count = await getProfileCount();
    if (count == 0) {
      await createProfile('Profile 1', avatarColor: 0xFFE50914);
    }
  }

  /// Default avatar colors (cycle through a palette).
  static const List<int> _avatarPalette = [
    0xFFE50914, // Red
    0xFF1DB954, // Green
    0xFF5865F2, // Blue
    0xFFFFA500, // Orange
    0xFF9B59B6, // Purple
    0xFF1ABC9C, // Teal
  ];

  int _defaultAvatarColor(int index) {
    return _avatarPalette[index % _avatarPalette.length];
  }
}
