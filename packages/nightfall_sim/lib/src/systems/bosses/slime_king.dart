// Slime King (wave 5): jumps onto the player with a telegraphed slam, splits off slimelets when hit.

import 'dart:math' as math;

import '../../entities.dart';
import '../../types.dart';

void slimeKing(GameState s, Enemy e, Player target, double nx, double ny, double sp, double dt, bool enraged) {
  if (e.state == 0) {
    e.x += nx * sp * dt;
    e.y += ny * sp * dt;
    e.t -= dt;
    if (e.t <= 0) {
      e.state = 1;
      e.t2 = 0.55;
      e.tx = target.x;
      e.ty = target.y;
      addHazard(s, 'slam', x: e.tx, y: e.ty, r: e.radius + 80, warn: 0.55 + 0.9, life: 0.3, dmg: e.dmg * 1.2);
    }
  } else if (e.state == 1) {
    e.t2 -= dt;
    if (e.t2 <= 0) {
      e.state = 2;
      e.t2 = 0.9;
      e.sx = e.x;
      e.sy = e.y;
      e.intangible = true;
    }
  } else {
    e.t2 -= dt;
    final prog = math.min(1.0, 1 - e.t2 / 0.9);
    e.x = e.sx + (e.tx - e.sx) * prog;
    e.y = e.sy + (e.ty - e.sy) * prog;
    if (e.t2 <= 0) {
      e.intangible = false;
      e.state = 0;
      e.t = enraged ? 2.2 : 3.4;
      addHazard(s, 'ring', x: e.x, y: e.y, r: e.radius, w: 14, speed: 320, life: 1.6, dmg: e.dmg * 0.8);
      if (enraged) addHazard(s, 'ring', x: e.x, y: e.y, r: e.radius, w: 14, speed: 200, life: 2.2, dmg: e.dmg * 0.8);
    }
  }
}
