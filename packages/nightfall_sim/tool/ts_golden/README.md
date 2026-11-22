# TypeScript parity fixture

`test/fixtures/ts_golden.json` holds fingerprints (RNG state, entity counts,
summed enemy positions/HP, player state) recorded every 20 ticks from the
original TypeScript simulation, plus a save file it wrote. `test/ts_parity_test.dart`
replays the same scenarios on the Dart port and requires bit-identical results.

Only regenerate it if the TypeScript version changes (it lives on the
`legacy/typescript` branch). Node 24 runs `.ts` files directly, but needs
explicit import extensions, so copy the sources and patch the imports first:

```bash
git worktree add /tmp/nightfall-ts legacy/typescript
mkdir -p /tmp/golden && cp -r /tmp/nightfall-ts/src/sim /tmp/nightfall-ts/tests/helpers.ts /tmp/golden/
cp tool/ts_golden/golden.ts /tmp/golden/
python3 tool/ts_golden/add_extensions.py /tmp/golden
node /tmp/golden/golden.ts > test/fixtures/ts_golden.json
```

Once a gameplay change is made in Dart on purpose, the TypeScript history no
longer applies: delete the fixture and this test instead of regenerating.
