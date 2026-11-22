// Soul Orbs: orbs circling the player (evolution: Eternal Souls).

import 'dart:math' as math;

import '../../content/weapons.dart';
import '../../entities.dart';
import '../../js.dart';
import '../../types.dart';
import 'shared.dart';

void updateOrbs(GameState s, Player p, WeaponInst w, WStats st, double dt) {
  w.t = jsMod(w.t + st.speed * dt, tau);
  w.r = 92 * st.area;
  final alive = countOwnedProjectiles(s, p.id, (x) => x.src == 'orbs');
  void spawn(double life) {
    for (var i = 0; i < st.amount; i++) {
      addProjectile(
        s,
        owner: p.id,
        src: 'orbs',
        kind: w.evolved ? 'orb2' : 'orb',
        x: p.x,
        y: p.y, //
        dmg: st.dmg,
        radius: 13 * math.sqrt(st.area),
        pierce: 999,
        life: life,
        knock: st.knock,
        hitRate: 0.45,
        data: (i * tau) / st.amount,
      );
    }
  }

  if (w.evolved) {
    if (alive != st.amount) {
      for (final pr in s.projectiles) {
        if (pr.owner == p.id && pr.src == 'orbs') pr.dead = true;
      }
      spawn(1e6);
    }
  } else if (w.cd <= 0 && alive == 0) {
    spawn(st.duration);
    w.cd = st.cd + st.duration;
  }
}
