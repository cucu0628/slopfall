// Goldfang the Greedy, the secret boss. Whether (and on which boss wave) he
// shows up and what he drops is rolled once from the run seed, so a run can
// meet him at most once and reloading a save can't reroll either.

import '../content/perks.dart';
import '../content/weapons.dart';
import '../map.dart';
import '../types.dart';
import 'leveling.dart';
import 'waves.dart';

/// Chance per boss wave (from secretFirstWave on) that Goldfang replaces the boss.
const double secretChance = 0.03;

/// The first boss fight is always a regular one.
const int secretFirstWave = 10;
const int _maxBossWaves = 40;

const String secretWeapon = 'coins';
const String secretPerk = 'goldpurse';

SecretState rollSecret(int seed) {
  final reward = hash(seed, 7331, 1) % 2 == 0 ? 'weapon' : 'perk';
  for (var n = secretFirstWave; n <= _maxBossWaves * bossEvery; n += bossEvery) {
    if (hash(seed, 7331, 2, n) / 4294967296 < secretChance) return SecretState(wave: n, reward: reward);
  }
  return SecretState(wave: 0, reward: reward);
}

/// Picking up Goldfang's treasure: his unique weapon or perk, depending on the roll.
void grantSecretReward(GameState s, Player p) {
  if (s.secret.reward == 'weapon') {
    final d = weaponDefs[secretWeapon]!;
    if (!p.weapons.any((w) => w.id == secretWeapon)) p.weapons.add(WeaponInst(id: secretWeapon, cd: 0.3));
    s.events.add(UniqueEvent(p.id, d.name, d.desc));
  } else {
    final d = perkDefs[secretPerk]!;
    if (!p.perks.any((k) => k.id == secretPerk)) p.perks.add(PerkInst(id: secretPerk));
    refreshStats(p);
    s.events.add(UniqueEvent(p.id, d.name, d.desc(1)));
  }
}
