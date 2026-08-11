import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// Encrypts and decrypts playlist credentials (URL, username, password)
/// before storing them in the local Drift database.
///
/// Uses AES-256-CBC with a key derived from a fixed app secret combined
/// with the user's Supabase ID. Anonymous playlists use a device-specific
/// fallback key.
class EncryptionService {
  EncryptionService._();

  /// Fixed application secret (not a real secret — this is client-side
  /// obfuscation, not server-grade security).
  static const _appSecret = 'flixium_v1_playlist_encryption_key_2026';

  /// Fallback user ID for anonymous (guest) playlists.
  static const _anonymousUserId = 'anonymous_device_user';

  /// Returns an [Encrypter] for the given [userId].
  ///
  /// The AES key is derived by SHA-256 hashing the concatenation of the
  /// app secret and the user ID, yielding a 32-byte (256-bit) key.
  static Encrypter _encrypterFor(String userId) {
    final combined = '$_appSecret:$userId';
    final keyBytes = sha256.convert(utf8.encode(combined)).bytes;
    return Encrypter(AES(Key(Uint8List.fromList(keyBytes)), mode: AESMode.cbc));
  }

  /// Encrypts [plaintext] for the given [userId].
  ///
  /// Returns a base64 string containing the IV (16 bytes) prepended to
  /// the ciphertext. Pass `null` as [userId] for anonymous playlists.
  static String encrypt(String plaintext, {String? userId}) {
    final effectiveUserId = userId ?? _anonymousUserId;
    final encrypter = _encrypterFor(effectiveUserId);
    final iv = IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    // Prepend IV bytes to ciphertext so we can extract it during decryption.
    final combined = Uint8List.fromList(iv.bytes + encrypted.bytes);
    return base64.encode(combined);
  }

  /// Decrypts a [ciphertext] (base64-encoded IV + ciphertext) for the
  /// given [userId].
  ///
  /// Returns the original plaintext string. Pass `null` as [userId] for
  /// anonymous playlists.
  static String decrypt(String ciphertext, {String? userId}) {
    final effectiveUserId = userId ?? _anonymousUserId;
    final encrypter = _encrypterFor(effectiveUserId);
    final combined = base64.decode(ciphertext);
    final iv = IV(Uint8List.fromList(combined.sublist(0, 16)));
    final encrypted = Encrypted(Uint8List.fromList(combined.sublist(16)));
    return encrypter.decrypt(encrypted, iv: iv);
  }

  /// Returns `true` if [value] appears to be an encrypted blob (base64
  /// encoded, reasonable length).
  static bool isEncrypted(String value) {
    // Encrypted values are base64 and at least 32 bytes (16 IV + 16 min block).
    if (value.length < 44) return false;
    try {
      base64.decode(value);
      return true;
    } catch (_) {
      return false;
    }
  }
}
