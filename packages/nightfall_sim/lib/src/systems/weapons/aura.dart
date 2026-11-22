// Holy Aura: constant damage around the player (evolution: Sanctuary).

import '../../combat.dart';
import '../../content/weapons.dart';
import '../../js.dart';
import '../../spatial.dart';
import '../../types.dart';

void updateAura(GameState s, Player p, WeaponInst w, WStats st, double dt) {
  w.r = 85 * st.area;
  if (w.cd > 0) return;
  w.cd = st.cd;
  forEnemiesInCircle(p.x, p.y, w.r, (e) {
    final dx = e.x - p.x, dy = e.y - p.y, d = or1(hypot(dx, dy));
    damageEnemy(s, e, st.dmg, p, 'aura', dx / d, dy / d, st.knock);
    slowEnemy(e, w.evolved ? 0.35 : 0.15, 0.6);
  });
  if (w.evolved) healPlayer(s, p, 0.5);
}
