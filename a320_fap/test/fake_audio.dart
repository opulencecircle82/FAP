import 'package:aisat_fap/models/cabin_setup.dart';
import 'package:aisat_fap/services/fap_audio.dart';
import 'package:flutter/foundation.dart';

/// Records audio calls instead of touching platform plugins.
class FakeAudio implements FapAudio {
  final calls = <String>[];
  String? alarm;
  bool music = false;
  bool ttsAvailable = true;

  @override
  VoidCallback? onAnnouncementDone;

  @override
  Future<void> chime(ChimeType type) async => calls.add('chime:${type.name}');

  @override
  Future<void> startEvacTone() async {
    alarm = 'evac';
    calls.add('evac');
  }

  @override
  Future<void> startSmokeAlarm() async {
    alarm = 'smoke';
    calls.add('smoke');
  }

  @override
  Future<void> stopAlarm([String? id]) async {
    alarm = null;
    calls.add('stopAlarm');
  }

  @override
  Future<void> startMusic([BgmChannel channel = BgmChannel.classic]) async {
    music = true;
    musicChannel = channel;
    calls.add('music:${channel.name}');
  }

  @override
  BgmChannel? musicChannel;

  @override
  Future<void> click() async => calls.add('click');

  double? master;
  double? announceDb;

  @override
  void setOutput({
    required double loudspeaker,
    required bool muted,
    required double announceDb,
    required double chimeDb,
  }) {
    master = muted ? 0 : loudspeaker;
    this.announceDb = announceDb;
  }

  @override
  Future<void> stopMusic() async => music = false;

  @override
  Future<bool> announce(String pramId) async {
    calls.add('announce:$pramId');
    return ttsAvailable;
  }

  @override
  Future<void> stopAnnouncement() async {
    calls.add('stopAnnouncement');
    onAnnouncementDone?.call();
  }

  @override
  Future<void> stopAll() async {
    await stopAnnouncement();
    await stopMusic();
    await stopAlarm();
  }

  @override
  void setPaGain(double v) {}

  @override
  void setMusicLevel(double v) {}

  @override
  void dispose() {}
}
