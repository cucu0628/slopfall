// Run snapshots for "continue where you left off". A snapshot keeps what
// defines the run (map seed, heroes and their build, wave, time, kills, the
// bosses still alive) and drops transient things (other enemies, projectiles,
// effects); a restored run simply spawns fresh enemies for the saved wave.
//
// The JSON layout is shared with the TypeScript version of the game, so
// saves exported there load here.

import 'content/characters.dart';
import 'js.dart';
import 'systems/leveling.dart';
import 'systems/secret.dart';
import 'systems/waves.dart';
import 'types.dart';

/// Bump when GameState changes shape so old saves are ignored instead of breaking.
const int saveVersion = 5;

/// Older versions restore() can still upgrade.
const List<int> _upgradable = [3, 4];

/// A save file: `{v, savedAt, state}`. [savedAt] is wall clock ms, for display only.
Map<String, Object?> snapshot(GameState s, int savedAt) {
  final state = s.toJson()
    // bosses keep their HP: respawning the whole boss wave let players farm boss chests by reloading
    ..['enemies'] = [
      for (final e in s.enemies)
        if (e.boss && !e.dead) e.toJson(),
    ]
    ..['projectiles'] = <Object?>[]
    ..['eprojectiles'] = <Object?>[]
    ..['zones'] = <Object?>[]
    ..['hazards'] = <Object?>[]
    ..['turrets'] = <Object?>[]
    ..['minions'] = <Object?>[]
    ..['pickups'] = [
      for (final p in s.pickups)
        if ((p.kind == 'chest' || p.kind == 'relic') && !p.dead) p.toJson(),
    ]
    ..['corpses'] = <Object?>[]
    ..['events'] = <Object?>[];
  return {'v': saveVersion, 'savedAt': savedAt, 'state': state};
}

/// Returns a playable state from a decoded snapshot, or null if it is unusable.
GameState? restore(Object? save) {
  if (save is! Map) return null;
  final sv = jmap(save);
  final v = sv['v'] is num ? jint(sv['v'], -1) : -1;
  final rawState = sv['state'];
  if ((v != saveVersion && !_upgradable.contains(v)) || rawState is! Map || rawState['players'] is! List) return null;
  final GameState s;
  try {
    s = GameState.fromJson(rawState);
  } catch (_) {
    return null;
  }
  if (s.gameOver || s.players.isEmpty || s.players.any((p) => characterDefs[p.charId] == null || p.dead)) return null;
  if (v < 5) {
    // v4 and older predate the secret boss: he may still turn up later in the run
    final secret = rollSecret(s.mapSeed);
    s.secret = secret.wave > s.wave.n ? secret : SecretState(wave: 0, reward: secret.reward);
  }
  for (final p in s.players) {
    if (v == 3) {
      // v3 predates wave max HP: grant what the hero would have earned so far
      p.vigorHp = vigorHpAt(s.wave.n);
    }
    if (v < 5) refreshStats(p); // new stats (gemDouble, maxHpMul) get their defaults
    p.px = p.x;
    p.py = p.y;
    p.anchorX = p.x;
    p.anchorY = p.y;
    p.idleT = 0;
    p.dashT = 0;
    p.slowT = 0;
    p.invuln = 2; // a moment to get your bearings
  }
  s.events = [];
  s.wave.spawnAcc = 6;
  return s;
}
