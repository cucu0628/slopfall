// Piercing Arrow: fast piercing arrows (evolution: Phantom Volley).

import '../../content/weapons.dart';
import '../../entities.dart';
import '../../fdlibm.dart';
import '../../spatial.dart';
import '../../types.dart';
import 'shared.dart';

void fireArrow(GameState s, Player p, WeaponInst w, WStats st, double dt) {
  if (w.cd > 0) return;
  w.cd = st.cd;
  final t = nearestEnemy(s, p.x, p.y, 700);
  final a0 = t != null ? jsAtan2(t.y - p.y, t.x - p.x) : aimAngle(p);
  for (var i = 0; i < st.amount; i++) {
    final a = a0 + (i - (st.amount - 1) / 2) * 0.12;
    addProjectile(
      s,
      owner: p.id,
      src: 'arrow',
      kind: w.evolved ? 'arrow2' : 'arrow',
      x: p.x,
      y: p.y, //
      vx: jsCos(a) * st.speed,
      vy: jsSin(a) * st.speed,
      speed: st.speed,
      dmg: st.dmg,
      radius: 6 * st.area,
      pierce: st.pierce,
      life: st.duration,
      knock: st.knock,
    );
  }
  s.events.add(const SfxEvent('arrow'));
}
