// Frost Ring: bursts of slowing ice shards (evolution: Absolute Zero).

import '../../content/weapons.dart';
import '../../entities.dart';
import '../../fdlibm.dart';
import '../../rng.dart';
import '../../types.dart';
import 'shared.dart';

void fireFrost(GameState s, Player p, WeaponInst w, WStats st, double dt) {
  if (w.cd > 0) return;
  w.cd = st.cd;
  final a0 = rand(s) * tau;
  for (var i = 0; i < st.amount; i++) {
    final a = a0 + (i * tau) / st.amount;
    addProjectile(
      s,
      owner: p.id,
      src: 'frost',
      kind: w.evolved ? 'shard2' : 'shard',
      x: p.x,
      y: p.y, //
      vx: jsCos(a) * st.speed,
      vy: jsSin(a) * st.speed,
      speed: st.speed,
      ang: a,
      dmg: st.dmg,
      radius: 7 * st.area,
      pierce: st.pierce,
      life: st.duration,
      knock: st.knock,
      slow: w.evolved ? 0.9 : 0.5,
    );
  }
  s.events.add(const SfxEvent('frost'));
}
