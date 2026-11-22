// Brood Mother (wave 15): egg sacs, slowing webs, enraged pounce.

import '../../combat.dart';
import '../../entities.dart';
import '../../fdlibm.dart';
import '../../types.dart';
import 'shared.dart';

/// Skitters in bursts, lays egg sacs that hatch into swarms, spits slowing
/// webs and, when enraged, pounces (windup telegraphed).
/// states: 0 skitter, 1 pause, 3 pounce windup, 2 pounce
void broodMother(GameState s, Enemy e, double nx, double ny, double sp, double dt, bool enraged) {
  e.t -= dt;
  e.t2 -= dt;
  e.sx -= dt;
  e.t3 -= dt;
  switch (e.state) {
    case 0:
      e.x += nx * sp * 1.5 * dt;
      e.y += ny * sp * 1.5 * dt;
      if (e.t3 <= 0) {
        e.state = 1;
        e.t3 = 0.55;
      }
    case 1:
      if (e.t3 <= 0) {
        if (enraged && e.sx <= 0) {
          e.state = 3;
          e.t3 = 0.45;
          e.tx = nx;
          e.ty = ny;
          e.sx = 4;
        } else {
          e.state = 0;
          e.t3 = 0.9;
        }
      }
    case 3:
      if (e.t3 <= 0) {
        e.state = 2;
        e.t3 = 0.42;
      }
    case 2:
      e.x += e.tx * 650 * dt;
      e.y += e.ty * 650 * dt;
      if (e.t3 <= 0) {
        e.state = 1;
        e.t3 = 0.6;
        addHazard(s, 'ring', x: e.x, y: e.y, r: e.radius, w: 12, speed: 260, life: 1.1, dmg: e.dmg * 0.6);
      }
  }
  if (e.t <= 0) {
    e.t = enraged ? 4.5 : 6.5;
    if (s.enemies.length < 550) {
      final a0 = e.ang;
      e.ang += 1.1;
      for (var i = 0; i < 3; i++) {
        final a = a0 + (i * tau) / 3;
        spawnEnemy(s, 'egg', e.x + jsCos(a) * 75, e.y + jsSin(a) * 75, waveScale(s.wave.n));
      }
    }
  }
  if (e.t2 <= 0 && e.state != 2) {
    e.t2 = enraged ? 2.2 : 3.2;
    final base = jsAtan2(ny, nx);
    for (var i = -2; i <= 2; i++) {
      final a = base + i * 0.22;
      addEnemyProjectile(s, 'web', e.x, e.y, jsCos(a) * 250, jsSin(a) * 250, e.dmg * 0.35, 10, 4);
    }
  }
}
