// Pure simulation types. Everything in GameState must stay JSON-serializable
// (no class instances, no closures) so it can later be sent over the network.

export type PlayerId = string;

export interface InputCmd {
  mx: number; // movement direction, -1..1
  my: number;
  ax: number; // aim offset from the player, in world units
  ay: number;
  ability: boolean; // ability button held
  dash: boolean; // dash button held
  choose: number; // level-up choice index, -1 = none
}

export const emptyInput = (): InputCmd => ({ mx: 0, my: 0, ax: 1, ay: 0, ability: false, dash: false, choose: -1 });

export interface Stats {
  might: number;
  cooldown: number;
  speed: number;
  maxHp: number;
  regen: number;
  armor: number;
  magnet: number;
  area: number;
  duration: number;
  amount: number;
  crit: number;
  growth: number;
  lifesteal: number; // fraction of damage dealt healed
  lifestealCap: number; // max lifesteal healing per second, as a fraction of max HP
  dr: number; // damage reduction fraction (armor perk)
  burn: number; // chance to ignite on hit
}

export interface WeaponInst {
  id: string;
  level: number;
  evolved: boolean;
  evo: string; // id of the chosen evolution ('' while not evolved)
  cd: number;
  t: number; // weapon-specific timer / angle
  r: number; // weapon-specific radius (used by aura rendering)
}

export interface PerkInst {
  id: string;
  level: number;
  power: number; // sum of level-ups weighted by rarity
}

export type UpgradeOption =
  | { kind: 'weapon'; id: string; level: number }
  | { kind: 'perk'; id: string; level: number; rarity: number } // rarity index into RARITIES
  | { kind: 'ability'; id: 'ability'; level: number }
  | { kind: 'bonus'; id: string; level: number }
  | { kind: 'evo'; id: string; level: number } // id = weapon id, level = index into its evolutions
  | { kind: 'heal'; id: 'heal'; level: 0 };

export interface Player {
  id: PlayerId;
  charId: string;
  x: number;
  y: number;
  px: number;
  py: number;
  fx: number; // facing
  fy: number;
  ax: number; // last aim offset
  ay: number;
  hp: number;
  stats: Stats;
  radius: number;
  level: number;
  xp: number;
  xpNext: number;
  weapons: WeaponInst[];
  perks: PerkInst[];
  abilityLevel: number;
  abilityCd: number;
  abilityMaxCd: number;
  abilityT: number; // remaining time of an active ability effect
  invuln: number;
  hurtT: number;
  dashT: number;
  dashX: number;
  dashY: number;
  dashCd: number;
  dashMaxCd: number;
  bonus: Record<string, number>; // stackable bonus upgrades taken after everything is maxed
  healBudget: number; // necromancer kill-heal limiter
  lsBudget: number; // lifesteal healing still allowed this second
  idleT: number; // seconds spent near the same spot (anti-AFK)
  anchorX: number;
  anchorY: number;
  skyfallCd: number;
  skyfallN: number;
  slowT: number; // slowed by webs
  evoQueue: string[]; // weapons waiting for the player to pick an evolution
  pendingLevels: number;
  choices: UpgradeOption[] | null;
  dead: boolean;
  kills: number;
  dmgDealt: Record<string, number>;
}

export interface Enemy {
  id: number;
  type: string;
  x: number;
  y: number;
  px: number;
  py: number;
  kx: number; // knockback velocity
  ky: number;
  hp: number;
  maxHp: number;
  dmg: number;
  speed: number;
  radius: number;
  xp: number;
  elite: boolean;
  boss: boolean;
  chest: boolean; // drops a treasure chest
  slowT: number;
  slowAmt: number;
  flash: number;
  state: number;
  t: number;
  t2: number;
  t3: number;
  tx: number;
  ty: number;
  sx: number;
  sy: number;
  ang: number;
  dmgAcc: number;
  intangible: boolean;
  trail: number[]; // body segment positions (x, y pairs) for serpent bosses
  burnT: number; // remaining burn time
  burnDps: number; // base damage per second while burning
  burnTick: number;
  burnOwner: PlayerId;
  healReadyAt: number; // game time when shamans may heal this boss again
  dead: boolean;
}

