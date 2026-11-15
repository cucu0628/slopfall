// Goldfang the Greedy, the secret boss. Whether (and on which boss wave) he
// shows up and what he drops is rolled once from the run seed, so a run can
// meet him at most once and reloading a save can't reroll either.

import { PERKS } from '../content/perks';
import { WEAPONS } from '../content/weapons';
import { hash } from '../map';
import type { GameState, Player, SecretState } from '../types';
import { BOSS_EVERY } from './waves';
import { refreshStats } from './leveling';

/** Chance per boss wave (from SECRET_FIRST_WAVE on) that Goldfang replaces the boss. */
export const SECRET_CHANCE = 0.03;
/** The first boss fight is always a regular one. */
export const SECRET_FIRST_WAVE = 10;
const MAX_BOSS_WAVES = 40;

export const SECRET_WEAPON = 'coins';
export const SECRET_PERK = 'goldpurse';

export function rollSecret(seed: number): SecretState {
  const reward = hash(seed, 7331, 1) % 2 === 0 ? 'weapon' : 'perk';
  for (let n = SECRET_FIRST_WAVE; n <= MAX_BOSS_WAVES * BOSS_EVERY; n += BOSS_EVERY) {
    if (hash(seed, 7331, 2, n) / 4294967296 < SECRET_CHANCE) return { wave: n, reward };
  }
  return { wave: 0, reward };
}

/** Picking up Goldfang's treasure: his unique weapon or perk, depending on the roll. */
export function grantSecretReward(s: GameState, p: Player): void {
  if (s.secret.reward === 'weapon') {
    const d = WEAPONS[SECRET_WEAPON];
    if (!p.weapons.some((w) => w.id === SECRET_WEAPON)) {
      p.weapons.push({ id: SECRET_WEAPON, level: 1, evolved: false, evo: '', cd: 0.3, t: 0, r: 0 });
    }
    s.events.push({ t: 'unique', pid: p.id, name: d.name, desc: d.desc });
  } else {
    const d = PERKS[SECRET_PERK];
    if (!p.perks.some((k) => k.id === SECRET_PERK)) p.perks.push({ id: SECRET_PERK, level: 1, power: 1 });
    refreshStats(p);
    s.events.push({ t: 'unique', pid: p.id, name: d.name, desc: d.desc(1) });
  }
}
