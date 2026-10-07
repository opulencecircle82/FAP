import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/cabin_setup.dart';

/// Airbus cabin chime types.
///
/// * single high chime – passenger call
/// * high-low chime    – crew / interphone call
/// * single low chime  – passenger signs (seat belt / no smoking)
/// * emergency call     – high-low chime three times (cockpit emergency call)
enum ChimeType { singleHigh, highLow, singleLow, emergency }

/// Offline sound engine. Chimes, alarms and music are synthesised into
/// in-memory WAVs; PRAM announcements are recorded MP3s bundled in
/// assets/pram/ (same female voice on every device).
class FapAudio {
  FapAudio() {
    _init();
  }

  static const _highHz = 800.0;

  /// Boarding music keeps playing under a PA announcement at this share of
  /// its level, then returns to full level when the announcement ends.
  static const _duckFactor = 0.3;
  static const _lowHz = 600.0;

  final _chimePlayer = AudioPlayer(playerId: 'fap_chime');
  final _alarmPlayer = AudioPlayer(playerId: 'fap_alarm');
  final _musicPlayer = AudioPlayer(playerId: 'fap_music');
  final _voicePlayer = AudioPlayer(playerId: 'fap_pram');
  final _clickPlayer = AudioPlayer(playerId: 'fap_click');
  StreamSubscription<void>? _voiceDone;

  final _cache = <String, Uint8List>{};

  double _paGain = 0.8;
  double _musicLevel = 0.6;
  bool _ducked = false;
  bool _speaking = false;
  int _announcementToken = 0;
  String? _alarm;

  /// Called when a PRAM announcement finishes or is stopped.
  VoidCallback? onAnnouncementDone;

  Future<void> _init() async {
    if (!kIsWeb) {
      // Every player must mix with the others. On Android a player that asks
      // for audio focus makes the other players lose it, which PAUSES them
      // (boarding music stopped as soon as a PA announcement started). The
      // context has to be set on each player: a player copies the global
      // default when it is created, which is before this runs.
      final ctx = AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build();
      try {
        await AudioPlayer.global.setAudioContext(ctx);
        for (final p in [
          _chimePlayer,
          _alarmPlayer,
          _musicPlayer,
          _voicePlayer,
          _clickPlayer,
        ]) {
          await p.setAudioContext(ctx);
        }
      } catch (e) {
        debugPrint('FapAudio: audio context not set: $e');
      }
    }
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
    _voiceDone = _voicePlayer.onPlayerComplete.listen(
      (_) => _announcementFinished(),
    );
  }

  // ---------------------------------------------------------------- volume

  double _master = 1.0; // FAP set-up loudspeaker level x mute
  double _announceTrim = 1.0; // level adjustment (cabin zones)
  double _chimeTrim = 1.0;
  BgmChannel? _musicChannel;

  double get _voiceVol => (_paGain * _master * _announceTrim).clamp(0.0, 1.0);
  double get _chimeVol => (_paGain * _master * _chimeTrim).clamp(0.0, 1.0);
  double get _musicVol =>
      (_musicLevel * _master * (_ducked ? _duckFactor : 1.0)).clamp(0.0, 1.0);

  void setPaGain(double v) {
    _paGain = v.clamp(0.0, 1.0);
    _applyVolumes();
  }

  void setMusicLevel(double v) {
    _musicLevel = v.clamp(0.0, 1.0);
    _applyMusicVolume();
  }

  /// Loudspeaker level (FAP SET-UP), mute (FAP CONFIG) and the announce /
  /// chime level trims in dB (LEVEL ADJUSTMENT).
  void setOutput({
    required double loudspeaker,
    required bool muted,
    required double announceDb,
    required double chimeDb,
  }) {
    _master = muted ? 0.0 : loudspeaker.clamp(0.0, 1.0);
    _announceTrim = math.pow(10, announceDb / 20).toDouble();
    _chimeTrim = math.pow(10, chimeDb / 20).toDouble();
    _applyVolumes();
  }

  void _applyVolumes() {
    _voicePlayer.setVolume(_voiceVol);
    _chimePlayer.setVolume(_chimeVol);
    _alarmPlayer.setVolume(_master);
    _applyMusicVolume();
  }

  void _applyMusicVolume() {
    // A PA announcement lowers (never stops) the boarding music.
    _musicPlayer.setVolume(_musicVol);
  }

