// Frost Wyrm (wave 25): serpent body, ice breath, dives and icicles.

import 'dart:math' as math;

import '../../combat.dart';
import '../../entities.dart';
import '../../fdlibm.dart';
import '../../js.dart';
import '../../rng.dart';
import '../../types.dart';
import 'shared.dart';

const int wyrmSegments = 14;

const double wyrmGap = 22;

/// A serpent that weaves around the player. Its body segments (stored in
/// `trail`) hurt on contact. Breathes ice cones, telegraphs and performs a
/// dive that ends in a frost nova, and drops icicles when enraged.
/// states: 0 weave, 1 dive windup, 2 dive (timer in sx)
void wyrm(GameState s, Enemy e, Player target, double d, double nx, double ny, double sp, double dt, bool enraged) {
  e.t -= dt;
  e.t2 -= dt;
  e.t3 -= dt;
  var speed = sp;
  if (e.state == 0) {
    final side = e.id % 2 != 0 ? 1 : -1;
    final radial = d > 330 ? 0.9 : (d < 220 ? -0.7 : 0.0);
    final want = jsAtan2(nx * side + ny * radial, -ny * side + nx * radial) + jsSin(s.time * 3) * 0.6;
    e.ang = turnToward(e.ang, want, 2.6 * dt);
    if (e.t2 <= 0) {
      e.state = 1;
      e.sx = 0.75;
    }
    if (e.t <= 0) {
      e.t = enraged ? 2.4 : 3.4;
      final n = enraged ? 13 : 9;
      final base = jsAtan2(ny, nx);
      for (var i = 0; i < n; i++) {
        final a = base - 0.55 + (1.1 * i) / (n - 1);
        addEnemyProjectile(s, 'ice', e.x, e.y, jsCos(a) * 290, jsSin(a) * 290, e.dmg * 0.55, 7, 3);
      }
    }
  } else if (e.state == 1) {
    speed = sp * 0.3;
    e.ang = turnToward(e.ang, jsAtan2(ny, nx), 6 * dt);
    e.sx -= dt;
    if (e.sx <= 0) {
      e.state = 2;
      e.sx = 1.1;
    }
  } else {
    speed = sp * 3.4;
    e.sx -= dt;
    if (e.sx <= 0) {
      e.state = 0;
      e.t2 = enraged ? 6 : 8.5;
      addHazard(s, 'ring', x: e.x, y: e.y, r: e.radius, w: 14, speed: 300, life: 1.5, dmg: e.dmg * 0.7);
    }
  }
  e.x += jsCos(e.ang) * speed * dt;
  e.y += jsSin(e.ang) * speed * dt;

  if (enraged && e.t3 <= 0) {
    e.t3 = 3;
    for (var i = 0; i < 4; i++) {
      final a = rand(s) * tau, r = rand(s) * 180;
      addHazard(s, 'slam', x: target.x + jsCos(a) * r, y: target.y + jsSin(a) * r, r: 70, warn: 1.0, life: 0.3, dmg: e.dmg * 0.9);
    }
  }

  // body: drop a segment every wyrmGap units travelled
  if (e.trail.length < 2 || hypot(e.x - e.trail[0], e.y - e.trail[1]) >= wyrmGap) {
    e.trail.insertAll(0, [e.x, e.y]);
    if (e.trail.length > wyrmSegments * 2) e.trail.length = wyrmSegments * 2;
  }
  for (final p in s.players) {
    if (p.dead) continue;
    for (var i = 2; i < e.trail.length; i += 2) {
      final r = wyrmSegmentRadius(e.radius, i ~/ 2) + p.radius * 0.7;
      final dx = p.x - e.trail[i], dy = p.y - e.trail[i + 1];
      if (dx * dx + dy * dy < r * r) {
        hurtPlayer(s, p, e.dmg * 0.6);
        break;
      }
    }
  }
}

double wyrmSegmentRadius(double head, int index) => head * math.max(0.35, 0.85 - index * 0.035);
