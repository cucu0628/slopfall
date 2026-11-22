import 'package:flutter_test/flutter_test.dart';
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
}
