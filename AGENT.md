# AGENT.md

Guide for AI coding agents (and humans) working on **Nightfall Survivors**, a browser survivor roguelite (Vampire Survivors style) in TypeScript + Canvas 2D. Live at https://game.asked.hu/.

## Commands

```bash
npm install         # once
npm run dev         # dev server on http://localhost:3064
npm test            # vitest, all simulation tests (fast, < 5 s)
npm run typecheck   # tsc --noEmit (strict, no unused locals/params)
npm run build       # typecheck + production build into dist/
```

Before you finish any change: `npm run typecheck && npm test && npm run build` must pass.

## Architecture in one minute

```
src/
  main.ts                 entry point, only calls startApp()
  sim/                    THE GAME RULES. Deterministic, no DOM, runs anywhere (also on a future server)
    types.ts              GameState and every entity type (plain JSON data)
    world.ts              createGame() and step(state, inputs) – one fixed 60 Hz tick
    content/              data tables: characters, weapons (+evolutions), perks (+bonus shards), enemies (+bosses)
    systems/              per-tick logic: waves, enemies, leveling, pickups, abilities, hazards, idle (anti-AFK)
      weapons/            one file per weapon behaviour + index.ts registry, projectiles, zones, turrets, minions
      bosses/             one file per boss behaviour + index.ts registry
    combat.ts             damage, kills, healing, burn, wave scaling
    entities.ts           factories (spawnEnemy, addProjectile, addZone, ...)
    map.ts                procedural biomes/obstacles (pure function of mapSeed)
    spatial.ts            spatial hash for collision queries
    save.ts               run snapshot/restore for "Continue"
    rng.ts                seeded RNG stored in GameState
  client/                 BROWSER ONLY: input, rendering, audio, menus
    app.ts                menus, start/continue/pause flow, run saving
    session.ts            fixed-timestep loop, sim events -> effects/sounds
    input.ts, touch.ts    keyboard/mouse and on-screen touch controls -> InputCmd
    runStorage.ts         localStorage save slot
    audio.ts              procedural WebAudio sounds
    render/               canvas renderer, HUD, minimap, map, effects
      entities/           enemies, bosses, projectiles, zones, hazards, pickups, allies
      heroes/             one file per hero figure + shared drawing primitives
    ui/                   HTML overlay screens (dom.ts, charSelect, levelUp, pause, gameOver) and styles/*.css
tests/                    vitest suites by topic + helpers.ts (deterministic bot, run())
```

Data flow: `client` turns input into an `InputCmd` → `step(state, { [playerId]: cmd })` advances the sim → the sim pushes `state.events` (hits, kills, explosions, level-ups...) → `session.ts` turns events into particles, numbers and sounds → `renderer.ts` draws `GameState`.

## Hard rules for `src/sim`

The simulation must stay **deterministic** and **serializable** – this is what makes saving and future multiplayer possible, and `tests/determinism.test.ts` enforces it.

- No `Math.random`, `Date`, `performance`, timers, DOM or `window` in `src/sim`. Use `rand(s)` / `randRange(s, …)` from `rng.ts`.
- `GameState` holds plain data only (no classes, closures, `Map`/`Set`, `Infinity`/`NaN`). Use `1e9` instead of `Infinity`.
- Every player decision goes through `InputCmd` (movement, aim, ability, dash, level-up choice). Never read input directly in the sim.
- The sim never draws or plays sounds; it pushes a `SimEvent` and the client reacts.
- Iteration order must not depend on object identity or hashing of non-deterministic values.
- Dead entities are flagged `dead = true` and removed in `cleanup()` at the end of `step()`.
- `src/client` may import from `src/sim`, **never the other way round**.
- If you change the shape of `GameState` (add/rename fields on players, enemies, ...), bump `SAVE_VERSION` in `src/sim/save.ts` so old browser saves are discarded instead of breaking, and give new fields defaults in the factories (`createPlayer`, `spawnEnemy`, `addZone`, ...).

## Recipes

**New weapon**
1. Add its data to `src/sim/content/weapons.ts` (`base` stats, 7 `levels` deltas, `evos`).
2. Create `src/sim/systems/weapons/<name>.ts` exporting a `WeaponUpdate` and register it in `systems/weapons/index.ts`.
3. Draw new projectile/zone kinds in `src/client/render/entities/projectiles.ts` / `zones.ts` (and their glow colour in `projectileColor`).
4. Add a test (see `tests/leveling.test.ts` "runs every alternative evolution").

**New evolution** – add an entry to the weapon's `evos` array (`id`, required `perk`, `stats` deltas) and branch on `w.evo === '<id>'` in the weapon's behaviour file. The chest/evolution picker UI picks it up automatically.

**New perk** – add a `PerkDef` to `content/perks.ts`. `apply(stats, power)` receives the rarity-weighted sum of level-ups; if you need a new stat add it to `Stats` (types.ts) and its default in `computeStats` (systems/leveling.ts). Set `rarity: false` for integer effects.

**New enemy** – data row in `content/enemies.ts` (`unlock` wave, spawn `cost`, `group` size), behaviour case in `updateRegular` (systems/enemies.ts) if it is not a plain chaser, artwork case in `render/entities/enemies.ts`, and a Codex description in `client/ui/codexEntries.ts` (a test checks every enemy has one).

**New boss** – data row with `boss: true`, a behaviour file in `systems/bosses/` registered in its `index.ts` (`init` timers + `update`), add the id to `BOSS_ORDER`, artwork in `render/entities/bosses.ts`, Codex description in `client/ui/codexEntries.ts`.

**New hero** – entry in `content/characters.ts` (stats, starting weapon, passive mods, ability), ability logic in `systems/abilities.ts`, figure in `render/heroes/<name>.ts` registered in `render/heroes/index.ts`.

**Sounds** – add a case to `Sound.play` in `client/audio.ts` and emit `{ t: 'sfx', name }` from the sim.

## Balance knobs

- Enemy scaling: `waveScale()` in `sim/combat.ts`; boss HP: `bossHpFactor()` in `systems/waves.ts`.
- XP curve: `xpForLevel()` in `systems/leveling.ts`; perk rarity odds: `RARITIES` in `content/perks.ts`.
- Spawn rate and elites: `updateWaves()` in `systems/waves.ts`; chests: champion elite every 5 waves + bosses.
- Anti-AFK meteors: `systems/idle.ts`.

When tuning, measure instead of guessing: write a throwaway vitest that builds a player (`createGame`, set `weapons`/`perks`, `refreshStats`), runs `step()` and prints time-to-kill or survival time. Delete it afterwards.

## Conventions

- TypeScript strict; 2-space indent, single quotes, semicolons, trailing commas in multi-line literals.
- Comments explain *why*, not *what*; keep them short. Match the style of the file you edit.
- Player-facing text is English.
- Keep files focused; prefer adding a new file under the right folder over growing a big one.
- Rendering uses procedural vector graphics only (no image assets). Glows use `glow()` from `render/sprites.ts`, not `shadowBlur`.
- Mobile matters: test layouts at phone sizes (e.g. 390×844 and 844×390) when touching UI or CSS.

## Deployment and license

- Every push to `main` runs `.github/workflows/deploy.yml` (tests → build → GitHub Pages at game.asked.hu). Pull requests run `.github/workflows/ci.yml`.
- The project is **all rights reserved** (see `LICENSE`). Keep the copyright notice in the menu, the bundle banner and the LICENSE intact.
