// Codex screen: every enemy and boss with its artwork, base stats and what it does.

import { BOSS_ORDER, ENEMIES, WAVE_ENEMY_IDS, type EnemyDef } from '../../sim/content/enemies';
import { spawnEnemy } from '../../sim/entities';
import { BOSS_EVERY } from '../../sim/systems/waves';
import type { Enemy } from '../../sim/types';
import { createGame } from '../../sim/world';
import { drawEnemy } from '../render/entities';
import { CODEX_ENTRIES } from './codexEntries';
import { byId, el, esc } from './dom';

const SUMMONED_BY: Record<string, string> = { slimelet: 'Slime', egg: 'Brood Mother', skeleton: 'Necro Lord' };

/** Draws the enemy on a large scratch canvas, then crops and fits it into a square portrait. */
function portrait(e: Enemy, size = 160): HTMLCanvasElement {
  const W = 420;
  const scratch = document.createElement('canvas');
  scratch.width = scratch.height = W;
  const g = scratch.getContext('2d', { willReadFrequently: true })!;
  const cx = W / 2, cy = W / 2;
  if (e.type === 'wyrm') {
    e.ang = 0;
    e.trail = [];
    for (let i = 0; i < 9; i++) e.trail.push(cx - i * 22, cy + Math.sin(i * 0.8) * 16);
  }
  drawEnemy(g, e, cx, cy, 0.4, 0, 1);
  g.globalAlpha = 1;

  // bounding box of everything drawn
  const px = g.getImageData(0, 0, W, W).data;
  let x0 = W, y0 = W, x1 = 0, y1 = 0;
  for (let y = 0; y < W; y++) {
    for (let x = 0; x < W; x++) {
      if (px[(y * W + x) * 4 + 3] < 8) continue;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  const out = document.createElement('canvas');
  out.width = out.height = size;
  if (x1 < x0) return out;
  const bw = x1 - x0 + 1, bh = y1 - y0 + 1;
  // small enemies stay small so sizes still read relative to each other
  const k = Math.min((size * 0.9) / Math.max(bw, bh), 3.2);
  const o = out.getContext('2d')!;
  o.drawImage(scratch, x0, y0, bw, bh, (size - bw * k) / 2, (size - bh * k) / 2, bw * k, bh * k);
  return out;
}

function tagFor(d: EnemyDef): string {
  if (d.boss) return `Boss · wave ${(BOSS_ORDER.indexOf(d.id) + 1) * BOSS_EVERY}`;
  if (d.unlock > 0) return `From wave ${d.unlock}`;
  return `Summoned by ${SUMMONED_BY[d.id] ?? 'other enemies'}`;
}

function card(d: EnemyDef, e: Enemy): HTMLElement {
  const c = el('div', `codex-card${d.boss ? ' boss' : ''}`);
  c.style.setProperty('--c', d.color);
  const top = el('div', 'top');
  top.appendChild(portrait(e));
  const traits = [d.flying && !d.boss ? 'Flying' : ''].filter(Boolean).join(' · ');
  top.appendChild(el('div', '', `<div class="name">${esc(d.name)}</div><div class="tag">${esc(tagFor(d))}</div>`
    + (traits ? `<div class="tag">${esc(traits)}</div>` : '')));
  c.appendChild(top);
  const stat = (k: string, v: number) => `<span><b>${k}</b> ${v}</span>`;
  c.appendChild(el('div', 'stats-line', stat('HP', d.hp) + stat('DMG', d.dmg) + stat('SPD', d.speed) + stat('XP', d.xp)));
  c.appendChild(el('div', 'desc', esc(CODEX_ENTRIES[d.id] ?? '')));
  return c;
}

function section(title: string, note: string, ids: string[], enemies: Record<string, Enemy>): HTMLElement {
  const s = el('div', 'codex-section');
  s.appendChild(el('h3', '', esc(title)));
  if (note) s.appendChild(el('p', 'codex-note', note));
  const grid = el('div', 'codex-grid');
  for (const id of ids) grid.appendChild(card(ENEMIES[id], enemies[id]));
  s.appendChild(grid);
  return s;
}

let built = false;

/** Fills the codex on first open (drawing the portraits takes a moment). */
export function buildCodex(): void {
  if (built) return;
  built = true;
  // a throwaway game gives real enemy objects for the renderer to draw
  const s = createGame(1, [{ id: 'codex', charId: 'knight' }]);
  const enemies: Record<string, Enemy> = {};
  for (const id of Object.keys(ENEMIES)) enemies[id] = spawnEnemy(s, id, 0, 0, { hp: 1, dmg: 1, speed: 1 });

  const summoned = Object.keys(ENEMIES).filter((id) => !ENEMIES[id].boss && ENEMIES[id].unlock === 0);
  const root = byId('codex-list');
  root.innerHTML = '';
  root.appendChild(section(
    'Enemies',
    'Base stats at wave 1; every wave makes enemies tougher. A gold ring marks an <b>elite</b>: 6× HP, 1.5× damage and lots of XP.',
    [...WAVE_ENEMY_IDS].sort((a, b) => ENEMIES[a].unlock - ENEMIES[b].unlock),
    enemies,
  ));
  root.appendChild(section('Summoned', '', summoned, enemies));
  root.appendChild(section(
    'Bosses',
    `A boss arrives every ${BOSS_EVERY} waves, two at once from wave 20. Below 50% HP they become <b>enraged</b> and attack harder.`,
    BOSS_ORDER,
    enemies,
  ));
}
