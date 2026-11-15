// Goldfang's Coin Toss (unique, secret boss reward): a fan of coins that
// ricochet from enemy to enemy. Bounces live in projectiles.ts.

import type { WStats } from '../../content/weapons';
import { addProjectile } from '../../entities';
import { nearestEnemy } from '../../spatial';
import type { GameState, Player, WeaponInst } from '../../types';
import { aimAngle } from './shared';

/** Extra ricochets a single coin can earn by killing. */
export const COIN_KILL_BOUNCES = 3;
export const COIN_BOUNCE_RANGE = 280;

export function fireCoins(s: GameState, p: Player, w: WeaponInst, st: WStats): void {
  if (w.cd > 0) return;
  w.cd = st.cd;
  const t = nearestEnemy(s, p.x, p.y, 700);
  const a0 = t ? Math.atan2(t.y - p.y, t.x - p.x) : aimAngle(p);
  for (let i = 0; i < st.amount; i++) {
    const a = a0 + (i - (st.amount - 1) / 2) * 0.2;
    addProjectile(s, {
      owner: p.id, src: 'coins', kind: 'coin', x: p.x, y: p.y,
      vx: Math.cos(a) * st.speed, vy: Math.sin(a) * st.speed, speed: st.speed,
      dmg: st.dmg, radius: 7 * st.area, pierce: st.pierce, life: st.duration, knock: st.knock,
    });
  }
  s.events.push({ t: 'sfx', name: 'coin' });
}
