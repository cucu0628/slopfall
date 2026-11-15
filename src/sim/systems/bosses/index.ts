// Boss behaviours. Every boss has its own file; register it here by its
// enemy id (content/enemies.ts) and add it to BOSS_ORDER to make it spawn
// (the secret boss is spawned by systems/secret.ts instead).

import type { Enemy, GameState, Player } from '../../types';
import { broodMother } from './broodMother';
import { wyrm } from './frostWyrm';
import { goldfang, initGoldfang } from './goldfang';
import { golem } from './golem';
import { necroLord } from './necroLord';
import { slimeKing } from './slimeKing';
import { voidEye } from './voidEye';

export interface BossTick {
  s: GameState;
  e: Enemy;
  target: Player;
  d: number; // distance to target
  nx: number; // unit vector toward target
  ny: number;
  sp: number; // current move speed (slows applied)
  dt: number;
  enraged: boolean; // below 50% HP
}

interface BossBehavior {
  /** Initial attack timers when the boss spawns. */
  init: (e: Enemy) => void;
  update: (b: BossTick) => void;
}

const BOSSES: Record<string, BossBehavior> = {
  slimeking: {
    init: (e) => { e.t = 3; },
    update: (b) => slimeKing(b.s, b.e, b.target, b.nx, b.ny, b.sp, b.dt, b.enraged),
  },
  necrolord: {
    init: (e) => { e.t = 2; e.t2 = 3; e.t3 = 1; },
    update: (b) => necroLord(b.s, b.e, b.d, b.nx, b.ny, b.sp, b.dt, b.enraged),
  },
  golem: {
    init: (e) => { e.t = 3; e.t2 = 6; },
    update: (b) => golem(b.s, b.e, b.nx, b.ny, b.sp, b.dt, b.enraged),
  },
  voideye: {
    init: (e) => { e.t = 4; e.t2 = 0; },
    update: (b) => voidEye(b.s, b.e, b.d, b.nx, b.ny, b.sp, b.dt, b.enraged),
  },
  broodmother: {
    init: (e) => { e.t = 2.5; e.t2 = 1.5; e.t3 = 0.9; e.sx = 3; },
    update: (b) => broodMother(b.s, b.e, b.nx, b.ny, b.sp, b.dt, b.enraged),
  },
  wyrm: {
    init: (e) => { e.t = 2.5; e.t2 = 6; e.t3 = 2; },
    update: (b) => wyrm(b.s, b.e, b.target, b.d, b.nx, b.ny, b.sp, b.dt, b.enraged),
  },
  goldfang: {
    init: initGoldfang,
    update: (b) => goldfang(b.s, b.e, b.d, b.nx, b.ny, b.sp, b.dt, b.enraged),
  },
};

export function initBoss(e: Enemy): void {
  e.state = 0;
  BOSSES[e.type]?.init(e);
}

export function updateBoss(
  s: GameState, e: Enemy, target: Player, d: number, nx: number, ny: number, sp: number, dt: number,
): void {
  BOSSES[e.type]?.update({ s, e, target, d, nx, ny, sp, dt, enraged: e.hp < e.maxHp * 0.5 });
}

export { wyrmSegmentRadius } from './frostWyrm';
export { COIN_FUSE, GOLDFANG_ESCAPE } from './goldfang';
