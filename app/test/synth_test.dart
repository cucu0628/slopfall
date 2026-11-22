import 'package:flutter_test/flutter_test.dart';
import 'dart:math' as math;

import 'package:nightfall/audio/loudness.dart';
import 'package:nightfall/audio/synth.dart';

void main() {
  test('every sound renders to a sane, non-silent buffer', () {
    for (final e in soundRecipes().entries) {
      final s = e.value.render();
      var peak = 0.0;
      for (final v in s) {
        expect(v.isFinite, isTrue, reason: e.key);
        if (v.abs() > peak) peak = v.abs();
      }
      expect(peak, greaterThan(0.005), reason: e.key);
      expect(peak, lessThan(1.0), reason: e.key);
      expect(wav(s).length, 44 + s.length * 2);
    }
  });

  test('sounds are leveled to their target loudness', () {
    for (final e in soundRecipes().entries) {
      final target = soundLevels[e.key];
      expect(target, isNotNull, reason: '${e.key} needs a level');
      final s = renderLeveled(e.value, target!, loudness);
      final db = 20 * math.log(loudness(s)) / math.ln10;
      var peak = 0.0;
      for (final v in s) {
        peak = math.max(peak, v.abs());
      }
      expect(peak, lessThanOrEqualTo(0.9), reason: e.key);
      // only a sound whose peaks would clip may stay below its target
      if (peak < 0.88) expect(db, closeTo(target, 0.1), reason: e.key);
    }
  });
}
