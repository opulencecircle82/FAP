import 'dart:io';
import 'dart:math';

import 'package:aisat_fap/main.dart';
import 'package:aisat_fap/models/fap_state.dart';
import 'package:aisat_fap/providers/fap_provider.dart';
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
    await tester.pumpWidget(AisatFapApp(fap: fap));
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

  final openCode = Platform.environment['FAP_OPEN_CODE'] ?? '';

  testWidgets('open code is asked once', skip: openCode.isEmpty, (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    fap = FapProvider(audio: FakeAudio(), random: Random(7));
    await tester.pumpWidget(AisatFapApp(fap: fap, unlocked: false));
    await tester.pump();
    await shot(tester, 'unlock_screen');
    await tester.enterText(find.byType(EditableText), 'wrong');
    await tester.tap(find.text('UNLOCK'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong code. Please try again.'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), openCode);
    await tester.tap(find.text('UNLOCK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('UNLOCK'), findsNothing);
    expect(find.text('CIDS  FLIGHT ATTENDANT PANEL'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('fap_unlocked_v1'), isTrue);
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
