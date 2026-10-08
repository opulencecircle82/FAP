import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:aisat_fap/main.dart';
import 'package:aisat_fap/models/fap_state.dart';
import 'package:aisat_fap/providers/fap_provider.dart';
import 'package:aisat_fap/services/access_lock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aisat_fap/widgets/top_status_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_audio.dart';

/// Renders every FAP page and key alarm scenario with real fonts so layout
/// overflows fail the test, and writes reference screenshots to
/// test/goldens/ (run with --update-goldens to refresh them).
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final bytes = File(p).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? 'D:/dev/flutter';
  final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
  await load('Roboto', [
    '$fonts/roboto-regular.ttf',
    '$fonts/roboto-medium.ttf',
    '$fonts/roboto-bold.ttf',
    '$fonts/roboto-black.ttf',
  ]);
  await load('MaterialIcons', ['$fonts/materialicons-regular.otf']);
  await load('JetBrainsMono', [
    'assets/fonts/JetBrainsMono-Regular.ttf',
    'assets/fonts/JetBrainsMono-Bold.ttf',
  ]);
}

void main() {
  setUpAll(() async {
    fapClockNow = () => DateTime.utc(2026, 10, 4, 6, 30, 0);
    await _loadFonts();
  });

  late FapProvider fap;

  Future<void> boot(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    fap = FapProvider(audio: FakeAudio(), random: Random(7));
    await tester.pumpWidget(AisatFapApp(fap: fap, showDisclaimer: false));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    fap.dispose();
    tester.view.reset();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    // Two frames: the first starts the page transition, the second ends it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(AisatFapApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('every FAP page renders without overflow', (tester) async {
    await boot(tester, const Size(1600, 1000));
    for (final p in FapPage.values) {
      fap.goTo(p);
      await shot(tester, 'page_${p.name}');
    }
    // Protected pages open after the access code.
    fap.enterAccessCode(FapPage.cabinProg, '318');
    fap.enterAccessCode(FapPage.layout, '318');
    fap.enterAccessCode(FapPage.level, '318');
    fap.enterAccessCode(FapPage.swLoad, '813');
    for (final p in FapPage.values.where((p) => p.protected)) {
      fap.goTo(p);
      await shot(tester, 'page_${p.name}_open');
    }
    await teardown(tester);
  });

  testWidgets('CAM, audio and set-up scenarios render', (tester) async {
    await boot(tester, const Size(1600, 1000));
    // Audio: music on, memo list, an announcement playing.
    fap.bgmToggle();
    for (final id in ['welcome', 'safety', 'seatbelt']) {
      fap.selectPram(id);
      fap.memoAdd();
    }
    fap.selectPram('turbulence');
    await fap.playSelectedPram();
    fap.simulatePaxCall();
    fap.goTo(FapPage.audio);
    await shot(tester, 'scenario_audio_memo');
    fap.callReset();

    // Layout 2 loaded; lights follow its classes.
    fap.enterAccessCode(FapPage.layout, '318');
    fap.selectLayoutRow(2);
    fap.loadLayout();
    fap.goTo(FapPage.lights);
    await shot(tester, 'scenario_lights_layout2');

    // Cabin programming saved.
    fap.selectLayoutRow(3);
    fap.loadLayout();
    fap.enterAccessCode(FapPage.cabinProg, '318');
    fap.selectBoundary(1);
    fap.moveBoundary(3);
    fap.goTo(FapPage.cabinProg);
    await shot(tester, 'scenario_cabin_prog_draft');
    fap.saveProgramming();
    await shot(tester, 'scenario_cabin_prog_saved');
    fap.dismissSaved();

    // Seat settings with inhibited seats and a call.
    fap.inhibitSeat('12C');
    fap.inhibitSeat('3A');
    fap.goTo(FapPage.seat);
    await shot(tester, 'scenario_seat');

    // Level adjustment changed.
    fap.enterAccessCode(FapPage.level, '318');
    fap.adjustLevel(announce: 3, chime: -2);
    fap.goTo(FapPage.level);
    await shot(tester, 'scenario_level');

    // FAP config open + Fahrenheit + dimmed screen.
    fap.setTempUnit(true);
    fap.adjustBrightness(-30);
    fap.toggleConfig();
    fap.goTo(FapPage.temperature);
    await shot(tester, 'scenario_config_fahrenheit');
    fap.toggleConfig();
    fap.adjustBrightness(30);

    // Software loading in progress.
    fap.enterAccessCode(FapPage.swLoad, '813');
    fap.goTo(FapPage.swLoad);
    fap.loadSoftware();
    await tester.pump(const Duration(seconds: 4));
    await shot(tester, 'scenario_sw_loading');
    await tester.pump(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 5));
    await teardown(tester);
  });

  testWidgets('notice shows at every start on an unlocked device', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    fap = FapProvider(audio: FakeAudio(), random: Random(7));
    await tester.pumpWidget(AisatFapApp(fap: fap));
    await tester.pump();
    expect(find.text('IMPORTANT NOTICE & DISCLAIMER'), findsOneWidget);
    expect(find.textContaining('Overdrive Interactive'), findsWidgets);
    await tester.tap(find.text('I AGREE & CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('CIDS  FLIGHT ATTENDANT PANEL'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('license activation, then notice, then panel', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AccessLock.androidIdReader = () async => null;
    AccessLock.clientFactory = () => MockClient((req) async {
      if (req.url.path.endsWith('a320_restore_license')) {
        return http.Response(jsonEncode({'ok': false}), 200); // new device
      }
      final code = (jsonDecode(req.body) as Map)['p_code'];
      return http.Response(
        jsonEncode(
          code == 'A320-k7Rm9Qx2'
              ? {'ok': true}
              : {'ok': false, 'reason': 'ALREADY_USED'},
        ),
        200,
      );
    });
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    fap = FapProvider(audio: FakeAudio(), random: Random(7));
    await tester.pumpWidget(AisatFapApp(fap: fap, unlocked: false));
    expect(find.text('Checking this device...'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.text('Checking this device...'), findsNothing);
    expect(find.text('ACTIVATE'), findsOneWidget);
    await shot(tester, 'unlock_screen');
    await tester.enterText(find.byType(EditableText), 'A320-M82P');
    await tester.tap(find.text('ACTIVATE'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('already been used'), findsOneWidget);
    await shot(tester, 'unlock_screen_used');
    await tester.enterText(find.byType(EditableText), 'A320-k7Rm9Qx2');
    await tester.tap(find.text('ACTIVATE'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ACTIVATE'), findsNothing);
    // The notice comes next, before the panel.
    expect(find.text('IMPORTANT NOTICE & DISCLAIMER'), findsOneWidget);
    await shot(tester, 'disclaimer_screen');
    await tester.tap(find.text('I AGREE & CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('CIDS  FLIGHT ATTENDANT PANEL'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fap_license_v2'), isNotNull);
    await teardown(tester);
  });

  testWidgets('reinstalled device skips the code', (tester) async {
    SharedPreferences.setMockInitialValues({}); // app data gone
    AccessLock.androidIdReader = () async => '9774d56d682e549c';
    AccessLock.clientFactory = () => MockClient((req) async {
      expect(req.url.path, endsWith('a320_restore_license'));
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    fap = FapProvider(audio: FakeAudio(), random: Random(7));
    await tester.pumpWidget(AisatFapApp(fap: fap, unlocked: false));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ACTIVATE'), findsNothing);
    expect(find.text('IMPORTANT NOTICE & DISCLAIMER'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fap_license_v2'), isNotNull);
    await teardown(tester);
  });

  testWidgets('offline after reinstall offers CHECK AGAIN', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AccessLock.androidIdReader = () async => null;
    AccessLock.clientFactory = () =>
        MockClient((_) async => throw http.ClientException('no network'));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    fap = FapProvider(audio: FakeAudio(), random: Random(7));
    await tester.pumpWidget(AisatFapApp(fap: fap, unlocked: false));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.text('CHECK AGAIN'), findsOneWidget);
    await shot(tester, 'unlock_screen_offline');
    // Back online: CHECK AGAIN restores the license.
    AccessLock.clientFactory = () => MockClient(
      (_) async => http.Response(jsonEncode({'ok': true}), 200),
    );
    await tester.tap(find.text('CHECK AGAIN'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('IMPORTANT NOTICE & DISCLAIMER'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('demo: 1 light + 1 audio, everything else asks for a code', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    AccessLock.androidIdReader = () async => null;
    AccessLock.clientFactory = () => MockClient((req) async {
      if (req.url.path.endsWith('a320_restore_license')) {
        return http.Response(jsonEncode({'ok': false}), 200);
      }
      final code = (jsonDecode(req.body) as Map)['p_code'];
      return http.Response(
        jsonEncode(
          code == 'A320-k7Rm9Qx2'
              ? {'ok': true}
              : {'ok': false, 'reason': 'INVALID'},
        ),
        200,
      );
    });
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    fap = FapProvider(audio: FakeAudio(), random: Random(7));
    await tester.pumpWidget(AisatFapApp(fap: fap, unlocked: false));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    // The free demo code is on the start screen.
    expect(find.text('TRY DEMO'), findsOneWidget);
    expect(find.textContaining(AccessLock.demoCode), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'a320-demo');
    await tester.tap(find.text('ACTIVATE'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.tap(find.text('I AGREE & CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('DEMO VERSION'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('fap_demo'), isTrue);
    expect(prefs.getString('fap_license_v2'), isNull);
    await shot(tester, 'demo_panel');

    Future<void> tapAndSettle(Finder f) async {
      await tester.tap(f, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> closeDialog() async {
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('ENTER THE LICENSE CODE'), findsNothing);
    }

    // Allowed light: MAIN ON/OFF.
    final mainBefore = fap.mainLightsOn;
    await tapAndSettle(find.text('MAIN\nON/OFF'));
    expect(fap.mainLightsOn, !mainBefore);
    expect(find.text('ENTER THE LICENSE CODE'), findsNothing);

    // Any other light is locked: the license window opens, nothing changes.
    final wdoBefore = fap.windowLights;
    await tapAndSettle(find.text('WDO'));
    expect(fap.windowLights, wdoBefore);
    expect(find.text('ENTER THE LICENSE CODE'), findsOneWidget);
    await shot(tester, 'demo_license_dialog');
    await closeDialog();

    // The LIGHTS hard key below the screen is locked too.
    final mainNow = fap.mainLightsOn;
    await tapAndSettle(find.text('LIGHTS\nMAIN ON/OFF'));
    expect(fap.mainLightsOn, mainNow);
    expect(find.text('ENTER THE LICENSE CODE'), findsOneWidget);
    await closeDialog();

    // Other pages are locked; the AUDIO page is allowed.
    await tapAndSettle(find.text('DOORS\nSLIDES'));
    expect(fap.page, FapPage.lights);
    expect(find.text('ENTER THE LICENSE CODE'), findsOneWidget);
    await closeDialog();
    await tapAndSettle(find.text('AUDIO'));
    expect(fap.page, FapPage.audio);

    // Allowed audio: boarding music ON/OFF. Announcements are locked.
    final musicBefore = fap.musicPlaying;
    await tapAndSettle(find.text('ON/OFF'));
    expect(fap.musicPlaying, !musicBefore);
    expect(find.text('ENTER THE LICENSE CODE'), findsNothing);
    final playingBefore = fap.playingAnnouncement;
    await tapAndSettle(find.text('DIRECT PLAY'));
    expect(fap.playingAnnouncement, playingBefore);
    expect(find.text('ENTER THE LICENSE CODE'), findsOneWidget);

    // The demo code does not work as a license.
    await tester.enterText(find.byType(EditableText), 'A320-DEMO');
    await tester.tap(find.text('ACTIVATE'));
    await tester.pump();
    expect(find.textContaining('That is the demo code'), findsOneWidget);

    // A real license code unlocks everything at once.
    await tester.enterText(find.byType(EditableText), 'A320-k7Rm9Qx2');
    await tester.tap(find.text('ACTIVATE'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ENTER THE LICENSE CODE'), findsNothing);
    expect(find.text('DEMO VERSION'), findsNothing);
    expect(prefs.getBool('fap_demo'), isNull);
    expect(prefs.getString('fap_license_v2'), isNotNull);
    await tapAndSettle(find.text('DOORS\nSLIDES'));
    expect(fap.page, FapPage.doors);
    await teardown(tester);
  });

  testWidgets('demo is remembered: next start opens the demo panel', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'fap_demo': true});
    AccessLock.androidIdReader = () async => null;
    expect(await AccessLock.isUnlocked(), isFalse);
    expect(await AccessLock.isDemo(), isTrue);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    fap = FapProvider(audio: FakeAudio(), random: Random(7));
    await tester.pumpWidget(
      AisatFapApp(fap: fap, unlocked: false, demo: true, showDisclaimer: false),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ACTIVATE'), findsNothing);
    expect(find.text('DEMO VERSION'), findsOneWidget);
    // The bar's button opens the license window.
    await tester.tap(find.text('ENTER LICENSE CODE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ENTER THE LICENSE CODE'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('settings gear: deactivate & transfer locks the device', (
    tester,
  ) async {
    var online = false;
    var released = false;
    AccessLock.androidIdReader = () async => 'aaaa000011112222';
    AccessLock.clientFactory = () => MockClient((req) async {
      if (!online) throw http.ClientException('no network');
      final fn = req.url.pathSegments.last;
      final Map<String, dynamic> body = switch (fn) {
        'a320_my_license' => released
            ? {'ok': false, 'reason': 'NO_LICENSE'}
            : {'ok': true, 'code': 'A320-k7Rm9Qx2', 'used_at': '2026-10-08T06:00:00Z'},
        'a320_release_license' => {'ok': true, 'code': 'A320-k7Rm9Qx2'},
        'a320_restore_license' => {'ok': !released},
        _ => {'ok': false},
      };
      if (fn == 'a320_release_license') released = true;
      return http.Response(jsonEncode(body), 200);
    });
    // A licensed tablet.
    final device = await AccessLock.deviceId();
    SharedPreferences.setMockInitialValues({
      'fap_license_v2': device,
      'fap_license_code': 'A320-k7Rm9Qx2',
    });
    expect(await AccessLock.isUnlocked(), isTrue);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    fap = FapProvider(audio: FakeAudio(), random: Random(7));
    await tester.pumpWidget(AisatFapApp(fap: fap, showDisclaimer: false));
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Offline: the settings still show the saved code and the device id.
    await tester.tap(find.byTooltip('Settings'));
    await settle();
    expect(find.text('A320-k7Rm9Qx2'), findsOneWidget);
    expect(find.text(device), findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
    await tester.tap(find.text('DEACTIVATE & TRANSFER LICENSE'));
    await settle();
    expect(
      find.textContaining('Deactivating will lock this device'),
      findsOneWidget,
    );
    await tester.tap(find.text('DEACTIVATE'));
    await settle();
    expect(find.textContaining('Deactivation must be done online'), findsOneWidget);
    expect(await AccessLock.isUnlocked(), isTrue);
    await tester.tap(find.byTooltip('Close'));
    await settle();

    // Online: shows the activation date; cancel keeps the license.
    online = true;
    await tester.tap(find.byTooltip('Settings'));
    await settle();
    expect(find.text('ACTIVATED'), findsOneWidget);
    await shot(tester, 'settings_dialog');
    await tester.tap(find.text('DEACTIVATE & TRANSFER LICENSE'));
    await settle();
    await tester.tap(find.text('CANCEL'));
    await settle();
    expect(released, isFalse);

    // Confirm: the code is released and the app goes back to activation.
    await tester.tap(find.text('DEACTIVATE & TRANSFER LICENSE'));
    await settle();
    await tester.tap(find.text('DEACTIVATE'));
    await settle();
    await settle();
    expect(released, isTrue);
    expect(find.text('ACTIVATE'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsNothing);
    expect(await AccessLock.isUnlocked(), isFalse);
    expect(await AccessLock.savedCode(), isNull);
    await teardown(tester);
  });

  testWidgets('licensed device released elsewhere locks at start (online)', (
    tester,
  ) async {
    AccessLock.androidIdReader = () async => 'aaaa000011112222';
    final device = await AccessLock.deviceId();
    SharedPreferences.setMockInitialValues({'fap_license_v2': device});
    AccessLock.clientFactory = () => MockClient(
      (_) async => http.Response(
        jsonEncode({'ok': false, 'reason': 'NO_LICENSE'}),
        200,
      ),
    );
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    fap = FapProvider(audio: FakeAudio(), random: Random(7));
    await tester.pumpWidget(
      AisatFapApp(fap: fap, showDisclaimer: false, checkLicenseOnline: true),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ACTIVATE'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('offline start never locks a licensed device', (tester) async {
    AccessLock.androidIdReader = () async => 'aaaa000011112222';
    final device = await AccessLock.deviceId();
    SharedPreferences.setMockInitialValues({'fap_license_v2': device});
    AccessLock.clientFactory = () =>
        MockClient((_) async => throw http.ClientException('no network'));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    fap = FapProvider(audio: FakeAudio(), random: Random(7));
    await tester.pumpWidget(
      AisatFapApp(fap: fap, showDisclaimer: false, checkLicenseOnline: true),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(find.text('ACTIVATE'), findsNothing);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(await AccessLock.isUnlocked(), isTrue);
    await teardown(tester);
  });

  testWidgets('upright screen: the panel is turned sideways, never vertical', (
    tester,
  ) async {
    await boot(tester, const Size(800, 1280));
    final rotated = tester.widget<RotatedBox>(
      find.ancestor(
        of: find.text('CIDS  FLIGHT ATTENDANT PANEL'),
        matching: find.byType(RotatedBox),
      ),
    );
    expect(rotated.quarterTurns, 1);
    expect(tester.takeException(), isNull);
    await shot(tester, 'portrait_rotated');
    await teardown(tester);
  });

  testWidgets('alarm scenarios render', (tester) async {
    await boot(tester, const Size(1600, 1000));

    // Lights page with mixed levels, reading + emergency lights.
    fap.setZoneLight(LightZone.fwdEntry, LightLevel.dim1);
    fap.setZoneLight(LightZone.tourist, LightLevel.dim2);
    fap.toggleReadingAll();
    fap.toggleEmerLights();
    await shot(tester, 'scenario_lights_mixed');

    // Slide deployed at R2 after opening an armed door.
    fap.operateDoor(DoorId.l1);
    fap.armAllSlides();
    fap.operateDoor(DoorId.r2);
    fap.goTo(FapPage.doors);
    await shot(tester, 'scenario_slide_deployed');

    // Lavatory smoke, then reset with smoke still present.
    fap.triggerSmoke(Lavatory.d);
    await shot(tester, 'scenario_smoke');
    fap.triggerSmoke(Lavatory.a);
    fap.smokeReset();
    fap.triggerSmoke(Lavatory.d);
    await shot(tester, 'scenario_smoke_reset');

    // Temperature: FAP fine adjustment around the cockpit selection.
    fap.adjustTemp(TempZone.fwd, 1.5);
    fap.adjustCockpitTemp(TempZone.aft, -2);
    fap.goTo(FapPage.temperature);
    await shot(tester, 'scenario_temperature');
    fap.goTo(FapPage.smoke);
    fap.toggleEvacGuard();
    fap.evacCommand();
    await shot(tester, 'scenario_evac');

    // Waste tank full, CIDS 1+2 fault, screen lock.
    for (var i = 0; i < 8; i++) {
      fap.addWaste();
    }
    fap.goTo(FapPage.water);
    await shot(tester, 'scenario_waste_full');
    fap.toggleDirectorFault(1);
    fap.toggleDirectorFault(2);
    fap.goTo(FapPage.systemInfo);
    await shot(tester, 'scenario_cids_fault');
    fap.screenLock();
    await shot(tester, 'scenario_screen_lock');

    await teardown(tester);
  });

  testWidgets('small tablet scales the whole panel', (tester) async {
    await boot(tester, const Size(1024, 600));
    await shot(tester, 'tablet_1024x600');
    await teardown(tester);
  });

  testWidgets('hard keys respond to taps', (tester) async {
    await boot(tester, const Size(1600, 1000));
    await tester.tap(find.text('LIGHTS\nMAIN ON/OFF'));
    await tester.pump();
    expect(fap.mainLightsOn, isFalse);
    await tester.tap(find.text('EMER'));
    await tester.pump();
    expect(fap.emerLights, isTrue);
    // EVAC CMD: first tap lifts the guard, second tap commands.
    await tester.tap(find.text('GUARD'));
    await tester.pump();
    expect(fap.evacGuardOpen, isTrue);
    expect(fap.evacActive, isFalse);
    await tester.tapAt(
      tester.getCenter(find.text('EVAC\nCMD')) - const Offset(0, 40),
    );
    await tester.pump();
    expect(fap.evacActive, isTrue);
    await tester.tap(find.text('EVAC\nRESET'));
    await tester.pump();
    expect(fap.evacActive, isFalse);
    // Nav tab switches page.
    await tester.tap(find.text('DOORS\nSLIDES'));
    await tester.pump();
    expect(fap.page, FapPage.doors);
    await teardown(tester);
  });
}
