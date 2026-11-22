// Fire Nova: expanding fire rings (evolutions: Inferno, Supernova).

import '../../content/weapons.dart';
import '../../entities.dart';
import '../../types.dart';

void fireNova(GameState s, Player p, WeaponInst w, WStats st, double dt) {
  if (w.cd > 0) return;
  w.cd = st.cd;
  if (w.evo == 'supernova') {
    addZone(
      s,
      owner: p.id,
      src: 'nova',
      kind: 'nova3',
      x: p.x,
      y: p.y,
      r: 170 * st.area,
      r0: 12,
      life: st.duration * 1.4,
      dmg: st.dmg,
      knock: st.knock,
    );
    s.events.add(const ShakeEvent(6));
  }
  for (var i = 0; w.evo != 'supernova' && i < st.amount; i++) {
    addZone(
      s,
      owner: p.id,
      src: 'nova',
      kind: w.evolved ? 'nova2' : 'nova',
      x: p.x,
      y: p.y, //
      r: 170 * st.area,
      r0: 12,
      life: st.duration,
      delay: i * 0.3,
      dmg: st.dmg,
      knock: st.knock,
    );
  }
  s.events.add(const SfxEvent('nova'));
}
