// Goldfang's Coin Toss (unique, secret boss reward): a fan of coins that
// ricochet from enemy to enemy. Bounces live in projectiles.dart.

import '../../content/weapons.dart';
import '../../entities.dart';
import '../../fdlibm.dart';
import '../../spatial.dart';
import '../../types.dart';
import 'shared.dart';

/// Extra ricochets a single coin can earn by killing.
const double coinKillBounces = 3;
const double coinBounceRange = 280;

void fireCoins(GameState s, Player p, WeaponInst w, WStats st, double dt) {
  if (w.cd > 0) return;
  w.cd = st.cd;
  final t = nearestEnemy(s, p.x, p.y, 700);
  final a0 = t != null ? jsAtan2(t.y - p.y, t.x - p.x) : aimAngle(p);
  for (var i = 0; i < st.amount; i++) {
    final a = a0 + (i - (st.amount - 1) / 2) * 0.2;
    addProjectile(
      s,
      owner: p.id,
      src: 'coins',
      kind: 'coin',
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
    );
  }
  s.events.add(const SfxEvent('coin'));
}
