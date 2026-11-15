import type { Stats } from '../types';

export interface PerkDef {
  id: string;
  name: string;
  icon: string;
  color: string;
  max: number;
  /** Whether level-ups of this perk can roll Rare / Epic. */
  rarity: boolean;
  /** Effect of one level-up; `m` is the rarity multiplier (1 = common). */
  desc: (m: number) => string;
  /** `power` = sum of all taken level-ups weighted by their rarity. */
  apply: (s: Stats, power: number) => void;
}

/** Common / Rare / Epic: effect multiplier and roll chance of a perk level-up. */
export const RARITIES = [
  { name: 'Common', mul: 1, chance: 0.81, color: '#9aa3c4' },
  { name: 'Rare', mul: 1.4, chance: 0.15, color: '#4fa3ff' },
  { name: 'Epic', mul: 1.8, chance: 0.04, color: '#c084ff' },
];

const pct = (v: number) => `${Math.round(v * 10) / 10}%`;

const defs: PerkDef[] = [
  { id: 'might', name: 'Might', icon: '✊', color: '#ff5d5d', max: 5, rarity: true,
    desc: (m) => `+${pct(10 * m)} damage`,
    apply: (s, p) => { s.might += 0.1 * p; } },
  { id: 'haste', name: 'Haste', icon: '⌛', color: '#ffd166', max: 5, rarity: true,
    desc: (m) => `-${pct(8 * m)} weapon & ability cooldown`,
    apply: (s, p) => { s.cooldown *= Math.max(0.5, 1 - 0.08 * p); } },
  { id: 'swift', name: 'Swiftness', icon: '»', color: '#7ae7ff', max: 5, rarity: true,
    desc: (m) => `+${pct(8 * m)} movement speed`,
    apply: (s, p) => { s.speed *= 1 + 0.08 * p; } },
  { id: 'vitality', name: 'Vitality', icon: '♥', color: '#ff6b9a', max: 5, rarity: true,
    desc: (m) => `+${Math.round(20 * m)} max HP`,
    apply: (s, p) => { s.maxHp += 20 * p; } },
  { id: 'regen', name: 'Regeneration', icon: '✚', color: '#6bff8f', max: 5, rarity: true,
    desc: (m) => `+${(0.4 * m).toFixed(2).replace(/0$/, '')} HP per second`,
    apply: (s, p) => { s.regen += 0.4 * p; } },
  { id: 'armor', name: 'Armor', icon: '⬢', color: '#b0b8c8', max: 5, rarity: true,
    desc: (m) => `-${pct(6 * m)} damage taken (max 60%)`,
    apply: (s, p) => { s.dr += 0.06 * p; } },
  { id: 'magnet', name: 'Magnet', icon: '∪', color: '#5d9bff', max: 5, rarity: true,
    desc: (m) => `+${pct(30 * m)} pickup range`,
    apply: (s, p) => { s.magnet *= 1 + 0.3 * p; } },
  { id: 'area', name: 'Area', icon: '◎', color: '#ff9f43', max: 5, rarity: true,
    desc: (m) => `+${pct(10 * m)} area of effect`,
    apply: (s, p) => { s.area += 0.1 * p; } },
  { id: 'duration', name: 'Duration', icon: '∞', color: '#c38bff', max: 5, rarity: true,
    desc: (m) => `+${pct(12 * m)} effect duration`,
    apply: (s, p) => { s.duration += 0.12 * p; } },
  { id: 'multishot', name: 'Multishot', icon: '⁂', color: '#ffe66d', max: 2, rarity: false,
    desc: () => '+1 projectile amount',
    apply: (s, p) => { s.amount += Math.round(p); } },
  { id: 'crit', name: 'Critical', icon: '✷', color: '#ff4fd8', max: 5, rarity: true,
    desc: (m) => `+${pct(5 * m)} critical hit chance`,
    apply: (s, p) => { s.crit += 0.05 * p; } },
  { id: 'growth', name: 'Growth', icon: '❖', color: '#9dff6b', max: 5, rarity: true,
    desc: (m) => `+${pct(10 * m)} experience gained`,
    apply: (s, p) => { s.growth += 0.1 * p; } },
  { id: 'lifesteal', name: 'Vampirism', icon: '❣', color: '#e0315f', max: 5, rarity: true,
    desc: (m) => `Heal ${pct(1.2 * m)} of damage dealt (up to ${pct(1.8 * m)} max HP/s)`,
    apply: (s, p) => { s.lifesteal += 0.012 * p; s.lifestealCap += 0.018 * p; } },
  { id: 'burn', name: 'Ignite', icon: '♨', color: '#ff7a1a', max: 5, rarity: true,
    desc: (m) => `+${pct(8 * m)} chance to set enemies on fire (3s burn)`,
    apply: (s, p) => { s.burn += 0.08 * p; } },
];

export const PERKS: Record<string, PerkDef> = Object.fromEntries(defs.map((d) => [d.id, d]));
export const PERK_IDS = defs.map((d) => d.id);

/** Endless stackable upgrades offered once every weapon and perk is maxed. */
export interface BonusDef {
  id: string;
  name: string;
  icon: string;
  color: string;
  desc: string;
  max?: number; // stack limit (undefined = endless)
  apply: (s: Stats, count: number) => void;
}

const bonusDefs: BonusDef[] = [
  { id: 'power', name: 'Power Shard', icon: '◆', color: '#ff5d5d', desc: '+5% damage (stacks forever)',
    apply: (s, n) => { s.might += 0.05 * n; } },
  { id: 'life', name: 'Life Shard', icon: '♥', color: '#ff6b9a', desc: '+15 max HP (stacks forever)',
    apply: (s, n) => { s.maxHp += 15 * n; } },
  { id: 'time', name: 'Time Shard', icon: '⌛', color: '#ffd166', desc: '-3% cooldowns (stacks up to 15 times)', max: 15,
    apply: (s, n) => { s.cooldown *= Math.pow(0.97, Math.min(n, 15)); } },
  { id: 'reach', name: 'Reach Shard', icon: '◎', color: '#ff9f43', desc: '+5% area (stacks forever)',
    apply: (s, n) => { s.area += 0.05 * n; } },
  { id: 'fortune', name: 'Fortune Shard', icon: '✷', color: '#ff4fd8', desc: '+3% crit chance (stacks forever)',
    apply: (s, n) => { s.crit += 0.03 * n; } },
];

export const BONUSES: Record<string, BonusDef> = Object.fromEntries(bonusDefs.map((d) => [d.id, d]));
export const BONUS_IDS = bonusDefs.map((d) => d.id);
