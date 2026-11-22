// Movement and collision of all player projectiles.

import 'dart:math' as math;

import '../../combat.dart';
import '../../entities.dart';
import '../../fdlibm.dart';
import '../../js.dart';
import '../../spatial.dart';
import '../../types.dart';
import 'coins.dart';
import 'shared.dart';

/// Mortar shell explosion: a one-shot area zone (radius stored in `data`).
void _detonate(GameState s, Projectile pr) {
  addZone(s, owner: pr.owner, src: pr.src, kind: 'boom', x: pr.x, y: pr.y, r: pr.data, life: 0.05, dmg: pr.dmg, knock: 220);
}

void steer(Projectile pr, double tx, double ty, double turn) {
  final cur = jsAtan2(pr.vy, pr.vx);
  final want = jsAtan2(ty - pr.y, tx - pr.x);
  var diff = jsMod(want - cur + math.pi * 3, tau) - math.pi;
  diff = math.max(-turn, math.min(turn, diff));
  final a = cur + diff;
  pr.vx = jsCos(a) * pr.speed;
  pr.vy = jsSin(a) * pr.speed;
}

/// Coin ricochet: flies on toward the nearest enemy it has not hit yet.
void _ricochet(GameState s, Projectile pr) {
  final t = nearestEnemy(s, pr.x, pr.y, coinBounceRange, (e) => pr.hits.containsKey(e.id));
  if (t == null) return;
  final dx = t.x - pr.x, dy = t.y - pr.y, d = or1(hypot(dx, dy));
  pr.vx = (dx / d) * pr.speed;
  pr.vy = (dy / d) * pr.speed;
  pr.life = math.max(pr.life, 0.6); // enough time to reach the next target
}

WeaponInst? _weapon(Player p, String id) {
  for (final w in p.weapons) {
    if (w.id == id) return w;
  }
  return null;
}

void updateProjectiles(GameState s, double dt) {
  for (var i = 0; i < s.projectiles.length; i++) {
    final pr = s.projectiles[i];
    if (pr.dead) continue;
    pr.age += dt;
    pr.life -= dt;
    if (pr.life <= 0) {
      pr.dead = true;
      if (pr.kind == 'shell') _detonate(s, pr);
      continue;
    }
    final owner = findPlayer(s, pr.owner);
    if (owner == null) {
      pr.dead = true;
      continue;
    }
    var dirX = 0.0, dirY = 0.0;
    if (pr.src == 'orbs') {
      final w = _weapon(owner, 'orbs');
      if (w == null) {
        pr.dead = true;
        continue;
      }
      final a = w.t + pr.data;
      pr.x = owner.x + jsCos(a) * w.r;
      pr.y = owner.y + jsSin(a) * w.r;
    } else if (pr.src == 'axe') {
      final T = pr.data;
      pr.ang += 16 * dt;
      if (pr.age < T) {
        final f = 1 - pr.age / T;
        pr.x += pr.vx * pr.speed * f * dt;
        pr.y += pr.vy * pr.speed * f * dt;
      } else {
        final dx = owner.x - pr.x, dy = owner.y - pr.y, d = or1(hypot(dx, dy));
        final sp = pr.speed * math.min(1.5, 0.3 + (pr.age - T) / T);
        pr.x += (dx / d) * sp * dt;
        pr.y += (dy / d) * sp * dt;
        if (d < 24) pr.dead = true;
      }
    } else {
      if (pr.homing > 0) {
        final t = nearestEnemy(s, pr.x, pr.y, 450);
        if (t != null) steer(pr, t.x, t.y, pr.homing * dt);
      }
      pr.x += pr.vx * dt;
      pr.y += pr.vy * dt;
      final sp = or1(hypot(pr.vx, pr.vy));
      dirX = pr.vx / sp;
      dirY = pr.vy / sp;
    }
    final ox = pr.x - owner.x, oy = pr.y - owner.y;
    if (ox * ox + oy * oy > 1600 * 1600) pr.dead = true;
    if (pr.dead) continue;

    forEnemiesInCircleUntil(pr.x, pr.y, pr.radius, (e) {
      final nt = pr.hits[e.id];
      if (nt != null && nt > s.time) return false;
      if (e.intangible) return false;
      var kx = dirX, ky = dirY;
      if (kx == 0 && ky == 0) {
        final dx = e.x - pr.x, dy = e.y - pr.y, d = or1(hypot(dx, dy));
        kx = dx / d;
        ky = dy / d;
      }
      final killed = damageEnemy(s, e, pr.dmg, owner, pr.src, kx, ky, pr.knock);
      if (pr.slow > 0) slowEnemy(e, pr.slow, pr.slow > 0.8 ? 2 : 1.5);
      if (pr.hitRate > 0) {
        pr.hits[e.id] = s.time + pr.hitRate;
      } else {
        pr.hits[e.id] = 1e9;
        // coins: a kill earns a bonus bounce (data counts them)
        if (pr.kind == 'coin' && killed && pr.data < coinKillBounces) {
          pr.data++;
          pr.pierce++;
        }
        pr.pierce--;
        if (pr.pierce < 0) {
          pr.dead = true;
          if (pr.kind == 'shell') _detonate(s, pr);
          return true;
        }
        if (pr.kind == 'coin') {
          _ricochet(s, pr);
          return true;
        }
      }
      return false;
    });

    if (pr.hitRate > 0 && (s.tick & 63) == 0) {
      pr.hits.removeWhere((_, t) => t < s.time);
    }
  }
}
