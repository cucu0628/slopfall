export interface EnemyDef {
  id: string;
  name: string;
  hp: number;
  speed: number;
  dmg: number;
  radius: number;
  xp: number;
  color: string;
  cost: number; // spawn budget cost
  unlock: number; // first wave it can spawn in (0 = never spawned by waves)
  group: [number, number]; // spawn group size range
  boss?: boolean;
  flying?: boolean; // ignores obstacles
}

const defs: EnemyDef[] = [
  { id: 'bat', name: 'Bat', hp: 8, speed: 115, dmg: 6, radius: 10, xp: 1, color: '#a66bff', cost: 1, unlock: 1, group: [3, 5], flying: true },
  { id: 'zombie', name: 'Zombie', hp: 30, speed: 55, dmg: 10, radius: 15, xp: 2, color: '#6fbf4a', cost: 2, unlock: 1, group: [1, 2] },
  { id: 'swarm', name: 'Swarmling', hp: 4, speed: 100, dmg: 4, radius: 7, xp: 1, color: '#ff4d6d', cost: 0.5, unlock: 2, group: [7, 11] },
  { id: 'archer', name: 'Skeleton Archer', hp: 20, speed: 75, dmg: 8, radius: 13, xp: 3, color: '#e8e0c8', cost: 3, unlock: 3, group: [1, 2] },
  { id: 'slime', name: 'Slime', hp: 40, speed: 60, dmg: 10, radius: 18, xp: 3, color: '#3fa9ff', cost: 3, unlock: 4, group: [1, 3] },
  { id: 'charger', name: 'Charger', hp: 45, speed: 70, dmg: 16, radius: 16, xp: 4, color: '#ff8c1a', cost: 4, unlock: 6, group: [1, 1] },
  { id: 'exploder', name: 'Exploder', hp: 25, speed: 100, dmg: 26, radius: 14, xp: 3, color: '#ff3b30', cost: 3, unlock: 7, group: [1, 2] },
  { id: 'ghost', name: 'Ghost', hp: 35, speed: 85, dmg: 12, radius: 14, xp: 4, color: '#dff6ff', cost: 4, unlock: 9, group: [1, 3], flying: true },
  { id: 'shaman', name: 'Shaman', hp: 50, speed: 65, dmg: 8, radius: 15, xp: 6, color: '#2ee6c5', cost: 6, unlock: 11, group: [1, 1] },
  // Spawned only by other enemies
  { id: 'slimelet', name: 'Slimelet', hp: 12, speed: 85, dmg: 6, radius: 10, xp: 1, color: '#7cc8ff', cost: 1, unlock: 0, group: [1, 1] },
  { id: 'egg', name: 'Brood Egg', hp: 60, speed: 0, dmg: 0, radius: 13, xp: 1, color: '#e9dcc0', cost: 1, unlock: 0, group: [1, 1] },
  { id: 'skeleton', name: 'Skeleton', hp: 25, speed: 85, dmg: 9, radius: 13, xp: 2, color: '#d8d2bd', cost: 1, unlock: 0, group: [1, 1] },
  // Bosses
  { id: 'slimeking', name: 'Slime King', hp: 2600, speed: 70, dmg: 24, radius: 50, xp: 100, color: '#2f8fff', cost: 0, unlock: 0, group: [1, 1], boss: true },
  { id: 'necrolord', name: 'Necro Lord', hp: 3000, speed: 70, dmg: 20, radius: 34, xp: 120, color: '#9b59ff', cost: 0, unlock: 0, group: [1, 1], boss: true },
  { id: 'golem', name: 'Stone Golem', hp: 4600, speed: 50, dmg: 30, radius: 48, xp: 140, color: '#a08c74', cost: 0, unlock: 0, group: [1, 1], boss: true },
  { id: 'broodmother', name: 'Brood Mother', hp: 3400, speed: 85, dmg: 22, radius: 44, xp: 130, color: '#8b2f5a', cost: 0, unlock: 0, group: [1, 1], boss: true },
  { id: 'wyrm', name: 'Frost Wyrm', hp: 4300, speed: 135, dmg: 26, radius: 34, xp: 150, color: '#7fd4ff', cost: 0, unlock: 0, group: [1, 1], boss: true },
  { id: 'voideye', name: 'Void Eye', hp: 4000, speed: 45, dmg: 22, radius: 40, xp: 160, color: '#ff2e88', cost: 0, unlock: 0, group: [1, 1], boss: true },
  // Secret boss: never in BOSS_ORDER, see systems/secret.ts. No contact damage, it only runs.
  { id: 'goldfang', name: 'Goldfang the Greedy', hp: 1000, speed: 120, dmg: 0, radius: 30, xp: 200, color: '#ffc83d', cost: 0, unlock: 0, group: [1, 1], boss: true },
];

export const ENEMIES: Record<string, EnemyDef> = Object.fromEntries(defs.map((d) => [d.id, d]));
export const WAVE_ENEMY_IDS = defs.filter((d) => d.unlock > 0).map((d) => d.id);
export const ignoresObstacles = (type: string) => !!(ENEMIES[type].flying || ENEMIES[type].boss);
export const BOSS_ORDER = ['slimeking', 'necrolord', 'broodmother', 'golem', 'wyrm', 'voideye'];
