// Void Eye (wave 30): spiral bullet patterns and sweeping lasers.

import 'dart:math' as math;

import '../../entities.dart';
import '../../fdlibm.dart';
import '../../types.dart';
import 'shared.dart';

void voidEye(GameState s, Enemy e, double d, double nx, double ny, double sp, double dt, bool enraged) {
  if (e.state != 1) {
    final radial = d > 360 ? 1 : (d < 280 ? -1 : 0);
    e.x += (nx * radial - ny * 0.6) * sp * dt;
    e.y += (ny * radial + nx * 0.6) * sp * dt;
  }
  e.t -= dt;
  e.ang += (enraged ? 2.1 : 1.6) * dt;
  if (e.state == 0) {
    e.t2 -= dt;
    if (e.t2 <= 0) {
      e.t2 = enraged ? 0.08 : 0.11;
      final streams = enraged ? 4 : 3;
      for (var k = 0; k < streams; k++) {
        final a = e.ang + (k * tau) / streams;
        addEnemyProjectile(s, 'void', e.x, e.y, jsCos(a) * 190, jsSin(a) * 190, e.dmg * 0.6, 7, 6);
      }
    }
    if (e.t <= 0) {
      e.state = 1;
      e.t = 4.2;
      final toT = jsAtan2(ny, nx);
      final dir = e.id % 2 == 0 ? 1 : -1;
      final n = enraged ? 2 : 1;
      for (var i = 0; i < n; i++) {
        addHazard(
          s,
          'laser',
          x: e.x,
          y: e.y,
          src: e.id,
          ang: toT - dir * 1.2 + i * math.pi,
          angVel: dir * 0.9, //
          len: 1100,
          w: 24,
          warn: 1.0,
          life: 3.2,
          dmg: e.dmg,
        );
      }
    }
  } else if (e.state == 1) {
    if (e.t <= 0) {
      e.state = 2;
      e.t = 1.4;
      ring(s, e, 20, 220, e.dmg * 0.6, e.ang, 'void');
    }
  } else if (e.t <= 0) {
    e.state = 0;
    e.t = 4;
  }
}
