import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a license activation attempt.
enum LicenseResult { ok, invalid, alreadyUsed, tooManyAttempts, offline, error }

/// One-time license activation. The first time the app runs on a device
/// it asks for a license code (e.g. A320-k7Rm9Qx2, case-sensitive); the code is checked online
/// against Supabase and can be used on one device only. Once activated the
/// device is remembered and the app works offline.
///
/// On Android the device id comes from ANDROID_ID, which survives an
/// uninstall, so after a reinstall [restore] unlocks the app again without
/// a new code (online once).
class AccessLock {
  AccessLock._();

  static const _supabaseUrl = 'https://spaxgxlhfuasehumkglb.supabase.co';

  /// Publishable key: safe to ship, the database only exposes the
  /// activation function to it (no table access).
  static const _publishableKey =
      'sb_publishable_j1RmQ4wKmspwz0URRLvdTQ_7_iYrvGi';

  // v1 was the old shared open code (v3.0-v3.2); it no longer unlocks.
  // The value is the device id, so app data copied to another device
  // (e.g. by Android backup) does not unlock it.
  static const _licenseKey = 'fap_license_v2';
  static const _deviceKey = 'fap_device_id';
  static const _demoKey = 'fap_demo';
  static const _timeout = Duration(seconds: 15);

  /// Free demo code shown on the start screen. Works offline, is never sent
  /// to the server and unlocks only the demo functions.
  static const demoCode = 'A320-DEMO';

  static bool isDemoCode(String code) =>
      code.trim().toUpperCase() == demoCode;

  /// Demo mode was chosen on this device (and no license is active).
  static Future<bool> isDemo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_demoKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> startDemo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_demoKey, true);
    } catch (_) {
      // Demo still runs for this session.
    }
  }

  /// Replaced in tests.
  static http.Client Function() clientFactory = http.Client.new;

  /// Reads ANDROID_ID (null when not on Android). Replaced in tests.
  static Future<String?> Function() androidIdReader = _readAndroidId;

  static Future<String?> _readAndroidId() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    return const MethodChannel('fap/device').invokeMethod<String>('androidId');
  }

  static Future<bool> isUnlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_licenseKey);
      return saved != null && saved == await deviceId();
    } catch (_) {
      return false;
    }
  }

  /// The id sent to the server. On Android it is a hash of ANDROID_ID, so
  /// it stays the same after a reinstall; otherwise (web, or if ANDROID_ID
  /// is unavailable) a random id stored with the app.
  static Future<String> deviceId() async {
    try {
      final androidId = await androidIdReader().timeout(
        const Duration(seconds: 3),
      );
      if (androidId != null && androidId.isNotEmpty) {
        return sha256.convert(utf8.encode('a320-fap:$androidId')).toString();
      }
    } catch (_) {
      // Fall back to the stored random id.
    }
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

  /// Activates [code] online; on success remembers this device. The code
  /// this device used before also works again after a reinstall.
  static Future<LicenseResult> activate(String code) async =>
      isDemoCode(code)
      ? LicenseResult.invalid // the demo code is never a license
      : _call('a320_redeem_license', (device) => {
        'p_code': code.trim(),
        'p_device': device,
      });

  /// After a reinstall: unlocks the app if this device was activated
  /// before. [LicenseResult.invalid] means it was not.
  static Future<LicenseResult> restore() async =>
      _call('a320_restore_license', (device) => {'p_device': device});

  static Future<LicenseResult> _call(
    String fn,
    Map<String, String> Function(String device) args,
  ) async {
    final client = clientFactory();
    try {
      final device = await deviceId();
      final res = await client
          .post(
            Uri.parse('$_supabaseUrl/rest/v1/rpc/$fn'),
            headers: {
              'apikey': _publishableKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(args(device)),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return LicenseResult.error;
      final body = jsonDecode(res.body);
      if (body is! Map) return LicenseResult.error;
      if (body['ok'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_licenseKey, device);
        await prefs.remove(_demoKey);
        return LicenseResult.ok;
      }
      return switch (body['reason']) {
        null || 'INVALID' => LicenseResult.invalid,
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
