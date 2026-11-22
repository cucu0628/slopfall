// Offline renderer for the game's procedural sound effects. The original game
// built them live with WebAudio oscillators, gain ramps and biquad-filtered
// noise; here the same recipes are rendered once into PCM buffers (WAV) that
// the audio engine plays back.

import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 44100;

enum Wave { sine, square, sawtooth, triangle }

enum Filter { lowpass, highpass, bandpass }

/// One sound: a mix of tones and noise bursts rendered into a mono buffer.
class SoundRecipe {
  final List<void Function(Float32List out)> _parts = [];
  double _length = 0;

  /// Oscillator from [freq] (exponential slide to [slideTo] when non-zero),
  /// gain [vol] decaying exponentially to 0.001 over [dur]; starts after [delay].
  void tone(double freq, double dur, Wave type, double vol, [double slideTo = 0, double delay = 0]) {
    _length = math.max(_length, delay + dur + 0.02);
    _parts.add((out) {
      final start = (delay * sampleRate).round();
      final n = ((dur + 0.02) * sampleRate).round();
      var phase = 0.0;
      for (var i = 0; i < n && start + i < out.length; i++) {
        final t = i / sampleRate;
        final k = math.min(1.0, t / dur);
        final f = slideTo > 0 ? freq * math.pow(slideTo / freq, k) : freq;
        final dp = f / sampleRate;
        phase += dp;
        phase -= phase.floorToDouble();
        final g = vol * math.pow(0.001 / vol, k);
        out[start + i] += g * _osc(type, phase, dp);
      }
    });
  }

  /// White noise through a biquad filter at [freq] Hz with an exponential decay.
  void noise(double dur, double vol, double freq, [Filter type = Filter.lowpass, double delay = 0]) {
    _length = math.max(_length, delay + dur + 0.02);
    _parts.add((out) {
      final start = (delay * sampleRate).round();
      final n = ((dur + 0.02) * sampleRate).round();
      final bq = _Biquad(type, freq);
      final rnd = math.Random(freq.round() ^ (dur * 1000).round());
      for (var i = 0; i < n && start + i < out.length; i++) {
        final t = i / sampleRate;
        final k = math.min(1.0, t / dur);
        final g = vol * math.pow(0.001 / vol, k);
        out[start + i] += g * bq.process(rnd.nextDouble() * 2 - 1);
      }
    });
  }

  Float32List render() {
    final out = Float32List((_length * sampleRate).ceil() + 1);
    for (final p in _parts) {
      p(out);
    }
    return out;
  }
}

double _polyBlep(double t, double dt) {
  if (t < dt) {
    t /= dt;
    return t + t - t * t - 1;
  }
  if (t > 1 - dt) {
    t = (t - 1) / dt;
    return t * t + t + t + 1;
  }
  return 0;
}

/// Band-limited oscillators (PolyBLEP) so high square/saw tones don't alias.
double _osc(Wave type, double p, double dt) {
  switch (type) {
    case Wave.sine:
      return math.sin(p * 2 * math.pi);
    case Wave.sawtooth:
      return 2 * p - 1 - _polyBlep(p, dt);
    case Wave.square:
      var v = p < 0.5 ? 1.0 : -1.0;
      v += _polyBlep(p, dt);
      final q = p + 0.5 - (p + 0.5).floorToDouble();
      v -= _polyBlep(q, dt);
      return v;
    case Wave.triangle:
      return 1 - 4 * (p - 0.5).abs();
  }
}

/// Biquad matching the WebAudio BiquadFilterNode with its default Q (1).
class _Biquad {
  late final double b0, b1, b2, a1, a2;
  double x1 = 0, x2 = 0, y1 = 0, y2 = 0;

  _Biquad(Filter type, double freq) {
    final w0 = 2 * math.pi * math.min(freq, sampleRate / 2 - 1) / sampleRate;
    final cs = math.cos(w0), sn = math.sin(w0);
    // WebAudio reads Q in dB for low/highpass, linearly for bandpass
    final alpha = type == Filter.bandpass ? sn / 2 : sn / (2 * math.pow(10, 1 / 20));
    double nb0, nb1, nb2;
    switch (type) {
      case Filter.lowpass:
        nb0 = (1 - cs) / 2;
        nb1 = 1 - cs;
        nb2 = (1 - cs) / 2;
      case Filter.highpass:
        nb0 = (1 + cs) / 2;
        nb1 = -(1 + cs);
        nb2 = (1 + cs) / 2;
      case Filter.bandpass:
        nb0 = alpha;
        nb1 = 0;
        nb2 = -alpha;
    }
    final a0 = 1 + alpha;
    b0 = nb0 / a0;
    b1 = nb1 / a0;
    b2 = nb2 / a0;
    a1 = -2 * cs / a0;
    a2 = (1 - alpha) / a0;
  }

