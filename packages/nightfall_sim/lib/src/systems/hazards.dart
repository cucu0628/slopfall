import 'dart:math' as math;

import '../combat.dart';
import '../fdlibm.dart';
import '../js.dart';
import '../types.dart';
import 'bosses/goldfang.dart';

double _distToSegment(double px, double py, double x1, double y1, double x2, double y2) {
  final dx = x2 - x1, dy = y2 - y1;
  final l2raw = dx * dx + dy * dy;
  final l2 = l2raw == 0 ? 1 : l2raw;
  final t = math.max(0.0, math.min(1.0, ((px - x1) * dx + (py - y1) * dy) / l2));
  return hypot(px - (x1 + dx * t), py - (y1 + dy * t));
}

void updateEnemyProjectiles(GameState s, double dt) {
  for (final b in s.eprojectiles) {
    if (b.dead) continue;
    b.x += b.vx * dt;
    b.y += b.vy * dt;
    b.life -= dt;
    if (b.life <= 0) {
      b.dead = true;
      continue;
    }
    for (final p in s.players) {
      if (p.dead) continue;
      final rr = b.r + p.radius * 0.8;
      final dx = p.x - b.x, dy = p.y - b.y;
      if (dx * dx + dy * dy < rr * rr) {
        // webs slow you down unless you dash through them
        if (b.kind == 'web' && p.dashT <= 0) p.slowT = math.max(p.slowT, 2);
        hurtPlayer(s, p, b.dmg);
        b.dead = true;
        break;
      }
    }
  }
}

Enemy? _enemyById(GameState s, int id) {
  for (final e in s.enemies) {
    if (e.id == id) return e;
  }
  return null;
}

void updateHazards(GameState s, double dt) {
  for (final h in s.hazards) {
    if (h.dead) continue;
    if (h.kind == 'laser' && h.src >= 0) {
      final src = _enemyById(s, h.src);
      if (src == null || src.dead) {
        h.dead = true;
        continue;
      }
      h.x = src.x;
      h.y = src.y;
    }
    if (h.kind == 'coin' && h.speed == 0) {
      // Goldfang's fake coin: the fuse is lit when a player steps close, otherwise it fizzles out
      for (final p in s.players) {
        if (!p.dead && hypot(p.x - h.x, p.y - h.y) < 46 + p.radius) {
          h.speed = 1;
          h.warn = h.maxWarn = coinFuse;
          s.events.add(const SfxEvent('warn'));
          break;
        }
      }
      if (h.speed == 0 && h.warn <= dt) {
        h.dead = true;
        continue;
      }
    }
    if (h.warn > 0) {
      h.warn -= dt;
      continue;
    }
    h.life -= dt;
    if (h.life <= 0) h.dead = true;

    switch (h.kind) {
      case 'ring':
        // Shockwave: only the drawn band hurts. Once the ring has passed a
        // player (e.g. they dashed through it) it can't hit them any more.
        final prev = h.r;
        h.r += h.speed * dt;
        for (final p in s.players) {
          if (p.dead || (h.hit[p.id] ?? 0) != 0) continue;
          final d = hypot(p.x - h.x, p.y - h.y);
          final band = h.w + p.radius * 0.6;
          if (d < prev - band) {
            h.hit[p.id] = 1;
          } else if ((d - h.r).abs() < band) {
            h.hit[p.id] = 1;
            hurtPlayer(s, p, h.dmg);
          }
        }
      case 'slam':
      case 'skyfall':
      case 'coin':
        if (h.fired) break;
        h.fired = true;
        final color = h.kind == 'skyfall' ? '#ff7a1a' : (h.kind == 'coin' ? '#ffc83d' : '#ff4d4d');
        s.events.add(ExplodeEvent(h.x, h.y, h.r, color));
        s.events.add(ShakeEvent(h.kind == 'coin' ? 6 : 10));
        for (final p in s.players) {
          if (p.dead) continue;
          if (hypot(p.x - h.x, p.y - h.y) < h.r + p.radius) hurtPlayer(s, p, h.dmg);
        }
      case 'laser':
        h.ang += h.angVel * dt;
        final x2 = h.x + jsCos(h.ang) * h.len, y2 = h.y + jsSin(h.ang) * h.len;
        for (final p in s.players) {
          if (p.dead || (h.hit[p.id] ?? 0) > s.time) continue;
          if (_distToSegment(p.x, p.y, h.x, h.y, x2, y2) < h.w / 2 + p.radius) {
            h.hit[p.id] = s.time + 0.4;
            hurtPlayer(s, p, h.dmg);
          }
        }
    }
  }
}
