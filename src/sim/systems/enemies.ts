import { ignoresObstacles } from '../content/enemies';
import { hurtPlayer, killEnemy, updateBurn, waveScale } from '../combat';
import { addEnemyProjectile, nearestPlayer, spawnEnemy } from '../entities';
import { rand, randRange } from '../rng';
import { resolveObstacles } from '../map';
import { forEnemiesInCircle } from '../spatial';
import type { Enemy, GameState, Player } from '../types';
import { updateBoss } from './bosses';

export const EGG_HATCH = 5;
/** A boss takes at most one shaman heal (1% max HP) per this many seconds. */
export const BOSS_HEAL_EVERY = 3.5;

export function updateEnemies(s: GameState, dt: number): void {
  const decay = Math.max(0, 1 - 9 * dt);
  for (const e of s.enemies) {
    if (e.dead) continue;
    e.flash = Math.max(0, e.flash - dt);
    updateBurn(s, e, dt);
    if (e.dead) continue;
    e.slowT -= dt;
    e.x += e.kx * dt;
    e.y += e.ky * dt;
    e.kx *= decay;
    e.ky *= decay;

    const target = nearestPlayer(s, e.x, e.y);
    if (!target) continue;
    const dx = target.x - e.x, dy = target.y - e.y;
    const d = Math.hypot(dx, dy) || 1;
    const nx = dx / d, ny = dy / d;
    const sp = e.speed * (e.slowT > 0 ? 1 - e.slowAmt : 1);

    if (e.boss) updateBoss(s, e, target, d, nx, ny, sp, dt);
    else updateRegular(s, e, d, nx, ny, sp, dt);
    if (e.dead) continue;
    if (!ignoresObstacles(e.type)) slideAroundObstacles(s, e, nx, ny, sp, dt);

    if (!e.intangible && e.dmg > 0) {
      for (const p of s.players) {
        if (p.dead) continue;
        const rr = e.radius + p.radius;
        if ((p.x - e.x) ** 2 + (p.y - e.y) ** 2 < rr * rr) hurtPlayer(s, p, e.dmg);
      }
    }

    if (!e.boss && d > 1500) relocate(s, e, target);
  }
  separate(s);
}

/** Pushes the enemy out of obstacles and lets it slide along them toward its target. */
function slideAroundObstacles(s: GameState, e: Enemy, mx: number, my: number, sp: number, dt: number): void {
  const n = resolveObstacles(s.mapSeed, e, e.radius);
  const l = Math.hypot(n.nx, n.ny);
  if (l < 0.001) return;
  const ux = n.nx / l, uy = n.ny / l;
  const dot = mx * ux + my * uy;
  if (dot >= 0) return;
  let tx = mx - dot * ux, ty = my - dot * uy;
  let tl = Math.hypot(tx, ty);
  if (tl < 0.2) {
    const side = e.id % 2 === 0 ? 1 : -1;
    tx = -uy * side;
    ty = ux * side;
    tl = 1;
  }
  e.x += (tx / tl) * sp * 0.8 * dt;
  e.y += (ty / tl) * sp * 0.8 * dt;
  resolveObstacles(s.mapSeed, e, e.radius);
}

function relocate(s: GameState, e: Enemy, target: Player): void {
  const a = Math.atan2(target.fy, target.fx) + randRange(s, -1, 1);
  e.x = target.x + Math.cos(a) * 900;
  e.y = target.y + Math.sin(a) * 900;
  e.px = e.x;
  e.py = e.y;
}

function move(e: Enemy, x: number, y: number, sp: number, dt: number): void {
  e.x += x * sp * dt;
  e.y += y * sp * dt;
}

function keepDistance(e: Enemy, d: number, nx: number, ny: number, sp: number, dt: number, near: number, far: number): void {
  const side = e.id % 2 === 0 ? 1 : -1;
  if (d > far) move(e, nx, ny, sp, dt);
  else if (d < near) move(e, -nx, -ny, sp, dt);
  else move(e, -ny * side, nx * side, sp * 0.5, dt);
}

