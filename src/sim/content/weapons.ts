import type { Player, WeaponInst } from '../types';

export interface WStats {
  dmg: number;
  cd: number;
  amount: number;
  area: number;
  speed: number;
  pierce: number;
  duration: number;
  knock: number;
}

export interface WeaponDef {
  id: string;
  name: string;
  icon: string;
  color: string;
  desc: string;
  base: WStats;
  levels: Partial<WStats>[]; // deltas for levels 2..8
  /** Evolution paths. Each needs its perk owned; when several qualify the player picks one. */
  evos: EvoDef[];
  /** Only granted by the secret boss: never offered as a new weapon and takes no slot. */
  unique?: boolean;
}

export interface EvoDef {
  id: string;
  perk: string;
  name: string;
  desc: string;
  stats: Partial<WStats>;
}

export const MAX_WEAPON_LEVEL = 8;

const defs: WeaponDef[] = [
  {
    id: 'sword', name: 'Sword Arc', icon: '⚔', color: '#e8f1ff',
    desc: 'Slashes in a wide arc toward your aim.',
    base: { dmg: 20, cd: 1.2, amount: 1, area: 1, speed: 0, pierce: 999, duration: 0.2, knock: 260 },
    levels: [{ dmg: 6 }, { area: 0.15 }, { dmg: 8 }, { cd: -0.15 }, { amount: 1 }, { dmg: 10, area: 0.15 }, { dmg: 15 }],
    evos: [
      { id: 'holyblade', perk: 'armor', name: 'Holy Blade', desc: 'Spins a full circle of radiant steel.', stats: { dmg: 25, area: 0.4 } },
      { id: 'bladedancer', perk: 'crit', name: 'Blade Dancer', desc: 'A rapid flurry of crimson slashes all around you.', stats: { amount: 2, cd: -0.45, dmg: 12 } },
    ],
  },
  {
    id: 'bolt', name: 'Magic Bolt', icon: '✦', color: '#6ee7ff',
    desc: 'Fires homing bolts at the nearest enemy.',
    base: { dmg: 11, cd: 1.0, amount: 1, area: 1, speed: 430, pierce: 0, duration: 2.2, knock: 80 },
    levels: [{ amount: 1 }, { dmg: 5 }, { cd: -0.15 }, { amount: 1 }, { dmg: 6 }, { pierce: 1 }, { amount: 1 }],
    evos: [
      { id: 'arcanestorm', perk: 'haste', name: 'Arcane Storm', desc: 'A relentless torrent of seeking bolts.', stats: { cd: -0.4, amount: 2, dmg: 8, pierce: 1 } },
      { id: 'prism', perk: 'area', name: 'Prism Lance', desc: 'Huge lances of light that pierce everything in their path.', stats: { dmg: 24, pierce: 40, area: 0.9, speed: 180, cd: 0.1 } },
    ],
  },
  {
    id: 'arrow', name: 'Piercing Arrow', icon: '➶', color: '#b6ff7a',
    desc: 'Fast arrows that pierce through enemies.',
    base: { dmg: 14, cd: 0.9, amount: 1, area: 1, speed: 760, pierce: 2, duration: 1.2, knock: 60 },
    levels: [{ dmg: 5 }, { amount: 1 }, { pierce: 2 }, { cd: -0.15 }, { amount: 1 }, { dmg: 8 }, { pierce: 3 }],
    evos: [
      { id: 'phantom', perk: 'crit', name: 'Phantom Volley', desc: 'Endless spectral arrows that never stop.', stats: { amount: 3, pierce: 30, dmg: 10 } },
    ],
  },
  {
    id: 'orbs', name: 'Soul Orbs', icon: '◉', color: '#c084ff',
    desc: 'Orbs circle around you, hitting enemies.',
    base: { dmg: 10, cd: 4, amount: 2, area: 1, speed: 3.2, pierce: 999, duration: 3, knock: 140 },
    levels: [{ amount: 1 }, { area: 0.15, speed: 0.4 }, { dmg: 6 }, { duration: 1 }, { amount: 1 }, { dmg: 8 }, { amount: 1 }],
    evos: [
      { id: 'eternal', perk: 'duration', name: 'Eternal Souls', desc: 'The orbs never fade.', stats: { dmg: 10, area: 0.2, speed: 0.8 } },
    ],
  },
  {
    id: 'axe', name: 'Boomerang Axe', icon: '⟲', color: '#ffb347',
    desc: 'Throws an axe toward your aim that returns.',
    base: { dmg: 24, cd: 1.6, amount: 1, area: 1, speed: 560, pierce: 999, duration: 1.3, knock: 180 },
    levels: [{ dmg: 8 }, { amount: 1 }, { area: 0.2 }, { cd: -0.2 }, { dmg: 10 }, { amount: 1 }, { dmg: 12 }],
    evos: [
      { id: 'whirlwind', perk: 'might', name: 'Whirlwind', desc: 'Huge spinning axes shred everything.', stats: { amount: 2, area: 0.5, dmg: 18 } },
      { id: 'twinreavers', perk: 'multishot', name: 'Twin Reavers', desc: 'Axes fly out in every direction at once.', stats: { amount: 4, dmg: 12, duration: 0.3 } },
    ],
  },
  {
    id: 'lightning', name: 'Chain Lightning', icon: 'ϟ', color: '#fff36b',
    desc: 'Strikes a random enemy and chains to others.',
    base: { dmg: 15, cd: 1.8, amount: 1, area: 1, speed: 0, pierce: 2, duration: 0, knock: 0 },
    levels: [{ pierce: 1 }, { dmg: 5 }, { amount: 1 }, { cd: -0.2 }, { pierce: 1 }, { dmg: 6 }, { amount: 1 }],
    evos: [
      { id: 'thunderstorm', perk: 'multishot', name: 'Thunderstorm', desc: 'The sky itself rains lightning.', stats: { amount: 2, pierce: 2, dmg: 10 } },
    ],
  },
  {
    id: 'aura', name: 'Holy Aura', icon: '☀', color: '#ffe08a',
    desc: 'Damages all enemies around you.',
    base: { dmg: 6, cd: 0.5, amount: 0, area: 1, speed: 0, pierce: 0, duration: 0, knock: 40 },
    levels: [{ area: 0.15 }, { dmg: 3 }, { area: 0.15 }, { cd: -0.08 }, { dmg: 4 }, { area: 0.2 }, { dmg: 5 }],
    evos: [
      { id: 'sanctuary', perk: 'vitality', name: 'Sanctuary', desc: 'A vast holy field that also heals you.', stats: { area: 0.35, dmg: 8 } },
    ],
  },
  {
    id: 'nova', name: 'Fire Nova', icon: '✹', color: '#ff7043',
    desc: 'Releases an expanding ring of fire.',
    base: { dmg: 22, cd: 3.0, amount: 1, area: 1, speed: 0, pierce: 999, duration: 0.6, knock: 220 },
    levels: [{ dmg: 8 }, { area: 0.2 }, { cd: -0.4 }, { amount: 1 }, { dmg: 12 }, { area: 0.25 }, { cd: -0.4 }],
    evos: [
      { id: 'inferno', perk: 'area', name: 'Inferno', desc: 'Waves of hellfire engulf the battlefield.', stats: { amount: 2, dmg: 22, area: 0.4 } },
      { id: 'supernova', perk: 'might', name: 'Supernova', desc: 'One colossal blast with enormous damage and knockback.', stats: { dmg: 75, area: 0.9, cd: 1.2, knock: 300 } },
    ],
  },
  {
    id: 'turret', name: 'Turret', icon: '♜', color: '#7dffcf',
    desc: 'Deploys an auto-firing turret.',
    base: { dmg: 8, cd: 5, amount: 1, area: 1, speed: 640, pierce: 0, duration: 10, knock: 40 },
    levels: [{ dmg: 4 }, { amount: 1 }, { duration: 4 }, { cd: -1 }, { dmg: 5 }, { amount: 1 }, { dmg: 6 }],
    evos: [
      { id: 'tesla', perk: 'magnet', name: 'Tesla Array', desc: 'Turrets fire chain lightning.', stats: { amount: 1, dmg: 10 } },
      { id: 'mortar', perk: 'area', name: 'Mortar Battery', desc: 'Turrets lob explosive shells that blast whole groups.', stats: { dmg: 24, amount: 1 } },
    ],
  },
  {
    id: 'frost', name: 'Frost Ring', icon: '❄', color: '#9ad8ff',
    desc: 'Bursts of ice shards that slow enemies.',
    base: { dmg: 9, cd: 2.4, amount: 6, area: 1, speed: 380, pierce: 1, duration: 0.7, knock: 40 },
    levels: [{ amount: 2 }, { dmg: 4 }, { cd: -0.3 }, { amount: 2 }, { pierce: 1 }, { dmg: 6 }, { amount: 4 }],
    evos: [
      { id: 'abszero', perk: 'swift', name: 'Absolute Zero', desc: 'Shards freeze enemies solid.', stats: { amount: 8, dmg: 12, pierce: 3 } },
    ],
  },
  {
    // pierce = ricochets; a coin that kills gets a bonus ricochet (systems/weapons/coins.ts)
    id: 'coins', name: "Goldfang's Coin Toss", icon: '¤', color: '#ffc83d', unique: true,
    desc: 'Tosses a fan of gold coins that ricochet between enemies. Kills earn extra bounces.',
    base: { dmg: 15, cd: 1.1, amount: 3, area: 1, speed: 620, pierce: 2, duration: 1.4, knock: 50 },
    levels: [{ dmg: 5 }, { amount: 1 }, { pierce: 1 }, { cd: -0.15 }, { dmg: 7 }, { amount: 1 }, { dmg: 8, pierce: 2 }],
    evos: [],
  },
];

