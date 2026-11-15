import { describe, expect, it } from 'vitest';
import { damageEnemy, waveScale } from '../src/sim/combat';
import { addHazard, addPickup, spawnEnemy } from '../src/sim/entities';
import { restore, snapshot } from '../src/sim/save';
import { GOLDFANG_ESCAPE } from '../src/sim/systems/bosses';
import { MAX_SLOTS, computeStats, refreshStats, rollChoices } from '../src/sim/systems/leveling';
import { SECRET_FIRST_WAVE, SECRET_PERK, SECRET_WEAPON, rollSecret } from '../src/sim/systems/secret';
import { BOSS_EVERY, startWave } from '../src/sim/systems/waves';
import type { GameState, InputCmd } from '../src/sim/types';
import { createGame, step } from '../src/sim/world';

const idle: InputCmd = { mx: 0, my: 0, ax: 1, ay: 0, ability: false, dash: false, choose: 0 };

/** A run that is on Goldfang's wave, with nothing else around. */
function goldfangRun(seed = 3, reward: 'weapon' | 'perk' = 'weapon'): GameState {
  const s = createGame(seed, [{ id: 'p1', charId: 'mage' }], { godMode: true });
  s.secret = { wave: 10, reward };
  s.enemies = [];
  startWave(s, 10);
  s.wave.spawnAcc = -1e9; // no regular spawns
  return s;
}

const goldfang = (s: GameState) => s.enemies.find((e) => e.type === 'goldfang');

function killAndCollect(s: GameState): void {
  const g = goldfang(s)!;
  damageEnemy(s, g, g.hp + 1, s.players[0], 'test');
  const relic = s.pickups.find((p) => p.kind === 'relic')!;
  s.players[0].x = relic.x;
  s.players[0].y = relic.y;
  for (let i = 0; i < 30 && !relic.dead; i++) step(s, { p1: idle });
  expect(relic.dead).toBe(true);
}

