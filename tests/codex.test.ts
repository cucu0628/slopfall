import { describe, expect, it } from 'vitest';
import { CODEX_ENTRIES } from '../src/client/ui/codexEntries';
import { ENEMIES } from '../src/sim/content/enemies';

describe('codex', () => {
  it('describes every enemy and boss', () => {
    for (const id of Object.keys(ENEMIES)) expect(CODEX_ENTRIES[id], id).toBeTruthy();
    for (const id of Object.keys(CODEX_ENTRIES)) expect(ENEMIES[id], id).toBeTruthy();
  });
});