export const WEAPONS: Record<string, WeaponDef> = Object.fromEntries(defs.map((d) => [d.id, d]));
/** Weapons that level-ups may offer as new; unique ones are excluded. */
export const WEAPON_IDS = defs.filter((d) => !d.unique).map((d) => d.id);
export const UNIQUE_WEAPON_IDS = defs.filter((d) => d.unique).map((d) => d.id);
/** Owned weapons that count against MAX_SLOTS. */
export const slottedWeapons = (ws: readonly WeaponInst[]) => ws.filter((w) => !WEAPONS[w.id].unique).length;

const STAT_KEYS: (keyof WStats)[] = ['dmg', 'cd', 'amount', 'area', 'speed', 'pierce', 'duration', 'knock'];

export function evoDef(weaponId: string, evoId: string): EvoDef | undefined {
  return WEAPONS[weaponId]?.evos.find((e) => e.id === evoId);
}

/** Display name: the evolution's name once evolved. */
export function weaponName(w: WeaponInst): string {
  return evoDef(w.id, w.evo)?.name ?? WEAPONS[w.id].name;
}

/** Weapon stats from its level only (no player modifiers). */
export function baseWeaponStats(def: WeaponDef, level: number, evo = ''): WStats {
  const s = { ...def.base };
  for (let i = 0; i < level - 1 && i < def.levels.length; i++) {
    const d = def.levels[i];
    for (const k of STAT_KEYS) s[k] += d[k] ?? 0;
  }
  const e = def.evos.find((x) => x.id === evo);
  if (e) for (const k of STAT_KEYS) s[k] += e.stats[k] ?? 0;
  return s;
}

/** Weapon stats with player modifiers applied. */
export function weaponStats(p: Player, w: WeaponInst): WStats {
  const s = baseWeaponStats(WEAPONS[w.id], w.level, w.evo);
  s.cd = Math.max(0.05, s.cd * p.stats.cooldown);
  s.amount += p.stats.amount;
  s.area *= p.stats.area;
  s.duration *= p.stats.duration;
  return s;
}

const LABELS: Record<keyof WStats, string> = {
  dmg: 'damage', cd: 's cooldown', amount: 'amount', area: 'area', speed: 'speed',
  pierce: 'pierce', duration: 's duration', knock: 'knockback',
};

export function levelDesc(def: WeaponDef, level: number): string {
  if (level <= 1) return def.desc;
  const d = def.levels[level - 2];
  const parts: string[] = [];
  for (const k of STAT_KEYS) {
    const v = d[k];
    if (!v) continue;
    if (k === 'area') parts.push(`+${Math.round(v * 100)}% area`);
    else if (k === 'cd') parts.push(`${v}${LABELS[k]}`);
    else parts.push(`${v > 0 ? '+' : ''}${v} ${LABELS[k]}`);
  }
  return parts.join(', ');
}
