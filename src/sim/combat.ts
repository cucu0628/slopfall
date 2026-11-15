import { ENEMIES } from './content/enemies';
import { addPickup, spawnEnemy, type EnemyScale } from './entities';
import { rand, randRange } from './rng';
import type { Enemy, GameState, Player } from './types';

export function waveScale(n: number): EnemyScale {
  const w = n - 1;
  // After wave 20 enemies grow exponentially so a maxed build can't idle forever.
  const late = Math.max(0, n - 20);
  return {
    hp: (1 + 0.15 * w + 0.012 * w * w) * Math.pow(1.07, late),
    dmg: (1 + 0.05 * w + 0.0025 * w * w) * Math.pow(1.03, late),
    speed: Math.min(1.35, 1 + 0.007 * w),
  };
}

export function isRaging(p: Player): boolean {
  return p.charId === 'berserker' && p.abilityT > 0;
}

export function isOverclocked(p: Player): boolean {
  return p.charId === 'engineer' && p.abilityT > 0;
}

export function playerDmgMult(p: Player): number {
  let m = p.stats.might;
  if (p.charId === 'berserker') m *= 1 + 0.5 * (1 - p.hp / p.stats.maxHp);
  if (isRaging(p)) m *= 1.3 + 0.1 * (p.abilityLevel - 1);
  return m;
}

export function healPlayer(s: GameState, p: Player, v: number): void {
  if (p.dead || p.hp >= p.stats.maxHp) return;
  const before = p.hp;
  p.hp = Math.min(p.stats.maxHp, p.hp + v);
  if (v >= 5) s.events.push({ t: 'heal', pid: p.id, v: Math.round(p.hp - before) });
}

/** Burn damage per second, as a fraction of the igniting hit. */
export const IGNITE_DPS = 0.25;
export const IGNITE_TIME = 3;
const BURN_TICK = 0.5;

/** Sets an enemy on fire; a stronger burn replaces a weaker one, time is extended. */
export function ignite(e: Enemy, ownerId: string, dps: number, time: number): void {
  if (e.dead) return;
  if (dps >= e.burnDps || e.burnT <= 0) {
    e.burnDps = dps;
    e.burnOwner = ownerId;
  }
  if (e.burnT <= 0) e.burnTick = BURN_TICK;
  e.burnT = Math.max(e.burnT, time);
}

/** Burn damage over time; called every tick for each enemy. */
export function updateBurn(s: GameState, e: Enemy, dt: number): void {
  if (e.burnT <= 0) return;
  e.burnT -= dt;
  e.burnTick -= dt;
  if (e.burnTick > 0) return;
  e.burnTick += BURN_TICK;
  const owner = s.players.find((p) => p.id === e.burnOwner) ?? null;
  damageEnemy(s, e, e.burnDps * BURN_TICK, owner, 'burn', 0, 0, 0, true);
}

/**
 * Deals damage to an enemy. `base` is the raw weapon damage before the
 * owner's multipliers. `dot` marks damage over time (no crits, no ignite).
 * Returns true if the enemy died.
 */
