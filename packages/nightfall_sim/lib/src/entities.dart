import 'content/enemies.dart';
import 'map.dart';
import 'types.dart';

int nextId(GameState s) => s.nextId++;

Player? nearestPlayer(GameState s, double x, double y) {
  Player? best;
  var bestD = double.infinity;
  for (final p in s.players) {
    if (p.dead) continue;
    final d = (p.x - x) * (p.x - x) + (p.y - y) * (p.y - y);
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  return best;
}

class EnemyScale {
  final double hp;
  final double dmg;
  final double speed;
  const EnemyScale({required this.hp, required this.dmg, required this.speed});

  EnemyScale copyWith({double? hp, double? dmg, double? speed}) =>
      EnemyScale(hp: hp ?? this.hp, dmg: dmg ?? this.dmg, speed: speed ?? this.speed);
}

Enemy spawnEnemy(GameState s, String type, double x, double y, EnemyScale scale, [bool elite = false]) {
  final def = enemyDefs[type]!;
  final hpMul = scale.hp * (elite ? 6 : 1);
  final e = Enemy(id: nextId(s), type: type, x: x, y: y)
    ..hp = def.hp * hpMul
    ..maxHp = def.hp * hpMul
    ..dmg = def.dmg * scale.dmg * (elite ? 1.5 : 1)
    ..speed = def.speed * scale.speed * (elite ? 0.9 : 1)
    ..radius = def.radius * (elite ? 1.5 : 1)
    ..xp = def.xp * (elite ? 8 : 1)
    ..elite = elite
    ..boss = def.boss;
  if (!ignoresObstacles(type)) resolveObstacles(s.mapSeed, e, e.radius);
  e.px = e.x;
  e.py = e.y;
  s.enemies.add(e);
  return e;
}

Pickup addPickup(GameState s, String kind, double x, double y, [double value = 0, bool big = false]) {
  final p = Pickup(id: nextId(s), kind: kind, x: x, y: y, value: value, big: big);
  if (kind != 'xp') {
    resolveObstacles(s.mapSeed, p, 16);
    p.px = p.x;
    p.py = p.y;
  }
  s.pickups.add(p);
  return p;
}

Projectile addProjectile(
  GameState s, {
  required String owner,
  required String src,
  required String kind,
  required double x,
  required double y,
  double vx = 0,
  double vy = 0,
  double dmg = 0,
  double radius = 8,
  double pierce = 0,
  double life = 1,
  double knock = 0,
  double hitRate = 0,
  double homing = 0,
  double ang = 0,
  double data = 0,
  double slow = 0,
  double speed = 0,
}) {
  final p = Projectile(
    id: nextId(s),
    owner: owner,
    src: src,
    kind: kind,
    x: x,
    y: y,
    vx: vx,
    vy: vy,
    dmg: dmg,
    radius: radius, //
    pierce: pierce,
    life: life,
    knock: knock,
    hitRate: hitRate,
    homing: homing,
    ang: ang,
    data: data,
    slow: slow,
    speed: speed,
  );
  s.projectiles.add(p);
  return p;
}

Zone addZone(
  GameState s, {
  required String owner,
  required String src,
  required String kind,
  required double x,
  required double y,
  required double r,
  double? r0,
  double life = 0.3,
  double delay = 0,
  double dmg = 0,
  double knock = 0,
  double slow = 0,
  double ang = 0,
  double arc = 0,
  List<double>? pts,
  double burn = 0,
}) {
  final z = Zone(
    id: nextId(s),
    owner: owner,
    src: src,
    kind: kind,
    x: x,
    y: y,
    r: r,
    r0: r0,
    life: life,
    delay: delay, //
    dmg: dmg,
    knock: knock,
    slow: slow,
    ang: ang,
    arc: arc,
    pts: pts,
    burn: burn,
  );
  s.zones.add(z);
  return z;
}

EnemyProjectile addEnemyProjectile(
  GameState s,
  String kind,
  double x,
  double y,
  double vx,
  double vy,
  double dmg, [
  double r = 7,
  double life = 5,
]) {
  final p = EnemyProjectile(id: nextId(s), kind: kind, x: x, y: y, vx: vx, vy: vy, r: r, dmg: dmg, life: life);
  s.eprojectiles.add(p);
  return p;
}

Hazard addHazard(
  GameState s,
  String kind, {
  required double x,
  required double y,
  required double dmg,
  int src = -1,
  double r = 0,
  double w = 16,
  double speed = 0,
  double ang = 0,
  double angVel = 0,
  double len = 0,
  double warn = 0,
  double life = 1,
}) {
  final h = Hazard(
    id: nextId(s),
    kind: kind,
    x: x,
    y: y,
    dmg: dmg,
    src: src,
    r: r,
    w: w,
    speed: speed,
    ang: ang, //
    angVel: angVel,
    len: len,
    warn: warn,
    life: life,
  );
  s.hazards.add(h);
  return h;
}
