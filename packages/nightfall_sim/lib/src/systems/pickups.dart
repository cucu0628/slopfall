import 'dart:math' as math;

import '../combat.dart';
import '../js.dart';
import '../rng.dart';
import '../types.dart';
import 'leveling.dart';
import 'secret.dart';

const int _maxGems = 400;

void _collect(GameState s, Pickup pk, Player p) {
  pk.dead = true;
  s.events.add(PickupEvent(p.id, pk.kind));
  switch (pk.kind) {
    case 'xp':
    case 'coin':
      addXp(s, p, p.stats.gemDouble > 0 && rand(s) < p.stats.gemDouble ? pk.value * 2 : pk.value);
    case 'relic':
      grantSecretReward(s, p);
    case 'heal':
      healPlayer(s, p, 35);
    case 'magnet':
      for (final g in s.pickups) {
        if (g.kind == 'xp' && !g.dead && g.target.isEmpty) {
          g.target = p.id;
          g.sp = 100;
        }
      }
    case 'bomb':
      for (var i = 0; i < s.enemies.length; i++) {
        final e = s.enemies[i];
        final dx = e.x - p.x, dy = e.y - p.y;
        if (e.dead || dx * dx + dy * dy > 1000 * 1000) continue;
        if (e.boss) {
          damageEnemy(s, e, e.maxHp * 0.05, null, 'bomb');
        } else {
          killEnemy(s, e, p);
        }
      }
      s.events.add(ExplodeEvent(p.x, p.y, 700, '#ffffff'));
      s.events.add(const ShakeEvent(16));
    case 'chest':
      openChest(s, p, pk.big);
  }
}

Player? _player(GameState s, String id) {
  for (final p in s.players) {
    if (p.id == id) return p;
  }
  return null;
}

void updatePickups(GameState s, double dt) {
  var gems = 0;
  // index loop: pickups dropped while collecting (bomb kills) are handled this tick too
  for (var i = 0; i < s.pickups.length; i++) {
    final pk = s.pickups[i];
    if (pk.dead) continue;
    if (pk.kind == 'xp') gems++;
    if (pk.target.isNotEmpty) {
      final p = _player(s, pk.target);
      if (p == null || p.dead) {
        pk.target = '';
        continue;
      }
      pk.sp = math.min(1100, pk.sp + 1600 * dt);
      final dx = p.x - pk.x, dy = p.y - pk.y, d = or1(hypot(dx, dy));
      pk.x += (dx / d) * pk.sp * dt;
      pk.y += (dy / d) * pk.sp * dt;
      if (d < p.radius + 8) _collect(s, pk, p);
      continue;
    }
    for (final p in s.players) {
      if (p.dead) continue;
      final gem = pk.kind == 'xp' || pk.kind == 'coin';
      final range = gem ? p.stats.magnet : p.radius + 24;
      final dx = p.x - pk.x, dy = p.y - pk.y;
      if (dx * dx + dy * dy < range * range) {
        pk.target = p.id;
        pk.sp = gem ? -180 : 250;
        break;
      }
    }
  }

  if (gems > _maxGems) _mergeGems(s, gems - _maxGems + 50);
}

/// Folds the oldest idle gems into one so the pickup count stays bounded.
void _mergeGems(GameState s, int n) {
  Pickup? into;
  for (final pk in s.pickups) {
    if (n <= 0) break;
    if (pk.dead || pk.kind != 'xp' || pk.target.isNotEmpty) continue;
    if (into == null) {
      into = pk;
      continue;
    }
    into.value += pk.value;
    pk.dead = true;
    n--;
  }
}
