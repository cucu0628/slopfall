// Movement and collision of all player projectiles.

import { damageEnemy, slowEnemy } from '../../combat';
import { addZone } from '../../entities';
import { forEnemiesInCircle, nearestEnemy } from '../../spatial';
import type { GameState, Projectile } from '../../types';
import { TAU, findPlayer } from './shared';
import { COIN_BOUNCE_RANGE, COIN_KILL_BOUNCES } from './coins';

// ---------------------------------------------------------------------------
/** Mortar shell explosion: a one-shot area zone (radius stored in `data`). */
function detonate(s: GameState, pr: Projectile): void {
  addZone(s, { owner: pr.owner, src: pr.src, kind: 'boom', x: pr.x, y: pr.y, r: pr.data, life: 0.05, dmg: pr.dmg, knock: 220 });
}

export function steer(pr: Projectile, tx: number, ty: number, turn: number): void {
  const cur = Math.atan2(pr.vy, pr.vx);
  const want = Math.atan2(ty - pr.y, tx - pr.x);
  let diff = ((want - cur + Math.PI * 3) % TAU) - Math.PI;
  diff = Math.max(-turn, Math.min(turn, diff));
  const a = cur + diff;
  pr.vx = Math.cos(a) * pr.speed;
  pr.vy = Math.sin(a) * pr.speed;
}

/** Coin ricochet: flies on toward the nearest enemy it has not hit yet. */
function ricochet(s: GameState, pr: Projectile): void {
  const t = nearestEnemy(s, pr.x, pr.y, COIN_BOUNCE_RANGE, (e) => pr.hits[e.id] !== undefined);
  if (!t) return;
  const dx = t.x - pr.x, dy = t.y - pr.y, d = Math.hypot(dx, dy) || 1;
  pr.vx = (dx / d) * pr.speed;
  pr.vy = (dy / d) * pr.speed;
  pr.life = Math.max(pr.life, 0.6); // enough time to reach the next target
}

export function updateProjectiles(s: GameState, dt: number): void {
  for (const pr of s.projectiles) {
    if (pr.dead) continue;
    pr.age += dt;
    pr.life -= dt;
    if (pr.life <= 0) {
      pr.dead = true;
      if (pr.kind === 'shell') detonate(s, pr);
      continue;
    }
    const owner = findPlayer(s, pr.owner);
    if (!owner) {
      pr.dead = true;
      continue;
    }
    let dirX = 0, dirY = 0;
    if (pr.src === 'orbs') {
      const w = owner.weapons.find((x) => x.id === 'orbs');
      if (!w) {
        pr.dead = true;
        continue;
      }
      const a = w.t + pr.data;
      pr.x = owner.x + Math.cos(a) * w.r;
      pr.y = owner.y + Math.sin(a) * w.r;
    } else if (pr.src === 'axe') {
      const T = pr.data;
      pr.ang += 16 * dt;
      if (pr.age < T) {
        const f = 1 - pr.age / T;
        pr.x += pr.vx * pr.speed * f * dt;
        pr.y += pr.vy * pr.speed * f * dt;
      } else {
        const dx = owner.x - pr.x, dy = owner.y - pr.y, d = Math.hypot(dx, dy) || 1;
        const sp = pr.speed * Math.min(1.5, 0.3 + (pr.age - T) / T);
        pr.x += (dx / d) * sp * dt;
        pr.y += (dy / d) * sp * dt;
        if (d < 24) pr.dead = true;
      }
    } else {
      if (pr.homing > 0) {
        const t = nearestEnemy(s, pr.x, pr.y, 450);
        if (t) steer(pr, t.x, t.y, pr.homing * dt);
      }
      pr.x += pr.vx * dt;
      pr.y += pr.vy * dt;
      const sp = Math.hypot(pr.vx, pr.vy) || 1;
      dirX = pr.vx / sp;
      dirY = pr.vy / sp;
    }
    if ((pr.x - owner.x) ** 2 + (pr.y - owner.y) ** 2 > 1600 * 1600) pr.dead = true;
    if (pr.dead) continue;

    forEnemiesInCircle(pr.x, pr.y, pr.radius, (e) => {
      const nt = pr.hits[e.id];
      if (nt !== undefined && nt > s.time) return;
      if (e.intangible) return;
      let kx = dirX, ky = dirY;
      if (kx === 0 && ky === 0) {
        const dx = e.x - pr.x, dy = e.y - pr.y, d = Math.hypot(dx, dy) || 1;
        kx = dx / d;
        ky = dy / d;
      }
      const killed = damageEnemy(s, e, pr.dmg, owner, pr.src, kx, ky, pr.knock);
      if (pr.slow > 0) slowEnemy(e, pr.slow, pr.slow > 0.8 ? 2 : 1.5);
      if (pr.hitRate > 0) {
        pr.hits[e.id] = s.time + pr.hitRate;
      } else {
        pr.hits[e.id] = 1e9;
        // coins: a kill earns a bonus bounce (data counts them)
        if (pr.kind === 'coin' && killed && pr.data < COIN_KILL_BOUNCES) {
          pr.data++;
          pr.pierce++;
        }
        pr.pierce--;
        if (pr.pierce < 0) {
          pr.dead = true;
          if (pr.kind === 'shell') detonate(s, pr);
          return true;
        }
        if (pr.kind === 'coin') {
          ricochet(s, pr);
          return true;
        }
      }
    });

    if (pr.hitRate > 0 && (s.tick & 63) === 0) {
      for (const k in pr.hits) if (pr.hits[k] < s.time) delete pr.hits[k];
    }
  }
}
