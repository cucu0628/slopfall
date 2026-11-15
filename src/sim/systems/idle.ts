import { addHazard } from '../entities';
import type { GameState, Player } from '../types';

// Anti-AFK: a player who stays within IDLE_RADIUS of the same spot without
// really moving for IDLE_GRACE seconds gets meteors dropped on them, each
// stronger than the last. Moving counts even inside the radius: dodging back
// and forth or circling a boss must not look like standing still.
export const IDLE_RADIUS = 160;
export const IDLE_GRACE = 8;
export const IDLE_WARNING = 3; // HUD warns this many seconds before the first meteor
/** A tick counts as moving when the player covers this share of their own speed (web slow is 0.55). */
const MOVING_SHARE = 0.3;
/** Moving winds the idle timer back this many times faster than standing winds it up. */
const MOVE_DRAIN = 1.5;
const SKYFALL_EVERY = 2.5;
const SKYFALL_RADIUS = 110;
const SKYFALL_WARN = 1.1;

const NECRO_HEAL_PER_SEC = 4;

export function updateIdle(s: GameState, p: Player, dt: number): void {
  if (p.charId === 'necro') p.healBudget = Math.min(NECRO_HEAL_PER_SEC, p.healBudget + NECRO_HEAL_PER_SEC * dt);
  const lsCap = p.stats.maxHp * p.stats.lifestealCap;
  p.lsBudget = Math.min(lsCap, p.lsBudget + lsCap * dt);

  if ((p.x - p.anchorX) ** 2 + (p.y - p.anchorY) ** 2 > IDLE_RADIUS * IDLE_RADIUS) {
    p.anchorX = p.x;
    p.anchorY = p.y;
    p.idleT = 0;
    p.skyfallCd = 0;
    p.skyfallN = 0;
    return;
  }
  // px/py hold the position from the start of this tick; pushing into a wall barely moves you, so it still counts as idle
  const moved = Math.hypot(p.x - p.px, p.y - p.py);
  if (moved >= p.stats.speed * dt * MOVING_SHARE) p.idleT = Math.max(0, p.idleT - dt * MOVE_DRAIN);
  else p.idleT += dt;
  if (p.idleT < IDLE_GRACE) {
    // back out of the danger zone: the next idle streak starts with the weakest meteor again
    p.skyfallCd = 0;
    p.skyfallN = 0;
    return;
  }
  p.skyfallCd -= dt;
  if (p.skyfallCd > 0) return;
  p.skyfallCd = SKYFALL_EVERY;
  p.skyfallN++;
  // % of max HP so it matters at any point of the run; armor is added back so it can't be tanked
  const dmg = (p.stats.maxHp * (0.25 + 0.1 * (p.skyfallN - 1)) + p.stats.armor) / (1 - p.stats.dr);
  addHazard(s, 'skyfall', { x: p.x, y: p.y, r: SKYFALL_RADIUS, warn: SKYFALL_WARN, life: 0.3, dmg });
  s.events.push({ t: 'sfx', name: 'warn' });
}
