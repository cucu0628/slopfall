// Area effects: slashes, novas, meteors, arrow rain, mortar blasts.

import 'dart:math' as math;

import '../../combat.dart';
import '../../js.dart';
import '../../spatial.dart';
import '../../types.dart';

const double meteorBurnTime = 4;

void updateZones(GameState s, double dt) {
  for (var i = 0; i < s.zones.length; i++) {
    final z = s.zones[i];
    if (z.dead) continue;
    if (z.delay > 0) {
      z.delay -= dt;
      continue;
    }
    z.life -= dt;
    if (z.life <= 0) z.dead = true;
    final owner = findPlayer(s, z.owner);
    if (owner == null || z.dmg <= 0) continue;
    if (z.kind == 'nova' || z.kind == 'nova2' || z.kind == 'nova3') {
      final prog = 1 - math.max(0, z.life) / z.maxLife;
      final cur = z.r0 + (z.r - z.r0) * prog;
      forEnemiesInCircle(z.x, z.y, cur, (e) {
        if ((z.hits[e.id] ?? 0) != 0) return;
        z.hits[e.id] = 1;
        final dx = e.x - z.x, dy = e.y - z.y, d = or1(hypot(dx, dy));
        damageEnemy(s, e, z.dmg, owner, z.src, dx / d, dy / d, z.knock);
      });
    } else if (!z.fired) {
      z.fired = true;
      forEnemiesInCircle(z.x, z.y, z.r, (e) {
        final dx = e.x - z.x, dy = e.y - z.y, d = or1(hypot(dx, dy));
        damageEnemy(s, e, z.dmg, owner, z.src, dx / d, dy / d, z.knock);
        if (z.burn > 0) ignite(e, owner.id, z.burn, meteorBurnTime);
      });
      if (z.kind == 'boom') {
        s.events.add(ExplodeEvent(z.x, z.y, z.r, '#ffb347'));
      } else if (z.kind == 'meteor') {
        s.events.add(ExplodeEvent(z.x, z.y, z.r, '#ff7a1a'));
        s.events.add(const ShakeEvent(12));
      } else if (z.kind == 'rain') {
        s.events.add(ExplodeEvent(z.x, z.y, z.r * 0.6, '#b6ff7a'));
      }
    }
  }
}
