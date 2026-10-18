import { ENEMIES, ignoresObstacles } from './content/enemies';
import { resolveObstacles } from './map';
import type { Enemy, EnemyProjectile, GameState, Hazard, HazardKind, Pickup, PickupKind, Player, Projectile, Zone } from './types';

export const nextId = (s: GameState) => s.nextId++;

export function nearestPlayer(s: GameState, x: number, y: number): Player | null {
  let best: Player | null = null;
  let bestD = Infinity;
  for (const p of s.players) {
    if (p.dead) continue;
    const d = (p.x - x) ** 2 + (p.y - y) ** 2;
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  return best;
}

export interface EnemyScale {
  hp: number;
  dmg: number;
  speed: number;
}

export function spawnEnemy(s: GameState, type: string, x: number, y: number, scale: EnemyScale, elite = false): Enemy {
  const def = ENEMIES[type];
  const hpMul = scale.hp * (elite ? 6 : 1);
  const e: Enemy = {
    id: nextId(s), type, x, y, px: x, py: y, kx: 0, ky: 0,
    hp: def.hp * hpMul, maxHp: def.hp * hpMul,
    dmg: def.dmg * scale.dmg * (elite ? 1.5 : 1),
    speed: def.speed * scale.speed * (elite ? 0.9 : 1),
    radius: def.radius * (elite ? 1.5 : 1),
    xp: def.xp * (elite ? 8 : 1),
    elite, boss: !!def.boss, chest: false,
    slowT: 0, slowAmt: 0, flash: 0,
    state: 0, t: 0, t2: 0, t3: 0, tx: 0, ty: 0, sx: 0, sy: 0, ang: 0, dmgAcc: 0,
    intangible: false, trail: [], burnT: 0, burnDps: 0, burnTick: 0, burnOwner: '', healReadyAt: 0, dead: false,
  };
  if (!ignoresObstacles(type)) resolveObstacles(s.mapSeed, e, e.radius);
  e.px = e.x;
  e.py = e.y;
  s.enemies.push(e);
  return e;
}

export function addPickup(s: GameState, kind: PickupKind, x: number, y: number, value = 0, big = false): Pickup {
  const p: Pickup = { id: nextId(s), kind, x, y, px: x, py: y, value, target: '', sp: 0, big, dead: false };
  if (kind !== 'xp') {
    resolveObstacles(s.mapSeed, p, 16);
    p.px = p.x;
    p.py = p.y;
  }
  s.pickups.push(p);
  return p;
}

export function addProjectile(s: GameState, init: Partial<Projectile> & Pick<Projectile, 'owner' | 'src' | 'kind' | 'x' | 'y'>): Projectile {
  const p: Projectile = {
    id: nextId(s), vx: 0, vy: 0, dmg: 0, radius: 8, pierce: 0, life: 1, maxLife: 1, knock: 0,
    hits: {}, hitRate: 0, homing: 0, ang: 0, data: 0, slow: 0, age: 0, speed: 0, dead: false,
    px: init.x, py: init.y, ...init,
  };
  p.maxLife = p.life;
  s.projectiles.push(p);
  return p;
}

export function addZone(s: GameState, init: Partial<Zone> & Pick<Zone, 'owner' | 'src' | 'kind' | 'x' | 'y' | 'r'>): Zone {
  const z: Zone = {
    id: nextId(s), r0: init.r, life: 0.3, maxLife: 0.3, delay: 0, dmg: 0, knock: 0, slow: 0,
    ang: 0, arc: 0, pts: [], hits: {}, burn: 0, fired: false, dead: false, ...init,
  };
  z.maxLife = z.life;
  s.zones.push(z);
  return z;
}

export function addEnemyProjectile(s: GameState, kind: string, x: number, y: number, vx: number, vy: number, dmg: number, r = 7, life = 5): EnemyProjectile {
  const p: EnemyProjectile = { id: nextId(s), kind, x, y, px: x, py: y, vx, vy, r, dmg, life, dead: false };
  s.eprojectiles.push(p);
  return p;
}

export function addHazard(s: GameState, kind: HazardKind, init: Partial<Hazard> & Pick<Hazard, 'x' | 'y' | 'dmg'>): Hazard {
  const h: Hazard = {
    id: nextId(s), kind, src: -1, r: 0, w: 16, speed: 0, ang: 0, angVel: 0, len: 0,
    warn: 0, maxWarn: 0, life: 1, hit: {}, fired: false, dead: false, ...init,
  };
  h.maxWarn = h.warn;
  s.hazards.push(h);
  return h;
}
