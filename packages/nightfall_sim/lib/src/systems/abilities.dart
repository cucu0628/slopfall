import 'dart:math' as math;

import '../combat.dart';
import '../content/characters.dart';
import '../entities.dart';
import '../fdlibm.dart';
import '../js.dart';
import '../rng.dart';
import '../spatial.dart';
import '../types.dart';
import 'weapons/turret.dart';

/// Ability upgrades: +25% effect per level.
double abilityLevelMul(Player p) => 1 + 0.25 * (p.abilityLevel - 1);

/// Damage multiplier for abilities. It follows the enemy HP curve so an
/// ability stays meaningful no matter how deep into the endless waves you are.
double abilityPower(GameState s, Player p) => waveScale(s.wave.n).hp * abilityLevelMul(p);

/// Active ability effect time (Rage / Overclock).
double abilityDuration(Player p) => 6.0 + (p.abilityLevel - 1);

double abilityCooldown(Player p) => characterDefs[p.charId]!.ability.cd * p.stats.cooldown * (1 - 0.06 * (p.abilityLevel - 1));

void updateAbility(GameState s, Player p, InputCmd cmd, double dt) {
  p.abilityCd = math.max(0, p.abilityCd - dt);
  p.abilityT = math.max(0, p.abilityT - dt);
  p.abilityMaxCd = abilityCooldown(p);
  if (!cmd.ability || p.abilityCd > 0) return;
  p.abilityCd = p.abilityMaxCd;
  s.events.add(AbilityEvent(p.id, p.charId));
  switch (p.charId) {
    case 'knight':
      _shieldBash(s, p);
    case 'mage':
      _meteor(s, p);
    case 'ranger':
      _dash(s, p, cmd);
    case 'necro':
      _raiseDead(s, p);
    case 'engineer':
      _overclock(s, p);
    case 'berserker':
      p.abilityT = abilityDuration(p);
  }
}

void _shieldBash(GameState s, Player p) {
  final r = 230 * p.stats.area * (1 + 0.1 * (p.abilityLevel - 1));
  final dmg = 30 * abilityPower(s, p);
  forEnemiesInCircle(p.x, p.y, r, (e) {
    final dx = e.x - p.x, dy = e.y - p.y, d = or1(hypot(dx, dy));
    damageEnemy(s, e, dmg, p, 'ability', dx / d, dy / d, 900);
  });
  p.invuln = 1.5;
  p.abilityT = 1.5;
  addZone(s, owner: p.id, src: 'ability', kind: 'bash', x: p.x, y: p.y, r: r, life: 0.4);
  s.events.add(const ShakeEvent(8));
}

const double meteorRange = 480;

void _meteor(GameState s, Player p) {
  var ax = p.ax, ay = p.ay;
  final len = hypot(ax, ay);
  if (len > meteorRange) {
    ax = (ax / len) * meteorRange;
    ay = (ay / len) * meteorRange;
  }
  addZone(
    s,
    owner: p.id,
    src: 'ability',
    kind: 'meteor',
    x: p.x + ax,
    y: p.y + ay, //
    r: 170 * p.stats.area * (1 + 0.12 * (p.abilityLevel - 1)),
    delay: 0.7,
    life: 0.5,
    dmg: 150 * abilityPower(s, p),
    knock: 500,
    burn: 30 * abilityPower(s, p), // sets everything hit on fire
  );
}

void _dash(GameState s, Player p, InputCmd cmd) {
  var dx = cmd.mx, dy = cmd.my;
  if (dx == 0 && dy == 0) {
    dx = p.ax;
    dy = p.ay;
  }
  final d = or1(hypot(dx, dy));
  dx /= d;
  dy /= d;
  const speed = 1000.0, time = 0.22;
  p.dashT = time;
  p.dashX = dx * speed;
  p.dashY = dy * speed;
  p.invuln = math.max(p.invuln, time + 0.15);
  const dist = speed * time;
  final volleys = 7 + 2 * (p.abilityLevel - 1);
  final dmg = 50 * abilityPower(s, p);
  for (var i = 0; i < volleys; i++) {
    final f = i / (volleys - 1);
    final x = p.x + dx * dist * f + randRange(s, -50, 50);
    final y = p.y + dy * dist * f + randRange(s, -50, 50);
    addZone(
      s,
      owner: p.id,
      src: 'ability',
      kind: 'rain',
      x: x,
      y: y,
      r: 70 * p.stats.area,
      delay: 0.25 + i * 0.05,
      life: 0.3,
      dmg: dmg,
      knock: 150,
    );
  }
}

void _raiseDead(GameState s, Player p) {
  final maxN = 8 + 2 * (p.abilityLevel - 1);
  final near = s.corpses.where((c) {
    final dx = c.x - p.x, dy = c.y - p.y;
    return s.time - c.t < 6 && dx * dx + dy * dy < 450 * 450;
  }).toList();
  final spots = near.length > maxN ? near.sublist(near.length - maxN) : near;
  final minN = 4 + p.abilityLevel;
  while (spots.length < minN) {
    final a = (spots.length / minN) * math.pi * 2;
    spots.add(Corpse(x: p.x + jsCos(a) * 60, y: p.y + jsSin(a) * 60, t: s.time));
  }
  final dmg = 4.5 * abilityPower(s, p);
  for (final c in spots) {
    s.minions.add(Minion(id: s.nextId++, owner: p.id, x: c.x, y: c.y, life: 10 * p.stats.duration, cd: 0, dmg: dmg));
  }
  addZone(s, owner: p.id, src: 'ability', kind: 'raise', x: p.x, y: p.y, r: 450, life: 0.6);
}

void _overclock(GameState s, Player p) {
  p.abilityT = abilityDuration(p);
  for (var i = 0; i < p.abilityLevel; i++) {
    placeTurret(s, p, p.abilityT);
  }
}
