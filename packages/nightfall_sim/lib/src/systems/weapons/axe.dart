// Boomerang Axe: thrown axes that return (evolutions: Whirlwind, Twin Reavers).

import '../../content/weapons.dart';
import '../../entities.dart';
import '../../fdlibm.dart';
import '../../types.dart';
import 'shared.dart';

void fireAxe(GameState s, Player p, WeaponInst w, WStats st, double dt) {
  if (w.cd > 0) return;
  w.cd = st.cd;
  final base = aimAngle(p);
  final twin = w.evo == 'twinreavers';
  for (var i = 0; i < st.amount; i++) {
    final a = twin ? base + (i * tau) / st.amount : base + (i - (st.amount - 1) / 2) * 0.35;
    addProjectile(
      s,
      owner: p.id,
      src: 'axe',
      kind: twin ? 'axe3' : (w.evolved ? 'axe2' : 'axe'),
      x: p.x,
      y: p.y, //
      vx: jsCos(a),
      vy: jsSin(a),
      speed: st.speed,
      data: st.duration / 2,
      dmg: st.dmg,
      radius: 14 * st.area,
      pierce: 999,
      life: st.duration * 2 + 2,
      knock: st.knock,
      hitRate: 0.35,
    );
  }
  s.events.add(const SfxEvent('swing'));
}
