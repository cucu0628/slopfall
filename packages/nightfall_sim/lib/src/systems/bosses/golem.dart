// Stone Golem (wave 20): telegraphed charges and ground slams with shockwaves.

import '../../entities.dart';
import '../../types.dart';

void golem(GameState s, Enemy e, double nx, double ny, double sp, double dt, bool enraged) {
  final speedMul = enraged ? 1.4 : 1;
  switch (e.state) {
    case 0:
      e.x += nx * sp * speedMul * dt;
      e.y += ny * sp * speedMul * dt;
      e.t -= dt;
      e.t2 -= dt;
      if (e.t <= 0) {
        e.state = 1;
        e.t3 = 0.8;
        e.tx = nx;
        e.ty = ny;
      } else if (e.t2 <= 0) {
        e.state = 3;
        e.t3 = 1.2;
        addHazard(s, 'slam', x: e.x, y: e.y, r: 220, warn: 1.0, life: 0.3, dmg: e.dmg * 1.3);
      }
    case 1: // charge windup
      e.t3 -= dt;
      if (e.t3 <= 0) {
        e.state = 2;
        e.t3 = 0.75;
      }
    case 2: // charging
      e.x += e.tx * 680 * dt;
      e.y += e.ty * 680 * dt;
      e.t3 -= dt;
      if (e.t3 <= 0) {
        e.state = 0;
        e.t = enraged ? 3 : 4.5;
      }
    case 3: // slam
      e.t3 -= dt;
      if (e.t3 <= 0) {
        e.state = 0;
        e.t2 = enraged ? 5 : 7;
        addHazard(s, 'ring', x: e.x, y: e.y, r: 40, w: 16, speed: 380, life: 1.4, dmg: e.dmg * 0.7);
      }
  }
}
