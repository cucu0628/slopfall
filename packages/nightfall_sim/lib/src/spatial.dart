// Uniform spatial hash over enemies. Derived data: rebuilt every tick and
// never part of GameState.

import 'types.dart';

const double _cell = 64;
const double _margin = 56; // largest enemy radius, so center-only insertion still finds big ones

final _cells = <int, List<int>>{};
List<List<int>> _pool = [];
int _poolIdx = 0;
List<Enemy> _enemiesRef = [];

int _key(int cx, int cy) => (cx + 32768) * 65536 + (cy + 32768);

void buildGrid(GameState s) {
  _cells.clear();
  _poolIdx = 0;
  _enemiesRef = s.enemies;
  for (var i = 0; i < s.enemies.length; i++) {
    final e = s.enemies[i];
    if (e.dead) continue;
    final k = _key((e.x / _cell).floor(), (e.y / _cell).floor());
    var arr = _cells[k];
    if (arr == null) {
      if (_poolIdx < _pool.length) {
        arr = _pool[_poolIdx]..clear();
      } else {
        arr = <int>[];
        _pool.add(arr);
      }
      _poolIdx++;
      _cells[k] = arr;
    }
    arr.add(i);
  }
  if (_pool.length > 4096) _pool = _pool.sublist(0, 1024);
}

/// Calls [fn] for every live enemy whose circle overlaps the given circle.
/// Stops early when [fn] returns true.
void forEnemiesInCircleUntil(double x, double y, double r, bool Function(Enemy e) fn) {
  final ext = r + _margin;
  final x0 = ((x - ext) / _cell).floor(), x1 = ((x + ext) / _cell).floor();
  final y0 = ((y - ext) / _cell).floor(), y1 = ((y + ext) / _cell).floor();
  for (var cx = x0; cx <= x1; cx++) {
    for (var cy = y0; cy <= y1; cy++) {
      final arr = _cells[_key(cx, cy)];
      if (arr == null) continue;
      for (final i in arr) {
        final e = _enemiesRef[i];
        if (e.dead) continue;
        final dx = e.x - x, dy = e.y - y, rr = r + e.radius;
        if (dx * dx + dy * dy <= rr * rr) {
          if (fn(e)) return;
        }
      }
    }
  }
}

/// Calls [fn] for every live enemy whose circle overlaps the given circle.
void forEnemiesInCircle(double x, double y, double r, void Function(Enemy e) fn) {
  forEnemiesInCircleUntil(x, y, r, (e) {
    fn(e);
    return false;
  });
}

Enemy? nearestEnemy(GameState s, double x, double y, double maxR, [bool Function(Enemy e)? skip]) {
  Enemy? best;
  var bestD = maxR * maxR;
  for (final e in s.enemies) {
    if (e.dead || e.intangible) continue;
    if (skip != null && skip(e)) continue;
    final dx = e.x - x, dy = e.y - y;
    final d = dx * dx + dy * dy;
    if (d < bestD) {
      bestD = d;
      best = e;
    }
  }
  return best;
}
