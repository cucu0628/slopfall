import { ABILITY_MAX_LEVEL, CHARACTERS } from '../content/characters';
import { BONUSES, BONUS_IDS, PERKS, PERK_IDS, RARITIES, slottedPerks } from '../content/perks';
import { MAX_WEAPON_LEVEL, UNIQUE_WEAPON_IDS, WEAPONS, WEAPON_IDS, slottedWeapons } from '../content/weapons';
import { healPlayer } from '../combat';
import { rand, weightedPick } from '../rng';
import type { GameState, Player, Stats, UpgradeOption, WeaponInst } from '../types';

export const MAX_SLOTS = 6;

export function xpForLevel(level: number): number {
  return Math.floor(6 + level * 6 + 0.32 * level * level);
}

export function computeStats(p: Player): Stats {
  const c = CHARACTERS[p.charId];
  const s: Stats = {
    might: 1, cooldown: 1, speed: c.speed, maxHp: c.hp, regen: 0, armor: 0, magnet: 75,
    area: 1, duration: 1, amount: 0, crit: 0.05, growth: 1, lifesteal: 0, lifestealCap: 0, dr: 0, burn: 0, gemDouble: 0, maxHpMul: 1,
  };
  s.maxHp += p.vigorHp;
  for (const k of Object.keys(c.mods) as (keyof Stats)[]) s[k] += c.mods[k] ?? 0;
  for (const perk of p.perks) PERKS[perk.id].apply(s, perk.power);
  for (const id in p.bonus) BONUSES[id].apply(s, p.bonus[id]);
  s.maxHp *= s.maxHpMul;
  s.dr = Math.min(0.6, s.dr);
  s.burn = Math.min(1, s.burn);
  return s;
}

export function refreshStats(p: Player): void {
  const oldMax = p.stats.maxHp;
  p.stats = computeStats(p);
  if (p.stats.maxHp > oldMax) p.hp += p.stats.maxHp - oldMax;
  p.hp = Math.min(p.hp, p.stats.maxHp);
}

export function createPlayer(id: string, charId: string, x: number, y: number): Player {
  const c = CHARACTERS[charId];
  const p: Player = {
    id, charId, x, y, px: x, py: y, fx: 1, fy: 0, ax: 1, ay: 0,
    hp: c.hp, stats: null as unknown as Stats, radius: 14,
    level: 1, xp: 0, xpNext: xpForLevel(1),
    weapons: [{ id: c.weapon, level: 1, evolved: false, evo: '', cd: 0.5, t: 0, r: 0 }],
    perks: [],
    abilityLevel: 1, abilityCd: 0, abilityMaxCd: c.ability.cd, abilityT: 0,
    invuln: 0, hurtT: 0, dashT: 0, dashX: 0, dashY: 0, dashCd: 0, dashMaxCd: 0, bonus: {}, vigorHp: 0,
    healBudget: 0, lsBudget: 0, idleT: 0, anchorX: x, anchorY: y, skyfallCd: 0, skyfallN: 0, slowT: 0, evoQueue: [],
    pendingLevels: 0, choices: null, dead: false, kills: 0, dmgDealt: {},
  };
  p.stats = computeStats(p);
  p.hp = p.stats.maxHp;
  return p;
}

export function addXp(s: GameState, p: Player, amount: number): void {
  if (p.dead) return;
  p.xp += amount * p.stats.growth;
  while (p.xp >= p.xpNext) {
    p.xp -= p.xpNext;
    p.level++;
    p.xpNext = xpForLevel(p.level);
    p.pendingLevels++;
    s.events.push({ t: 'levelup', pid: p.id });
  }
}

function upgradePool(p: Player): UpgradeOption[] {
  const pool: UpgradeOption[] = [];
  const weaponSlots = slottedWeapons(p.weapons), perkSlots = slottedPerks(p.perks);
  // unique weapons (secret boss reward) level up like the others once owned
  for (const id of [...WEAPON_IDS, ...UNIQUE_WEAPON_IDS]) {
    const w = p.weapons.find((x) => x.id === id);
    if (w) {
      if (w.level < MAX_WEAPON_LEVEL) pool.push({ kind: 'weapon', id, level: w.level + 1 });
    } else if (weaponSlots < MAX_SLOTS && !WEAPONS[id].unique) {
      pool.push({ kind: 'weapon', id, level: 1 });
    }
  }
  for (const id of PERK_IDS) {
    const k = p.perks.find((x) => x.id === id);
    if (k) {
      if (k.level < PERKS[id].max) pool.push({ kind: 'perk', id, level: k.level + 1, rarity: 0 });
    } else if (perkSlots < MAX_SLOTS) {
      pool.push({ kind: 'perk', id, level: 1, rarity: 0 });
    }
  }
  if (p.abilityLevel < ABILITY_MAX_LEVEL) pool.push({ kind: 'ability', id: 'ability', level: p.abilityLevel + 1 });
  return pool;
}

const optionWeight = (o: UpgradeOption) => (o.kind === 'ability' ? 1.1 : o.level > 1 ? 1.4 : 1);

function rollRarity(s: GameState): number {
  let r = rand(s);
  for (let i = RARITIES.length - 1; i > 0; i--) {
    if (r < RARITIES[i].chance) return i;
    r -= RARITIES[i].chance;
  }
  return 0;
}

/** Bonus shards that have not hit their stack limit yet. */
function availableBonuses(p: Player): string[] {
  return BONUS_IDS.filter((id) => (p.bonus[id] ?? 0) < (BONUSES[id].max ?? Infinity));
}

function bonusOption(p: Player, id: string): UpgradeOption {
  return { kind: 'bonus', id, level: (p.bonus[id] ?? 0) + 1 };
}

