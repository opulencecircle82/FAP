import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Airbus cabin chime types.
///
/// * single high chime – passenger call
/// * high-low chime    – crew / interphone call
/// * single low chime  – passenger signs (seat belt / no smoking)
enum ChimeType { singleHigh, highLow, singleLow }

/// Offline sound engine. Every sound is synthesised into an in-memory WAV,
/// so the app ships without audio files and works with no network.
class FapAudio {
  FapAudio() {
    _init();
  }

  static const _highHz = 800.0;
  static const _lowHz = 600.0;

  final _chimePlayer = AudioPlayer(playerId: 'fap_chime');
  final _alarmPlayer = AudioPlayer(playerId: 'fap_alarm');
  final _musicPlayer = AudioPlayer(playerId: 'fap_music');
  final _tts = FlutterTts();

  final _cache = <String, Uint8List>{};

  double _paGain = 0.8;
  double _musicLevel = 0.6;
  bool _ducked = false;
  bool _ttsReady = false;
  bool _speaking = false;
  int _announcementToken = 0;
  String? _alarm;

  /// Called when a spoken PRAM announcement finishes or is stopped.
  VoidCallback? onAnnouncementDone;

  Future<void> _init() async {
    if (!kIsWeb) {
      try {
        await AudioPlayer.global.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build(),
        );
      } catch (e) {
        debugPrint('FapAudio: audio context not set: $e');
      }
    }
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(kIsWeb ? 0.95 : 0.47);
      await _tts.setPitch(1.0);
      await _tts.setVolume(_paGain);
      _tts.setCompletionHandler(_announcementFinished);
      _tts.setCancelHandler(_announcementFinished);
      _tts.setErrorHandler((_) => _announcementFinished());
      _ttsReady = true;
    } catch (e) {
      debugPrint('FapAudio: TTS unavailable: $e');
    }
  }

  // ---------------------------------------------------------------- volume

  void setPaGain(double v) {
    _paGain = v.clamp(0.0, 1.0);
    if (_ttsReady) _tts.setVolume(_paGain);
    _chimePlayer.setVolume(_paGain);
  }

  void setMusicLevel(double v) {
    _musicLevel = v.clamp(0.0, 1.0);
    _applyMusicVolume();
  }

  void _applyMusicVolume() {
    // A PA announcement always overrides boarding music (ducked to 15 %).
    _musicPlayer.setVolume(_ducked ? _musicLevel * 0.15 : _musicLevel);
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
      }
    });
    await _chimePlayer.stop();
    await _chimePlayer.play(
      BytesSource(bytes, mimeType: 'audio/wav'),
      volume: _paGain,
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
      volume: 1.0,
    );
  }

  Future<void> stopAlarm([String? id]) async {
    if (id != null && _alarm != id) return;
    _alarm = null;
    await _alarmPlayer.stop();
  }

  // ---------------------------------------------------------------- PRAM

  Future<void> startMusic() async {
    final bytes = _sound('music', _renderBoardingMusic);
    _applyMusicVolume();
    await _musicPlayer.play(
      BytesSource(bytes, mimeType: 'audio/wav'),
      volume: _ducked ? _musicLevel * 0.15 : _musicLevel,
    );
  }

  Future<void> stopMusic() => _musicPlayer.stop();

  /// Plays the PA chime then speaks [script]. Returns false when the
  /// speech engine is unavailable on this device.
  Future<bool> announce(String script) async {
    if (!_ttsReady) return false;
    final token = ++_announcementToken;
    if (_speaking) {
      _speaking = false;
      await _tts.stop();
    }
    _ducked = true;
    _applyMusicVolume();
    await chime(ChimeType.singleHigh);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (token != _announcementToken) return true;
    _speaking = true;
    await _tts.speak(script);
    return true;
  }

  Future<void> stopAnnouncement() async {
    _announcementToken++;
    final wasActive = _ducked;
    _speaking = false;
    if (_ttsReady) await _tts.stop();
    if (wasActive) _endAnnouncement();
  }

  /// TTS completion / cancel / error callback.
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
    _tts.stop();
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

  /// 12 second seamless loop: C – Am – F – G pads with a soft arpeggio.
  Float64List _renderBoardingMusic() {
    const chordSec = 3.0;
    const chords = [
      [261.63, 329.63, 392.00], // C
      [220.00, 261.63, 329.63], // Am
      [174.61, 220.00, 261.63], // F
      [196.00, 246.94, 293.66], // G
    ];
    final b = _render(chordSec * chords.length, (_) {});
    final chordLen = (chordSec * _sampleRate).round();
    for (var c = 0; c < chords.length; c++) {
      final s0 = c * chordLen;
      for (final f in chords[c]) {
        for (var i = 0; i < chordLen; i++) {
          final t = i / _sampleRate;
          final env =
              math.min(1.0, t / 0.6) * math.min(1.0, (chordSec - t) / 0.6);
          b[s0 + i] +=
              0.09 *
              env *
              (math.sin(2 * math.pi * f * t) +
                  0.3 * math.sin(2 * math.pi * 2 * f * t));
        }
      }
      // Arpeggio one octave up, eighth notes at 80 BPM.
      final notes = [...chords[c], chords[c][1]];
      for (var k = 0; k < 8; k++) {
        _bell(
          b,
          c * chordSec + k * 0.375,
          notes[k % 4] * 2,
          amp: 0.09,
          decay: 0.35,
          wrap: true,
        );
      }
    }
    return b;
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