export function damageEnemy(
  s: GameState, e: Enemy, base: number, owner: Player | null, src: string,
  dirX = 0, dirY = 0, knock = 0, dot = false,
): boolean {
  if (e.dead || e.intangible) return false;
  let dmg = base;
  let crit = false;
  if (owner) {
    dmg *= playerDmgMult(owner);
    if (!dot && rand(s) < owner.stats.crit) {
      dmg *= 2;
      crit = true;
    }
  }
  const dealt = Math.min(dmg, e.hp);
  e.hp -= dmg;
  if (e.flash <= 0) e.flash = 0.12;
  if (knock > 0 && !e.boss) {
    const k = e.elite ? knock * 0.4 : knock;
    e.kx += dirX * k;
    e.ky += dirY * k;
  }
  if (owner) {
    owner.dmgDealt[src] = (owner.dmgDealt[src] ?? 0) + dealt;
    // lifesteal is limited per second (lsBudget refills from lifestealCap)
    if (owner.stats.lifesteal > 0 && owner.lsBudget > 0) {
      const heal = Math.min(owner.lsBudget, dealt * owner.stats.lifesteal);
      owner.lsBudget -= heal;
      healPlayer(s, owner, heal);
    }
    if (!dot && owner.stats.burn > 0 && e.hp > 0 && rand(s) < owner.stats.burn) {
      ignite(e, owner.id, base * IGNITE_DPS, IGNITE_TIME);
    }
  }
  s.events.push({ t: 'hit', x: e.x, y: e.y - e.radius, v: Math.round(dmg), crit, dot });

  if (e.type === 'slimeking' && e.hp > 0) {
    e.dmgAcc += dealt;
    while (e.dmgAcc >= e.maxHp * 0.07) {
      e.dmgAcc -= e.maxHp * 0.07;
      for (let i = 0; i < 2; i++) {
        const a = rand(s) * Math.PI * 2;
        spawnEnemy(s, 'slimelet', e.x + Math.cos(a) * e.radius, e.y + Math.sin(a) * e.radius, waveScale(s.wave.n));
      }
    }
  }

  if (e.hp <= 0) {
    killEnemy(s, e, owner);
    return true;
  }
  return false;
}

export function killEnemy(s: GameState, e: Enemy, owner: Player | null): void {
  if (e.dead) return;
  e.dead = true;
  s.kills++;
  if (owner) {
    owner.kills++;
    if (owner.charId === 'necro' && owner.healBudget >= 1) {
      owner.healBudget -= 1;
      healPlayer(s, owner, 1);
    }
  }
  s.events.push({ t: 'kill', x: e.x, y: e.y, type: e.type, elite: e.elite, boss: e.boss, r: e.radius });
  s.corpses.push({ x: e.x, y: e.y, t: s.time });
  if (s.corpses.length > 40) s.corpses.shift();

  addPickup(s, 'xp', e.x, e.y, e.xp);
  if (e.boss) {
    // the secret boss drops his treasure (unique weapon or perk) instead of a chest
    addPickup(s, e.type === 'goldfang' ? 'relic' : 'chest', e.x, e.y, 0, true);
    addPickup(s, 'heal', e.x + 30, e.y, 0);
  } else if (e.chest) {
    addPickup(s, 'chest', e.x, e.y, 0);
  } else if (!e.elite) {
    const r = rand(s);
    if (r < 0.006) addPickup(s, 'heal', e.x, e.y);
    else if (r < 0.0085) addPickup(s, 'magnet', e.x, e.y);
    else if (r < 0.0105) addPickup(s, 'bomb', e.x, e.y);
  }

  if (e.type === 'slime') {
    const scale = waveScale(s.wave.n);
    for (let i = 0; i < 2; i++) {
      spawnEnemy(s, 'slimelet', e.x + randRange(s, -12, 12), e.y + randRange(s, -12, 12), scale, e.elite);
    }
  }
}

export function hurtPlayer(s: GameState, p: Player, raw: number): void {
  if (p.dead || s.cfg.godMode) return;
  if (p.dashT > 0) {
    // dashing through an attack: no damage, just feedback
    s.events.push({ t: 'dodge', pid: p.id });
    return;
  }
  if (p.invuln > 0) return;
  let dmg = Math.max(1, raw - p.stats.armor) * (1 - p.stats.dr);
  if (isRaging(p)) dmg *= 1.25;
  p.hp -= dmg;
  p.invuln = 0.45;
  p.hurtT = 0.25;
  s.events.push({ t: 'phurt', pid: p.id, v: Math.round(dmg) });
  if (p.hp <= 0) {
    p.hp = 0;
    p.dead = true;
    s.events.push({ t: 'pdeath', pid: p.id });
  }
}

export function slowEnemy(e: Enemy, amount: number, time: number): void {
  if (e.boss) amount *= 0.4;
  if (amount >= e.slowAmt || e.slowT <= 0) e.slowAmt = amount;
  e.slowT = Math.max(e.slowT, time);
}

export const enemyName = (type: string) => ENEMIES[type]?.name ?? type;
