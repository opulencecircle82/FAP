import 'dart:io';

import 'package:aisat_fap/main.dart';
import 'package:aisat_fap/models/fap_state.dart';
import 'package:aisat_fap/providers/fap_provider.dart';
import 'package:aisat_fap/screens/landing_page_screen.dart';
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
    fap = FapProvider(audio: FakeAudio());
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
    await teardown(tester);
  });

  testWidgets('alarm scenarios render', (tester) async {
    await boot(tester, const Size(1600, 1000));

    // Lights page with mixed levels, reading + emergency lights.
    fap.setZoneLight(LightZone.fwdEntry, LightLevel.dim1);
    fap.setZoneLight(LightZone.aftCabin, LightLevel.dim2);
    fap.toggleReadingAll();
    fap.toggleEmerLights();
    await shot(tester, 'scenario_lights_mixed');

    // Slide deployed at R2 after opening an armed door.
    fap.operateDoor(DoorId.l1);
    fap.armAllSlides();
    fap.operateDoor(DoorId.r2);
    fap.goTo(FapPage.doors);
    await shot(tester, 'scenario_slide_deployed');

    // Lavatory smoke + EVAC command.
    fap.triggerSmoke(Lavatory.d);
    await shot(tester, 'scenario_smoke');
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

  for (final size in const [Size(1440, 900), Size(390, 844)]) {
    testWidgets('landing page ${size.width.toInt()}w', (tester) async {
      await boot(tester, size);
      await tester.binding.handlePushRoute(LandingPageScreen.route);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await shot(tester, 'landing_${size.width.toInt()}');
      await teardown(tester);
    });
  }
}
