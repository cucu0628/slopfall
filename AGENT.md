# AGENT.md

Guide for AI coding agents (and humans) working on **Nightfall Survivors**, a survivor roguelite (Vampire Survivors style) in Dart + Flutter for Linux, Windows, web and Android. Live at https://game.asked.hu/.

## Commands

```bash
# simulation (pure Dart package)
cd packages/nightfall_sim
dart test                      # all simulation tests, incl. TypeScript parity (< 10 s)
dart test -p node test/cross_platform_test.dart              # same results compiled to JS
dart test -p node -c dart2wasm test/cross_platform_test.dart # ... and to Wasm
dart analyze --fatal-infos && dart format lib test

# app (Flutter)
cd app
flutter run -d linux           # or: -d chrome, -d windows, an Android device
flutter test                   # widget + render tests
flutter analyze --fatal-infos
flutter build web --release --wasm | linux | windows | apk
SNAPSHOT_DIR=/tmp/shots flutter test test/render_snapshot_test.dart test/ui_snapshot_test.dart  # PNGs of gameplay and every screen
```

Before you finish any change: `dart test` (sim), `flutter analyze --fatal-infos` and `flutter test` (app) must pass.
Linux builds and app tests need `clang cmake ninja-build pkg-config` and the GTK 3 dev package (the audio plugin compiles native code).

## Architecture in one minute

```
packages/nightfall_sim/          THE GAME RULES. Pure Dart, no Flutter, deterministic, runs anywhere (also on a future server)
  lib/src/types.dart             GameState and every entity type, with toJson/fromJson (same JSON as the TypeScript version)
  lib/src/world.dart             createGame() and step(state, inputs) – one fixed 60 Hz tick
  lib/src/content/               data tables: characters, weapons (+evolutions), perks (+bonus shards), enemies (+bosses)
  lib/src/systems/               per-tick logic: waves, enemies, leveling, pickups, abilities, hazards, idle (anti-AFK), secret boss
    weapons/                     one file per weapon behaviour + index.dart registry, projectiles, zones, turrets, minions
    bosses/                      one file per boss behaviour + index.dart registry
  lib/src/combat.dart            damage, kills, healing, burn, wave scaling
  lib/src/entities.dart          factories (spawnEnemy, addProjectile, addZone, ...)
  lib/src/map.dart               procedural biomes/obstacles (pure function of mapSeed)
  lib/src/spatial.dart           spatial hash for collision queries
  lib/src/save.dart              run snapshot/restore for "Continue" (also reads saves of the TypeScript game)
  lib/src/rng.dart               seeded RNG stored in GameState
  lib/src/js.dart, fdlibm.dart   JS-identical number helpers and sin/cos/atan2 (see "Determinism")
  test/                          suites by topic, helpers.dart (deterministic bot), ts_parity_test + fixtures
app/                             Flutter client: Linux, Windows, web, Android
  lib/main.dart, app.dart        entry point; app flow (menus, start/continue/pause, saving) – the GameShell widget
  lib/game/session.dart          fixed-timestep loop, sim events -> effects/sounds, demo bot
  lib/game/input.dart, touch.dart  keyboard/mouse and touch control state -> InputCmd
  lib/render/canvas2d.dart       Canvas 2D API (paths, gradients, dashes, 'lighter', text) on Flutter's Canvas
  lib/render/                    renderer, map, minimap, HUD, effects, sprites (glows)
    entities/                    enemies, bosses, projectiles, zones, hazards, pickups, allies
    heroes/                      one file per hero figure + shared drawing primitives
  lib/ui/theme.dart              design tokens (Nf.*) and primitives: Panel, NfButton, NfLabel, Kbd, ScreenTitle, ScreenLayer
  lib/ui/screens/                main menu, char select, level up, pause, game over, codex (+ codex_entries.dart)
  lib/ui/touch_controls.dart     joystick, ability/dash/pause buttons
  lib/audio/                     synth.dart renders the procedural sounds to PCM; sound.dart plays them (flutter_soloud)
  lib/storage/                   save slot (web: localStorage key "nightfall.run", like the old game; else shared_preferences)
  lib/platform/window*.dart      fullscreen (F11 via the "nightfall/window" channel in the Linux/Windows runners), wakelock
  assets/fonts/                  subsetted Noto fonts (OFL) so text and symbols look the same everywhere
```

Data flow: the client turns input into an `InputCmd` → `step(state, {playerId: cmd})` advances the sim → the sim pushes `state.events` (sealed `SimEvent` classes: hits, kills, explosions, level-ups...) → `session.dart` turns events into particles, numbers and sounds → `renderer.dart` draws `GameState`.

The original TypeScript version lives on the `legacy/typescript` branch; `ts_parity_test.dart` checks the Dart port against scenarios recorded from it.

## Hard rules for `packages/nightfall_sim`

The simulation must stay **deterministic** and **serializable** – this is what makes saving and future multiplayer possible, and `determinism_test.dart` / `cross_platform_test.dart` enforce it.

