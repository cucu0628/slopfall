// Game over summary and damage breakdown.

import { WEAPONS, weaponName } from '../../sim/content/weapons';
import type { GameState, Player } from '../../sim/types';
import { fmtTime } from '../render/hud';
import { byId, esc } from './dom';

export const SRC_NAMES: Record<string, string> = { ability: 'Ability', raise: 'Raised Dead', bomb: 'Bomb' };

export function buildGameOver(s: GameState, p: Player): void {
  const items: [string, string][] = [
    ['Survived', fmtTime(s.time)],
    ['Wave', String(s.wave.n)],
    ['Level', String(p.level)],
    ['Kills', String(p.kills)],
  ];
  byId('over-summary').innerHTML = items.map(([k, v]) => `<div><div class="v">${v}</div><div class="k">${k}</div></div>`).join('');
  const rows = Object.entries(p.dmgDealt).sort((a, b) => b[1] - a[1]);
  const top = rows[0]?.[1] ?? 1;
  byId('over-damage').innerHTML = rows
    .map(([src, v]) => {
      const w = WEAPONS[src];
      const inst = p.weapons.find((x) => x.id === src);
      const color = w?.color ?? 'var(--muted)';
      const name = w ? `<span style="color:${w.color}">${w.icon}</span> ${esc(inst ? weaponName(inst) : w.name)}` : SRC_NAMES[src] ?? src;
      const bar = `<span class="dmg-bar"><i style="width:${Math.max(2, (v / top) * 100)}%;background:${color}"></i></span>`;
      return `<tr><td>${name}${bar}</td><td>${Math.round(v).toLocaleString('en-US')}</td></tr>`;
    })
    .join('') || '<tr><td class="empty">No damage dealt</td><td></td></tr>';
}
