// Saving the current run in the browser (localStorage) so it can be
// continued after the tab is closed. Storage can be full or blocked
// (private mode); then runs simply aren't resumable.

import { CHARACTERS } from '../sim/content/characters';
import { restore, snapshot } from '../sim/save';
import type { GameState } from '../sim/types';

const SAVE_KEY = 'nightfall.run';

export function loadRun(): GameState | null {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    return raw ? restore(JSON.parse(raw)) : null;
  } catch {
    return null;
  }
}

export function saveRun(s: GameState): boolean {
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(snapshot(s, Date.now())));
    return true;
  } catch {
    return false;
  }
}

export function clearRun(): void {
  try {
    localStorage.removeItem(SAVE_KEY);
  } catch {
    // ignore
  }
}

/** The stored save as text for an export file, or null when there is no usable save. */
export function exportRun(): string | null {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    return raw && loadRun() ? raw : null;
  } catch {
    return null;
  }
}

/**
 * Validates an exported save and makes it the current save slot.
 * Returns the run, or null if the text is not a usable save or storage is blocked.
 */
export function importRun(text: string): GameState | null {
  try {
    const data: unknown = JSON.parse(text);
    const s = restore(data);
    if (!s) return null;
    localStorage.setItem(SAVE_KEY, JSON.stringify(data));
    return s;
  } catch {
    return null;
  }
}

/** File name for an exported save, e.g. "nightfall-mage-wave7.json". */
export function exportName(s: GameState): string {
  return `nightfall-${s.players[0].charId}-wave${s.wave.n}.json`;
}

/** One-line summary for the Continue button, e.g. "Mage · Wave 7 · Lv 21 · 5:12". */
export function describeRun(s: GameState): string {
  const p = s.players[0];
  const m = Math.floor(s.time / 60), sec = Math.floor(s.time % 60);
  return `${CHARACTERS[p.charId].name} · Wave ${s.wave.n} · Lv ${p.level} · ${m}:${String(sec).padStart(2, '0')}`;
}
