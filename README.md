# Nightfall Survivors

Browser-based 2D survivor roguelite (Vampire Survivors style) built with TypeScript + Canvas 2D. No runtime dependencies and no image assets — everything is drawn procedurally.

```bash
npm install
npm run dev      # play at http://localhost:3064
npm run test     # simulation tests (determinism, waves, level-ups)
npm run typecheck  # strict TypeScript check
npm run build    # type-check + production build into dist/
npm run preview  # serve the production build on port 3064
```

Both the dev server and `preview` listen on all interfaces on port **3064** (see `vite.config.ts`).

## Hosting
Every push to `main` runs `.github/workflows/deploy.yml`: it installs, runs the tests, builds and publishes `dist/` to GitHub Pages at **https://cucu0628.github.io/slopfall/**. The game is a static site, so `dist/` can also be served by any web server.

## Controls
WASD / arrows move · mouse aims · Space or right click uses your hero's ability · Shift dashes · 1–3 picks a level-up · Esc pauses · M mutes.

On phones and tablets on-screen controls appear automatically: drag on the left half to move (aiming is automatic), ★ ability, » dash, ❚❚ pause.

## Content
- **6 heroes**, each with a starting weapon, a passive and an active ability (Knight, Mage, Ranger, Necromancer, Engineer, Berserker).
- **10 weapons** (8 levels each). At max level a chest unlocks an **evolution**; five weapons have two evolution paths (each needs a different perk) and the player picks one.
- **14 perks** (incl. Vampirism lifesteal and Ignite burn); level-ups can roll **Rare** (×1.4) or **Epic** (×1.8) strength. Max 6 weapon + 6 perk slots.
- The current run is **saved in the browser** (every few seconds and when the tab is hidden/closed) and can be continued from the main menu. Saves can be **exported to a file and imported** (e.g. to move a run to another device).
- The main menu has a **Codex** describing every enemy and boss.
- Heroes gain **+5 max HP after every 5th wave**, even without HP perks.
- **9 enemy types** + elites, **6 bosses** every 5th wave (two at once from wave 20), endless scaling waves, anti-AFK meteors.

## License
© 2026 cucu0628. **All rights reserved.** The code is published for viewing only; copying, modifying, re-hosting or any other use requires written permission. See [LICENSE](LICENSE).

## Contributing
Bug reports and ideas are welcome through the issue templates (**Bug report** / **Feature request**).

Pull requests are welcome too: read [AGENT.md](AGENT.md) first (architecture, rules and step-by-step recipes for new weapons, perks, enemies, bosses and heroes). Every PR is checked by CI (`npm run typecheck`, `npm test`, build). By opening a pull request you agree to the contribution terms in [LICENSE](LICENSE).

## Project structure
```
src/sim/        deterministic game rules (no DOM) – content/ data tables, systems/ per-tick logic,
                systems/weapons/ and systems/bosses/ one file per weapon / boss
src/client/     browser side – app flow, input/touch, audio, render/ (entities/, heroes/), ui/ (screens, styles/)
tests/          vitest suites by topic
```

## Architecture (multiplayer-ready)
- `src/sim/` is a pure, deterministic simulation: no DOM, no `Math.random`/`Date.now`, seeded RNG stored in the state, fixed 60 Hz `step(state, inputs)`.
- `GameState` is plain JSON-serializable data with a `players[]` array; every player decision (movement, aim, ability, level-up choice) is an `InputCmd`.
- The sim emits `events[]`; the client (`src/client/`) turns them into particles, sounds and UI.
- Content (heroes, weapons, perks, enemies) lives in data tables under `src/sim/content/`.

To add multiplayer later, run `src/sim` on a server (or in lockstep on every client), collect each player's `InputCmd` per tick, and broadcast inputs or state snapshots. For co-op, set `cfg.pauseOnLevelUp = false`.
