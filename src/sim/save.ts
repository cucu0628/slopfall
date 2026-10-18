// Run snapshots for "continue where you left off". A snapshot keeps what
// defines the run (map seed, heroes and their build, wave, time, kills, the
// bosses still alive) and drops transient things (other enemies, projectiles,
// effects); a restored run simply spawns fresh enemies for the saved wave.

import { CHARACTERS } from './content/characters';
import type { GameState } from './types';

/** Bump when GameState changes shape so old saves are ignored instead of breaking. */
export const SAVE_VERSION = 3;

export interface RunSave {
  v: number;
  savedAt: number; // wall clock ms, for display only
  state: GameState;
}

export function snapshot(s: GameState, savedAt: number): RunSave {
  const state: GameState = {
    ...s,
    // bosses keep their HP: respawning the whole boss wave let players farm boss chests by reloading
    enemies: s.enemies.filter((e) => e.boss && !e.dead),
    projectiles: [],
    eprojectiles: [],
    zones: [],
    hazards: [],
    turrets: [],
    minions: [],
    pickups: s.pickups.filter((p) => p.kind === 'chest' && !p.dead),
    corpses: [],
    events: [],
  };
  return { v: SAVE_VERSION, savedAt, state: JSON.parse(JSON.stringify(state)) as GameState };
}

/** Returns a playable state from a snapshot, or null if it is unusable. */
export function restore(save: unknown): GameState | null {
  const sv = save as RunSave | null;
  if (!sv || sv.v !== SAVE_VERSION || !sv.state || !Array.isArray(sv.state.players)) return null;
  const s = JSON.parse(JSON.stringify(sv.state)) as GameState;
  if (s.gameOver || s.players.length === 0 || s.players.some((p) => !CHARACTERS[p.charId] || p.dead)) return null;
  for (const p of s.players) {
    p.px = p.x;
    p.py = p.y;
    p.anchorX = p.x;
    p.anchorY = p.y;
    p.idleT = 0;
    p.dashT = 0;
    p.slowT = 0;
    p.invuln = 2; // a moment to get your bearings
  }
  s.events = [];
  s.wave.spawnAcc = 6;
  return s;
}
