import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time unlock of the app. The open code is asked the first time the
/// app runs on a device; after that the device stays unlocked.
///
/// Only the SHA-256 of the code is stored in the source (the repository is
/// public), never the code itself.
class AccessLock {
  AccessLock._();

  static const _codeSha256 =
      '21707b0f4415ba02c139cb9d23a12b695687b1fd7af0f1001f5381f763f211b7';
  static const _prefsKey = 'fap_unlocked_v1';

  static bool matches(String code) =>
      sha256.convert(utf8.encode(code.trim())).toString() == _codeSha256;

  static Future<bool> isUnlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefsKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks [code]; on success remembers this device as unlocked.
  static Future<bool> unlock(String code) async {
    if (!matches(code)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, true);
    } catch (_) {
      // Unlocked for this session even if it cannot be remembered.
    }
    return true;
  }
}
