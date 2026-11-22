// Necro Lord (wave 10): keeps its distance, fires skull rings and summons skeletons.

import '../../combat.dart';
import '../../entities.dart';
import '../../fdlibm.dart';
import '../../types.dart';
import 'shared.dart';

void necroLord(GameState s, Enemy e, double d, double nx, double ny, double sp, double dt, bool enraged) {
  final side = jsSin(s.time * 0.5) > 0 ? 1 : -1;
  if (d > 330) {
    e.x += nx * sp * dt;
    e.y += ny * sp * dt;
  } else if (d < 230) {
    e.x -= nx * sp * dt;
    e.y -= ny * sp * dt;
  } else {
    e.x += -ny * side * sp * 0.6 * dt;
    e.y += nx * side * sp * 0.6 * dt;
  }
  e.t -= dt;
  e.t2 -= dt;
  e.t3 -= dt;
  if (e.t <= 0) {
    e.t = enraged ? 1.8 : 2.6;
    e.ang += 0.17;
    ring(s, e, enraged ? 24 : 18, 170, e.dmg * 0.7, e.ang, 'skull');
  }
  if (e.t2 <= 0) {
    e.t2 = 7;
    if (s.enemies.length < 550) {
      final n = enraged ? 6 : 4;
      for (var i = 0; i < n; i++) {
        final a = (i * tau) / n;
        spawnEnemy(s, 'skeleton', e.x + jsCos(a) * 70, e.y + jsSin(a) * 70, waveScale(s.wave.n));
      }
      s.events.add(ExplodeEvent(e.x, e.y, 90, '#9b59ff'));
    }
  }
  if (enraged && e.t3 <= 0) {
    e.t3 = 1.2;
    final base = jsAtan2(ny, nx);
    for (var i = -1; i <= 1; i++) {
      final a = base + i * 0.15;
      addEnemyProjectile(s, 'skull', e.x, e.y, jsCos(a) * 300, jsSin(a) * 300, e.dmg * 0.7, 8, 4);
    }
  }
}
