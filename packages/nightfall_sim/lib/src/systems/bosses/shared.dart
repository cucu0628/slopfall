// Helpers shared by boss behaviours.

import 'dart:math' as math;

import '../../entities.dart';
import '../../fdlibm.dart';
import '../../js.dart';
import '../../types.dart';

const double tau = math.pi * 2;

void ring(GameState s, Enemy e, int n, double speed, double dmg, double offset, String kind) {
  for (var i = 0; i < n; i++) {
    final a = offset + (i * tau) / n;
    addEnemyProjectile(s, kind, e.x, e.y, jsCos(a) * speed, jsSin(a) * speed, dmg, 8, 6);
  }
}

double turnToward(double cur, double want, double rate) {
  final diff = jsMod(want - cur + math.pi * 3, tau) - math.pi;
  return cur + math.max(-rate, math.min(rate, diff));
}
