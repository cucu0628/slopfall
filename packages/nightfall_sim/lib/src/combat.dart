import 'fdlibm.dart';
import 'dart:math' as math;

import 'content/enemies.dart';
import 'entities.dart';
import 'js.dart';
import 'rng.dart';
import 'types.dart';

EnemyScale waveScale(int n) {
  final w = n - 1;
  // After wave 20 enemies grow exponentially so a maxed build can't idle forever.
  final late = math.max(0, n - 20);
  return EnemyScale(
    hp: (1 + 0.15 * w + 0.012 * w * w) * math.pow(1.07, late).toDouble(),
    dmg: (1 + 0.05 * w + 0.0025 * w * w) * math.pow(1.03, late).toDouble(),
    speed: math.min(1.35, 1 + 0.007 * w),
  );
}

bool isRaging(Player p) => p.charId == 'berserker' && p.abilityT > 0;

bool isOverclocked(Player p) => p.charId == 'engineer' && p.abilityT > 0;

double playerDmgMult(Player p) {
  var m = p.stats.might;
  if (p.charId == 'berserker') m *= 1 + 0.5 * (1 - p.hp / p.stats.maxHp);
  if (isRaging(p)) m *= 1.3 + 0.1 * (p.abilityLevel - 1);
  return m;
}

void healPlayer(GameState s, Player p, double v) {
  if (p.dead || p.hp >= p.stats.maxHp) return;
  final before = p.hp;
  p.hp = math.min(p.stats.maxHp, p.hp + v);
  if (v >= 5) s.events.add(HealEvent(p.id, roundInt(p.hp - before)));
}

/// Burn damage per second, as a fraction of the igniting hit.
const double igniteDps = 0.25;
const double igniteTime = 3;
const double _burnTick = 0.5;

/// Sets an enemy on fire; a stronger burn replaces a weaker one, time is extended.
void ignite(Enemy e, String ownerId, double dps, double time) {
  if (e.dead) return;
  if (dps >= e.burnDps || e.burnT <= 0) {
    e.burnDps = dps;
    e.burnOwner = ownerId;
  }
  if (e.burnT <= 0) e.burnTick = _burnTick;
  e.burnT = math.max(e.burnT, time);
}

Player? findPlayer(GameState s, String id) {
  for (final p in s.players) {
    if (p.id == id) return p;
  }
  return null;
}

/// Burn damage over time; called every tick for each enemy.
void updateBurn(GameState s, Enemy e, double dt) {
  if (e.burnT <= 0) return;
  e.burnT -= dt;
  e.burnTick -= dt;
  if (e.burnTick > 0) return;
  e.burnTick += _burnTick;
  damageEnemy(s, e, e.burnDps * _burnTick, findPlayer(s, e.burnOwner), 'burn', 0, 0, 0, true);
}

/// Deals damage to an enemy. [base] is the raw weapon damage before the
/// owner's multipliers. [dot] marks damage over time (no crits, no ignite).
/// Returns true if the enemy died.
bool damageEnemy(
  GameState s,
  Enemy e,
  double base,
  Player? owner,
  String src, [
  double dirX = 0,
  double dirY = 0,
  double knock = 0,
  bool dot = false,
]) {
  if (e.dead || e.intangible) return false;
  var dmg = base;
  var crit = false;
  if (owner != null) {
    dmg *= playerDmgMult(owner);
    if (!dot && rand(s) < owner.stats.crit) {
      dmg *= 2;
      crit = true;
    }
  }
  final dealt = math.min(dmg, e.hp);
  e.hp -= dmg;
  if (e.flash <= 0) e.flash = 0.12;
  if (knock > 0 && !e.boss) {
    final k = e.elite ? knock * 0.4 : knock;
    e.kx += dirX * k;
    e.ky += dirY * k;
  }
  if (owner != null) {
    owner.dmgDealt[src] = (owner.dmgDealt[src] ?? 0) + dealt;
    // lifesteal is limited per second (lsBudget refills from lifestealCap)
    if (owner.stats.lifesteal > 0 && owner.lsBudget > 0) {
      final heal = math.min(owner.lsBudget, dealt * owner.stats.lifesteal);
      owner.lsBudget -= heal;
      healPlayer(s, owner, heal);
    }
    if (!dot && owner.stats.burn > 0 && e.hp > 0 && rand(s) < owner.stats.burn) {
      ignite(e, owner.id, base * igniteDps, igniteTime);
    }
  }
  s.events.add(HitEvent(e.x, e.y - e.radius, roundInt(dmg), crit, dot));

  if (e.type == 'slimeking' && e.hp > 0) {
    e.dmgAcc += dealt;
    while (e.dmgAcc >= e.maxHp * 0.07) {
      e.dmgAcc -= e.maxHp * 0.07;
      for (var i = 0; i < 2; i++) {
        final a = rand(s) * math.pi * 2;
        spawnEnemy(s, 'slimelet', e.x + jsCos(a) * e.radius, e.y + jsSin(a) * e.radius, waveScale(s.wave.n));
      }
    }
  }

  if (e.hp <= 0) {
    killEnemy(s, e, owner);
    return true;
  }
  return false;
}