export interface Projectile {
  id: number;
  owner: PlayerId;
  src: string; // weapon id, for damage stats
  kind: string; // render kind
  x: number;
  y: number;
  px: number;
  py: number;
  vx: number;
  vy: number;
  dmg: number;
  radius: number;
  pierce: number;
  life: number;
  maxLife: number;
  knock: number;
  hits: Record<number, number>; // enemy id -> time when it can be hit again
  hitRate: number; // 0 = each enemy only once
  homing: number;
  ang: number;
  data: number;
  slow: number;
  age: number;
  speed: number;
  dead: boolean;
}

export interface Zone {
  id: number;
  owner: PlayerId;
  src: string;
  kind: string;
  x: number;
  y: number;
  r: number;
  r0: number;
  life: number;
  maxLife: number;
  delay: number;
  dmg: number;
  knock: number;
  slow: number;
  ang: number;
  arc: number;
  pts: number[];
  hits: Record<number, number>;
  burn: number; // base burn damage per second applied to enemies hit (0 = none)
  fired: boolean;
  dead: boolean;
}

export interface EnemyProjectile {
  id: number;
  kind: string;
  x: number;
  y: number;
  px: number;
  py: number;
  vx: number;
  vy: number;
  r: number;
  dmg: number;
  life: number;
  dead: boolean;
}

export type HazardKind = 'ring' | 'slam' | 'laser' | 'skyfall';

export interface Hazard {
  id: number;
  kind: HazardKind;
  src: number; // enemy id the hazard is attached to (lasers)
  x: number;
  y: number;
  r: number;
  w: number;
  speed: number;
  ang: number;
  angVel: number;
  len: number;
  warn: number;
  maxWarn: number;
  life: number;
  dmg: number;
  hit: Record<string, number>;
  fired: boolean;
  dead: boolean;
}

export interface Turret {
  id: number;
  owner: PlayerId;
  x: number;
  y: number;
  life: number;
  maxLife: number;
  cd: number;
  ang: number;
  dead: boolean;
}

export interface Minion {
  id: number;
  owner: PlayerId;
  x: number;
  y: number;
  px: number;
  py: number;
  life: number;
  cd: number;
  dmg: number;
  dead: boolean;
}

export type PickupKind = 'xp' | 'heal' | 'magnet' | 'bomb' | 'chest';

export interface Pickup {
  id: number;
  kind: PickupKind;
  x: number;
  y: number;
  px: number;
  py: number;
  value: number;
  target: PlayerId | '';
  sp: number;
  big: boolean; // boss chest
  dead: boolean;
}

export interface Corpse {
  x: number;
  y: number;
  t: number;
}

export interface WaveState {
  n: number;
  timer: number;
  spawnAcc: number;
  bossWave: boolean;
  eliteSpawned: boolean;
}

export type SimEvent =
  | { t: 'hit'; x: number; y: number; v: number; crit: boolean; dot: boolean }
  | { t: 'kill'; x: number; y: number; type: string; elite: boolean; boss: boolean; r: number }
  | { t: 'phurt'; pid: PlayerId; v: number }
  | { t: 'pdeath'; pid: PlayerId }
  | { t: 'heal'; pid: PlayerId; v: number }
  | { t: 'levelup'; pid: PlayerId }
  | { t: 'wave'; n: number; boss: boolean }
  | { t: 'boss'; name: string }
  | { t: 'explode'; x: number; y: number; r: number; color: string }
  | { t: 'pickup'; pid: PlayerId; kind: PickupKind }
  | { t: 'chest'; pid: PlayerId; items: string[] }
  | { t: 'evolve'; pid: PlayerId; name: string }
  | { t: 'ability'; pid: PlayerId; char: string }
  | { t: 'dash'; pid: PlayerId }
  | { t: 'dodge'; pid: PlayerId }
  | { t: 'sfx'; name: string }
  | { t: 'shake'; v: number };

export interface SimConfig {
  pauseOnLevelUp: boolean;
  waveDuration: number;
  godMode: boolean;
}

export interface GameState {
  cfg: SimConfig;
  mapSeed: number; // obstacles are a pure function of this seed
  rng: number;
  tick: number;
  time: number;
  nextId: number;
  players: Player[];
  enemies: Enemy[];
  projectiles: Projectile[];
  eprojectiles: EnemyProjectile[];
  zones: Zone[];
  hazards: Hazard[];
  turrets: Turret[];
  minions: Minion[];
  pickups: Pickup[];
  corpses: Corpse[];
  wave: WaveState;
  events: SimEvent[];
  kills: number;
  gameOver: boolean;
}

export const DT = 1 / 60;
