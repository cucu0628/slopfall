// Plays the procedural sound effects (rendered by synth.dart) with SoLoud.
// Audio starts on the first user interaction (browsers require a gesture).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../game/session.dart';
import 'loudness.dart';
import 'synth.dart';

const Map<String, double> _minGap = {
  'coin': 0.06, 'hit': 0.035, 'kill': 0.04, 'gem': 0.03, 'swing': 0.06, //
  'bolt': 0.06, 'arrow': 0.05, 'zap': 0.08, 'frost': 0.1, 'hurt': 0.15,
};

/// Engine volume at 100 % (the original WebAudio master gain).
const double _masterVolume = 0.22;

class Sound implements SoundSink {
  final Map<String, AudioSource> _sources = {};
  final Map<String, double> _last = {};
  final Stopwatch _clock = Stopwatch()..start();
  final math.Random _rnd = math.Random();
  Future<void>? _starting;
  bool _ready = false;
  int _gemPitch = 0;
  double _gemChain = -1;
  bool muted = false;

  /// Player volume, 0..1 (on top of the master gain).
  double volume = 1;

  /// False in tests: no audio device is touched.
  final bool enabled;

  Sound({this.enabled = true});

  double get _now => _clock.elapsedMicroseconds / 1e6;

  /// Starts the audio engine and renders the sounds (once).
  Future<void> unlock() => _starting ??= (enabled ? _start() : Future.value());

  Future<void> _start() async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) await soloud.init(bufferSize: 1024);
      soloud.setMaxActiveVoiceCount(32);
      _applyVolume();
      for (final e in soundRecipes().entries) {
        final pcm = renderLeveled(e.value, soundLevels[e.key] ?? -19, loudness);
        _sources[e.key] = await soloud.loadMem('${e.key}.wav', wav(pcm));
      }
      _ready = true;
    } catch (e) {
      // no audio device (or blocked): the game simply stays silent
      debugPrint('audio unavailable: $e');
    }
  }

  void _applyVolume() {
    final soloud = SoLoud.instance;
    if (soloud.isInitialized) soloud.setGlobalVolume(muted ? 0 : _masterVolume * volume * volume); // squared: feels linear
  }

  void toggleMute() {
    muted = !muted;
    _applyVolume();
  }

  void setVolume(double v) {
    volume = v.clamp(0.0, 1.0);
    if (volume > 0) muted = false;
    _applyVolume();
  }

  @override
  void play(String name) {
    if (!_ready || muted) return;
    final now = _now;
    if (now - (_last[name] ?? -1) < (_minGap[name] ?? 0.02)) return;
    _last[name] = now;
    final src = _sources[name];
    if (src == null) return;
    var speed = 1.0;
    if (name == 'kill') {
      speed = (260 + _rnd.nextDouble() * 80) / 300;
    } else if (name == 'gem') {
      _gemPitch = now - _gemChain < 0.3 ? math.min(_gemPitch + 1, 12) : 0;
      _gemChain = now;
      speed = math.pow(2, _gemPitch / 24).toDouble();
    }
    try {
      final h = SoLoud.instance.play(src);
      if (speed != 1) SoLoud.instance.setRelativePlaySpeed(h, speed);
    } catch (_) {
      // a full voice pool just drops the sound
    }
  }
}
