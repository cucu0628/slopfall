// Codex screen: a bestiary laid out like a book. Chapter tabs on top, the
// entry index on the left page, the selected enemy on the right page.

import { BOSS_ORDER, ENEMIES, WAVE_ENEMY_IDS, type EnemyDef } from '../../sim/content/enemies';
import { spawnEnemy } from '../../sim/entities';
import { SECRET_CHANCE, SECRET_FIRST_WAVE } from '../../sim/systems/secret';
import { BOSS_EVERY } from '../../sim/systems/waves';
import type { Enemy } from '../../sim/types';
import { createGame } from '../../sim/world';
import { drawEnemy } from '../render/entities';
import { CODEX_ENTRIES } from './codexEntries';
import { byId, el, esc } from './dom';

const SUMMONED_BY: Record<string, string> = { slimelet: 'Slime', egg: 'Brood Mother', skeleton: 'Necro Lord' };

interface Chapter {
  title: string;
  note: string;
  ids: string[];
}

const CHAPTERS: Chapter[] = [
  {
    title: 'Creatures',
    note: 'Base stats at wave 1; every wave makes them tougher. A gold ring marks an <b>elite</b>: 6× HP, 1.5× damage and lots of XP.',
    ids: [...WAVE_ENEMY_IDS].sort((a, b) => ENEMIES[a].unlock - ENEMIES[b].unlock),
  },
  {
    title: 'Summoned',
    note: 'Never spawned by the night itself, only brought forth by other enemies.',
    ids: Object.keys(ENEMIES).filter((id) => !ENEMIES[id].boss && ENEMIES[id].unlock === 0),
  },
  {
    title: 'Bosses',
    note: `One arrives every ${BOSS_EVERY} waves, two at once from wave 20. Below 50% HP they become <b>enraged</b>.`,
    ids: BOSS_ORDER,
  },
  {
    title: 'Secrets',
    note: `Rare guests. From wave ${SECRET_FIRST_WAVE} each boss wave has a ${Math.round(SECRET_CHANCE * 100)}% chance to bring one instead of the boss, at most once per run.`,
    ids: Object.keys(ENEMIES).filter((id) => ENEMIES[id].boss && !BOSS_ORDER.includes(id)),
  },
];

/** Every entry in book order, for numbering and paging. */
const ORDER = CHAPTERS.flatMap((c) => c.ids);

/** Draws the enemy on a large scratch canvas, then crops and fits it into a square portrait. */
function renderPortrait(e: Enemy, size: number): HTMLCanvasElement {
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
  // small enemies stay smaller so sizes still read relative to each other
  const k = Math.min((size * 0.88) / Math.max(bw, bh), (size / 160) * 3.2);
  out.getContext('2d')!.drawImage(scratch, x0, y0, bw, bh, (size - bw * k) / 2, (size - bh * k) / 2, bw * k, bh * k);
  return out;
}

function copyCanvas(src: HTMLCanvasElement, size: number): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  c.getContext('2d')!.drawImage(src, 0, 0, size, size);
  return c;
}

function tagFor(d: EnemyDef): string {
  if (d.boss && !BOSS_ORDER.includes(d.id)) return `Secret boss · rare, from wave ${SECRET_FIRST_WAVE}`;
  if (d.boss) return `Boss · wave ${(BOSS_ORDER.indexOf(d.id) + 1) * BOSS_EVERY}`;
  return d.unlock > 0 ? `From wave ${d.unlock}` : `Summoned by ${SUMMONED_BY[d.id] ?? 'other enemies'}`;
}

const pad2 = (n: number) => String(n).padStart(2, '0');

let portraits: Record<string, HTMLCanvasElement> | null = null;
let chapter = 0;
let current = ORDER[0];

function chapterOf(id: string): number {
  return CHAPTERS.findIndex((c) => c.ids.includes(id));
}

function renderTabs(): void {
  const tabs = byId('codex-tabs');
  tabs.innerHTML = '';
  CHAPTERS.forEach((c, i) => {
    const b = el('button', `tome-tab${i === chapter ? ' active' : ''}`, `${esc(c.title)}<span>${c.ids.length}</span>`);
    b.setAttribute('role', 'tab');
    b.setAttribute('aria-selected', String(i === chapter));
    b.addEventListener('click', () => select(CHAPTERS[i].ids[0]));
    tabs.appendChild(b);
  });
}

