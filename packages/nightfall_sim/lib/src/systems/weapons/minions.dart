// Raised minions (Necromancer ability).

import '../../combat.dart';
import '../../js.dart';
import '../../spatial.dart';
import '../../types.dart';

void updateMinions(GameState s, double dt) {
  for (var i = 0; i < s.minions.length; i++) {
    final m = s.minions[i];
    if (m.dead) continue;
    m.life -= dt;
    m.cd -= dt;
    if (m.life <= 0) {
      m.dead = true;
      continue;
    }
    final owner = findPlayer(s, m.owner);
    if (owner == null) {
      m.dead = true;
      continue;
    }
    final t = nearestEnemy(s, m.x, m.y, 600);
    var tx = owner.x, ty = owner.y;
    if (t != null) {
      tx = t.x;
      ty = t.y;
    }
    final dx = tx - m.x, dy = ty - m.y, d = or1(hypot(dx, dy));
    if (t != null || d > 60) {
      m.x += (dx / d) * 190 * dt;
      m.y += (dy / d) * 190 * dt;
    }
    if (t != null && m.cd <= 0 && d < t.radius + 14) {
      m.cd = 0.5;
      damageEnemy(s, t, m.dmg, owner, 'raise', dx / d, dy / d, 120);
    }
  }
}