  double process(double x) {
    final y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    return y;
  }
}

/// 16-bit mono WAV file bytes.
Uint8List wav(Float32List samples) {
  final data = ByteData(44 + samples.length * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// The game's sound effects, same recipes as the original WebAudio version.
/// 'kill' is rendered at 300 Hz and 'gem' at 880 Hz; the player varies their
/// pitch with the playback speed.
Map<String, SoundRecipe> soundRecipes() {
  final m = <String, SoundRecipe>{};
  SoundRecipe r(String name) => m[name] = SoundRecipe();
  r('hit').noise(0.05, 0.15, 2500, Filter.bandpass);
  r('kill').tone(300, 0.08, Wave.triangle, 0.12, 90);
  r('gem').tone(880, 0.06, Wave.sine, 0.08);
  r('swing').noise(0.12, 0.18, 1800, Filter.highpass);
  r('bolt').tone(500, 0.12, Wave.sine, 0.1, 1100);
  r('arrow').tone(900, 0.05, Wave.square, 0.04, 500);
  r('zap')
    ..noise(0.15, 0.2, 4000, Filter.highpass)
    ..tone(1400, 0.1, Wave.sawtooth, 0.04, 300);
  r('nova')
    ..noise(0.4, 0.25, 600)
    ..tone(160, 0.35, Wave.sawtooth, 0.08, 60);
  r('frost').tone(1600, 0.2, Wave.triangle, 0.06, 2400);
  r('deploy')
    ..tone(400, 0.06, Wave.square, 0.06)
    ..tone(700, 0.08, Wave.square, 0.06, 0, 0.07);
  r('hurt')
    ..tone(140, 0.2, Wave.square, 0.18, 60)
    ..noise(0.1, 0.2, 800);
  r('death').tone(300, 1.2, Wave.sawtooth, 0.2, 40);
  final lv = r('levelup');
  const lvNotes = [523.0, 659.0, 784.0, 1047.0];
  for (var i = 0; i < lvNotes.length; i++) {
    lv.tone(lvNotes[i], 0.18, Wave.triangle, 0.12, 0, i * 0.07);
  }
  r('select').tone(660, 0.08, Wave.triangle, 0.1, 990);
  final chest = r('chest');
  const chestNotes = [392.0, 523.0, 659.0, 784.0, 1047.0, 1319.0];
  for (var i = 0; i < chestNotes.length; i++) {
    chest.tone(chestNotes[i], 0.25, Wave.triangle, 0.1, 0, i * 0.06);
  }
  r('pickup').tone(700, 0.12, Wave.triangle, 0.12, 1400);
  r('coin')
    ..tone(1568, 0.07, Wave.square, 0.04)
    ..tone(2093, 0.12, Wave.square, 0.04, 0, 0.06);
  r('explode')
    ..noise(0.5, 0.35, 400)
    ..tone(90, 0.4, Wave.sine, 0.25, 30);
  r('warn')
    ..tone(880, 0.12, Wave.square, 0.08)
    ..tone(660, 0.16, Wave.square, 0.08, 0, 0.14);
  r('dash')
    ..noise(0.18, 0.18, 2200, Filter.bandpass)
    ..tone(500, 0.15, Wave.sine, 0.05, 220);
  r('ability')
    ..noise(0.25, 0.2, 1200, Filter.bandpass)
    ..tone(300, 0.25, Wave.sine, 0.12, 900);
  r('wave')
    ..tone(440, 0.15, Wave.triangle, 0.1)
    ..tone(660, 0.25, Wave.triangle, 0.1, 0, 0.12);
  r('boss')
    ..tone(70, 1.4, Wave.sawtooth, 0.22, 50)
    ..tone(105, 1.4, Wave.sawtooth, 0.12, 70);
  final vic = r('victory');
  const vicNotes = [523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0];
  for (var i = 0; i < vicNotes.length; i++) {
    vic.tone(vicNotes[i], 0.22, Wave.square, 0.06, 0, i * 0.1);
  }
  return m;
}
