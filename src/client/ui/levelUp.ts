// Level-up / evolution choice cards.

import { ABILITY_MAX_LEVEL, CHARACTERS } from '../../sim/content/characters';
import { BONUSES, PERKS, RARITIES } from '../../sim/content/perks';
import { MAX_WEAPON_LEVEL, WEAPONS, levelDesc } from '../../sim/content/weapons';
import type { Player, UpgradeOption } from '../../sim/types';
import { byId, el, esc } from './dom';

export interface OptionView {
  icon: string;
  color: string;
  name: string;
  tag: string;
  isNew: boolean;
  desc: string;
  evo: string;
  rarity?: string;
}

export function optionView(o: UpgradeOption, charId: string): OptionView {
  if (o.kind === 'weapon') {
    const d = WEAPONS[o.id];
    const paths = d.evos.map((e) => `${e.name} (${PERKS[e.perk].name})`).join(' or ');
    const evo = d.unique ? 'Unique: takes no weapon slot'
      : o.level === MAX_WEAPON_LEVEL ? `Max level! Open a chest to evolve: ${paths}`
      : o.level === 1 ? `Evolves into ${paths}` : '';
    return { icon: d.icon, color: d.color, name: d.name, tag: o.level === 1 ? 'NEW WEAPON' : `LEVEL ${o.level}`, isNew: o.level === 1, desc: levelDesc(d, o.level), evo };
  }
  if (o.kind === 'perk') {
    const d = PERKS[o.id];
    const r = RARITIES[o.rarity] ?? RARITIES[0];
    return {
      icon: d.icon, color: o.rarity > 0 ? r.color : d.color, name: d.name,
      tag: o.level === 1 ? 'NEW PERK' : `LEVEL ${o.level} / ${d.max}`, isNew: o.level === 1,
      desc: d.desc(r.mul), evo: '', rarity: o.rarity > 0 ? r.name.toUpperCase() : '',
    };
  }
  if (o.kind === 'ability') {
    const c = CHARACTERS[charId];
    return { icon: '★', color: c.accent, name: c.ability.name, tag: `ABILITY ${o.level} / ${ABILITY_MAX_LEVEL}`, isNew: false, desc: c.ability.upgrade, evo: '' };
  }
  if (o.kind === 'evo') {
    const w = WEAPONS[o.id], e = w.evos[o.level];
    return { icon: w.icon, color: '#ffd166', name: e.name, tag: `EVOLVE ${w.name.toUpperCase()}`, isNew: true, desc: e.desc, evo: `Requires ${PERKS[e.perk].name} ✓` };
  }
  if (o.kind === 'bonus') {
    const d = BONUSES[o.id];
    return { icon: d.icon, color: d.color, name: d.name, tag: `BONUS ×${o.level}`, isNew: false, desc: d.desc, evo: '' };
  }
  return { icon: '✚', color: '#6bff8f', name: 'Restore', tag: 'HEAL', isNew: false, desc: 'Heal 50% of max HP', evo: '' };
}

export function buildLevelUp(choices: UpgradeOption[], p: Player, onChoose: (i: number) => void): void {
  const box = byId('levelup-cards');
  box.innerHTML = '';
  const evolving = choices[0]?.kind === 'evo';
  byId('levelup-title').textContent = evolving ? 'Choose an evolution' : 'Level up!';
  choices.forEach((o, i) => {
    const v = optionView(o, p.charId);
    const card = el('div', `card panel accent${v.rarity ? ' rarity-' + v.rarity.toLowerCase() : ''}`);
    card.style.setProperty('--c', v.color);
    card.innerHTML = `
      ${v.rarity ? `<div class="rarity">${v.rarity}</div>` : ''}
      <div class="icon">${v.icon}</div>
      <div class="cname">${esc(v.name)}</div>
      <div class="tag ${v.isNew ? 'new' : ''}">${v.tag}</div>
      <div class="desc">${esc(v.desc)}</div>
      ${v.evo ? `<div class="evo">${esc(v.evo)}</div>` : ''}
      <div class="key"><kbd>${i + 1}</kbd></div>`;
    card.addEventListener('click', () => onChoose(i));
    box.appendChild(card);
  });
  // Evolution paths whose perk is missing are shown locked, so the choice is visible.
  if (evolving) {
    const w = WEAPONS[choices[0].id];
    w.evos.forEach((e, i) => {
      if (choices.some((o) => o.level === i)) return;
      const card = el('div', 'card panel accent locked');
      card.style.setProperty('--c', '#6b7290');
      card.innerHTML = `
        <div class="icon">🔒</div>
        <div class="cname">${esc(e.name)}</div>
        <div class="tag">LOCKED</div>
        <div class="desc">${esc(e.desc)}</div>
        <div class="evo">Requires ${esc(PERKS[e.perk].name)} perk</div>`;
      box.appendChild(card);
    });
  }
}
