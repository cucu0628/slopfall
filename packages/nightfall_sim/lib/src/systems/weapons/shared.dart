// Helpers shared by several weapon behaviours.

import 'dart:math' as math;

import '../../combat.dart';
import '../../content/weapons.dart';
import '../../entities.dart';
import '../../fdlibm.dart';
import '../../js.dart';
import '../../spatial.dart';
import '../../types.dart';

const double tau = math.pi * 2;

double aimAngle(Player p) {
  if (p.ax * p.ax + p.ay * p.ay > 1) return jsAtan2(p.ay, p.ax);
  return jsAtan2(p.fy, p.fx);
}

/// Damages enemies in a circular sector.
void arcHit(GameState s, Player p, String src, double range, double ang, double arc, WStats st) {
  forEnemiesInCircle(p.x, p.y, range, (e) {
    final dx = e.x - p.x, dy = e.y - p.y;
    final d = or1(hypot(dx, dy));
    if (arc < tau) {
      final diff = (jsMod(jsAtan2(dy, dx) - ang + math.pi * 3, tau) - math.pi).abs();
      if (diff > arc / 2 + e.radius / d) return;
    }
    damageEnemy(s, e, st.dmg, p, src, dx / d, dy / d, st.knock);
  });
}

void chainLightning(
  GameState s,
  Player owner,
  String src,
  double fromX,
  double fromY,
  Enemy first,
  double chains,
  double range,
  double dmg,
) {
  final pts = [fromX, fromY];
  final hit = <int>{};
  Enemy? cur = first;
  for (var i = 0; i <= chains && cur != null; i++) {
    hit.add(cur.id);
    pts.addAll([cur.x, cur.y]);
    final cx = cur.x, cy = cur.y;
    damageEnemy(s, cur, dmg, owner, src, 0, 0, 0);
    cur = nearestEnemy(s, cx, cy, range, (e) => hit.contains(e.id));
  }
  addZone(s, owner: owner.id, src: src, kind: 'bolt', x: fromX, y: fromY, r: 0, pts: pts, life: 0.22);
}

int countOwnedProjectiles(GameState s, String owner, bool Function(Projectile x) pred) {
  var n = 0;
  for (final x in s.projectiles) {
    if (!x.dead && x.owner == owner && pred(x)) n++;
  }
  return n;
}

int countOwnedTurrets(GameState s, String owner) {
  var n = 0;
  for (final x in s.turrets) {
    if (!x.dead && x.owner == owner) n++;
  }
  return n;
}
