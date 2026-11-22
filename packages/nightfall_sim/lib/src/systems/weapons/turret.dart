// Turret: deployable auto-firing turrets (evolutions: Tesla Array, Mortar Battery).

import 'dart:math' as math;

import '../../combat.dart';
import '../../content/weapons.dart';
import '../../entities.dart';
import '../../fdlibm.dart';
import '../../js.dart';
import '../../map.dart';
import '../../rng.dart';
import '../../spatial.dart';
import '../../types.dart';
import 'shared.dart';

class _Spot implements Pos {
  @override
  double x;
  @override
  double y;
  _Spot(this.x, this.y);
}

void deployTurret(GameState s, Player p, WeaponInst w, WStats st, double dt) {
  if (w.cd > 0) return;
  if (countOwnedTurrets(s, p.id) >= st.amount) return;
  w.cd = st.cd;
  placeTurret(s, p, st.duration);
}

void placeTurret(GameState s, Player p, double life) {
  final a = rand(s) * tau;
  final pos = _Spot(p.x + jsCos(a) * 30, p.y + jsSin(a) * 30);
  resolveObstacles(s.mapSeed, pos, 12);
  s.turrets.add(Turret(id: s.nextId++, owner: p.id, x: pos.x, y: pos.y, life: life, cd: 0.3, ang: a));
  s.events.add(const SfxEvent('deploy'));
}

void updateTurrets(GameState s, double dt) {
  for (var i = 0; i < s.turrets.length; i++) {
    final t = s.turrets[i];
    if (t.dead) continue;
    t.life -= dt;
    if (t.life <= 0) {
      t.dead = true;
      continue;
    }
    final owner = findPlayer(s, t.owner);
    if (owner == null) {
      t.dead = true;
      continue;
    }
    WeaponInst? w;
    for (final x in owner.weapons) {
      if (x.id == 'turret') {
        w = x;
        break;
      }
    }
    final st = w != null ? weaponStats(owner, w) : baseWeaponStats(weaponDefs['turret']!, 1);
    t.cd -= dt * (isOverclocked(owner) ? 3 : 1);
    final target = nearestEnemy(s, t.x, t.y, 480);
    if (target == null) continue;
    t.ang = jsAtan2(target.y - t.y, target.x - t.x);
    if (t.cd > 0) continue;
    if (w?.evo == 'tesla') {
      t.cd = 0.8;
      chainLightning(s, owner, 'turret', t.x, t.y, target, 3, 160, st.dmg);
    } else if (w?.evo == 'mortar') {
      t.cd = 1.2;
      final d = hypot(target.x - t.x, target.y - t.y);
      const sp = 420.0;
      addProjectile(
        s,
        owner: owner.id,
        src: 'turret',
        kind: 'shell',
        x: t.x,
        y: t.y, //
        vx: jsCos(t.ang) * sp,
        vy: jsSin(t.ang) * sp,
        speed: sp,
        dmg: st.dmg,
        radius: 8,
        pierce: 0,
        life: math.max(0.15, d / sp),
        data: 80 * st.area,
        knock: 0,
      );
    } else {
      t.cd = 0.5;
      addProjectile(
        s,
        owner: owner.id,
        src: 'turret',
        kind: 'bullet',
        x: t.x,
        y: t.y, //
        vx: jsCos(t.ang) * st.speed,
        vy: jsSin(t.ang) * st.speed,
        speed: st.speed,
        dmg: st.dmg,
        radius: 5,
        pierce: st.pierce,
        life: 1,
        knock: st.knock,
      );
    }
  }
}
