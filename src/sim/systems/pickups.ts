import { damageEnemy, healPlayer, killEnemy } from '../combat';
import type { GameState, Pickup, Player } from '../types';
import { rand } from '../rng';
import { addXp, openChest } from './leveling';
import { grantSecretReward } from './secret';

const MAX_GEMS = 400;

function collect(s: GameState, pk: Pickup, p: Player): void {
  pk.dead = true;
  s.events.push({ t: 'pickup', pid: p.id, kind: pk.kind });
  switch (pk.kind) {
    case 'xp':
    case 'coin':
      addXp(s, p, p.stats.gemDouble > 0 && rand(s) < p.stats.gemDouble ? pk.value * 2 : pk.value);
      break;
    case 'relic':
      grantSecretReward(s, p);
      break;
    case 'heal':
      healPlayer(s, p, 35);
      break;
    case 'magnet':
      for (const g of s.pickups) {
        if (g.kind === 'xp' && !g.dead && !g.target) {
          g.target = p.id;
          g.sp = 100;
        }
      }
      break;
    case 'bomb':
      for (const e of s.enemies) {
        if (e.dead || (e.x - p.x) ** 2 + (e.y - p.y) ** 2 > 1000 * 1000) continue;
        if (e.boss) damageEnemy(s, e, e.maxHp * 0.05, null, 'bomb');
        else killEnemy(s, e, p);
      }
      s.events.push({ t: 'explode', x: p.x, y: p.y, r: 700, color: '#ffffff' });
      s.events.push({ t: 'shake', v: 16 });
      break;
    case 'chest':
      openChest(s, p, pk.big);
      break;
  }
}

export function updatePickups(s: GameState, dt: number): void {
  let gems = 0;
  for (const pk of s.pickups) {
    if (pk.dead) continue;
    if (pk.kind === 'xp') gems++;
    if (pk.target) {
      const p = s.players.find((x) => x.id === pk.target);
      if (!p || p.dead) {
        pk.target = '';
        continue;
      }
      pk.sp = Math.min(1100, pk.sp + 1600 * dt);
      const dx = p.x - pk.x, dy = p.y - pk.y, d = Math.hypot(dx, dy) || 1;
      pk.x += (dx / d) * pk.sp * dt;
      pk.y += (dy / d) * pk.sp * dt;
      if (d < p.radius + 8) collect(s, pk, p);
      continue;
    }
    for (const p of s.players) {
      if (p.dead) continue;
      const gem = pk.kind === 'xp' || pk.kind === 'coin';
      const range = gem ? p.stats.magnet : p.radius + 24;
      if ((p.x - pk.x) ** 2 + (p.y - pk.y) ** 2 < range * range) {
        pk.target = p.id;
        pk.sp = gem ? -180 : 250;
        break;
      }
    }
  }

  if (gems > MAX_GEMS) mergeGems(s, gems - MAX_GEMS + 50);
}

/** Folds the oldest idle gems into one so the pickup count stays bounded. */
function mergeGems(s: GameState, n: number): void {
  let into: Pickup | null = null;
  for (const pk of s.pickups) {
    if (n <= 0) break;
    if (pk.dead || pk.kind !== 'xp' || pk.target) continue;
    if (!into) {
      into = pk;
      continue;
    }
    into.value += pk.value;
    pk.dead = true;
    n--;
  }
}
