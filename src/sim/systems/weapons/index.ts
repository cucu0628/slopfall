// Weapon behaviours. Every weapon has its own file and is registered here by
// id; the id must match its data entry in content/weapons.ts.

import { weaponStats, type WStats } from '../../content/weapons';
import { isRaging } from '../../combat';
import type { GameState, Player, WeaponInst } from '../../types';
import { fireArrow } from './arrow';
import { updateAura } from './aura';
import { fireAxe } from './axe';
import { fireBolt } from './bolt';
import { fireCoins } from './coins';
import { fireFrost } from './frost';
import { fireLightning } from './lightning';
import { fireNova } from './nova';
import { updateOrbs } from './orbs';
import { fireSword } from './sword';
import { deployTurret } from './turret';

/** Called every tick for each weapon the player owns. `w.cd` is already ticked down. */
export type WeaponUpdate = (s: GameState, p: Player, w: WeaponInst, st: WStats, dt: number) => void;

const WEAPON_UPDATES: Record<string, WeaponUpdate> = {
  sword: fireSword,
  bolt: fireBolt,
  arrow: fireArrow,
  orbs: updateOrbs,
  axe: fireAxe,
  lightning: fireLightning,
  aura: updateAura,
  nova: fireNova,
  turret: deployTurret,
  frost: fireFrost,
  coins: fireCoins,
};

export function updateWeapons(s: GameState, p: Player, dt: number): void {
  const rate = isRaging(p) ? 1.5 : 1;
  for (const w of p.weapons) {
    const st = weaponStats(p, w);
    w.cd -= dt * rate;
    WEAPON_UPDATES[w.id]?.(s, p, w, st, dt);
  }
}

export { chainLightning } from './shared';
export { placeTurret, updateTurrets } from './turret';
export { updateProjectiles } from './projectiles';
export { updateZones } from './zones';
export { updateMinions } from './minions';