  /// Short touchscreen click (FAP SET-UP > TOUCHSCREEN CLICK).
  Future<void> click() async {
    final bytes = _sound('click', () {
      return _render(0.05, (b) {
        for (var i = 0; i < b.length; i++) {
          final t = i / _sampleRate;
          b[i] = math.sin(2 * math.pi * 2400 * t) * math.exp(-t / 0.006);
        }
      });
    });
    await _clickPlayer.stop();
    await _clickPlayer.play(
      BytesSource(bytes, mimeType: 'audio/wav'),
      volume: (_master * 0.6).clamp(0.0, 1.0),
    );
  }

  // ---------------------------------------------------------------- chimes

  Future<void> chime(ChimeType type) async {
    final bytes = _sound('chime_${type.name}', () {
      switch (type) {
        case ChimeType.singleHigh:
          return _render(1.6, (b) => _bell(b, 0, _highHz));
        case ChimeType.highLow:
          return _render(2.2, (b) {
            _bell(b, 0, _highHz);
            _bell(b, 0.55, _lowHz);
          });
        case ChimeType.singleLow:
          return _render(1.6, (b) => _bell(b, 0, _lowHz));
        case ChimeType.emergency:
          return _render(4.6, (b) {
            for (var i = 0; i < 3; i++) {
              _bell(b, i * 1.35, _highHz);
              _bell(b, i * 1.35 + 0.55, _lowHz);
            }
          });
      }
    });
    await _chimePlayer.stop();
    await _chimePlayer.play(
      BytesSource(bytes, mimeType: 'audio/wav'),
      volume: _chimeVol,
    );
  }

  // ---------------------------------------------------------------- alarms

  /// Repetitive EVAC tone through the cabin loudspeakers.
  Future<void> startEvacTone() => _startAlarm('evac', () {
    return _render(1.0, (b) {
      const f = 440.0;
      final n = (0.55 * _sampleRate).round();
      for (var i = 0; i < n; i++) {
        final t = i / _sampleRate;
        final env = math.min(1.0, i / 300) * math.min(1.0, (n - i) / 300);
        // Odd harmonics give the harsh "horn" timbre.
        final s =
            math.sin(2 * math.pi * f * t) +
            math.sin(2 * math.pi * 3 * f * t) / 3 +
            math.sin(2 * math.pi * 5 * f * t) / 5;
        b[i] += 0.55 * env * s;
      }
    });
  });

  /// Lavatory smoke: triple high chime, repeated until SMOKE RESET.
  Future<void> startSmokeAlarm() => _startAlarm('smoke', () {
    return _render(4.0, (b) {
      _bell(b, 0.0, _highHz);
      _bell(b, 0.45, _highHz);
      _bell(b, 0.9, _highHz);
    });
  });

  Future<void> _startAlarm(String id, Float64List Function() build) async {
    if (_alarm == id) return;
    _alarm = id;
    final bytes = _sound('alarm_$id', build);
    await _alarmPlayer.stop();
    await _alarmPlayer.play(
      BytesSource(bytes, mimeType: 'audio/wav'),
      volume: _master,
    );
  }

  Future<void> stopAlarm([String? id]) async {
    if (id != null && _alarm != id) return;
    _alarm = null;
    await _alarmPlayer.stop();
  }

  // ---------------------------------------------------------------- PRAM

  /// Plays boarding music channel [channel] in a loop (switching channel
  /// while playing changes the music straight away).
  Future<void> startMusic([BgmChannel channel = BgmChannel.classic]) async {
    final bytes = _sound('music_${channel.name}', () => _renderBgm(channel));
    _musicChannel = channel;
    await _musicPlayer.stop();
    await _musicPlayer.play(
      BytesSource(bytes, mimeType: 'audio/wav'),
      volume: _musicVol,
    );
  }

  Future<void> stopMusic() async {
    _musicChannel = null;
    await _musicPlayer.stop();
  }

  BgmChannel? get musicChannel => _musicChannel;

  /// Plays the PA chime, then the recorded announcement
  /// `assets/pram/<pramId>.mp3`. Returns false if it cannot be played.
  Future<bool> announce(String pramId) async {
    final token = ++_announcementToken;
    if (_speaking) {
      _speaking = false;
      await _voicePlayer.stop();
    }
    _ducked = true;
    _applyMusicVolume();
    await chime(ChimeType.singleHigh);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (token != _announcementToken) return true;
    _speaking = true;
    try {
      await _voicePlayer.play(
        AssetSource('pram/$pramId.mp3'),
        volume: _voiceVol,
      );
      return true;
    } catch (e) {
      debugPrint('FapAudio: cannot play announcement $pramId: $e');
      _speaking = false;
      _endAnnouncement();
      return false;
    }
  }

