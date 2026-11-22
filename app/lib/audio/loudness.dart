// Perceived loudness of a rendered sound: K-weighting (ITU-R BS.1770: a
// high shelf around 1.5 kHz and a low cut), then the loudest 50 ms window.
// Used to even out the sound effects, whose raw recipes differ a lot: a soft
// sine beep and a burst of filtered noise at the same gain sound very
// different.

import 'dart:math' as math;
import 'dart:typed_data';

import 'synth.dart';

class _Iir {
  final double b0, b1, b2, a1, a2;
  double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  _Iir(this.b0, this.b1, this.b2, this.a1, this.a2);

  double process(double x) {
    final y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    return y;
  }
}

/// High shelf (+4 dB above ~1.7 kHz), the first stage of K-weighting.
_Iir _shelf() {
  const f0 = 1681.974450955533, g = 3.999843853973347, q = 0.7071752369554196;
  final k = math.tan(math.pi * f0 / sampleRate);
  final vh = math.pow(10, g / 20).toDouble();
  final vb = math.pow(vh, 0.4996667741545416).toDouble();
  final a0 = 1 + k / q + k * k;
  return _Iir((vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0, 2 * (k * k - 1) / a0,
      (1 - k / q + k * k) / a0);
}

/// Low cut (~38 Hz), the second stage of K-weighting.
_Iir _lowCut() {
  const f0 = 38.13547087602444, q = 0.5003270373238773;
  final k = math.tan(math.pi * f0 / sampleRate);
  final a0 = 1 + k / q + k * k;
  return _Iir(1, -2, 1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0);
}

/// Loudest 50 ms of the K-weighted signal, as RMS (linear).
double loudness(Float32List s) {
  final shelf = _shelf(), cut = _lowCut();
  final w = Float64List(s.length);
  for (var i = 0; i < s.length; i++) {
    w[i] = cut.process(shelf.process(s[i]));
  }
  const win = sampleRate ~/ 20;
  var best = 0.0, acc = 0.0;
  for (var i = 0; i < w.length; i++) {
    acc += w[i] * w[i];
    if (i >= win) acc -= w[i - win] * w[i - win];
    final n = math.min(i + 1, win);
    best = math.max(best, acc / n);
  }
  return math.sqrt(best);
}