function updateRegular(s: GameState, e: Enemy, d: number, nx: number, ny: number, sp: number, dt: number): void {
  e.t -= dt;
  switch (e.type) {
    case 'bat': {
      e.ang += dt * 7;
      const w = Math.sin(e.ang + e.id) * 0.7;
      const mx = nx - ny * w, my = ny + nx * w, l = Math.hypot(mx, my) || 1;
      move(e, mx / l, my / l, sp, dt);
      break;
    }
    case 'archer': {
      keepDistance(e, d, nx, ny, sp, dt, 200, 300);
      if (e.t <= 0 && d < 520) {
        e.t = 2.4 + rand(s) * 0.8;
        addEnemyProjectile(s, 'arrow', e.x, e.y, nx * 250, ny * 250, e.dmg, 6, 3);
      }
      break;
    }
    case 'shaman': {
      keepDistance(e, d, nx, ny, sp, dt, 250, 340);
      if (e.t <= 0) {
        e.t = 3.5;
        forEnemiesInCircle(e.x, e.y, 220, (o) => {
          if (!o.boss) {
            o.hp = Math.min(o.maxHp, o.hp + o.maxHp * 0.15);
          } else if (s.time >= o.healReadyAt) {
            // shamans gather around the boss, so their heals must not stack or weaker builds can't out-damage them
            o.healReadyAt = s.time + BOSS_HEAL_EVERY;
            o.hp = Math.min(o.maxHp, o.hp + o.maxHp * 0.01);
          }
        });
        s.events.push({ t: 'explode', x: e.x, y: e.y, r: 220, color: '#2ee6c5' });
      }
      break;
    }
    case 'charger': {
      if (e.state === 0) {
        move(e, nx, ny, sp, dt);
        if (d < 330 && e.t <= 0) {
          e.state = 1;
          e.t2 = 0.6;
          e.tx = nx;
          e.ty = ny;
        }
      } else if (e.state === 1) {
        e.t2 -= dt;
        if (e.t2 <= 0) {
          e.state = 2;
          e.t2 = 0.5;
        }
      } else {
        move(e, e.tx, e.ty, sp * 7.5, dt);
        e.t2 -= dt;
        if (e.t2 <= 0) {
          e.state = 0;
          e.t = 2.5;
        }
      }
      break;
    }
    case 'exploder': {
      if (e.state === 0) {
        move(e, nx, ny, sp, dt);
        if (d < 55 + e.radius) {
          e.state = 1;
          e.t2 = 0.6;
        }
      } else {
        move(e, nx, ny, sp * 0.3, dt);
        e.t2 -= dt;
        if (e.t2 <= 0) {
          const r = 95 * (e.elite ? 1.5 : 1);
          for (const p of s.players) {
            if (!p.dead && Math.hypot(p.x - e.x, p.y - e.y) < r + p.radius) hurtPlayer(s, p, e.dmg);
          }
          s.events.push({ t: 'explode', x: e.x, y: e.y, r, color: '#ff3b30' });
          s.events.push({ t: 'shake', v: 5 });
          killEnemy(s, e, null);
        }
      }
      break;
    }
    case 'egg': {
      // hatches into a swarm unless destroyed in time
      e.t2 += dt;
      if (e.t2 >= EGG_HATCH) {
        const sc = waveScale(s.wave.n);
        for (let i = 0; i < 5; i++) spawnEnemy(s, 'swarm', e.x + randRange(s, -14, 14), e.y + randRange(s, -14, 14), sc);
        s.events.push({ t: 'explode', x: e.x, y: e.y, r: 40, color: '#e9dcc0' });
        e.dead = true;
      }
      break;
    }
    case 'ghost': {
      e.ang += dt;
      const phase = (e.ang + e.id * 0.37) % 5;
      e.intangible = phase > 3.5;
      move(e, nx, ny, sp * (e.intangible ? 1.4 : 1), dt);
      break;
    }
    default:
      move(e, nx, ny, sp, dt);
  }
}

/** Soft separation so enemies don't stack on one spot. */
function separate(s: GameState): void {
  for (const e of s.enemies) {
    if (e.dead || e.intangible) continue;
    forEnemiesInCircle(e.x, e.y, e.radius, (o) => {
      if (o === e || o.intangible) return;
      const dx = e.x - o.x, dy = e.y - o.y;
      const d = Math.hypot(dx, dy) || 0.01;
      const overlap = e.radius + o.radius - d;
      if (overlap <= 0) return;
      const push = overlap * 0.25;
      const ux = dx / d, uy = dy / d;
      if (!e.boss) {
        e.x += ux * push;
        e.y += uy * push;
      }
      if (!o.boss) {
        o.x -= ux * push;
        o.y -= uy * push;
      }
    });
    if (!ignoresObstacles(e.type)) resolveObstacles(s.mapSeed, e, e.radius);
  }
}