  Future<void> stopAnnouncement() async {
    _announcementToken++;
    final wasActive = _ducked;
    _speaking = false;
    await _voicePlayer.stop();
    if (wasActive) _endAnnouncement();
  }

  /// The announcement played to the end.
  void _announcementFinished() {
    if (!_speaking) return;
    _speaking = false;
    _endAnnouncement();
  }

  void _endAnnouncement() {
    _ducked = false;
    _applyMusicVolume();
    onAnnouncementDone?.call();
  }

  Future<void> stopAll() async {
    await stopAnnouncement();
    await stopMusic();
    await stopAlarm();
  }

  void dispose() {
    _voiceDone?.cancel();
    _voicePlayer.dispose();
    _clickPlayer.dispose();
    _chimePlayer.dispose();
    _alarmPlayer.dispose();
    _musicPlayer.dispose();
  }

  // ---------------------------------------------------------------- synth

  static const _sampleRate = 22050;

  Uint8List _sound(String key, Float64List Function() build) =>
      _cache.putIfAbsent(key, () => _toWav(build()));

  Float64List _render(double seconds, void Function(Float64List) fill) {
    final buf = Float64List((seconds * _sampleRate).round());
    fill(buf);
    return buf;
  }

  /// Vibraphone-like chime tone with exponential decay.
  /// With [wrap], the tail that runs past the end of the buffer is written
  /// to its start so a looping buffer has no click at the seam.
  void _bell(
    Float64List b,
    double start,
    double f, {
    double amp = 0.5,
    double decay = 0.55,
    bool wrap = false,
  }) {
    final s0 = (start * _sampleRate).round();
    final tail = (decay * 4.5 * _sampleRate).round();
    final n = wrap ? math.min(b.length, tail) : math.min(b.length - s0, tail);
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final attack = math.min(1.0, i / 110);
      final env = attack * math.exp(-t / decay);
      final s =
          math.sin(2 * math.pi * f * t) +
          0.28 * math.sin(2 * math.pi * 2 * f * t) * math.exp(-t / 0.15) +
          0.08 * math.sin(2 * math.pi * 3 * f * t) * math.exp(-t / 0.08);
      b[(s0 + i) % b.length] += amp * env * s;
    }
  }

  // Boarding music channels: four short seamless loops, each its own style.
  Float64List _renderBgm(BgmChannel channel) => switch (channel) {
    BgmChannel.classic => _renderClassic(),
    BgmChannel.blues => _renderBlues(),
    BgmChannel.country => _renderCountry(),
    BgmChannel.jazz => _renderJazz(),
  };

  /// Soft sustained chord.
  void _pad(
    Float64List b,
    double start,
    double len,
    List<double> freqs, {
    double amp = 0.08,
  }) {
    final s0 = (start * _sampleRate).round();
    final n = (len * _sampleRate).round();
    for (final f in freqs) {
      for (var i = 0; i < n && s0 + i < b.length; i++) {
        final t = i / _sampleRate;
        final env = math.min(1.0, t / 0.4) * math.min(1.0, (len - t) / 0.4);
        b[s0 + i] +=
            amp *
            env *
            (math.sin(2 * math.pi * f * t) +
                0.3 * math.sin(2 * math.pi * 2 * f * t));
      }
    }
  }

  /// Plucked bass note.
  void _bass(Float64List b, double start, double f, {double amp = 0.22}) {
    final s0 = (start * _sampleRate).round();
    final n = (0.5 * _sampleRate).round();
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final env = math.min(1.0, i / 60) * math.exp(-t / 0.18);
      b[(s0 + i) % b.length] +=
          amp *
          env *
          (math.sin(2 * math.pi * f * t) +
              0.4 * math.sin(2 * math.pi * 2 * f * t));
    }
  }

  Float64List _loop(
    int chords,
    double chordSec,
    void Function(Float64List b, int c, double t0) fill,
  ) {
    final b = _render(chordSec * chords, (_) {});
    for (var c = 0; c < chords; c++) {
      fill(b, c, c * chordSec);
    }
    return b;
  }

  /// CLASSIC: C – Am – F – G pads with a gentle arpeggio, 80 BPM.
  Float64List _renderClassic() {
    const chords = [
      [261.63, 329.63, 392.00],
      [220.00, 261.63, 329.63],
      [174.61, 220.00, 261.63],
      [196.00, 246.94, 293.66],
    ];
    return _loop(4, 3.0, (b, c, t0) {
      _pad(b, t0, 3.0, chords[c], amp: 0.09);
      final notes = [...chords[c], chords[c][1]];
      for (var k = 0; k < 8; k++) {
        _bell(
          b,
          t0 + k * 0.375,
          notes[k % 4] * 2,
          amp: 0.09,
          decay: 0.35,
          wrap: true,
        );
      }
    });
  }

  /// BLUES: E7 – A7 – E7 – B7 shuffle, 100 BPM.
  Float64List _renderBlues() {
    const chords = [
      [164.81, 207.65, 246.94, 293.66],
      [220.00, 277.18, 329.63, 392.00],
      [164.81, 207.65, 246.94, 293.66],
      [246.94, 311.13, 369.99, 440.00],
    ];
    const roots = [82.41, 110.00, 82.41, 123.47];
    const beat = 0.6;
    return _loop(4, beat * 4, (b, c, t0) {
      _pad(b, t0, beat * 4, chords[c], amp: 0.035);
      for (var k = 0; k < 4; k++) {
        // walking shuffle bass: root, third, fifth, sixth
        final f = roots[c] * const [1.0, 1.26, 1.5, 1.68][k];
        _bass(b, t0 + k * beat, f);
        // swung off-beat chord stab
        for (final n in chords[c].take(3)) {
          _bell(
            b,
            t0 + k * beat + beat * 2 / 3,
            n,
            amp: 0.05,
            decay: 0.18,
            wrap: true,
          );
        }
      }
    });
  }

  /// COUNTRY: G – C – D – G "boom-chick", 110 BPM.
  Float64List _renderCountry() {
    const chords = [
      [196.00, 246.94, 293.66],
      [261.63, 329.63, 392.00],
      [293.66, 369.99, 440.00],
      [196.00, 246.94, 293.66],
    ];
    const roots = [98.00, 130.81, 146.83, 98.00];
    const beat = 0.545;
    return _loop(4, beat * 4, (b, c, t0) {
      for (var k = 0; k < 4; k++) {
        if (k.isEven) {
          _bass(b, t0 + k * beat, k == 0 ? roots[c] : roots[c] * 1.5);
        } else {
          for (final n in chords[c]) {
            _bell(b, t0 + k * beat, n, amp: 0.06, decay: 0.2, wrap: true);
          }
        }
        // light melody on the upbeat
        _bell(
          b,
          t0 + k * beat + beat / 2,
          chords[c][k % 3] * 2,
          amp: 0.05,
          decay: 0.25,
          wrap: true,
        );
      }
    });
  }

  /// JAZZ: Dm7 – G7 – Cmaj7 – A7 with vibraphone, 90 BPM.
  Float64List _renderJazz() {
    const chords = [
      [146.83, 174.61, 220.00, 261.63],
      [196.00, 246.94, 293.66, 349.23],
      [130.81, 164.81, 196.00, 246.94],
      [220.00, 277.18, 329.63, 392.00],
    ];
    const roots = [73.42, 98.00, 65.41, 110.00];
    const beat = 0.667;
    return _loop(4, beat * 4, (b, c, t0) {
      _pad(b, t0, beat * 4, chords[c], amp: 0.05);
      _bass(b, t0, roots[c], amp: 0.18);
      _bass(b, t0 + beat * 2, roots[c] * 1.5, amp: 0.15);
      for (final (i, at) in const [0.0, 1.5, 2.5, 3.0].indexed) {
        _bell(
          b,
          t0 + at * beat,
          chords[c][(i + c) % 4] * 2,
          amp: 0.08,
          decay: 0.5,
          wrap: true,
        );
      }
    });
  }

  Uint8List _toWav(Float64List samples) {
    var peak = 0.0;
    for (final s in samples) {
      peak = math.max(peak, s.abs());
    }
    final gain = peak > 0 ? 0.85 / peak : 1.0;
    final dataLen = samples.length * 2;
    final bytes = ByteData(44 + dataLen);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, _sampleRate, Endian.little);
    bytes.setUint32(28, _sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    str(36, 'data');
    bytes.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i] * gain * 32767).round().clamp(-32768, 32767);
      bytes.setInt16(44 + i * 2, v, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
