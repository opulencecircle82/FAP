import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a license activation attempt.
enum LicenseResult { ok, invalid, alreadyUsed, tooManyAttempts, offline, error }

/// One-time license activation. The first time the app runs on a device
/// it asks for a license code (e.g. A320-K92A); the code is checked online
/// against Supabase and can be used on one device only. Once activated the
/// device is remembered and the app works offline.
class AccessLock {
  AccessLock._();

  static const _supabaseUrl = 'https://spaxgxlhfuasehumkglb.supabase.co';

  /// Publishable key: safe to ship, the database only exposes the
  /// activation function to it (no table access).
  static const _publishableKey =
      'sb_publishable_j1RmQ4wKmspwz0URRLvdTQ_7_iYrvGi';

  static const _unlockedKey = 'fap_unlocked_v1';
  static const _deviceKey = 'fap_device_id';
  static const _timeout = Duration(seconds: 15);

  /// Replaced in tests.
  static http.Client Function() clientFactory = http.Client.new;

  static Future<bool> isUnlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_unlockedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// A random id for this installation (stored on the device).
  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceKey);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(
        16,
        (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await prefs.setString(_deviceKey, id);
    }
    return id;
  }

  /// Activates [code] online; on success remembers this device.
  static Future<LicenseResult> activate(String code) async {
    final client = clientFactory();
    try {
      final device = await deviceId();
      final res = await client
          .post(
            Uri.parse('$_supabaseUrl/rest/v1/rpc/a320_redeem_license'),
            headers: {
              'apikey': _publishableKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'p_code': code.trim(), 'p_device': device}),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return LicenseResult.error;
      final body = jsonDecode(res.body);
      if (body is! Map) return LicenseResult.error;
      if (body['ok'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_unlockedKey, true);
        return LicenseResult.ok;
      }
      return switch (body['reason']) {
        'INVALID' => LicenseResult.invalid,
        'ALREADY_USED' => LicenseResult.alreadyUsed,
        'TOO_MANY_ATTEMPTS' => LicenseResult.tooManyAttempts,
        _ => LicenseResult.error,
      };
    } on TimeoutException {
      return LicenseResult.offline;
    } on http.ClientException {
      return LicenseResult.offline;
    } catch (_) {
      return LicenseResult.error;
    } finally {
      client.close();
    }
  }
}