- No `dart:math` `sin/cos/atan2/Random`, `DateTime`, `Stopwatch`, I/O or Flutter in the sim. Use `jsSin/jsCos/jsAtan2` (fdlibm.dart), `hypot` (js.dart) and `rand(s)` / `randRange(s, …)` from rng.dart.
- Integer bit tricks go through `u32/i32/imul/ushr` (js.dart): on the web `>>`, `&`, `^` work on unsigned 32-bit values, on the VM on 64-bit ints.
- Use `jsMod` for `%` on doubles (JS keeps the dividend's sign), `jsRound`/`roundInt` for `Math.round`, `or1(d)` for `d || 1`.
- Loops over entity lists that can grow while iterating (spawns, drops) use index loops, not `for-in`.
- `GameState` holds plain data only; add new fields to the class, its `toJson`/`fromJson` (with a default for old saves) and the factory.
- Every player decision goes through `InputCmd`. The sim never reads input, draws or plays sounds; it pushes a `SimEvent` and the client reacts.
- Dead entities are flagged `dead = true` and removed in `_cleanup()` at the end of `step()`.
- `app` may import `nightfall_sim`, **never the other way round**.
- If you change the shape of `GameState`, bump `saveVersion` in save.dart and handle older versions in `restore()`.
- `ts_parity_test.dart` replays scenarios recorded from the TypeScript game. A deliberate gameplay change breaks it: then delete the fixture and that test (see `tool/ts_golden/README.md`).

## Recipes

**New weapon**
1. Add its data to `content/weapons.dart` (`base` stats, 7 `levels` deltas, `evos`).
2. Create `systems/weapons/<name>.dart` with a `WeaponUpdate` function and register it in `systems/weapons/index.dart`.
3. Draw new projectile/zone kinds in `app/lib/render/entities/projectiles.dart` / `zones.dart` (and their glow colour in `projectileColor`).
4. Add a test (see `leveling_test.dart` "runs every alternative evolution"). If the icon is a new symbol, add it to the icon font subset (`assets/fonts`).

**New evolution** – add an `EvoDef` to the weapon's `evos` and branch on `w.evo == '<id>'` in the weapon's behaviour file. The chest/evolution picker UI picks it up automatically.

**New perk** – add a `PerkDef` to `content/perks.dart`. `apply(stats, power)` receives the rarity-weighted sum of level-ups; for a new stat add it to `Stats` (types.dart: field, `keys`, `[]`/`[]=`) and its default in `computeStats` (systems/leveling.dart). Set `rarity: false` for integer effects.

**New enemy** – data row in `content/enemies.dart` (`unlock` wave, spawn `cost`, `group` size), behaviour case in `_updateRegular` (systems/enemies.dart) if it is not a plain chaser, artwork case in `app/lib/render/entities/enemies.dart`, and a Codex entry in `app/lib/ui/codex_entries.dart`.

**New boss** – data row with `boss: true`, a behaviour file in `systems/bosses/` registered in its `index.dart` (`init` timers + `update`), add the id to `bossOrder`, artwork in `app/lib/render/entities/bosses.dart`, Codex entry.

**Secret boss** – Goldfang the Greedy (`systems/secret.dart`, `systems/bosses/goldfang.dart`). `rollSecret(seed)` decides once per run, from the seed, on which boss wave (if any) he replaces the lineup and whether his treasure (`relic` pickup) is the unique weapon `coins` or the unique perk `goldpurse`. Unique items (`unique: true`) are left out of `weaponIds` / `perkIds`, never offered as new and take no slot.

**New hero** – entry in `content/characters.dart`, ability logic in `systems/abilities.dart`, figure in `app/lib/render/heroes/<name>.dart` registered in `heroes/index.dart`.

**Sounds** – add a recipe to `soundRecipes()` in `app/lib/audio/synth.dart` (tones and filtered noise, like the old WebAudio code) and emit `SfxEvent('<name>')` from the sim.

## Balance knobs

- Enemy scaling: `waveScale()` in combat.dart; boss HP: `bossHpFactor()` in systems/waves.dart.
- XP curve: `xpForLevel()` in systems/leveling.dart; perk rarity odds: `rarities` in content/perks.dart.
- Spawn rate and elites: `updateWaves()` in systems/waves.dart; chests: champion elite every 5 waves + bosses.
- Anti-AFK meteors: systems/idle.dart.

When tuning, measure instead of guessing: write a throwaway test that builds a player (`createGame`, set `weapons`/`perks`, `refreshStats`), runs `step()` and prints time-to-kill or survival time. Delete it afterwards.

## Conventions

- Dart: `dart format` with 140 columns (`analysis_options.yaml`), single quotes, `--fatal-infos` clean.
- Comments explain *why*, not *what*; keep them short. Match the style of the file you edit.
- Player-facing text is English.
- Keep files focused; prefer adding a new file under the right folder over growing a big one.
- Rendering uses procedural vector graphics only (no image assets), drawn through `Ctx2D`. Glows use `glow()` from render/sprites.dart, not blurs.
- UI uses the tokens in `ui/theme.dart` (`Nf.s*` spacing, `Nf.fs*` sizes, `Nf.r*` radii, colours) and its primitives. Don't add raw sizes or colours in screens.
- Mobile matters: phones are played **in landscape only** (Android: `sensorLandscape` + immersive mode from start-up; web: `web/index.html` enters fullscreen and locks landscape on the first tap, `RotateHint` covers portrait where the lock fails). Check layouts at 844×390 and 740×360 with the UI snapshot test. Short screens (`Nf.compact(context)`, height < 520) get tighter layouts: cards in one row, Back beside the title, a hero strip instead of the hero grid.
- Overlay performance: while an overlay covers a run, `GameView(frozen: true)` keeps one blurred image of the last frame instead of redrawing the world (no `BackdropFilter`). `Nf.lite` (touch platforms) drops the soft panel shadows. On the web, touch devices render at most 2 device pixels per CSS pixel (`index.html`).

## Deployment and license

- Every push to `main` runs `.github/workflows/deploy.yml` (tests → Flutter web build → GitHub Pages at game.asked.hu). Pull requests run `.github/workflows/ci.yml`. A `v*` tag runs `release.yml` (Linux, Windows and Android builds attached to a GitHub release).
- The project is **all rights reserved** (see `LICENSE`). Keep the copyright notice in the menu, `main.dart` and the LICENSE intact. The bundled Noto fonts are under the SIL OFL (`app/assets/fonts/OFL.txt`).
