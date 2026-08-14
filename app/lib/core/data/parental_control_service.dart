import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages parental control settings: PIN storage, verification, and
/// adult-content detection.
///
/// Uses a singleton pattern so the PIN state is shared across the app.
/// The PIN is stored as a SHA-256 hash in SharedPreferences under the
/// key `parental_pin_hash`.
class ParentalControlService {
  ParentalControlService._();

  static final ParentalControlService _instance = ParentalControlService._();

  /// Returns the shared singleton instance.
  static ParentalControlService get instance => _instance;

  /// SharedPreferences key for the hashed PIN.
  static const _pinHashKey = 'parental_pin_hash';

  /// SharedPreferences key for the hide-adult-content preference.
  static const _hideAdultContentKey = 'hide_adult_content';

  /// Set of rating strings considered adult-only.
  static const _adultRatings = {
    '18+',
    'r18',
    'nc-17',
    'x',
    'xxx',
    'adult',
  };

  // ---------------------------------------------------------------------------
  // PIN management
  // ---------------------------------------------------------------------------

  /// Hashes [pin] with SHA-256 and stores it in SharedPreferences.
  Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinHashKey, hash);
  }

  /// Returns `true` if [pin] matches the stored hash.
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_pinHashKey);
    if (storedHash == null) return false;
    return _hashPin(pin) == storedHash;
  }

  /// Returns `true` if a parental PIN has been configured.
  Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinHashKey);
  }

  /// Removes the stored PIN, effectively unlocking all content.
  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
  }

  /// Returns `true` if adult content should be hidden (i.e. a PIN is set
  /// and the user has not temporarily unlocked the session).
  Future<bool> isAdultContentLocked() async {
    if (_temporarilyUnlocked) return false;
    return isPinSet();
  }

  /// Whether the user has temporarily unlocked adult content for this
  /// app session. The flag resets when the app is killed.
  bool _temporarilyUnlocked = false;

  /// Returns `true` if the user has entered their PIN to temporarily
  /// show adult content during this app session.
  bool get isUnlocked => _temporarilyUnlocked;

  /// Unlocks adult content for the rest of the current app session.
  ///
  /// Call this after verifying the user's PIN. The unlock is lost when the
  /// process terminates (i.e. the app is fully closed, not just backgrounded).
  void unlockTemporarily() {
    _temporarilyUnlocked = true;
  }

  /// Re-locks adult content (e.g. user taps the lock button again).
  void lockAgain() {
    _temporarilyUnlocked = false;
  }

  // ---------------------------------------------------------------------------
  // Adult content visibility preference
  // ---------------------------------------------------------------------------

  /// Returns `true` if adult content should be visible.
  ///
  /// - If no PIN is set, adult content is always visible (returns `true`).
  /// - If a PIN is set, returns the stored preference (default: `false` / hidden).
  Future<bool> isAdultContentVisible() async {
    final pinSet = await isPinSet();
    if (!pinSet) return true; // No PIN => always visible.
    final prefs = await SharedPreferences.getInstance();
    // Default: hide adult content when PIN is set.
    final hidden = prefs.getBool(_hideAdultContentKey) ?? true;
    return !hidden;
  }

  /// Sets whether adult content should be visible.
  ///
  /// When [visible] is `true` and a PIN is set, the caller must verify the PIN
  /// *before* calling this method. Returns `true` if the preference was saved.
  /// Returns `false` if PIN verification is required but was not provided
  /// (i.e. the caller should prompt for the PIN first).
  Future<bool> setAdultContentVisible(bool visible) async {
    final pinSet = await isPinSet();

    // If hiding adult content, no PIN verification needed.
    if (!visible) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hideAdultContentKey, true);
      return true;
    }

    // If showing adult content and PIN is set, the caller must have already
    // verified the PIN. We check the session unlock flag as a guard.
    if (pinSet && !_temporarilyUnlocked) {
      // Caller should have verified PIN before calling this. Return false
      // to signal that PIN verification is still required.
      return false;
    }

    // No PIN set, or PIN already verified => save the preference.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideAdultContentKey, false);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Adult content detection
  // ---------------------------------------------------------------------------

  /// Determines whether the given content should be considered adult.
  ///
  /// Checks three criteria (any match returns `true`):
  /// 1. [isAdult] field is `"1"` or `"true"` (from the database).
  /// 2. [title] contains `"XXX"` (case-insensitive).
  /// 3. [rating] matches a known adult rating (case-insensitive).
  static bool isAdultContent({
    required String title,
    String? rating,
    String? isAdult,
  }) {
    // Check the database flag.
    if (isAdult != null) {
      final normalized = isAdult.trim().toLowerCase();
      if (normalized == '1' || normalized == 'true') return true;
    }

    // Check title for "XXX".
    if (title.toUpperCase().contains('XXX')) return true;

    // Check rating against known adult ratings.
    if (rating != null && rating.isNotEmpty) {
      final normalizedRating = rating.trim().toLowerCase();
      if (_adultRatings.contains(normalizedRating)) return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the SHA-256 hex digest of [pin].
  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }
}
