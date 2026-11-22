// Magic Bolt: homing bolts (evolutions: Arcane Storm, Prism Lance).

import '../../content/weapons.dart';
import '../../entities.dart';
import '../../fdlibm.dart';
import '../../spatial.dart';
import '../../types.dart';

void fireBolt(GameState s, Player p, WeaponInst w, WStats st, double dt) {
  if (w.cd > 0) return;
  final t = nearestEnemy(s, p.x, p.y, 650);
  if (t == null) return;
  w.cd = st.cd;
  final a0 = jsAtan2(t.y - p.y, t.x - p.x);
  for (var i = 0; i < st.amount; i++) {
    final a = a0 + (i - (st.amount - 1) / 2) * 0.3;
    addProjectile(
      s,
      owner: p.id,
      src: 'bolt',
      kind: w.evo == 'prism' ? 'prism' : (w.evolved ? 'bolt2' : 'bolt'),
      x: p.x,
      y: p.y, //
      vx: jsCos(a) * st.speed,
      vy: jsSin(a) * st.speed,
      speed: st.speed,
      dmg: st.dmg,
      radius: 7 * st.area,
      pierce: st.pierce,
      life: st.duration,
      knock: st.knock,
      homing: w.evo == 'prism' ? 1.5 : 7,
    );
  }
  s.events.add(const SfxEvent('bolt'));
}
