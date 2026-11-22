// Sword Arc: melee arcs toward the aim (evolutions: Holy Blade, Blade Dancer).

import 'dart:math' as math;

import '../../content/weapons.dart';
import '../../entities.dart';
import '../../types.dart';
import 'shared.dart';

void fireSword(GameState s, Player p, WeaponInst w, WStats st, double dt) {
  if (w.cd > 0) return;
  w.cd = st.cd;
  final range = 95 * st.area;
  final base = aimAngle(p);
  if (w.evo == 'holyblade') {
    arcHit(s, p, 'sword', range * 1.2, base, tau, st);
    addZone(s, owner: p.id, src: 'sword', kind: 'slash2', x: p.x, y: p.y, r: range * 1.2, ang: base, arc: tau, life: 0.25);
  } else {
    final n = math.max(1.0, st.amount);
    final kind = w.evo == 'bladedancer' ? 'slash3' : 'slash';
    for (var i = 0; i < n; i++) {
      final ang = base + (i * tau) / n;
      arcHit(s, p, 'sword', range, ang, 2.1, st);
      addZone(s, owner: p.id, src: 'sword', kind: kind, x: p.x, y: p.y, r: range, ang: ang, arc: 2.1, life: 0.18);
    }
  }
  s.events.add(const SfxEvent('swing'));
}
