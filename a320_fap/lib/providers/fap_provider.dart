import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/fap_state.dart';
import '../models/pram_item.dart';
import '../services/fap_audio.dart';
import '../theme/fap_theme.dart';

/// One line in the FAP caution / info row.
class CautionMessage {
  const CautionMessage(this.text, this.color, {this.flashing = false});
  final String text;
  final Color color;
  final bool flashing;
}

/// Transient feedback shown on the screen for a few seconds.
class FapNotice {
  const FapNotice(this.id, this.text, this.color);
  final int id;
  final String text;
  final Color color;
}

/// Complete A320 CIDS FAP simulator state and logic. Everything is local:
/// persistent settings are stored with SharedPreferences, alarms are not.
class FapProvider extends ChangeNotifier {
  FapProvider({FapAudio? audio}) : audio = audio ?? FapAudio() {
    this.audio.onAnnouncementDone = _onAnnouncementDone;
    this.audio.setPaGain(_paGain);
    this.audio.setMusicLevel(_musicLevel);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  static const _prefsKey = 'fap_state_v1';

  final FapAudio audio;
  late final Timer _tick;
  SharedPreferences? _prefs;
  Timer? _saveTimer;
  Timer? _noticeTimer;
  Timer? _lockTimer;
  Timer? _restartTimer;
  bool _disposed = false;

  // ------------------------------------------------------------ navigation

  FapPage _page = FapPage.lights;
  FapPage get page => _page;

  void goTo(FapPage p) {
    if (_page == p) return;
    _page = p;
    notifyListeners();
  }

  FapNotice? _notice;
  int _noticeSeq = 0;
  FapNotice? get notice => _notice;

  void _showNotice(String text, {Color color = FapColors.amber}) {
    _notice = FapNotice(++_noticeSeq, text, color);
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (_disposed) return;
      _notice = null;
      notifyListeners();
    });
  }

  // ------------------------------------------------------------ lighting

  final Map<LightZone, LightLevel> _lights = {
    for (final z in LightZone.values) z: LightLevel.bright,
  };
  bool _windowLights = true;
  bool _readingAll = false;
  bool _attWorkLights = true;
  bool _lavMaint = false;
  bool _emerLights = false;

  LightLevel lightLevel(LightZone z) => _lights[z]!;
  bool get windowLights => _windowLights;
  bool get readingAll => _readingAll;
  bool get attWorkLights => _attWorkLights;
  bool get lavMaint => _lavMaint;
  bool get emerLights => _emerLights;

  /// True when any general cabin illumination zone is on.
  bool get mainLightsOn => _lights.values.any((l) => l != LightLevel.off);

  /// The level shared by every zone, or null when zones differ / are off.
  LightLevel? get generalLevel {
    final first = _lights.values.first;
    if (first == LightLevel.off) return null;
    return _lights.values.every((l) => l == first) ? first : null;
  }

  /// Pressing the selected level again switches that zone off (FAP toggle).
  void setZoneLight(LightZone z, LightLevel level) {
    _lights[z] = _lights[z] == level ? LightLevel.off : level;
    _changed();
  }

  void setGeneralLight(LightLevel level) {
    final target = generalLevel == level ? LightLevel.off : level;
    for (final z in LightZone.values) {
      _lights[z] = target;
    }
    _changed();
  }

  /// LIGHTS MAIN ON/OFF hard key.
  void toggleMainLights() {
    final target = mainLightsOn ? LightLevel.off : LightLevel.bright;
    for (final z in LightZone.values) {
      _lights[z] = target;
    }
    _changed();
  }

  void toggleWindowLights() {
    _windowLights = !_windowLights;
    _changed();
  }

  void toggleReadingAll() {
    _readingAll = !_readingAll;
    _changed();
  }

  void toggleAttWorkLights() {
    _attWorkLights = !_attWorkLights;
    _changed();
  }

  /// LAV MAINT hard key: lavatory lights full bright for maintenance.
  void toggleLavMaint() {
    _lavMaint = !_lavMaint;
    _changed();
  }

  /// EMER hard key: cabin emergency lighting on/off.
  void toggleEmerLights() {
    _emerLights = !_emerLights;
    _changed();
  }

  // ------------------------------------------------------------ doors

  static Map<DoorId, DoorStatus> _defaultDoors() => {
    for (final d in DoorId.values)
      d: d.isOverwing
          ? const DoorStatus(closed: true, armed: true)
          // Aircraft at the gate: L1 open for boarding, all disarmed.
          : DoorStatus(closed: d != DoorId.l1, armed: false),
  };

  final Map<DoorId, DoorStatus> _doors = _defaultDoors();

  DoorStatus door(DoorId id) => _doors[id]!;

  bool get allDoorsSecure => _doors.values.every((d) => d.isSecure);
  bool get anySlideDeployed => _doors.values.any((d) => d.slideDeployed);
  bool get allDoorsClosed => _doors.values.every((d) => d.closed);
  int get armedCount => _doors.values.where((d) => d.armed).length;
  int get closedCount => _doors.values.where((d) => d.closed).length;
  List<DoorId> get deployedDoors =>
      DoorId.values.where((d) => _doors[d]!.slideDeployed).toList();

  /// Trainer: moves the arming lever at the door.
  void toggleSlideArm(DoorId id) {
    final d = _doors[id]!;
    if (id.isOverwing) {
      _showNotice('${id.label}: OVERWING SLIDE IS PERMANENTLY ARMED');
    } else if (d.slideDeployed) {
      _showNotice(
        '${id.label}: SLIDE DEPLOYED - USE RESET DRILL',
        color: FapColors.red,
      );
    } else if (!d.closed) {
      _showNotice('${id.label}: CLOSE THE DOOR BEFORE ARMING');
    } else {
      _doors[id] = d.copyWith(armed: !d.armed);
    }
    _changed();
  }

  /// Trainer: opens or closes the door. Opening an armed door deploys
  /// its escape slide, exactly like the aircraft.
  void operateDoor(DoorId id) {
    final d = _doors[id]!;
    if (d.slideDeployed) {
      _showNotice(
        '${id.label}: SLIDE DEPLOYED - USE RESET DRILL',
        color: FapColors.red,
      );
    } else if (!d.closed) {
      _doors[id] = d.copyWith(closed: true);
    } else if (d.armed) {
      _doors[id] = d.copyWith(closed: false, slideDeployed: true);
      _showNotice(
        'SLIDE DEPLOYED AT ${id.label} - DOOR OPENED WHILE ARMED',
        color: FapColors.red,
      );
    } else {
      _doors[id] = d.copyWith(closed: false);
    }
    _changed();
  }

  /// Trainer: "Cabin crew, arm slides and cross-check".
  void armAllSlides() {
    final open = <String>[];
    for (final id in DoorId.values) {
      final d = _doors[id]!;
      if (d.slideDeployed) continue;
      if (!d.closed) {
        open.add(id.label);
      } else {
        _doors[id] = d.copyWith(armed: true);
      }
    }
    if (open.isNotEmpty) {
      _showNotice('NOT ARMED - DOOR OPEN: ${open.join(', ')}');
    }
    _changed();
  }

  /// Trainer: "Cabin crew, disarm slides and cross-check".
  void disarmAllSlides() {
    for (final id in DoorId.values) {
      final d = _doors[id]!;
      if (id.isOverwing || d.slideDeployed) continue;
      _doors[id] = d.copyWith(armed: false);
    }
    _changed();
  }

  void resetDoorsDrill() {
    _doors
      ..clear()
      ..addAll(_defaultDoors());
    _changed();
  }

  // ------------------------------------------------------------ audio / PRAM

  String _selectedPram = pramLibrary.first.id;
  String? _playingAnnouncement;
  bool _musicPlaying = false;
  double _paGain = 0.8;
  double _musicLevel = 0.6;

  String get selectedPram => _selectedPram;
  PramItem get selectedPramItem =>
      pramLibrary.firstWhere((p) => p.id == _selectedPram);
  String? get playingAnnouncement => _playingAnnouncement;
  bool get musicPlaying => _musicPlaying;
  double get paGain => _paGain;
  double get musicLevel => _musicLevel;

  bool isPramPlaying(PramItem item) =>
      item.isMusic ? _musicPlaying : _playingAnnouncement == item.id;

  void selectPram(String id) {
    _selectedPram = id;
    notifyListeners();
  }

  Future<void> playSelectedPram() async {
    if (cidsDown) {
      _showNotice('CIDS 1+2 FAULT - PA NOT AVAILABLE', color: FapColors.red);
      notifyListeners();
      return;
    }
    final item = selectedPramItem;
    if (item.isMusic) {
      _musicPlaying = true;
      notifyListeners();
      await audio.startMusic();
      return;
    }
    _playingAnnouncement = item.id;
    notifyListeners();
    final ok = await audio.announce(item.id);
    if (!ok) {
      _playingAnnouncement = null;
      _showNotice('ANNOUNCEMENT COULD NOT BE PLAYED');
      notifyListeners();
    }
  }

  Future<void> stopSelectedPram() async {
    if (selectedPramItem.isMusic) {
      _musicPlaying = false;
      notifyListeners();
      await audio.stopMusic();
    } else if (_playingAnnouncement != null) {
      await audio.stopAnnouncement();
    }
  }

  Future<void> stopAllAudio() async {
    _musicPlaying = false;
    notifyListeners();
    await audio.stopMusic();
    await audio.stopAnnouncement();
  }

  void _onAnnouncementDone() {
    if (_playingAnnouncement == null) return;
    _playingAnnouncement = null;
    notifyListeners();
  }

  void setPaGain(double v) {
    _paGain = v;
    audio.setPaGain(v);
    _changed();
  }

  void setMusicLevel(double v) {
    _musicLevel = v;
    audio.setMusicLevel(v);
    _changed();
  }

  bool _chimeInhibit = false;
  bool get chimeInhibit => _chimeInhibit;

  /// CHIME INHIB on the audio page: silences cabin chimes.
  void toggleChimeInhibit() {
    _chimeInhibit = !_chimeInhibit;
    _changed();
  }

  void playChime(ChimeType type) {
    if (_chimeInhibit) {
      _showNotice('CHIME INHIBITED - PRESS CHIME INHIB TO RESTORE');
      notifyListeners();
      return;
    }
    if (cidsDown) {
      _showNotice(
        'CIDS 1+2 FAULT - CHIMES NOT AVAILABLE',
        color: FapColors.red,
      );
      notifyListeners();
      return;
    }
    audio.chime(type);
  }

  // ------------------------------------------------------------ temperature

  /// Zone temperature selected by the flight crew (cockpit, 18-30 °C).
  final Map<TempZone, double> _cockpitTemp = {
    TempZone.fwd: 22.0,
    TempZone.aft: 22.0,
  };

  /// Cabin crew fine adjustment from the FAP (±2.5 °C).
  final Map<TempZone, double> _fapTrim = {TempZone.fwd: 0.0, TempZone.aft: 0.0};
  final Map<TempZone, double> _actualTemp = {
    TempZone.fwd: 24.0,
    TempZone.aft: 23.5,
  };

  double cockpitTemp(TempZone z) => _cockpitTemp[z]!;
  double fapTrim(TempZone z) => _fapTrim[z]!;
  double targetTemp(TempZone z) => (_cockpitTemp[z]! + _fapTrim[z]!)
      .clamp(FapConstants.minTemp, FapConstants.maxTemp)
      .toDouble();
  double actualTemp(TempZone z) => _actualTemp[z]!;
  double get cabinTemp =>
      _actualTemp.values.reduce((a, b) => a + b) / _actualTemp.length;

  /// FAP +/-: fine adjustment around the cockpit selection.
  void adjustTemp(TempZone z, double delta) {
    const limit = FapConstants.fapTempTrim;
    final next = (_fapTrim[z]! + delta).clamp(-limit, limit).toDouble();
    if (next == _fapTrim[z]) {
      _showNotice('FAP ADJUSTMENT LIMIT ±$limit°C - ASK THE FLIGHT CREW');
    }
    _fapTrim[z] = next;
    _changed();
  }

  /// Trainer: the flight crew changes the zone selector in the cockpit.
  void adjustCockpitTemp(TempZone z, double delta) {
    _cockpitTemp[z] = (_cockpitTemp[z]! + delta)
        .clamp(FapConstants.minTemp, FapConstants.maxTemp)
        .toDouble();
    _changed();
  }

  // ------------------------------------------------------------ water / waste

  double _waterPct = 80;
  double _wastePct = 25;
  int _waterPreselect = 100;

  double get waterPct => _waterPct;
  double get wastePct => _wastePct;
  int get waterPreselect => _waterPreselect;
  double get waterLitres => FapConstants.potableWaterLitres * _waterPct / 100;
  double get wasteLitres => FapConstants.wasteTankLitres * _wastePct / 100;
  bool get waterLow => _waterPct <= 20;
  bool get waterEmpty => _waterPct <= 0;
  bool get wasteFull => _wastePct >= 100;
  bool get wasteHigh => _wastePct >= 80;

  /// A full waste tank makes every vacuum toilet inoperative.
  bool get lavsInop => wasteFull;

  void setWaterPreselect(int pct) {
    _waterPreselect = pct;
    _changed();
  }

  void refillWater() {
    _waterPct = _waterPreselect.toDouble();
    _changed();
  }

  void consumeWater() {
    _waterPct = (_waterPct - 10).clamp(0, 100).toDouble();
    _changed();
  }

  void addWaste() {
    _wastePct = (_wastePct + 10).clamp(0, 100).toDouble();
    _changed();
  }

  void drainWaste() {
    _wastePct = 0;
    _changed();
  }

  // ------------------------------------------------------------ smoke

  final Map<Lavatory, LavSmokeStatus> _smoke = {
    for (final l in Lavatory.values) l: const LavSmokeStatus(),
  };

  LavSmokeStatus smoke(Lavatory l) => _smoke[l]!;
  bool get smokeAlarm => _smoke.values.any((s) => s.alert == SmokeAlert.alarm);
  bool get smokeMonitoring =>
      _smoke.values.any((s) => s.alert == SmokeAlert.reset);
  List<Lavatory> get smokeLavs => Lavatory.values
      .where((l) => _smoke[l]!.alert == SmokeAlert.alarm)
      .toList();

  /// Trainer: smoke appears in a lavatory.
  void triggerSmoke(Lavatory l) {
    _smoke[l] = const LavSmokeStatus(alert: SmokeAlert.alarm, source: true);
    _page = FapPage.smoke; // FAP pops the smoke page automatically.
    _updateAlarmSound();
    notifyListeners();
  }

  /// Trainer: the smoke has cleared. With no more smoke detected the CIDS
  /// resets all visual and aural indications automatically.
  void extinguishSmoke(Lavatory l) {
    _smoke[l] = const LavSmokeStatus();
    _updateAlarmSound();
    notifyListeners();
  }

  /// SMOKE RESET (hard key or touchscreen): silences the aural alert and
  /// the cabin indications. The FAP keeps showing the smoke for as long as
  /// the detector still senses it.
  void smokeReset() {
    var any = false;
    for (final l in Lavatory.values) {
      final s = _smoke[l]!;
      if (s.alert != SmokeAlert.alarm) continue;
      any = true;
      _smoke[l] = s.copyWith(alert: SmokeAlert.reset);
    }
    if (!any) _showNotice('NO ACTIVE SMOKE ALERT', color: FapColors.textDim);
    _updateAlarmSound();
    notifyListeners();
  }

  // ------------------------------------------------------------ evacuation

  bool _evacGuardOpen = false;
  bool _evacActive = false;

  bool _evacCaptOnly = false;

  bool get evacGuardOpen => _evacGuardOpen;
  bool get evacActive => _evacActive;

  /// Cockpit CAPT / CAPT & PURS selector. In CAPT, a cabin EVAC CMD only
  /// sounds the cockpit horn for 3 s; no cabin evacuation alert.
  bool get evacCaptOnly => _evacCaptOnly;

  /// Trainer: moves the cockpit CAPT / CAPT & PURS selector.
  void toggleEvacSelector() {
    _evacCaptOnly = !_evacCaptOnly;
    notifyListeners();
  }

  /// Trainer: the flight crew sets EVAC COMMAND ON in the cockpit.
  void cockpitEvacCommand() {
    _evacActive = true;
    _showNotice('EVAC COMMANDED FROM THE COCKPIT', color: FapColors.red);
    _updateAlarmSound();
    notifyListeners();
  }

  void toggleEvacGuard() {
    _evacGuardOpen = !_evacGuardOpen;
    notifyListeners();
  }

  /// EVAC CMD hard key (guarded).
  void evacCommand() {
    if (!_evacGuardOpen) {
      _showNotice('LIFT THE EVAC CMD GUARD FIRST');
      notifyListeners();
      return;
    }
    _evacGuardOpen = false;
    if (_evacCaptOnly) {
      _showNotice('SELECTOR IN CAPT: COCKPIT HORN ONLY (3 S) - NO CABIN EVAC');
      notifyListeners();
      return;
    }
    _evacActive = true;
    _updateAlarmSound();
    notifyListeners();
  }

  /// EVAC RESET hard key: silences the EVAC tone at this station and
  /// clears the EVAC indications.
  void evacReset() {
    if (!_evacActive) {
      _showNotice('NO EVAC COMMAND ACTIVE', color: FapColors.textDim);
      notifyListeners();
      return;
    }
    _evacActive = false;
    _updateAlarmSound();
    notifyListeners();
  }

  void _updateAlarmSound() {
    if (_evacActive) {
      audio.startEvacTone();
    } else if (smokeAlarm) {
      audio.startSmokeAlarm();
    } else {
      audio.stopAlarm();
    }
  }

  // ------------------------------------------------------------ other keys

  bool _paxSys = true;
  bool get paxSys => _paxSys;

  void togglePaxSys() {
    _paxSys = !_paxSys;
    _changed();
  }

  bool _pedPower = true;
  bool get pedPower => _pedPower;

  /// PED POWER hard key: passenger in-seat power supply on/off.
  void togglePedPower() {
    _pedPower = !_pedPower;
    _changed();
  }

  bool _fapRestarting = false;
  bool get fapRestarting => _fapRestarting;

  /// FAP-PC RESET hard key: restarts the FAP computer (screen only; the
  /// cabin systems keep their state).
  void fapReset() {
    if (_fapRestarting) return;
    _fapRestarting = true;
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(seconds: 4), () {
      if (_disposed) return;
      _fapRestarting = false;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Trainer: low cabin pressure. CIDS switches the cabin lights to BRT.
  void lowCabinPressure() {
    for (final z in LightZone.values) {
      _lights[z] = LightLevel.bright;
    }
    _showNotice(
      'LOW CABIN PRESSURE - CABIN LIGHTS BRT (AUTO)',
      color: FapColors.red,
    );
    _changed();
  }

  int _lockRemaining = 0;
  int get lockRemaining => _lockRemaining;
  bool get screenLocked => _lockRemaining > 0;

  /// SCREEN 30 SEC LOCK hard key: disables the touchscreen for cleaning.
  void screenLock() {
    _lockRemaining = FapConstants.screenLockSeconds;
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _lockRemaining--;
      if (_lockRemaining <= 0) {
        _lockRemaining = 0;
        t.cancel();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  // ------------------------------------------------------------ CIDS

  bool _dir1Fault = false;
  bool _dir2Fault = false;
  bool get dir1Fault => _dir1Fault;
  bool get dir2Fault => _dir2Fault;
  bool get cidsDown => _dir1Fault && _dir2Fault;

  /// 1 or 2, or null when both directors have failed.
  int? get activeDirector => !_dir1Fault ? 1 : (!_dir2Fault ? 2 : null);

  void toggleDirectorFault(int n) {
    if (n == 1) {
      _dir1Fault = !_dir1Fault;
    } else {
      _dir2Fault = !_dir2Fault;
    }
    if (cidsDown) {
      // PA, interphone and passenger signs are lost.
      _musicPlaying = false;
      audio.stopMusic();
      audio.stopAnnouncement();
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ status row

  CautionMessage get caution {
    if (_evacActive) {
      return const CautionMessage(
        'EVAC  -  EVACUATION COMMAND ACTIVE',
        FapColors.red,
        flashing: true,
      );
    }
    if (smokeAlarm) {
      return CautionMessage(
        'SMOKE  ${smokeLavs.map((l) => l.label).join(' / ')}',
        FapColors.red,
        flashing: true,
      );
    }
    if (cidsDown) {
      return const CautionMessage(
        'CIDS 1+2 FAULT - PA / INTERPHONE / SIGNS LOST',
        FapColors.red,
      );
    }
    if (anySlideDeployed) {
      return CautionMessage(
        'SLIDE DEPLOYED  ${deployedDoors.map((d) => d.label).join(' / ')}',
        FapColors.red,
      );
    }
    if (lavsInop) {
      return const CautionMessage(
        'WASTE TANK FULL - LAVATORIES INOP',
        FapColors.amber,
      );
    }
    if (_dir1Fault || _dir2Fault) {
      return CautionMessage(
        'CIDS DIR ${_dir1Fault ? 1 : 2} FAULT',
        FapColors.amber,
      );
    }
    if (!allDoorsSecure) {
      return const CautionMessage(
        'Please check door/slide status prior departure',
        FapColors.cyan,
        flashing: true,
      );
    }
    return const CautionMessage(
      'ALL DOORS CLOSED  -  ALL SLIDES ARMED',
      FapColors.okGreen,
    );
  }

  // ------------------------------------------------------------ lifecycle

  void _onTick() {
    var moved = false;
    for (final z in TempZone.values) {
      final a = _actualTemp[z]!;
      final t = targetTemp(z);
      if (a == t) continue;
      final diff = t - a;
      _actualTemp[z] = diff.abs() <= 0.1 ? t : a + (diff > 0 ? 0.1 : -0.1);
      moved = true;
    }
    if (moved) notifyListeners();
  }

  /// Restores factory defaults (everything except audio levels).
  void resetSimulator() {
    for (final z in LightZone.values) {
      _lights[z] = LightLevel.bright;
    }
    _windowLights = true;
    _readingAll = false;
    _attWorkLights = true;
    _lavMaint = false;
    _emerLights = false;
    _doors
      ..clear()
      ..addAll(_defaultDoors());
    _cockpitTemp.updateAll((_, _) => 22.0);
    _fapTrim.updateAll((_, _) => 0.0);
    _actualTemp[TempZone.fwd] = 24.0;
    _actualTemp[TempZone.aft] = 23.5;
    _waterPct = 80;
    _wastePct = 25;
    _waterPreselect = 100;
    _smoke.updateAll((_, _) => const LavSmokeStatus());
    _evacActive = false;
    _evacGuardOpen = false;
    _evacCaptOnly = false;
    _paxSys = true;
    _pedPower = true;
    _chimeInhibit = false;
    _dir1Fault = false;
    _dir2Fault = false;
    _musicPlaying = false;
    _playingAnnouncement = null;
    audio.stopAll();
    _page = FapPage.lights;
    _showNotice('SIMULATOR RESET TO DEFAULTS', color: FapColors.okGreen);
    _changed();
  }

  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_prefsKey);
      if (raw == null) return;
      _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      audio.setPaGain(_paGain);
      audio.setMusicLevel(_musicLevel);
      notifyListeners();
    } catch (e) {
      debugPrint('FapProvider: could not restore state: $e');
    }
  }

  Future<void> _save() async {
    if (_disposed) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_prefsKey, jsonEncode(_toJson()));
    } catch (e) {
      debugPrint('FapProvider: could not save state: $e');
    }
  }

  Map<String, dynamic> _toJson() => {
    'lights': {for (final e in _lights.entries) e.key.name: e.value.name},
    'window': _windowLights,
    'reading': _readingAll,
    'att': _attWorkLights,
    'lavMaint': _lavMaint,
    'emer': _emerLights,
    'doors': {for (final e in _doors.entries) e.key.name: e.value.toJson()},
    'paGain': _paGain,
    'musicLevel': _musicLevel,
    'cockpitTemp': {for (final e in _cockpitTemp.entries) e.key.name: e.value},
    'fapTrim': {for (final e in _fapTrim.entries) e.key.name: e.value},
    'actualTemp': {for (final e in _actualTemp.entries) e.key.name: e.value},
    'water': _waterPct,
    'waste': _wastePct,
    'preselect': _waterPreselect,
    'paxSys': _paxSys,
    'pedPower': _pedPower,
    'chimeInhibit': _chimeInhibit,
  };

  void _fromJson(Map<String, dynamic> j) {
    T? byName<T extends Enum>(List<T> values, Object? name) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    final lights = j['lights'] as Map<String, dynamic>? ?? {};
    for (final e in lights.entries) {
      final z = byName(LightZone.values, e.key);
      final l = byName(LightLevel.values, e.value);
      if (z != null && l != null) _lights[z] = l;
    }
    _windowLights = j['window'] as bool? ?? _windowLights;
    _readingAll = j['reading'] as bool? ?? _readingAll;
    _attWorkLights = j['att'] as bool? ?? _attWorkLights;
    _lavMaint = j['lavMaint'] as bool? ?? _lavMaint;
    _emerLights = j['emer'] as bool? ?? _emerLights;

    final doors = j['doors'] as Map<String, dynamic>? ?? {};
    for (final e in doors.entries) {
      final id = byName(DoorId.values, e.key);
      if (id == null) continue;
      var s = DoorStatus.fromJson(e.value as Map<String, dynamic>);
      if (id.isOverwing) s = s.copyWith(armed: true);
      _doors[id] = s;
    }

    _paGain = (j['paGain'] as num?)?.toDouble() ?? _paGain;
    _musicLevel = (j['musicLevel'] as num?)?.toDouble() ?? _musicLevel;

    void temps(String key, Map<TempZone, double> into, double lo, double hi) {
      final m = j[key] as Map<String, dynamic>? ?? {};
      for (final e in m.entries) {
        final z = byName(TempZone.values, e.key);
        if (z != null && e.value is num) {
          into[z] = (e.value as num).toDouble().clamp(lo, hi);
        }
      }
    }

    const minT = FapConstants.minTemp, maxT = FapConstants.maxTemp;
    const trim = FapConstants.fapTempTrim;
    temps('cockpitTemp', _cockpitTemp, minT, maxT);
    temps('fapTrim', _fapTrim, -trim, trim);
    temps('actualTemp', _actualTemp, minT, maxT);
    _waterPct = ((j['water'] as num?)?.toDouble() ?? _waterPct)
        .clamp(0, 100)
        .toDouble();
    _wastePct = ((j['waste'] as num?)?.toDouble() ?? _wastePct)
        .clamp(0, 100)
        .toDouble();
    final pre = j['preselect'] as int?;
    if (pre != null && FapConstants.waterPreselect.contains(pre)) {
      _waterPreselect = pre;
    }
    _paxSys = j['paxSys'] as bool? ?? _paxSys;
    _pedPower = j['pedPower'] as bool? ?? _pedPower;
    _chimeInhibit = j['chimeInhibit'] as bool? ?? _chimeInhibit;
  }

  @override
  void dispose() {
    _disposed = true;
    _tick.cancel();
    _saveTimer?.cancel();
    _noticeTimer?.cancel();
    _lockTimer?.cancel();
    _restartTimer?.cancel();
    audio.dispose();
    super.dispose();
  }
}
