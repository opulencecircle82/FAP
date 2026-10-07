import 'dart:convert';

import 'package:aisat_fap/models/cabin_setup.dart';
import 'package:aisat_fap/models/fap_state.dart';
import 'package:aisat_fap/models/pram_item.dart';
import 'package:aisat_fap/services/access_lock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
    AccessLock.androidIdReader = () async => null;
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
      fap.setZoneLight(LightZone.business, LightLevel.dim1);
      expect(fap.lightLevel(LightZone.business), LightLevel.dim1);
      expect(fap.generalLevel, isNull); // zones now differ
      fap.setZoneLight(LightZone.business, LightLevel.dim1);
      expect(fap.lightLevel(LightZone.business), LightLevel.off);
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
      fap.setZoneLight(LightZone.tourist, LightLevel.dim1);
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

    test('SMOKE RESET silences; FAP keeps showing smoke while detected', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        f.triggerSmoke(Lavatory.a);
        f.smokeReset();
        expect(f.smoke(Lavatory.a).alert, SmokeAlert.reset);
        expect(f.smokeMonitoring, isTrue);
        expect(audio.alarm, isNull);
        async.elapse(const Duration(seconds: 60));
        expect(f.smoke(Lavatory.a).alert, SmokeAlert.reset);
        f.dispose();
      });
    });

    test('no more smoke: CIDS clears all indications automatically', () {
      fap.triggerSmoke(Lavatory.e);
      expect(audio.alarm, 'smoke');
      fap.extinguishSmoke(Lavatory.e); // without pressing SMOKE RESET
      expect(fap.smoke(Lavatory.e).alert, SmokeAlert.normal);
      expect(fap.smokeAlarm, isFalse);
      expect(audio.alarm, isNull);
    });

    test('one lav cleared, another still alarming keeps the alert', () {
      fap.triggerSmoke(Lavatory.a);
      fap.triggerSmoke(Lavatory.d);
      fap.extinguishSmoke(Lavatory.a);
      expect(fap.smokeLavs, [Lavatory.d]);
      expect(audio.alarm, 'smoke');
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

    test('selector in CAPT: cabin EVAC CMD gives no cabin evac', () {
      fap.toggleEvacSelector();
      fap.toggleEvacGuard();
      fap.evacCommand();
      expect(fap.evacActive, isFalse);
      expect(audio.alarm, isNull);
      expect(fap.notice?.text, contains('COCKPIT HORN ONLY'));
    });

    test('cockpit EVAC command activates cabin evac in any position', () {
      fap.toggleEvacSelector(); // CAPT
      fap.cockpitEvacCommand();
      expect(fap.evacActive, isTrue);
      expect(audio.alarm, 'evac');
    });
  });

  group('other A320 functions', () {
    test('CHIME INHIB blocks chimes', () {
      fap.toggleChimeInhibit();
      audio.calls.clear();
      fap.playChime(ChimeType.singleHigh);
      expect(audio.calls, isEmpty);
      fap.toggleChimeInhibit();
      fap.playChime(ChimeType.emergency);
      expect(audio.calls, ['chime:emergency']);
    });

    test('low cabin pressure switches cabin lights to BRT', () {
      fap.setGeneralLight(LightLevel.dim2);
      fap.lowCabinPressure();
      expect(fap.generalLevel, LightLevel.bright);
    });

    test('PED POWER toggles and FAP RESET restarts for 4 s', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        f.togglePedPower();
        expect(f.pedPower, isFalse);
        f.fapReset();
        expect(f.fapRestarting, isTrue);
        async.elapse(const Duration(seconds: 4));
        expect(f.fapRestarting, isFalse);
        expect(f.pedPower, isFalse); // cabin state kept
        f.dispose();
      });
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
    test('FAP fine adjustment limited to ±2.5 °C of cockpit selection', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        expect(f.cockpitTemp(TempZone.fwd), 22);
        for (var i = 0; i < 20; i++) {
          f.adjustTemp(TempZone.fwd, 0.5);
        }
        expect(f.fapTrim(TempZone.fwd), 2.5);
        expect(f.targetTemp(TempZone.fwd), 24.5);
        expect(f.notice?.text, contains('LIMIT'));
        for (var i = 0; i < 20; i++) {
          f.adjustTemp(TempZone.fwd, -0.5);
        }
        expect(f.targetTemp(TempZone.fwd), 19.5);
        async.elapse(const Duration(seconds: 70));
        expect(f.actualTemp(TempZone.fwd), 19.5);
        f.dispose();
      });
    });

    test('cockpit selection 18-30 °C; target never leaves that range', () {
      for (var i = 0; i < 40; i++) {
        fap.adjustCockpitTemp(TempZone.aft, 0.5);
      }
      expect(fap.cockpitTemp(TempZone.aft), 30);
      fap.adjustTemp(TempZone.aft, 0.5);
      expect(fap.targetTemp(TempZone.aft), 30);
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
      expect(fap.playingAnnouncement, isNull);
      fap.bgmToggle();
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
      expect(audio.calls, contains('announce:safety'));
      await fap.stopSelectedPram();
      expect(fap.playingAnnouncement, isNull);
    });

    test('announcement that cannot play shows a notice', () async {
      audio.ttsAvailable = false;
      fap.selectPram('welcome');
      await fap.playSelectedPram();
      expect(fap.playingAnnouncement, isNull);
      expect(fap.notice?.text, contains('COULD NOT BE PLAYED'));
    });

    test('PRAM list holds announcements only', () {
      expect(pramLibrary.map((p) => p.id), isNot(contains('music')));
    });

    test('MEMO: add, play next, play all in order', () async {
      fap.selectPram('welcome');
      fap.memoAdd();
      fap.selectPram('seatbelt');
      fap.memoAdd();
      fap.selectPram('descent');
      fap.memoAdd();
      expect(fap.memo, ['welcome', 'seatbelt', 'descent']);
      await fap.playNext();
      expect(fap.playingAnnouncement, 'welcome');
      expect(fap.memo, ['seatbelt', 'descent']);
      fakeAsync((async) {
        fap.playAll();
        async.flushMicrotasks();
        expect(fap.playingAnnouncement, 'seatbelt');
        audio.onAnnouncementDone!(); // seatbelt ends by itself
        async.elapse(const Duration(seconds: 1));
        expect(fap.playingAnnouncement, 'descent');
        expect(fap.memo, isEmpty);
        audio.onAnnouncementDone!();
        async.elapse(const Duration(seconds: 1));
        expect(fap.playingAnnouncement, isNull);
        expect(fap.playingAll, isFalse);
      });
    });

    test('STOP ends PLAY ALL', () {
      fakeAsync((async) {
        fap.selectPram('welcome');
        fap.memoAdd();
        fap.memoAdd();
        fap.playAll();
        async.flushMicrotasks();
        fap.stopSelectedPram();
        async.elapse(const Duration(seconds: 2));
        expect(fap.playingAll, isFalse);
        expect(fap.playingAnnouncement, isNull);
        expect(fap.memo.length, 1);
      });
    });

    test('memo remove / clear', () {
      fap.memoAdd();
      fap.memoAdd();
      fap.memoRemove();
      expect(fap.memo.length, 1);
      fap.memoClear();
      expect(fap.memo, isEmpty);
    });
  });

  group('boarding music', () {
    test('ON/OFF, channel and volume', () {
      fap.bgmToggle();
      expect(fap.musicPlaying, isTrue);
      expect(audio.music, isTrue);
      expect(audio.musicChannel, BgmChannel.blues);
      fap.bgmSelect(BgmChannel.jazz);
      expect(audio.musicChannel, BgmChannel.jazz);
      fap.bgmChannelStep(1);
      expect(fap.bgmChannel, BgmChannel.blues); // wraps around
      final v = fap.bgmVolume;
      fap.bgmVolumeStep(1);
      expect(fap.bgmVolume, v + 1);
      for (var i = 0; i < 20; i++) {
        fap.bgmVolumeStep(1);
      }
      expect(fap.bgmVolume, 10);
      fap.bgmToggle();
      expect(fap.musicPlaying, isFalse);
      expect(audio.music, isFalse);
    });

    test('changing channel while off does not start the music', () {
      fap.bgmSelect(BgmChannel.country);
      expect(audio.music, isFalse);
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
        f.adjustTemp(TempZone.aft, -1.0);
        f.adjustCockpitTemp(TempZone.aft, 2.0);
        f.togglePedPower();
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
      expect(restored.fapTrim(TempZone.aft), -1.0);
      expect(restored.cockpitTemp(TempZone.aft), 24.0);
      expect(restored.pedPower, isFalse);
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

  group('CAM layouts and cabin programming', () {
    test('default layout 3: three classes, zones follow it', () {
      expect(fap.activeLayout.id, 3);
      expect(fap.activeZones, [
        LightZone.fwdEntry,
        LightZone.first,
        LightZone.business,
        LightZone.tourist,
        LightZone.aftEntry,
      ]);
      expect(fap.classRows(0), (1, 3));
      expect(fap.classRows(2), (11, 36));
      expect(fap.classOfRow(5), CabinClass.business);
    });

    test('load layout 1: tourist class only', () {
      fap.selectLayoutRow(1);
      expect(fap.activeLayout.id, 3); // not active until LOAD
      fap.loadLayout();
      expect(fap.activeLayout.id, 1);
      expect(fap.activeZones, [
        LightZone.fwdEntry,
        LightZone.tourist,
        LightZone.aftEntry,
      ]);
      expect(fap.classOfRow(1), CabinClass.tourist);
    });

    test('move a cabin zone boundary, then SAVE', () {
      fap.selectBoundary(1); // first / business
      fap.moveBoundary(3);
      expect(fap.draftStarts, [1, 7, 11]);
      expect(fap.classStarts(), [1, 4, 11]); // not saved yet
      expect(fap.programmingDirty, isTrue);
      fap.saveProgramming();
      expect(fap.classStarts(), [1, 7, 11]);
      expect(fap.layoutCount(3), 1);
      expect(fap.savedInfo!.count, 1);
      fap.dismissSaved();
      expect(fap.savedInfo, isNull);
    });

    test('boundary cannot leave a class with zero rows', () {
      fap.selectBoundary(1);
      fap.moveBoundary(50);
      expect(fap.draftStarts[1], 10); // business keeps row 10
      fap.moveBoundary(-50);
      expect(fap.draftStarts[1], 2); // first keeps row 1
    });

    test('non-smoker flag is saved with SAVE', () {
      expect(fap.nonSmoker, isTrue);
      fap.toggleNonSmokerDraft();
      expect(fap.nonSmoker, isTrue);
      fap.saveProgramming();
      expect(fap.nonSmoker, isFalse);
    });
  });

  group('access codes', () {
    test('protected pages need the CIDS code; FAP RESET locks again', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        expect(f.accessGranted(FapPage.cabinProg), isFalse);
        expect(f.accessGranted(FapPage.fapSetup), isTrue);
        expect(f.enterAccessCode(FapPage.cabinProg, '111'), isFalse);
        expect(f.enterAccessCode(FapPage.cabinProg, '318'), isTrue);
        expect(f.accessGranted(FapPage.cabinProg), isTrue);
        expect(f.enterAccessCode(FapPage.swLoad, '318'), isFalse);
        expect(f.enterAccessCode(FapPage.swLoad, '813'), isTrue);
        f.fapReset();
        expect(f.accessGranted(FapPage.cabinProg), isFalse);
        async.elapse(const Duration(seconds: 5));
        f.dispose();
      });
    });

    // License activation against a fake Supabase RPC.
    http.Client fakeServer(
      Map<String, dynamic> Function(Map body) reply, {
      List<Map>? seen,
    }) {
      return MockClient((req) async {
        expect(req.url.path, startsWith('/rest/v1/rpc/a320_'));
        expect(req.headers['apikey'], startsWith('sb_publishable_'));
        final body = {
          ...jsonDecode(req.body) as Map,
          '_fn': req.url.pathSegments.last,
        };
        seen?.add(body);
        return http.Response(jsonEncode(reply(body)), 200);
      });
    }

    test('valid code activates and is remembered; device id is sent', () async {
      final seen = <Map>[];
      AccessLock.clientFactory = () => fakeServer(
        (b) => b['p_code'] == 'A320-k7Rm9Qx2'
            ? {'ok': true}
            : {'ok': false, 'reason': 'INVALID'},
        seen: seen,
      );
      expect(await AccessLock.isUnlocked(), isFalse);
      expect(await AccessLock.activate('A320-XXXX'), LicenseResult.invalid);
      expect(await AccessLock.isUnlocked(), isFalse);
      expect(await AccessLock.activate(' A320-k7Rm9Qx2 '), LicenseResult.ok);
      expect(await AccessLock.isUnlocked(), isTrue);
      expect(seen.last['p_code'], 'A320-k7Rm9Qx2');
      expect(seen.first['p_device'], seen.last['p_device']); // same device
      expect((seen.first['p_device'] as String).length, 32);
    });

    test('reinstall on the same device restores without a code', () async {
      // Fake server with the real rules: a code belongs to one device.
      final owner = <String, String>{};
      Map<String, dynamic> server(Map b) {
        final device = b['p_device'] as String;
        if (b['_fn'] == 'a320_restore_license') {
          return {'ok': owner.containsValue(device)};
        }
        if (b['p_code'] != 'A320-k7Rm9Qx2') {
          return {'ok': false, 'reason': 'INVALID'};
        }
        final used = owner['A320-k7Rm9Qx2'];
        if (used != null && used != device) {
          return {'ok': false, 'reason': 'ALREADY_USED'};
        }
        owner['A320-k7Rm9Qx2'] = device;
        return {'ok': true};
      }

      final seen = <Map>[];
      AccessLock.clientFactory = () => fakeServer(server, seen: seen);
      AccessLock.androidIdReader = () async => '9774d56d682e549c';

      // First install: nothing to restore, so a code is needed.
      expect(await AccessLock.restore(), LicenseResult.invalid);
      expect(await AccessLock.isUnlocked(), isFalse);
      expect(await AccessLock.activate('A320-k7Rm9Qx2'), LicenseResult.ok);
      final device = seen.last['p_device'] as String;
      expect(device.length, 64); // a hash; the raw id is never sent
      expect(device, isNot(contains('9774d56d682e549c')));

      // Uninstall + install: app data is gone, ANDROID_ID is the same.
      SharedPreferences.setMockInitialValues({});
      expect(await AccessLock.isUnlocked(), isFalse);
      expect(await AccessLock.restore(), LicenseResult.ok);
      expect(await AccessLock.isUnlocked(), isTrue);
      expect(seen.last['p_device'], device);

      // Typing the same code again on the same device also works.
      SharedPreferences.setMockInitialValues({});
      expect(await AccessLock.activate('A320-k7Rm9Qx2'), LicenseResult.ok);

      // Another device cannot restore or reuse the code.
      SharedPreferences.setMockInitialValues({});
      AccessLock.androidIdReader = () async => 'ffff000011112222';
      expect(await AccessLock.restore(), LicenseResult.invalid);
      expect(
        await AccessLock.activate('A320-k7Rm9Qx2'),
        LicenseResult.alreadyUsed,
      );
      expect(await AccessLock.isUnlocked(), isFalse);

      // Offline after a reinstall: stays locked until online.
      AccessLock.clientFactory = () =>
          MockClient((_) async => throw http.ClientException('no network'));
      expect(await AccessLock.restore(), LicenseResult.offline);
      expect(await AccessLock.isUnlocked(), isFalse);
    });

    test('old open-code unlock and copied app data do not unlock', () async {
      // Updated from v3.2, which was unlocked with the old shared code.
      SharedPreferences.setMockInitialValues({'fap_unlocked_v1': true});
      expect(await AccessLock.isUnlocked(), isFalse);

      // Activated on device A...
      AccessLock.androidIdReader = () async => '9774d56d682e549c';
      AccessLock.clientFactory = () => fakeServer((_) => {'ok': true});
      expect(await AccessLock.activate('A320-k7Rm9Qx2'), LicenseResult.ok);
      expect(await AccessLock.isUnlocked(), isTrue);
      // ...then the app data is restored onto device B (Android backup).
      AccessLock.androidIdReader = () async => 'ffff000011112222';
      expect(await AccessLock.isUnlocked(), isFalse);
    });

    test('the demo code is never a license and never sent', () async {
      var calls = 0;
      AccessLock.clientFactory = () => MockClient((_) async {
        calls++;
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      expect(AccessLock.isDemoCode(' a320-demo '), isTrue);
      expect(await AccessLock.activate('A320-DEMO'), LicenseResult.invalid);
      expect(calls, 0);
      expect(await AccessLock.isUnlocked(), isFalse);
      await AccessLock.startDemo();
      expect(await AccessLock.isDemo(), isTrue);
    });

    test('server reasons map to messages', () async {
      for (final (reason, result) in [
        ('ALREADY_USED', LicenseResult.alreadyUsed),
        ('TOO_MANY_ATTEMPTS', LicenseResult.tooManyAttempts),
        ('SOMETHING_ELSE', LicenseResult.error),
      ]) {
        AccessLock.clientFactory = () =>
            fakeServer((_) => {'ok': false, 'reason': reason});
        expect(await AccessLock.activate('A320-k7Rm9Qx2'), result);
      }
      expect(await AccessLock.isUnlocked(), isFalse);
    });

    test('offline or server error never unlocks', () async {
      AccessLock.clientFactory = () =>
          MockClient((_) async => throw http.ClientException('no network'));
      expect(await AccessLock.activate('A320-k7Rm9Qx2'), LicenseResult.offline);
      AccessLock.clientFactory = () =>
          MockClient((_) async => http.Response('oops', 500));
      expect(await AccessLock.activate('A320-k7Rm9Qx2'), LicenseResult.error);
      expect(await AccessLock.isUnlocked(), isFalse);
    });
  });

  group('seats and passenger calls', () {
    test('call, chime, CALL RESET', () {
      audio.calls.clear();
      fap.simulatePaxCall();
      expect(fap.paxCalls.length, 1);
      expect(audio.calls, contains('chime:singleHigh'));
      expect(fap.caution.text, contains('PAX CALL'));
      fap.callReset();
      expect(fap.paxCalls, isEmpty);
    });

    test('CALL INHIBIT blocks calls; inhibited seats never call', () {
      fap.toggleCallInhibitAll();
      fap.simulatePaxCall();
      expect(fap.paxCalls, isEmpty);
      fap.toggleCallInhibitAll();
      // inhibit every seat but 1A
      for (var r = 1; r <= fap.activeLayout.rows; r++) {
        for (final l in seatLetters) {
          if ('$r$l' != '1A') fap.inhibitSeat('$r$l');
        }
      }
      fap.simulatePaxCall();
      expect(fap.paxCalls, ['1A']);
      fap.enableAllSeats();
      expect(fap.inhibitedSeats, isEmpty);
    });

    test('chime inhibit silences the call chime', () {
      fap.toggleChimeInhibit();
      audio.calls.clear();
      fap.simulatePaxCall();
      expect(fap.paxCalls.length, 1);
      expect(audio.calls, isEmpty);
    });

    test('reading light inhibits are separate from call inhibits', () {
      fap.setSeatMode(true);
      fap.inhibitSeat('5C');
      expect(fap.readingInhibitedCount, 1);
      fap.setSeatMode(false);
      expect(fap.inhibitedSeats, isEmpty);
    });
  });

  group('level adjustment and FAP set-up', () {
    test('levels limited to -6..+6 dB and drive the PA volume', () {
      fap.setLevelGroup(LevelGroup.cabinZones);
      for (var i = 0; i < 10; i++) {
        fap.adjustLevel(announce: 1);
      }
      expect(fap.level(fap.levelAreas[0]).announce, 6);
      expect(audio.announceDb, closeTo(6 / 3, 1e-9)); // average of 3 classes
      fap.levelsDefault();
      expect(fap.level(fap.levelAreas[0]).announce, 0);
    });

    test('loudspeaker and mute set the master volume', () {
      fap.adjustLoudspeaker(-30);
      expect(audio.master, closeTo(0.7, 1e-9));
      fap.setMuteAll(true);
      expect(audio.master, 0);
      fap.setMuteAll(false);
      expect(audio.master, closeTo(0.7, 1e-9));
    });

    test('brightness 20..100 and touch click', () {
      for (var i = 0; i < 20; i++) {
        fap.adjustBrightness(-10);
      }
      expect(fap.brightness, 20);
      audio.calls.clear();
      fap.keyClick();
      expect(audio.calls, ['click']);
      fap.toggleTouchClick();
      audio.calls.clear();
      fap.keyClick();
      expect(audio.calls, isEmpty);
    });
  });

  group('software, temperature, water, cabin', () {
    test('LOAD SW runs to the end, then the FAP restarts', () {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        f.loadSoftware();
        expect(f.swProgress, 0);
        async.elapse(const Duration(seconds: 5));
        expect(f.swProgress, greaterThan(0.4));
        async.elapse(const Duration(seconds: 6));
        expect(f.swProgress, isNull);
        expect(f.swUpdated, isTrue);
        expect(f.fapRestarting, isTrue);
        async.elapse(const Duration(seconds: 5));
        f.dispose();
      });
    });

    test('RESET temperature back to the cockpit selection', () {
      fap.adjustTemp(TempZone.fwd, 1.5);
      fap.adjustTemp(TempZone.aft, -2.0);
      fap.resetTempToCockpit();
      expect(fap.fapTrim(TempZone.fwd), 0);
      expect(fap.fapTrim(TempZone.aft), 0);
    });

    test('temperature unit', () {
      expect(fap.formatTemp(22), '22.0 °C');
      fap.setTempUnit(true);
      expect(fap.formatTemp(22), '71.6 °F');
    });

    test('RESET WARN hides the waste caution until it happens again', () {
      for (var i = 0; i < 10; i++) {
        fap.addWaste();
      }
      expect(fap.caution.text, contains('WASTE TANK FULL'));
      fap.resetWarn();
      expect(fap.caution.text, isNot(contains('WASTE TANK FULL')));
      fap.drainWaste();
      for (var i = 0; i < 10; i++) {
        fap.addWaste();
      }
      expect(fap.caution.text, contains('WASTE TANK FULL'));
    });

    test('CABIN READY and SCREEN OFF', () {
      fap.operateDoor(DoorId.l1);
      fap.armAllSlides();
      fap.toggleCabinReady();
      expect(fap.cabinReady, isTrue);
      expect(fap.caution.text, contains('CABIN READY'));
      fap.setScreenOff(true);
      expect(fap.screenOff, isTrue);
      fap.setScreenOff(false);
      expect(fap.screenOff, isFalse);
    });

    test('new settings survive a restart', () async {
      fakeAsync((async) {
        final f = FapProvider(audio: audio);
        f.selectLayoutRow(2);
        f.loadLayout();
        f.inhibitSeat('3C');
        f.bgmSelect(BgmChannel.country);
        f.adjustBrightness(-30);
        f.setTempUnit(true);
        f.selectPram('safety');
        f.memoAdd();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        f.dispose();
      });
      final r = FapProvider(audio: FakeAudio());
      await r.load();
      expect(r.activeLayout.id, 2);
      expect(r.inhibitedSeats, {'3C'});
      expect(r.bgmChannel, BgmChannel.country);
      expect(r.brightness, 70);
      expect(r.tempFahrenheit, isTrue);
      expect(r.memo, ['safety']);
      r.dispose();
    });
  });
}
