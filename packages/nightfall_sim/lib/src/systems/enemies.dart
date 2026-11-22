import 'dart:math' as math;

import '../combat.dart';
import '../content/enemies.dart';
import '../entities.dart';
import '../fdlibm.dart';
import '../js.dart';
import '../map.dart';
import '../rng.dart';
import '../spatial.dart';
import '../types.dart';
import 'bosses/index.dart';

const double eggHatch = 5;

/// A boss takes at most one shaman heal (1% max HP) per this many seconds.
const double bossHealEvery = 3.5;

void updateEnemies(GameState s, double dt) {
  final decay = math.max(0.0, 1 - 9 * dt);
  // index loop: enemies spawned during the update are processed this tick too (as in JS for..of)
  for (var i = 0; i < s.enemies.length; i++) {
    final e = s.enemies[i];
    if (e.dead) continue;
    e.flash = math.max(0, e.flash - dt);
    updateBurn(s, e, dt);
    if (e.dead) continue;
    e.slowT -= dt;
    e.x += e.kx * dt;
    e.y += e.ky * dt;
    e.kx *= decay;
    e.ky *= decay;

    final target = nearestPlayer(s, e.x, e.y);
    if (target == null) continue;
    final dx = target.x - e.x, dy = target.y - e.y;
    final d = or1(hypot(dx, dy));
    final nx = dx / d, ny = dy / d;
    final sp = e.speed * (e.slowT > 0 ? 1 - e.slowAmt : 1);

    if (e.boss) {
      updateBoss(s, e, target, d, nx, ny, sp, dt);
    } else {
      _updateRegular(s, e, d, nx, ny, sp, dt);
    }
    if (e.dead) continue;
    if (!ignoresObstacles(e.type)) _slideAroundObstacles(s, e, nx, ny, sp, dt);

    if (!e.intangible && e.dmg > 0) {
      for (final p in s.players) {
        if (p.dead) continue;
        final rr = e.radius + p.radius;
        final ex = p.x - e.x, ey = p.y - e.y;
        if (ex * ex + ey * ey < rr * rr) hurtPlayer(s, p, e.dmg);
      }
    }

    if (!e.boss && d > 1500) _relocate(s, e, target);
  }
  _separate(s);
}

/// Pushes the enemy out of obstacles and lets it slide along them toward its target.
void _slideAroundObstacles(GameState s, Enemy e, double mx, double my, double sp, double dt) {
  final (nx, ny) = resolveObstacles(s.mapSeed, e, e.radius);
  final l = hypot(nx, ny);
  if (l < 0.001) return;
  final ux = nx / l, uy = ny / l;
  final dot = mx * ux + my * uy;
  if (dot >= 0) return;
  var tx = mx - dot * ux, ty = my - dot * uy;
  var tl = hypot(tx, ty);
  if (tl < 0.2) {
    final side = e.id % 2 == 0 ? 1 : -1;
    tx = -uy * side;
    ty = ux * side;
    tl = 1;
  }
  e.x += (tx / tl) * sp * 0.8 * dt;
  e.y += (ty / tl) * sp * 0.8 * dt;
  resolveObstacles(s.mapSeed, e, e.radius);
}

void _relocate(GameState s, Enemy e, Player target) {
  final a = jsAtan2(target.fy, target.fx) + randRange(s, -1, 1);
  e.x = target.x + jsCos(a) * 900;
  e.y = target.y + jsSin(a) * 900;
  e.px = e.x;
  e.py = e.y;
}

void _move(Enemy e, double x, double y, double sp, double dt) {
  e.x += x * sp * dt;
  e.y += y * sp * dt;
}

void _keepDistance(Enemy e, double d, double nx, double ny, double sp, double dt, double near, double far) {
  final side = e.id % 2 == 0 ? 1 : -1;
  if (d > far) {
    _move(e, nx, ny, sp, dt);
  } else if (d < near) {
    _move(e, -nx, -ny, sp, dt);
  } else {
    _move(e, -ny * side, nx * side, sp * 0.5, dt);
  }
}

