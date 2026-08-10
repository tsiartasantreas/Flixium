import 'package:drift/drift.dart';

/// Represents a local user profile for multi-user support.
///
/// Each profile has a display name, optional Supabase user ID linkage,
/// an avatar color for visual identification, and an active flag to track
/// which profile is currently selected.
@DataClassName('UserProfile')
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// User-visible display name (e.g. "Dad", "Kids").
  TextColumn get displayName => text()();

  /// Optional Supabase user ID for authenticated profiles.
  /// Null for anonymous / local-only profiles.
  TextColumn get supabaseUserId => text().nullable()();

  /// Avatar background color stored as a 32-bit ARGB integer.
  IntColumn get avatarColor => integer()();

  /// Whether this is the currently active profile.
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();

  /// When the profile was created.
  DateTimeColumn get createdAt => dateTime()();
}
