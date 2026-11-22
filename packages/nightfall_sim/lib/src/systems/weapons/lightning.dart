// Chain Lightning: strikes and chains between enemies (evolution: Thunderstorm).

import '../../content/weapons.dart';
import '../../rng.dart';
import '../../types.dart';
import 'shared.dart';

void fireLightning(GameState s, Player p, WeaponInst w, WStats st, double dt) {
  if (w.cd > 0) return;
  final candidates = s.enemies.where((e) {
    final dx = e.x - p.x, dy = e.y - p.y;
    return !e.dead && !e.intangible && dx * dx + dy * dy < 550 * 550;
  }).toList();
  if (candidates.isEmpty) return;
  w.cd = st.cd;
  for (var i = 0; i < st.amount; i++) {
    final e = candidates[(rand(s) * candidates.length).floor()];
    if (e.dead) continue;
    chainLightning(s, p, 'lightning', e.x, e.y - 500, e, st.pierce, 170 * st.area, st.dmg);
  }
  s.events.add(const SfxEvent('zap'));
}