void killEnemy(GameState s, Enemy e, Player? owner) {
  if (e.dead) return;
  e.dead = true;
  s.kills++;
  if (owner != null) {
    owner.kills++;
    if (owner.charId == 'necro' && owner.healBudget >= 1) {
      owner.healBudget -= 1;
      healPlayer(s, owner, 1);
    }
  }
  s.events.add(KillEvent(e.x, e.y, e.type, e.elite, e.boss, e.radius));
  s.corpses.add(Corpse(x: e.x, y: e.y, t: s.time));
  if (s.corpses.length > 40) s.corpses.removeAt(0);

  addPickup(s, 'xp', e.x, e.y, e.xp);
  if (e.boss) {
    // the secret boss drops his treasure (unique weapon or perk) instead of a chest
    addPickup(s, e.type == 'goldfang' ? 'relic' : 'chest', e.x, e.y, 0, true);
    addPickup(s, 'heal', e.x + 30, e.y, 0);
  } else if (e.chest) {
    addPickup(s, 'chest', e.x, e.y, 0);
  } else if (!e.elite) {
    final r = rand(s);
    if (r < 0.006) {
      addPickup(s, 'heal', e.x, e.y);
    } else if (r < 0.0085) {
      addPickup(s, 'magnet', e.x, e.y);
    } else if (r < 0.0105) {
      addPickup(s, 'bomb', e.x, e.y);
    }
  }

  if (e.type == 'slime') {
    final scale = waveScale(s.wave.n);
    for (var i = 0; i < 2; i++) {
      final x = e.x + randRange(s, -12, 12);
      final y = e.y + randRange(s, -12, 12);
      spawnEnemy(s, 'slimelet', x, y, scale, e.elite);
    }
  }
}

void hurtPlayer(GameState s, Player p, double raw) {
  if (p.dead || s.cfg.godMode) return;
  if (p.dashT > 0) {
    // dashing through an attack: no damage, just feedback
    s.events.add(DodgeEvent(p.id));
    return;
  }
  if (p.invuln > 0) return;
  var dmg = math.max(1.0, raw - p.stats.armor) * (1 - p.stats.dr);
  if (isRaging(p)) dmg *= 1.25;
  p.hp -= dmg;
  p.invuln = 0.45;
  p.hurtT = 0.25;
  s.events.add(PlayerHurtEvent(p.id, roundInt(dmg)));
  if (p.hp <= 0) {
    p.hp = 0;
    p.dead = true;
    s.events.add(PlayerDeathEvent(p.id));
  }
}

void slowEnemy(Enemy e, double amount, double time) {
  if (e.boss) amount *= 0.4;
  if (amount >= e.slowAmt || e.slowT <= 0) e.slowAmt = amount;
  e.slowT = math.max(e.slowT, time);
}

String enemyName(String type) => enemyDefs[type]?.name ?? type;