void _updateRegular(GameState s, Enemy e, double d, double nx, double ny, double sp, double dt) {
  e.t -= dt;
  switch (e.type) {
    case 'bat':
      e.ang += dt * 7;
      final w = jsSin(e.ang + e.id) * 0.7;
      final mx = nx - ny * w, my = ny + nx * w, l = or1(hypot(mx, my));
      _move(e, mx / l, my / l, sp, dt);
    case 'archer':
      _keepDistance(e, d, nx, ny, sp, dt, 200, 300);
      if (e.t <= 0 && d < 520) {
        e.t = 2.4 + rand(s) * 0.8;
        addEnemyProjectile(s, 'arrow', e.x, e.y, nx * 250, ny * 250, e.dmg, 6, 3);
      }
    case 'shaman':
      _keepDistance(e, d, nx, ny, sp, dt, 250, 340);
      if (e.t <= 0) {
        e.t = 3.5;
        forEnemiesInCircle(e.x, e.y, 220, (o) {
          if (!o.boss) {
            o.hp = math.min(o.maxHp, o.hp + o.maxHp * 0.15);
          } else if (s.time >= o.healReadyAt) {
            // shamans gather around the boss, so their heals must not stack or weaker builds can't out-damage them
            o.healReadyAt = s.time + bossHealEvery;
            o.hp = math.min(o.maxHp, o.hp + o.maxHp * 0.01);
          }
        });
        s.events.add(ExplodeEvent(e.x, e.y, 220, '#2ee6c5'));
      }
    case 'charger':
      if (e.state == 0) {
        _move(e, nx, ny, sp, dt);
        if (d < 330 && e.t <= 0) {
          e.state = 1;
          e.t2 = 0.6;
          e.tx = nx;
          e.ty = ny;
        }
      } else if (e.state == 1) {
        e.t2 -= dt;
        if (e.t2 <= 0) {
          e.state = 2;
          e.t2 = 0.5;
        }
      } else {
        _move(e, e.tx, e.ty, sp * 7.5, dt);
        e.t2 -= dt;
        if (e.t2 <= 0) {
          e.state = 0;
          e.t = 2.5;
        }
      }
    case 'exploder':
      if (e.state == 0) {
        _move(e, nx, ny, sp, dt);
        if (d < 55 + e.radius) {
          e.state = 1;
          e.t2 = 0.6;
        }
      } else {
        _move(e, nx, ny, sp * 0.3, dt);
        e.t2 -= dt;
        if (e.t2 <= 0) {
          final r = 95 * (e.elite ? 1.5 : 1);
          for (final p in s.players) {
            if (!p.dead && hypot(p.x - e.x, p.y - e.y) < r + p.radius) hurtPlayer(s, p, e.dmg);
          }
          s.events.add(ExplodeEvent(e.x, e.y, r.toDouble(), '#ff3b30'));
          s.events.add(const ShakeEvent(5));
          killEnemy(s, e, null);
        }
      }
    case 'egg':
      // hatches into a swarm unless destroyed in time
      e.t2 += dt;
      if (e.t2 >= eggHatch) {
        final sc = waveScale(s.wave.n);
        for (var i = 0; i < 5; i++) {
          final x = e.x + randRange(s, -14, 14);
          final y = e.y + randRange(s, -14, 14);
          spawnEnemy(s, 'swarm', x, y, sc);
        }
        s.events.add(ExplodeEvent(e.x, e.y, 40, '#e9dcc0'));
        e.dead = true;
      }
    case 'ghost':
      e.ang += dt;
      final phase = jsMod(e.ang + e.id * 0.37, 5);
      e.intangible = phase > 3.5;
      _move(e, nx, ny, sp * (e.intangible ? 1.4 : 1), dt);
    default:
      _move(e, nx, ny, sp, dt);
  }
}

/// Soft separation so enemies don't stack on one spot.
void _separate(GameState s) {
  for (var i = 0; i < s.enemies.length; i++) {
    final e = s.enemies[i];
    if (e.dead || e.intangible) continue;
    forEnemiesInCircle(e.x, e.y, e.radius, (o) {
      if (identical(o, e) || o.intangible) return;
      final dx = e.x - o.x, dy = e.y - o.y;
      final d = hypot(dx, dy);
      final dd = (d == 0 || d.isNaN) ? 0.01 : d;
      final overlap = e.radius + o.radius - dd;
      if (overlap <= 0) return;
      final push = overlap * 0.25;
      final ux = dx / dd, uy = dy / dd;
      if (!e.boss) {
        e.x += ux * push;
        e.y += uy * push;
      }
      if (!o.boss) {
        o.x -= ux * push;
        o.y -= uy * push;
      }
    });
    if (!ignoresObstacles(e.type)) resolveObstacles(s.mapSeed, e, e.radius);
  }
}
