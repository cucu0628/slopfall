import { describe, expect, it } from 'vitest';
import { restore, snapshot } from '../src/sim/save';
import { damageEnemy } from '../src/sim/combat';
import { startWave } from '../src/sim/systems/waves';
import { createGame } from '../src/sim/world';
import { run } from './helpers';

describe('saving runs', () => {
  it('saves and restores a run without enemies', () => {
    const s = createGame(46, [{ id: 'p1', charId: 'ranger' }], { godMode: true });
    run(s, 2400);
    const save = JSON.parse(JSON.stringify(snapshot(s, 123)));
    expect(save.state.enemies.length).toBe(0);
    const r = restore(save)!;
    expect(r).not.toBeNull();
    expect(r.wave.n).toBe(s.wave.n);
    expect(r.mapSeed).toBe(s.mapSeed);
    expect(r.players[0].weapons).toEqual(s.players[0].weapons);
    expect(r.players[0].level).toBe(s.players[0].level);
    run(r, 600);
    expect(r.enemies.length).toBeGreaterThan(0);
    expect(restore({ ...save, v: -1 })).toBeNull();

    const b = createGame(47, [{ id: 'p1', charId: 'knight' }]);
    startWave(b, 10);
    const rb = restore(JSON.parse(JSON.stringify(snapshot(b, 0))))!;
    expect(rb.enemies.some((e) => e.boss)).toBe(true);
  });

  it('keeps boss HP and does not bring back a killed boss', () => {
    const s = createGame(48, [{ id: 'p1', charId: 'knight' }], { godMode: true });
    startWave(s, 20);
    const [a, b] = s.enemies.filter((e) => e.boss);
    damageEnemy(s, a, a.hp + 1, null, 'test');
    damageEnemy(s, b, b.maxHp * 0.4, null, 'test');
    const r = restore(JSON.parse(JSON.stringify(snapshot(s, 0))))!;
    const bosses = r.enemies.filter((e) => e.boss);
    expect(bosses.map((e) => e.id)).toEqual([b.id]);
    expect(bosses[0].hp).toBeCloseTo(b.hp);
    expect(r.wave.n).toBe(20);
  });
});
