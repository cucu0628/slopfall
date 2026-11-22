# Nightfall Survivors

2D survivor roguelite (Vampire Survivors style) built with Dart + Flutter. Runs on **Linux, Windows, the web and Android** from one codebase. No image assets — everything is drawn procedurally, and the sound effects are synthesized.

```bash
# play
cd app
flutter run -d linux          # or -d chrome, -d windows, or a connected Android device

# check
cd packages/nightfall_sim && dart test      # simulation tests (determinism, waves, level-ups, parity with the original)
cd app && flutter analyze && flutter test   # app tests

# build
cd app
flutter build web --release --wasm          # static site in build/web
flutter build linux --release               # build/linux/x64/release/bundle
flutter build windows --release             # on Windows
flutter build apk --release                 # Android
```

Linux desktop builds need `clang cmake ninja-build pkg-config` and the GTK 3 development package (e.g. `sudo dnf install clang cmake ninja-build pkgconf-pkg-config gtk3-devel`).

## Hosting
Every push to `main` runs `.github/workflows/deploy.yml`: it runs the tests, builds the web app and publishes `app/build/web` to GitHub Pages at **https://game.asked.hu/**. Tagging a release (`v1.2.0`) runs `release.yml`, which attaches Linux, Windows and Android builds to the GitHub release.

The game used to be a TypeScript + Canvas 2D web app; that version is kept on the `legacy/typescript` branch. Saves carry over: on the same website the old save slot is picked up automatically, and exported save files can be imported on any platform.

## Controls
WASD / arrows move · mouse aims · Space or right click uses your hero's ability · Shift dashes · 1–3 picks a level-up · Esc pauses · M mutes · F11 fullscreen (desktop and web).

On phones and tablets on-screen controls appear automatically: drag on the left half to move (aiming is automatic), ★ ability, » dash, ❚❚ pause.

## Content
- **6 heroes**, each with a starting weapon, a passive and an active ability (Knight, Mage, Ranger, Necromancer, Engineer, Berserker).
- **10 weapons** (8 levels each). At max level a chest unlocks an **evolution**; five weapons have two evolution paths (each needs a different perk) and the player picks one.
- **14 perks** (incl. Vampirism lifesteal and Ignite burn); level-ups can roll **Rare** (×1.4) or **Epic** (×1.8) strength. Max 6 weapon + 6 perk slots.
- The current run is **saved** (every few seconds and when the app is hidden or closed) and can be continued from the main menu. Saves can be **exported to a file and imported** (e.g. to move a run to another device).
- The main menu has a **Codex** describing every enemy and boss.
- Heroes gain **+5 max HP after every 5th wave**, even without HP perks.
- **9 enemy types** + elites, **6 bosses** every 5th wave (two at once from wave 20), endless scaling waves, anti-AFK meteors.

## License
© 2026 cucu0628. **All rights reserved.** The code is published for viewing only; copying, modifying, re-hosting or any other use requires written permission. See [LICENSE](LICENSE).

## Contributing
Bug reports and ideas are welcome through the issue templates (**Bug report** / **Feature request**).

Pull requests are welcome too: read [AGENT.md](AGENT.md) first (architecture, rules and step-by-step recipes for new weapons, perks, enemies, bosses and heroes). Every PR is checked by CI (simulation tests incl. web parity, `flutter analyze`, `flutter test`, web build). By opening a pull request you agree to the contribution terms in [LICENSE](LICENSE).

## Project structure
```
packages/nightfall_sim/   deterministic game rules (pure Dart) – content/ data tables, systems/ per-tick logic,
                          systems/weapons/ and systems/bosses/ one file per weapon / boss, test/ suites by topic
app/                      Flutter client – game/ loop and input, render/ (entities/, heroes/), ui/ screens,
                          audio/ (synthesized sounds), storage/ (save slot), platform/ (fullscreen, wakelock)
src/, tests/              the original TypeScript version, the reference the Dart port is tested against
```

## Architecture (multiplayer-ready)
- `packages/nightfall_sim` is a pure, deterministic simulation: no Flutter, no clock, seeded RNG stored in the state, fixed 60 Hz `step(state, inputs)`. It gives bit-identical results on the Dart VM, compiled to JavaScript and to WebAssembly (its own `sin`/`cos`/`atan2` and 32-bit integer helpers make sure of that), and matches the original TypeScript game tick for tick.
- `GameState` is plain JSON-serializable data with a `players` list; every player decision (movement, aim, ability, level-up choice) is an `InputCmd`.
- The sim emits events; the client (`app/`) turns them into particles, sounds and UI.
- Content (heroes, weapons, perks, enemies) lives in data tables under `lib/src/content/`.

To add multiplayer later, run the simulation on a server (or in lockstep on every client — all platforms compute the same results), collect each player's `InputCmd` per tick, and broadcast inputs or state snapshots. For co-op, create the game with `pauseOnLevelUp: false`.
