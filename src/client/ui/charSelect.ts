// Character select screen.

import { CHARACTERS, CHARACTER_IDS } from '../../sim/content/characters';
import { WEAPONS } from '../../sim/content/weapons';
import { drawCharacterBody } from '../render/heroes';
import { byId, el, esc } from './dom';

export function portrait(charId: string, size = 192): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  const g = c.getContext('2d')!;
  g.scale(size / 72, size / 72);
  g.fillStyle = 'rgba(0,0,0,0.35)';
  g.beginPath();
  g.ellipse(32, 60, 16, 5, 0, 0, Math.PI * 2);
  g.fill();
  drawCharacterBody(g, charId, 32, 45, 15, 0.8, 0.25, 0);
  return c;
}

export function buildCharSelect(onPick: (id: string) => void): void {
  const grid = byId('char-grid');
  grid.innerHTML = '';
  for (const id of CHARACTER_IDS) {
    const c = CHARACTERS[id];
    const w = WEAPONS[c.weapon];
    const card = el('div', 'char-card panel accent');
    card.style.setProperty('--c', c.accent);
    const top = el('div', 'top');
    top.appendChild(portrait(id));
    top.appendChild(el('div', '', `<div class="name">${esc(c.name)}</div><div class="title">${esc(c.title)}</div>`));
    card.appendChild(top);
    card.appendChild(el('div', 'line', `<b>HP</b> ${c.hp} &nbsp; <b>Speed</b> ${c.speed}`));
    card.appendChild(el('div', 'line', `<b>Weapon</b> <span style="color:${w.color}">${w.icon}</span> ${esc(w.name)}`));
    card.appendChild(el('div', 'line', `<b>Passive</b> ${esc(c.passive)}`));
    card.appendChild(el('div', 'ability', `<strong>${esc(c.ability.name)}</strong> · ${c.ability.cd}s<br>${esc(c.ability.desc)}`));
    card.addEventListener('click', () => onPick(id));
    grid.appendChild(card);
  }
}
