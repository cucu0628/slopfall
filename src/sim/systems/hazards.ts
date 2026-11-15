import { hurtPlayer } from '../combat';
import { COIN_FUSE } from './bosses/goldfang';
import type { GameState } from '../types';

function distToSegment(px: number, py: number, x1: number, y1: number, x2: number, y2: number): number {
  const dx = x2 - x1, dy = y2 - y1;
  const l2 = dx * dx + dy * dy || 1;
  const t = Math.max(0, Math.min(1, ((px - x1) * dx + (py - y1) * dy) / l2));
  return Math.hypot(px - (x1 + dx * t), py - (y1 + dy * t));
}

export function updateEnemyProjectiles(s: GameState, dt: number): void {
  for (const b of s.eprojectiles) {
    if (b.dead) continue;
    b.x += b.vx * dt;
    b.y += b.vy * dt;
    b.life -= dt;
    if (b.life <= 0) {
      b.dead = true;
      continue;
    }
    for (const p of s.players) {
      if (p.dead) continue;
      const rr = b.r + p.radius * 0.8;
      if ((p.x - b.x) ** 2 + (p.y - b.y) ** 2 < rr * rr) {
        // webs slow you down unless you dash through them
        if (b.kind === 'web' && p.dashT <= 0) p.slowT = Math.max(p.slowT, 2);
        hurtPlayer(s, p, b.dmg);
        b.dead = true;
        break;
      }
    }
  }
}

export function updateHazards(s: GameState, dt: number): void {
  for (const h of s.hazards) {
    if (h.dead) continue;
    if (h.kind === 'laser' && h.src >= 0) {
      const src = s.enemies.find((e) => e.id === h.src);
      if (!src || src.dead) {
        h.dead = true;
        continue;
      }
      h.x = src.x;
      h.y = src.y;
    }
    if (h.kind === 'coin' && h.speed === 0) {
      // Goldfang's fake coin: the fuse is lit when a player steps close, otherwise it fizzles out
      for (const p of s.players) {
        if (!p.dead && Math.hypot(p.x - h.x, p.y - h.y) < 46 + p.radius) {
          h.speed = 1;
          h.warn = h.maxWarn = COIN_FUSE;
          s.events.push({ t: 'sfx', name: 'warn' });
          break;
        }
      }
      if (h.speed === 0 && h.warn <= dt) {
        h.dead = true;
        continue;
      }
    }
    if (h.warn > 0) {
      h.warn -= dt;
      continue;
    }
    h.life -= dt;
    if (h.life <= 0) h.dead = true;

    switch (h.kind) {
      case 'ring': {
        // Shockwave: only the drawn band hurts. Once the ring has passed a
        // player (e.g. they dashed through it) it can't hit them any more.
        const prev = h.r;
        h.r += h.speed * dt;
        for (const p of s.players) {
          if (p.dead || h.hit[p.id]) continue;
          const d = Math.hypot(p.x - h.x, p.y - h.y);
          const band = h.w + p.radius * 0.6;
          if (d < prev - band) {
            h.hit[p.id] = 1;
          } else if (Math.abs(d - h.r) < band) {
            h.hit[p.id] = 1;
            hurtPlayer(s, p, h.dmg);
          }
        }
        break;
      }
      case 'slam':
      case 'skyfall':
      case 'coin': {
        if (h.fired) break;
        h.fired = true;
        const color = h.kind === 'skyfall' ? '#ff7a1a' : h.kind === 'coin' ? '#ffc83d' : '#ff4d4d';
        s.events.push({ t: 'explode', x: h.x, y: h.y, r: h.r, color });
        s.events.push({ t: 'shake', v: h.kind === 'coin' ? 6 : 10 });
        for (const p of s.players) {
          if (p.dead) continue;
          if (Math.hypot(p.x - h.x, p.y - h.y) < h.r + p.radius) hurtPlayer(s, p, h.dmg);
        }
        break;
      }
      case 'laser': {
        h.ang += h.angVel * dt;
        const x2 = h.x + Math.cos(h.ang) * h.len, y2 = h.y + Math.sin(h.ang) * h.len;
        for (const p of s.players) {
          if (p.dead || (h.hit[p.id] ?? 0) > s.time) continue;
          if (distToSegment(p.x, p.y, h.x, h.y, x2, y2) < h.w / 2 + p.radius) {
            h.hit[p.id] = s.time + 0.4;
            hurtPlayer(s, p, h.dmg);
          }
        }
        break;
      }
    }
  }
}
