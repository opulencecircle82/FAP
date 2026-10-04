import 'package:aisat_fap/models/fap_state.dart';
import 'package:aisat_fap/providers/fap_provider.dart';
import 'package:aisat_fap/services/fap_audio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_audio.dart';

void main() {
  late FakeAudio audio;
  late FapProvider fap;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    audio = FakeAudio();
    fap = FapProvider(audio: audio);
  });

  tearDown(() => fap.dispose());

  group('lighting', () {
    test('starts with all zones BRT and MAIN on', () {
      for (final z in LightZone.values) {
        expect(fap.lightLevel(z), LightLevel.bright);
      }
      expect(fap.mainLightsOn, isTrue);
      expect(fap.generalLevel, LightLevel.bright);
    });

    test('zone level press selects, second press switches zone off', () {
      fap.setZoneLight(LightZone.fwdCabin, LightLevel.dim1);
      expect(fap.lightLevel(LightZone.fwdCabin), LightLevel.dim1);
      expect(fap.generalLevel, isNull); // zones now differ
      fap.setZoneLight(LightZone.fwdCabin, LightLevel.dim1);
      expect(fap.lightLevel(LightZone.fwdCabin), LightLevel.off);
    });

    test('general sets every zone; pressing the active level turns off', () {
      fap.setGeneralLight(LightLevel.dim2);
      for (final z in LightZone.values) {
        expect(fap.lightLevel(z), LightLevel.dim2);
      }
      fap.setGeneralLight(LightLevel.dim2);
      expect(fap.mainLightsOn, isFalse);
    });

    test('MAIN ON/OFF hard key toggles all zones off then BRT', () {
      fap.setZoneLight(LightZone.aftCabin, LightLevel.dim1);
      fap.toggleMainLights();
      expect(fap.mainLightsOn, isFalse);
      fap.toggleMainLights();
      for (final z in LightZone.values) {
        expect(fap.lightLevel(z), LightLevel.bright);
      }
    });

    test('levels are 100 / 50 / 10 percent', () {
      expect(LightLevel.bright.percent, 100);
      expect(LightLevel.dim1.percent, 50);
      expect(LightLevel.dim2.percent, 10);
    });
  });

  group('doors and slides', () {
    test('gate state: L1 open, pax doors disarmed, overwing armed', () {
      expect(fap.door(DoorId.l1).closed, isFalse);
      expect(fap.door(DoorId.r1).armed, isFalse);
      expect(fap.door(DoorId.owL1).armed, isTrue);
      expect(fap.allDoorsSecure, isFalse);
      expect(
        fap.caution.text,
        'Please check door/slide status prior departure',
      );
    });

    test('cannot arm an open door', () {
      fap.toggleSlideArm(DoorId.l1);
      expect(fap.door(DoorId.l1).armed, isFalse);
      expect(fap.notice?.text, contains('CLOSE THE DOOR'));
    });

    test('overwing slides cannot be disarmed', () {
      fap.toggleSlideArm(DoorId.owR2);
      expect(fap.door(DoorId.owR2).armed, isTrue);
      fap.disarmAllSlides();
      expect(fap.door(DoorId.owR2).armed, isTrue);
    });

    test('opening a disarmed door does not deploy the slide', () {
      fap.operateDoor(DoorId.r1);
      expect(fap.door(DoorId.r1).closed, isFalse);
      expect(fap.anySlideDeployed, isFalse);
    });

    test('opening an armed door deploys the slide', () {
      fap.toggleSlideArm(DoorId.r2);
      fap.operateDoor(DoorId.r2);
      final d = fap.door(DoorId.r2);
      expect(d.slideDeployed, isTrue);
      expect(d.closed, isFalse);
      expect(fap.caution.text, contains('SLIDE DEPLOYED'));
      expect(fap.caution.text, contains('R2'));
      // Cannot close or disarm a deployed door until the drill is reset.
      fap.operateDoor(DoorId.r2);
      fap.toggleSlideArm(DoorId.r2);
      expect(fap.door(DoorId.r2).slideDeployed, isTrue);
      fap.resetDoorsDrill();
      expect(fap.anySlideDeployed, isFalse);
    });

    test('arm slides skips open doors and reports them', () {
      fap.armAllSlides();
      expect(fap.door(DoorId.l1).armed, isFalse);
      expect(fap.door(DoorId.r1).armed, isTrue);
      expect(fap.notice?.text, contains('L1'));
    });

    test('close L1 then arm all gives all-secure green status', () {
      fap.operateDoor(DoorId.l1); // close
      fap.armAllSlides();
      expect(fap.allDoorsSecure, isTrue);
      expect(fap.armedCount, DoorId.values.length);
      expect(fap.caution.text, 'ALL DOORS CLOSED  -  ALL SLIDES ARMED');
    });
  });

  group('lavatory smoke', () {
    test('smoke alarms, pops the smoke page and sounds the alert', () {
      fap.triggerSmoke(Lavatory.d);
      expect(fap.smokeAlarm, isTrue);
      expect(fap.page, FapPage.smoke);
      expect(audio.alarm, 'smoke');
      expect(fap.caution.text, contains('LAV D'));
    });

    test('reset with smoke still present re-alarms after 10 s', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        f.triggerSmoke(Lavatory.a);
        f.goTo(FapPage.lights);
        f.smokeReset();
        expect(f.smoke(Lavatory.a).alert, SmokeAlert.reset);
        expect(audio.alarm, isNull);
        async.elapse(const Duration(seconds: 9));
        expect(f.smoke(Lavatory.a).alert, SmokeAlert.reset);
        async.elapse(const Duration(seconds: 2));
        expect(f.smoke(Lavatory.a).alert, SmokeAlert.alarm);
        expect(audio.alarm, 'smoke');
        expect(f.page, FapPage.smoke);
        f.dispose();
      });
    });

    test('extinguish during monitoring clears; no re-alarm', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        f.triggerSmoke(Lavatory.e);
        f.smokeReset();
        f.extinguishSmoke(Lavatory.e);
        expect(f.smoke(Lavatory.e).alert, SmokeAlert.normal);
        async.elapse(const Duration(seconds: 15));
        expect(f.smoke(Lavatory.e).alert, SmokeAlert.normal);
        f.dispose();
      });
    });

    test('extinguished while alarming still needs SMOKE RESET', () {
      fap.triggerSmoke(Lavatory.a);
      fap.extinguishSmoke(Lavatory.a);
      expect(fap.smoke(Lavatory.a).alert, SmokeAlert.alarm);
      fap.smokeReset();
      expect(fap.smoke(Lavatory.a).alert, SmokeAlert.normal);
      expect(audio.alarm, isNull);
    });
  });

  group('evacuation', () {
    test('EVAC CMD needs the guard lifted', () {
      fap.evacCommand();
      expect(fap.evacActive, isFalse);
      fap.toggleEvacGuard();
      fap.evacCommand();
      expect(fap.evacActive, isTrue);
      expect(audio.alarm, 'evac');
      expect(fap.caution.color, isNotNull);
      expect(fap.caution.text, contains('EVAC'));
    });

    test('EVAC RESET silences; smoke alert resumes if still active', () {
      fap.triggerSmoke(Lavatory.a);
      fap.toggleEvacGuard();
      fap.evacCommand();
      expect(audio.alarm, 'evac'); // evac has priority
      fap.evacReset();
      expect(fap.evacActive, isFalse);
      expect(audio.alarm, 'smoke');
    });
  });

  group('water / waste', () {
    test('A320 tank capacities and default levels', () {
      expect(fap.waterLitres, 160); // 80 % of 200 L
      expect(fap.wasteLitres, closeTo(42.5, 0.01)); // 25 % of 170 L
    });

    test('full waste tank makes lavs inop; drain restores', () {
      for (var i = 0; i < 10; i++) {
        fap.addWaste();
      }
      expect(fap.wastePct, 100);
      expect(fap.lavsInop, isTrue);
      fap.drainWaste();
      expect(fap.lavsInop, isFalse);
    });

    test('refill goes to the preselected quantity', () {
      fap.setWaterPreselect(50);
      fap.refillWater();
      expect(fap.waterPct, 50);
      for (var i = 0; i < 8; i++) {
        fap.consumeWater();
      }
      expect(fap.waterPct, 0);
      expect(fap.waterEmpty, isTrue);
    });
  });

  group('temperature', () {
    test('clamped to 18-30 and actual drifts toward target', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        for (var i = 0; i < 40; i++) {
          f.adjustTemp(TempZone.fwd, 0.5);
        }
        expect(f.targetTemp(TempZone.fwd), 30);
        for (var i = 0; i < 40; i++) {
          f.adjustTemp(TempZone.fwd, -0.5);
        }
        expect(f.targetTemp(TempZone.fwd), 18);
        async.elapse(const Duration(seconds: 70));
        expect(f.actualTemp(TempZone.fwd), 18);
        f.dispose();
      });
    });
  });

  group('CIDS', () {
    test('DIR 1 fault hands over to DIR 2; both = PA lost', () async {
      fap.toggleDirectorFault(1);
      expect(fap.activeDirector, 2);
      expect(fap.cidsDown, isFalse);
      fap.toggleDirectorFault(2);
      expect(fap.cidsDown, isTrue);
      await fap.playSelectedPram();
      expect(fap.musicPlaying, isFalse);
      audio.calls.clear();
      fap.playChime(ChimeType.highLow);
      expect(audio.calls, isEmpty);
      expect(fap.caution.text, contains('CIDS 1+2 FAULT'));
    });
  });

  group('PRAM', () {
    test('announcement plays and clears when done', () async {
      fap.selectPram('safety');
      await fap.playSelectedPram();
      expect(fap.playingAnnouncement, 'safety');
      await fap.stopSelectedPram();
      expect(fap.playingAnnouncement, isNull);
    });

    test('no voice engine shows a notice', () async {
      audio.ttsAvailable = false;
      fap.selectPram('welcome');
      await fap.playSelectedPram();
      expect(fap.playingAnnouncement, isNull);
      expect(fap.notice?.text, contains('VOICE ENGINE'));
    });

    test('music toggles', () async {
      fap.selectPram('music');
      await fap.playSelectedPram();
      expect(fap.musicPlaying, isTrue);
      expect(audio.music, isTrue);
      await fap.stopSelectedPram();
      expect(fap.musicPlaying, isFalse);
    });
  });

  group('screen lock', () {
    test('locks for 30 s then unlocks', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        f.screenLock();
        expect(f.screenLocked, isTrue);
        async.elapse(const Duration(seconds: 29));
        expect(f.screenLocked, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(f.screenLocked, isFalse);
        f.dispose();
      });
    });
  });

  group('persistence', () {
    test('settings survive a restart; alarms do not', () async {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        f.setGeneralLight(LightLevel.dim1);
        f.operateDoor(DoorId.l1);
        f.armAllSlides();
        f.setWaterPreselect(75);
        f.addWaste();
        f.triggerSmoke(Lavatory.a);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        f.dispose();
      });

      final restored = FapProvider(audio: FakeAudio());
      await restored.load();
      expect(restored.generalLevel, LightLevel.dim1);
      expect(restored.allDoorsSecure, isTrue);
      expect(restored.waterPreselect, 75);
      expect(restored.wastePct, 35);
      expect(restored.smokeAlarm, isFalse);
      restored.dispose();
    });

    test('reset simulator restores defaults', () {
      fap.setGeneralLight(LightLevel.dim2);
      fap.toggleDirectorFault(1);
      fap.resetSimulator();
      expect(fap.generalLevel, LightLevel.bright);
      expect(fap.dir1Fault, isFalse);
      expect(fap.door(DoorId.l1).closed, isFalse);
    });
  });
}