/**
 * Up to `count` distinct options. Once the regular pool runs dry the
 * remaining slots are filled with endless bonus shards, so a level-up is
 * never just a heal.
 */
export function rollChoices(s: GameState, p: Player, count = 3): UpgradeOption[] {
  const pool = upgradePool(p);
  const out: UpgradeOption[] = [];
  while (out.length < count && pool.length > 0) {
    const o = weightedPick(s, pool, optionWeight);
    pool.splice(pool.indexOf(o), 1);
    out.push(o.kind === 'perk' && PERKS[o.id].rarity ? { ...o, rarity: rollRarity(s) } : o);
  }
  if (out.length < count) {
    const bonus = availableBonuses(p);
    while (out.length < count && bonus.length > 0) {
      const id = bonus.splice(Math.floor(rand(s) * bonus.length), 1)[0];
      out.push(bonusOption(p, id));
    }
    if (p.hp < p.stats.maxHp * 0.5) out[out.length - 1] = { kind: 'heal', id: 'heal', level: 0 };
  }
  return out;
}

export function applyOption(s: GameState, p: Player, o: UpgradeOption): void {
  if (o.kind === 'weapon') {
    const w = p.weapons.find((x) => x.id === o.id);
    if (w) w.level = o.level;
    else p.weapons.push({ id: o.id, level: 1, evolved: false, evo: '', cd: 0.2, t: 0, r: 0 });
  } else if (o.kind === 'perk') {
    const k = p.perks.find((x) => x.id === o.id);
    const gain = RARITIES[o.rarity]?.mul ?? 1;
    if (k) {
      k.level = o.level;
      k.power += gain;
    } else {
      p.perks.push({ id: o.id, level: 1, power: gain });
    }
    refreshStats(p);
  } else if (o.kind === 'ability') {
    p.abilityLevel = o.level;
  } else if (o.kind === 'evo') {
    const w = p.weapons.find((x) => x.id === o.id);
    const e = WEAPONS[o.id].evos[o.level];
    if (w && e && !w.evolved) {
      w.evolved = true;
      w.evo = e.id;
      s.events.push({ t: 'evolve', pid: p.id, name: e.name });
    }
  } else if (o.kind === 'bonus') {
    p.bonus[o.id] = o.level;
    refreshStats(p);
  } else {
    healPlayer(s, p, p.stats.maxHp * 0.5);
  }
}

export function chooseUpgrade(s: GameState, p: Player, index: number): void {
  if (!p.choices) return;
  const o = p.choices[Math.max(0, Math.min(index, p.choices.length - 1))];
  applyOption(s, p, o);
  p.choices = null;
  s.events.push({ t: 'sfx', name: 'select' });
}

/** Evolutions of a weapon whose required perk the player owns. */
export function evoChoices(p: Player, weaponId: string): UpgradeOption[] {
  const out: UpgradeOption[] = [];
  WEAPONS[weaponId].evos.forEach((e, i) => {
    if (p.perks.some((k) => k.id === e.perk)) out.push({ kind: 'evo', id: weaponId, level: i });
  });
  return out;
}

function canEvolve(p: Player, w: WeaponInst): boolean {
  return !w.evolved && w.level >= MAX_WEAPON_LEVEL && !p.evoQueue.includes(w.id) && evoChoices(p, w.id).length > 0;
}

export function updateLeveling(s: GameState, p: Player): void {
  if (p.dead || p.choices) return;
  // A pending evolution pick comes before regular level-ups.
  while (p.evoQueue.length > 0) {
    const id = p.evoQueue.shift()!;
    const opts = evoChoices(p, id);
    if (opts.length > 0 && !p.weapons.find((w) => w.id === id)?.evolved) {
      p.choices = opts;
      return;
    }
  }
  if (p.pendingLevels > 0) {
    p.pendingLevels--;
    p.choices = rollChoices(s, p);
  }
}

export function optionName(o: UpgradeOption): string {
  if (o.kind === 'weapon') return `${WEAPONS[o.id].name} ${o.level > 1 ? 'Lv ' + o.level : '(new)'}`;
  if (o.kind === 'perk') return `${o.rarity > 0 ? RARITIES[o.rarity].name + ' ' : ''}${PERKS[o.id].name} ${o.level > 1 ? 'Lv ' + o.level : '(new)'}`;
  if (o.kind === 'ability') return `Ability Lv ${o.level}`;
  if (o.kind === 'evo') return WEAPONS[o.id].evos[o.level].name;
  if (o.kind === 'bonus') return BONUSES[o.id].name;
  return 'Heal';
}

/**
 * Chest: unlocks an evolution if a max level weapon qualifies (the player
 * then picks which one), otherwise grants random upgrades.
 */
export function openChest(s: GameState, p: Player, big: boolean): void {
  const items: string[] = [];
  let count = big ? 3 : 1;
  const w = p.weapons.find((x) => canEvolve(p, x));
  if (w) {
    p.evoQueue.push(w.id);
    items.push(`Evolution unlocked: ${WEAPONS[w.id].name}!`);
    count--;
  }
  for (let i = 0; i < count; i++) {
    const pool = upgradePool(p).filter((o) => o.level > 1);
    const opts = pool.length > 0 ? pool : upgradePool(p);
    const bonus = availableBonuses(p);
    const o = opts.length > 0
      ? opts[Math.floor(rand(s) * opts.length)]
      : bonus.length > 0 ? bonusOption(p, bonus[Math.floor(rand(s) * bonus.length)]) : null;
    if (!o) {
      healPlayer(s, p, p.stats.maxHp * 0.3);
      items.push('Heal');
      continue;
    }
    applyOption(s, p, o);
    items.push(optionName(o));
  }
  s.events.push({ t: 'chest', pid: p.id, items });
}