describe('secret boss: Goldfang', () => {
  it('is rolled from the seed: rare, at most once, never on the first boss wave', () => {
    expect(rollSecret(1234)).toEqual(rollSecret(1234));
    let early = 0;
    const rewards = new Set<string>();
    for (let seed = 0; seed < 4000; seed++) {
      const r = rollSecret(seed);
      rewards.add(r.reward);
      if (r.wave === 0) continue;
      expect(r.wave % BOSS_EVERY).toBe(0);
      expect(r.wave).toBeGreaterThanOrEqual(SECRET_FIRST_WAVE);
      if (r.wave <= 30) early++;
    }
    // 5 boss waves from 10 to 30 at 3% each: about 14% of runs
    expect(early / 4000).toBeGreaterThan(0.09);
    expect(early / 4000).toBeLessThan(0.2);
    expect([...rewards].sort()).toEqual(['perk', 'weapon']);
  });

  it('replaces the whole boss lineup on its wave only', () => {
    const s = createGame(3, [{ id: 'p1', charId: 'mage' }], { godMode: true });
    s.secret = { wave: 20, reward: 'perk' };
    startWave(s, 20);
    expect(s.enemies.filter((e) => e.boss).map((e) => e.type)).toEqual(['goldfang']);
    expect(s.events).toContainEqual({ t: 'boss', id: 'goldfang', name: 'Goldfang the Greedy' });
    s.enemies = [];
    startWave(s, 25);
    const later = s.enemies.filter((e) => e.boss).map((e) => e.type);
    expect(later).toHaveLength(2);
    expect(later).not.toContain('goldfang');
  });

  it('escapes with his treasure if he is not caught in time', () => {
    const s = goldfangRun();
    let escaped = false;
    for (let i = 0; i < 60 * (GOLDFANG_ESCAPE + 1); i++) {
      step(s, { p1: idle });
      if (s.events.some((e) => e.t === 'escape')) escaped = true;
    }
    expect(escaped).toBe(true);
    expect(goldfang(s)).toBeUndefined();
    expect(s.pickups.some((p) => p.kind === 'relic' || p.kind === 'chest')).toBe(false);
    expect(s.wave.n).toBe(11);
  });

  it('runs from the player and never deals contact damage', () => {
    const s = goldfangRun();
    const g = goldfang(s)!;
    g.x = s.players[0].x + 100;
    g.y = s.players[0].y;
    for (let i = 0; i < 60; i++) step(s, { p1: idle });
    expect(Math.hypot(g.x - s.players[0].x, g.y - s.players[0].y)).toBeGreaterThan(200);
    expect(g.dmg).toBe(0);
  });

  it('drops a relic that grants his unique weapon without using a slot', () => {
    const s = goldfangRun(3, 'weapon');
    const p = s.players[0];
    p.weapons = ['bolt', 'arrow', 'axe', 'nova', 'frost', 'aura'].map((id) => ({ id, level: 2, evolved: false, evo: '', cd: 1, t: 0, r: 0 }));
    killAndCollect(s);
    expect(s.pickups.some((pk) => pk.kind === 'chest')).toBe(false);
    expect(p.weapons).toHaveLength(MAX_SLOTS + 1);
    expect(p.weapons.some((w) => w.id === SECRET_WEAPON)).toBe(true);
    // it levels up like any weapon, but is never offered to someone who doesn't own it
    const offered = Array.from({ length: 60 }, () => rollChoices(s, p)).flat();
    expect(offered.some((o) => o.kind === 'weapon' && o.id === SECRET_WEAPON && o.level === 2)).toBe(true);
    const fresh = createGame(4, [{ id: 'p1', charId: 'mage' }]);
    const freshOffers = Array.from({ length: 200 }, () => rollChoices(fresh, fresh.players[0])).flat();
    expect(freshOffers.some((o) => o.id === SECRET_WEAPON || o.id === SECRET_PERK)).toBe(false);
  });

  it('drops a relic that grants his unique perk', () => {
    const s = goldfangRun(3, 'perk');
    const p = s.players[0];
    killAndCollect(s);
    expect(p.perks.map((k) => k.id)).toContain(SECRET_PERK);
    // the HP penalty applies after every flat bonus, whatever order the perks were taken in
    const without = computeStats({ ...p, perks: p.perks.filter((k) => k.id !== SECRET_PERK) });
    expect(p.stats.growth).toBeCloseTo(without.growth + 0.25);
    expect(p.stats.maxHp).toBeCloseTo(without.maxHp * 0.9);
    expect(p.stats.gemDouble).toBeCloseTo(0.05);
    expect(s.events.some((e) => e.t === 'unique' && e.pid === 'p1')).toBe(true);
  });

  it("keeps Goldfang's clock and an uncollected relic across a save", () => {
    const s = goldfangRun();
    for (let i = 0; i < 60 * 5; i++) step(s, { p1: idle });
    const left = goldfang(s)!.t;
    const r = restore(JSON.parse(JSON.stringify(snapshot(s, 0))))!;
    expect(r.enemies.find((e) => e.type === 'goldfang')!.t).toBeCloseTo(left);
    expect(r.secret).toEqual(s.secret);

    const g = goldfang(s)!;
    damageEnemy(s, g, g.hp + 1, null, 'test');
    const r2 = restore(JSON.parse(JSON.stringify(snapshot(s, 0))))!;
    expect(r2.pickups.filter((p) => p.kind === 'relic')).toHaveLength(1);
    expect(r2.enemies.some((e) => e.type === 'goldfang')).toBe(false);
  });

  it('fake coins explode when stepped near, real coins give XP', () => {
    const s = goldfangRun();
    s.enemies = [];
    s.cfg.godMode = false;
    const p = s.players[0];
    const hp = p.hp;
    addHazard(s, 'coin', { x: p.x + 30, y: p.y, r: 65, dmg: 20, warn: 8, life: 0.05 });
    for (let i = 0; i < 60; i++) step(s, { p1: idle });
    expect(p.hp).toBeLessThan(hp);

    const xp = p.xp + p.level * 1000;
    addPickup(s, 'coin', p.x + 40, p.y, 5);
    for (let i = 0; i < 60; i++) step(s, { p1: idle });
    expect(p.xp + p.level * 1000).toBeGreaterThan(xp);
  });

  it('coins ricochet from enemy to enemy', () => {
    const s = createGame(9, [{ id: 'p1', charId: 'mage' }], { godMode: true });
    const p = s.players[0];
    p.weapons = [{ id: SECRET_WEAPON, level: 1, evolved: false, evo: '', cd: 0, t: 0, r: 0 }];
    refreshStats(p);
    s.enemies = [];
    s.wave.spawnAcc = -1e9;
    const tough = { ...waveScale(1), hp: 50 };
    const foes = [0, 1, 2].map((i) => spawnEnemy(s, 'zombie', p.x + 150 + i * 70, p.y + (i % 2) * 60, tough));
    for (const e of foes) e.speed = 0;
    for (let i = 0; i < 30; i++) {
      s.wave.spawnAcc = -1e9;
      step(s, { p1: idle });
    }
    expect(foes.filter((e) => e.hp < e.maxHp).length).toBeGreaterThanOrEqual(2);
    expect(p.dmgDealt[SECRET_WEAPON]).toBeGreaterThan(0);
  });
});
