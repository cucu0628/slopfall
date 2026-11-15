import { hash, resolveObstacles } from './map';
import { buildGrid } from './spatial';
import { updateAbility } from './systems/abilities';
import { updateEnemies } from './systems/enemies';
import { updateIdle } from './systems/idle';
import { updateEnemyProjectiles, updateHazards } from './systems/hazards';
import { chooseUpgrade, createPlayer, updateLeveling } from './systems/leveling';
import { updatePickups } from './systems/pickups';
import { rollSecret } from './systems/secret';
import { startWave, updateWaves } from './systems/waves';
import { updateMinions, updateProjectiles, updateTurrets, updateWeapons, updateZones } from './systems/weapons';
import { DT, emptyInput, type GameState, type InputCmd, type Player, type SimConfig } from './types';

export interface PlayerSetup {
  id: string;
  charId: string;
}

export function createGame(seed: number, setups: PlayerSetup[], cfg: Partial<SimConfig> = {}): GameState {
  const s: GameState = {
    cfg: { pauseOnLevelUp: true, waveDuration: 45, godMode: false, ...cfg },
    mapSeed: hash(seed, 17, 31),
    rng: seed | 0,
    tick: 0,
    time: 0,
    nextId: 1,
    players: setups.map((p, i) => createPlayer(p.id, p.charId, i * 60, 0)),
    enemies: [],
    projectiles: [],
    eprojectiles: [],
    zones: [],
    hazards: [],
    turrets: [],
    minions: [],
    pickups: [],
    corpses: [],
    wave: { n: 0, timer: 0, spawnAcc: 8, bossWave: false, eliteSpawned: false },
    secret: rollSecret(seed),
    events: [],
    kills: 0,
    gameOver: false,
  };
  startWave(s, 1);
  return s;
}

const finite = (v: number, lim: number) => (Number.isFinite(v) ? Math.max(-lim, Math.min(lim, v)) : 0);

/** Inputs may come from the network one day: never trust them. */
function sanitize(cmd: InputCmd | undefined): InputCmd {
  if (!cmd) return emptyInput();
  return {
    mx: finite(cmd.mx, 1),
    my: finite(cmd.my, 1),
    ax: finite(cmd.ax, 5000),
    ay: finite(cmd.ay, 5000),
    ability: !!cmd.ability,
    dash: !!cmd.dash,
    choose: Number.isInteger(cmd.choose) ? cmd.choose : -1,
  };
}

export function isFrozen(s: GameState): boolean {
  return s.cfg.pauseOnLevelUp && s.players.some((p) => !p.dead && p.choices !== null);
}

const WEB_SLOW = 0.55;
const DASH_SPEED = 1050;
const DASH_TIME = 0.18;

/** Universal dash: a short invulnerable burst in the movement (or facing) direction. */
function startDash(s: GameState, p: Player, cmd: InputCmd): void {
  let dx = cmd.mx, dy = cmd.my;
  if (Math.hypot(dx, dy) < 0.1) {
    dx = p.fx;
    dy = p.fy;
  }
  const l = Math.hypot(dx, dy) || 1;
  p.dashT = DASH_TIME;
  p.dashX = (dx / l) * DASH_SPEED;
  p.dashY = (dy / l) * DASH_SPEED;
  p.invuln = Math.max(p.invuln, DASH_TIME + 0.15);
  p.dashCd = p.dashMaxCd;
  s.events.push({ t: 'dash', pid: p.id });
}

function updatePlayer(s: GameState, p: Player, cmd: InputCmd, dt: number): void {
  p.ax = cmd.ax;
  p.ay = cmd.ay;
  p.invuln = Math.max(0, p.invuln - dt);
  p.hurtT = Math.max(0, p.hurtT - dt);
  p.dashMaxCd = (p.charId === 'ranger' ? 1.8 : 2.6) * p.stats.cooldown;
  p.dashCd = Math.max(0, p.dashCd - dt);
  p.slowT = Math.max(0, p.slowT - dt);
  if (cmd.dash && p.dashCd <= 0 && p.dashT <= 0) startDash(s, p, cmd);
  if (p.dashT > 0) {
    p.dashT -= dt;
    p.x += p.dashX * dt;
    p.y += p.dashY * dt;
  } else {
    let mx = cmd.mx, my = cmd.my;
    const l = Math.hypot(mx, my);
    if (l > 1) {
      mx /= l;
      my /= l;
    }
    const speed = p.stats.speed * (p.slowT > 0 ? WEB_SLOW : 1);
    p.x += mx * speed * dt;
    p.y += my * speed * dt;
    if (l > 0.1) {
      const fl = Math.hypot(mx, my);
      p.fx = mx / fl;
      p.fy = my / fl;
    }
  }
  resolveObstacles(s.mapSeed, p, p.radius);
  updateIdle(s, p, dt);
  if (p.stats.regen > 0) p.hp = Math.min(p.stats.maxHp, p.hp + p.stats.regen * dt);
  updateAbility(s, p, cmd, dt);
  updateWeapons(s, p, dt);
}

function savePrev(s: GameState): void {
  for (const a of [s.players, s.enemies, s.projectiles, s.eprojectiles, s.minions, s.pickups] as { x: number; y: number; px: number; py: number }[][]) {
    for (const o of a) {
      o.px = o.x;
      o.py = o.y;
    }
  }
}

function cleanup(s: GameState): void {
  const alive = <T extends { dead: boolean }>(x: T) => !x.dead;
  s.enemies = s.enemies.filter(alive);
  s.projectiles = s.projectiles.filter(alive);
  s.eprojectiles = s.eprojectiles.filter(alive);
  s.zones = s.zones.filter(alive);
  s.hazards = s.hazards.filter(alive);
  s.turrets = s.turrets.filter(alive);
  s.minions = s.minions.filter(alive);
  s.pickups = s.pickups.filter(alive);
  while (s.corpses.length > 0 && s.time - s.corpses[0].t > 8) s.corpses.shift();
}

/** Advances the simulation by one fixed tick. */
export function step(s: GameState, inputs: Record<string, InputCmd>, dt = DT): void {
  s.events.length = 0;
  if (s.gameOver) return;

  for (const p of s.players) {
    const cmd = sanitize(inputs[p.id]);
    if (p.choices && cmd.choose >= 0) chooseUpgrade(s, p, cmd.choose);
    updateLeveling(s, p);
  }
  if (isFrozen(s)) return;

  savePrev(s);
  s.tick++;
  s.time += dt;
  buildGrid(s);

  for (const p of s.players) if (!p.dead) updatePlayer(s, p, sanitize(inputs[p.id]), dt);
  updateEnemies(s, dt);
  updateProjectiles(s, dt);
  updateZones(s, dt);
  updateTurrets(s, dt);
  updateMinions(s, dt);
  updateEnemyProjectiles(s, dt);
  updateHazards(s, dt);
  updatePickups(s, dt);
  updateWaves(s, dt);
  for (const p of s.players) updateLeveling(s, p);
  cleanup(s);

  if (s.players.every((p) => p.dead)) s.gameOver = true;
}
