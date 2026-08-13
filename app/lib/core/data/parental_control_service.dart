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

  /// Returns `true` if adult content should be hidden (i.e. a PIN is set).
  Future<bool> isAdultContentLocked() => isPinSet();

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
