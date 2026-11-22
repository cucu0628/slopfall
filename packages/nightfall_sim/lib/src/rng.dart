// Seeded mulberry32 RNG. The generator state lives in GameState.rng so the
// simulation stays deterministic and serializable. The state is kept as a
// signed 32-bit value, exactly like the TypeScript version stored it.

import 'js.dart';

abstract interface class RngHolder {
  int get rng;
  set rng(int v);
}

/// One mulberry32 step: hands the next signed 32-bit state to [store] and
/// returns a value in [0, 1).
double mulberryNext(int state, void Function(int next) store) {
  final next = i32(state + 0x6d2b79f5);
  store(next);
  var t = u32(next);
  t = imul(t ^ ushr(t, 15), t | 1);
  t = u32(t ^ (t + imul(t ^ ushr(t, 7), t | 61)));
  return u32(t ^ ushr(t, 14)) / 4294967296;
}

double rand(RngHolder s) => mulberryNext(s.rng, (v) => s.rng = v);

double randRange(RngHolder s, double a, double b) => a + rand(s) * (b - a);

int randInt(RngHolder s, int a, int b) => randRange(s, a.toDouble(), b + 1.0).floor();

T pick<T>(RngHolder s, List<T> arr) => arr[(rand(s) * arr.length).floor()];

T weightedPick<T>(RngHolder s, List<T> items, double Function(T item) weight) {
  var total = 0.0;
  for (final it in items) {
    total += weight(it);
  }
  var r = rand(s) * total;
  for (final it in items) {
    r -= weight(it);
    if (r <= 0) return it;
  }
  return items[items.length - 1];
}
