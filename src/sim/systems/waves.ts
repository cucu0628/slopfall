import { BOSS_ORDER, ENEMIES, WAVE_ENEMY_IDS } from '../content/enemies';
import { waveScale } from '../combat';
import { spawnEnemy } from '../entities';
import { pick, rand, randInt, randRange, weightedPick } from '../rng';
import type { GameState, Player } from '../types';
import { initBoss } from './bosses';
import { refreshStats } from './leveling';

export const ENEMY_CAP = 500;
export const BOSS_EVERY = 5;
/** Every this many cleared waves each hero gains VIGOR_HP max HP, so late waves don't one-shot builds without HP perks. */
export const VIGOR_EVERY = 5;
export const VIGOR_HP = 5;

/** Max HP a hero has earned from waves by the time wave `n` starts. */
export const vigorHpAt = (n: number) => Math.floor((n - 1) / VIGOR_EVERY) * VIGOR_HP;

function spawnPoint(s: GameState, target: Player, dist: number): [number, number] {
  const a = rand(s) * Math.PI * 2;
  const d = dist + rand(s) * 80;
  return [target.x + Math.cos(a) * d, target.y + Math.sin(a) * d];
}

/**
 * Extra HP for bosses on top of the normal wave scaling. It grows with the
 * wave because builds grow much faster than a linear curve: a typical build
 * should need roughly 30-45 s for a boss.
 */
export function bossHpFactor(n: number): number {
  return n <= 10 ? Math.max(0.6, 0.2 * n - 0.1) : 1.9 + 0.12 * (n - 10);
}

export function startWave(s: GameState, n: number): void {
  const w = s.wave;
  w.n = n;
  w.timer = s.cfg.waveDuration;
  w.bossWave = n % BOSS_EVERY === 0;
  w.eliteSpawned = false;
  s.events.push({ t: 'wave', n, boss: w.bossWave });
  grantVigor(s, n);
  if (!w.bossWave) return;

  const alive = s.players.filter((p) => !p.dead);
  if (alive.length === 0) return;
  const k = n / BOSS_EVERY - 1;
  const ids = [BOSS_ORDER[k % BOSS_ORDER.length]];
  if (n >= 20) ids.push(BOSS_ORDER[(k + 1) % BOSS_ORDER.length]);
  if (n === s.secret.wave) ids.splice(0, ids.length, 'goldfang'); // the secret boss comes alone
  const sc = waveScale(n);
  const hpMul = sc.hp * bossHpFactor(n) * (ids.length > 1 ? 0.75 : 1) * alive.length;
  for (const id of ids) {
    const [x, y] = spawnPoint(s, pick(s, alive), 600);
    const e = spawnEnemy(s, id, x, y, { hp: hpMul, dmg: sc.dmg, speed: 1 });
    initBoss(e);
    s.events.push({ t: 'boss', id, name: ENEMIES[id].name });
  }
}

function grantVigor(s: GameState, n: number): void {
  const want = vigorHpAt(n);
  for (const p of s.players) {
    if (p.dead || p.vigorHp >= want) continue;
    const gain = want - p.vigorHp;
    p.vigorHp = want;
    refreshStats(p); // raises current HP by the same amount
    s.events.push({ t: 'vigor', pid: p.id, v: gain });
  }
}

export function updateWaves(s: GameState, dt: number): void {
  const w = s.wave;
  if (w.bossWave) {
    if (!s.enemies.some((e) => e.boss && !e.dead)) startWave(s, w.n + 1);
  } else {
    w.timer -= dt;
    if (w.timer <= 0) startWave(s, w.n + 1);
  }

  const alive = s.players.filter((p) => !p.dead);
  if (alive.length === 0) return;
  const sc = waveScale(w.n);
  const rate = (1.8 + 0.8 * w.n + 0.035 * w.n * w.n) * (w.bossWave ? 0.35 : 1) * (0.6 + 0.4 * alive.length);
  w.spawnAcc += rate * dt;

  const types = WAVE_ENEMY_IDS.filter((id) => ENEMIES[id].unlock <= w.n);
  let live = 0;
  for (const e of s.enemies) if (!e.dead) live++;

  while (w.spawnAcc > 0 && live < ENEMY_CAP) {
    const type = weightedPick(s, types, (id) => 1 + (ENEMIES[id].cost >= 3 ? w.n * 0.04 : 0));
    const def = ENEMIES[type];
    const count = randInt(s, def.group[0], def.group[1]);
    w.spawnAcc -= def.cost * count;
    const target = pick(s, alive);
    const [cx, cy] = spawnPoint(s, target, 780);
    const eliteChance = Math.min(0.01, 0.0005 * w.n);
    for (let i = 0; i < count; i++) {
      spawnEnemy(s, type, cx + randRange(s, -45, 45), cy + randRange(s, -45, 45), sc, rand(s) < eliteChance);
      live++;
    }
  }

  // One mid-wave elite from wave 3. Only the "champion" (once per boss
  // cycle) carries a chest, so chests stay rare: one champion + one boss
  // chest every 5 waves.
  if (!w.bossWave && !w.eliteSpawned && w.n >= 3 && w.timer < s.cfg.waveDuration * 0.5) {
    w.eliteSpawned = true;
    const type = pick(s, types.filter((t) => t !== 'swarm'));
    const [x, y] = spawnPoint(s, pick(s, alive), 800);
    const e = spawnEnemy(s, type, x, y, sc, true);
    e.chest = w.n % BOSS_EVERY === 3;
  }
}
