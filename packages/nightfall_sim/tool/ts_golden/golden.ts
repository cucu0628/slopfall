// Runs fixed scenarios on the TypeScript sim and prints fingerprints as JSON.
// Used to build packages/nightfall_sim/test/fixtures/ts_golden.json.
import { createGame, step } from './sim/world.ts';
import { startWave } from './sim/systems/waves.ts';
import { refreshStats } from './sim/systems/leveling.ts';
import { restore, snapshot } from './sim/save.ts';
import { botInput } from './helpers.ts';
import type { GameState, InputCmd } from './sim/types.ts';

interface Scenario {
  name: string; seed: number; chars: string[]; godMode: boolean; waveDuration: number; ticks: number;
  wave?: number; weapons?: [string, number, string][]; perks?: [string, number, number][];
  secret?: { wave: number; reward: string }; saveAt?: number;
}

const evo = (name: string, weapon: string, id: string, perk: string, seed: number): Scenario => ({
  name, seed, chars: ['knight'], godMode: true, waveDuration: 20, ticks: 2400, wave: 4,
  weapons: [[weapon, 8, id]], perks: [[perk, 3, 3], ['lifesteal', 2, 2], ['burn', 2, 2]],
});

const SCENARIOS: Scenario[] = [
  ...['knight', 'mage', 'ranger', 'necro', 'engineer', 'berserker'].map((c, i) => ({
    name: c, seed: 101 * (i + 1), chars: [c], godMode: false, waveDuration: 45, ticks: 6000,
  })),
  { name: 'coop', seed: 707, chars: ['mage', 'knight', 'necro'], godMode: true, waveDuration: 8, ticks: 6000 },
  ...[10, 15, 20, 25, 30].map((w) => ({
    name: `boss${w}`, seed: 800 + w, chars: ['engineer'], godMode: true, waveDuration: 45, ticks: 3600, wave: w,
    weapons: [['turret', 8, 'mortar'], ['nova', 6, ''], ['lightning', 5, ''], ['frost', 4, '']] as [string, number, string][],
  })),
  { name: 'goldfang', seed: 3, chars: ['mage'], godMode: true, waveDuration: 45, ticks: 2400, wave: 10, secret: { wave: 10, reward: 'weapon' } },
  evo('holyblade', 'sword', 'holyblade', 'armor', 11),
  evo('bladedancer', 'sword', 'bladedancer', 'crit', 12),
  evo('arcanestorm', 'bolt', 'arcanestorm', 'haste', 13),
  evo('prism', 'bolt', 'prism', 'area', 14),
  evo('phantom', 'arrow', 'phantom', 'crit', 15),
  evo('eternal', 'orbs', 'eternal', 'duration', 16),
  evo('whirlwind', 'axe', 'whirlwind', 'might', 17),
  evo('twinreavers', 'axe', 'twinreavers', 'multishot', 18),
  evo('thunderstorm', 'lightning', 'thunderstorm', 'multishot', 19),
  evo('sanctuary', 'aura', 'sanctuary', 'vitality', 20),
  evo('inferno', 'nova', 'inferno', 'area', 21),
  evo('supernova', 'nova', 'supernova', 'might', 22),
  evo('tesla', 'turret', 'tesla', 'magnet', 23),
  evo('mortar', 'turret', 'mortar', 'area', 24),
  evo('abszero', 'frost', 'abszero', 'swift', 25),
  evo('coins', 'coins', '', 'growth', 26),
  { name: 'saved', seed: 46, chars: ['ranger'], godMode: true, waveDuration: 45, ticks: 4800, saveAt: 2400 },
];

const SAMPLE = 20;

function fp(s: GameState): unknown[] {
  let ex = 0, ey = 0, ehp = 0;
  for (const e of s.enemies) { ex += e.x; ey += e.y; ehp += e.hp; }
  return [
    s.tick, s.rng, s.nextId, s.kills, s.wave.n, s.enemies.length, s.projectiles.length, s.pickups.length,
    s.zones.length, s.hazards.length, s.eprojectiles.length, ex, ey, ehp,
    ...s.players.flatMap((p) => [p.x, p.y, p.hp, p.xp, p.level, p.weapons.map((w) => w.id + w.level + w.evo).join(','), p.perks.map((k) => k.id + k.level).join(',')]),
  ];
}

const rows: Record<string, unknown[][]> = {};
const saves: Record<string, unknown> = {};
for (const sc of SCENARIOS) {
  let s = createGame(sc.seed, sc.chars.map((c, i) => ({ id: `p${i}`, charId: c })), { godMode: sc.godMode, waveDuration: sc.waveDuration });
  if (sc.secret) s.secret = sc.secret as GameState['secret'];
  if (sc.wave) { s.enemies = []; startWave(s, sc.wave); }
  for (const p of s.players) {
    if (sc.weapons) p.weapons = sc.weapons.map(([id, level, e]) => ({ id, level, evolved: e !== '', evo: e, cd: 0, t: 0, r: 0 }));
    if (sc.perks) p.perks = sc.perks.map(([id, level, power]) => ({ id, level, power }));
    refreshStats(p);
  }
  const out: unknown[][] = [fp(s)];
  for (let i = 1; i <= sc.ticks && !s.gameOver; i++) {
    const inputs: Record<string, InputCmd> = {};
    for (const p of s.players) inputs[p.id] = botInput(s, p.id);
    step(s, inputs);
    if (sc.saveAt === i) {
      const save = JSON.parse(JSON.stringify(snapshot(s, 1700000000000)));
      saves[sc.name] = save;
      s = restore(save)!;
    }
    if (i % SAMPLE === 0 || s.gameOver) out.push(fp(s));
  }
  rows[sc.name] = out;
}
process.stdout.write(JSON.stringify({ sample: SAMPLE, scenarios: SCENARIOS, rows, saves }));