function renderIndex(): void {
  const idx = byId('codex-index');
  idx.innerHTML = '';
  const list = el('ol', 'tome-list');
  for (const id of CHAPTERS[chapter].ids) {
    const d = ENEMIES[id];
    const li = el('li');
    const b = el('button', `tome-entry${id === current ? ' active' : ''}`);
    b.style.setProperty('--c', d.color);
    b.appendChild(copyCanvas(portraits![id], 64));
    b.appendChild(el('span', 'no', pad2(ORDER.indexOf(id) + 1)));
    b.appendChild(el('span', 'nm', esc(d.name)));
    b.addEventListener('click', () => select(id));
    li.appendChild(b);
    list.appendChild(li);
  }
  idx.appendChild(list);
  idx.appendChild(el('p', 'tome-note', CHAPTERS[chapter].note));
  idx.querySelector<HTMLElement>('.tome-entry.active')?.scrollIntoView({ block: 'nearest', inline: 'nearest' });
}

function statRow(label: string, v: number, max: number): string {
  const w = max > 0 ? Math.max(4, Math.round((v / max) * 100)) : 0;
  return `<div class="st"><span class="k">${label}</span><span class="bar"><i style="width:${w}%"></i></span><span class="v">${v}</span></div>`;
}

function renderPage(): void {
  const d = ENEMIES[current];
  const peers = CHAPTERS[chapter].ids.map((id) => ENEMIES[id]);
  const max = (f: (e: EnemyDef) => number) => Math.max(...peers.map(f));
  const page = byId('codex-page');
  page.innerHTML = '';
  page.style.setProperty('--c', d.color);
  page.classList.toggle('boss', !!d.boss);

  const head = el('header', 'page-head');
  const plate = el('div', 'plate');
  plate.appendChild(copyCanvas(portraits![current], 160));
  head.appendChild(plate);
  const entry = CODEX_ENTRIES[current];
  head.appendChild(el('div', 'page-title', `
    <div class="no">No. ${pad2(ORDER.indexOf(current) + 1)} · ${esc(tagFor(d))}</div>
    <div class="nm">${esc(d.name)}</div>
    <div class="chips">${(entry?.traits ?? []).map((t) => `<span>${esc(t)}</span>`).join('')}</div>`));
  page.appendChild(head);
  page.appendChild(el('div', 'rule', '<span>◆</span>'));
  page.appendChild(el('div', 'statblock',
    statRow('Health', d.hp, max((e) => e.hp))
    + statRow('Damage', d.dmg, max((e) => e.dmg))
    + statRow('Speed', d.speed, max((e) => e.speed))
    + statRow('XP', d.xp, max((e) => e.xp))));
  page.appendChild(el('section', 'page-sec', `<h4 class="label">Behaviour</h4><p class="lore">${esc(entry?.text ?? '')}</p>`));
  if (entry?.tip) page.appendChild(el('section', 'page-tip', `<h4 class="label">How to survive</h4><p>${esc(entry.tip)}</p>`));
  page.appendChild(el('p', 'tome-note', CHAPTERS[chapter].note)); // shown on phones, where the index is a strip
  const i = ORDER.indexOf(current);
  const foot = el('footer', 'folio');
  const prev = el('button', 'turn', '‹');
  const next = el('button', 'turn', '›');
  prev.setAttribute('aria-label', 'Previous entry');
  next.setAttribute('aria-label', 'Next entry');
  (prev as HTMLButtonElement).disabled = i === 0;
  (next as HTMLButtonElement).disabled = i === ORDER.length - 1;
  prev.addEventListener('click', () => turn(-1));
  next.addEventListener('click', () => turn(1));
  foot.append(prev, el('span', '', `${i + 1} / ${ORDER.length}`), next);
  page.appendChild(foot);
  page.scrollTop = 0;
  // replay the page-turn animation
  page.classList.remove('turned');
  void page.offsetWidth;
  page.classList.add('turned');
}

function select(id: string): void {
  current = id;
  chapter = chapterOf(id);
  renderTabs();
  renderIndex();
  renderPage();
}

function turn(dir: number): void {
  const i = ORDER.indexOf(current) + dir;
  if (i >= 0 && i < ORDER.length) select(ORDER[i]);
}

/** Arrow keys page through the book. Returns true when the key was used. */
export function codexKey(code: string): boolean {
  if (code === 'ArrowDown' || code === 'ArrowRight') turn(1);
  else if (code === 'ArrowUp' || code === 'ArrowLeft') turn(-1);
  else return false;
  return true;
}

/** Opens the codex; portraits are drawn on the first open. */
export function buildCodex(): void {
  if (!portraits) {
    // a throwaway game gives real enemy objects for the renderer to draw
    const s = createGame(1, [{ id: 'codex', charId: 'knight' }]);
    portraits = {};
    for (const id of ORDER) portraits[id] = renderPortrait(spawnEnemy(s, id, 0, 0, { hp: 1, dmg: 1, speed: 1 }), 160);
  }
  select(current);
}
