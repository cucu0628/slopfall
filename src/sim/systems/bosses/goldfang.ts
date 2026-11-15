// Goldfang the Greedy (secret boss): never attacks, keeps just out of reach
// and escapes with his treasure after GOLDFANG_ESCAPE seconds. He drops coins
// while running; every third one is a fake that blows up when stepped near.

import { waveScale } from '../../combat';
import { addHazard, addPickup } from '../../entities';
import { randRange } from '../../rng';
import type { Enemy, GameState } from '../../types';

export const GOLDFANG_ESCAPE = 25;
/** Fuse of a fake coin once a player steps close. */
export const COIN_FUSE = 0.5;

export function initGoldfang(e: Enemy): void {
  e.t = GOLDFANG_ESCAPE; // escape timer
  e.t2 = 1.5; // next coin
  e.t3 = 0; // coins dropped
  e.sx = 2; // next strafe direction change
  e.sy = 1; // strafe direction
}

export function goldfang(s: GameState, e: Enemy, d: number, nx: number, ny: number, sp: number, dt: number, enraged: boolean): void {
  e.t -= dt;
  if (e.t <= 0) {
    e.dead = true; // got away: no kill, no treasure
    s.events.push({ t: 'escape', x: e.x, y: e.y, name: 'Goldfang' });
    s.events.push({ t: 'explode', x: e.x, y: e.y, r: 90, color: '#ffc83d' });
    return;
  }

  e.sx -= dt;
  if (e.sx <= 0) {
    e.sx = randRange(s, 1.8, 3.5);
    e.sy = -e.sy;
  }
  // stays close enough to be shot at, but runs from anyone who gets near
  const speed = sp * (enraged ? 1.15 : 1);
  let mx: number, my: number;
  if (d < 280) {
    mx = -nx - ny * e.sy * 0.6;
    my = -ny + nx * e.sy * 0.6;
  } else if (d > 440) {
    mx = nx;
    my = ny;
  } else {
    mx = -ny * e.sy;
    my = nx * e.sy;
  }
  const l = Math.hypot(mx, my) || 1;
  e.x += (mx / l) * speed * dt;
  e.y += (my / l) * speed * dt;
  e.ang = Math.atan2(my, mx);

  e.t2 -= dt;
  if (e.t2 <= 0) {
    e.t2 = enraged ? 0.75 : 1.1;
    e.t3++;
    if (e.t3 % 3 === 0) {
      // speed = 1 once the fuse is lit (systems/hazards.ts)
      addHazard(s, 'coin', { x: e.x, y: e.y, r: 65, dmg: 14 * waveScale(s.wave.n).dmg, warn: 8, life: 0.05 });
    } else {
      addPickup(s, 'coin', e.x, e.y, Math.round(3 + s.wave.n * 0.5));
    }
  }
}
