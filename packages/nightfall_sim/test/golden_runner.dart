// Replays a scenario recorded from the TypeScript simulation (see
// tool/ts_golden/README.md) and reports fingerprints along the way.

import 'package:nightfall_sim/nightfall_sim.dart';

import 'helpers.dart';

List<Object?> fingerprint(GameState s) {
  var ex = 0.0, ey = 0.0, ehp = 0.0;
  for (final e in s.enemies) {
    ex += e.x;
    ey += e.y;
    ehp += e.hp;
  }
  return [
    s.tick, s.rng, s.nextId, s.kills, s.wave.n, s.enemies.length, s.projectiles.length, s.pickups.length, //
    s.zones.length, s.hazards.length, s.eprojectiles.length, ex, ey, ehp,
    for (final p in s.players) ...[
      p.x, p.y, p.hp, p.xp, p.level, p.weapons.map((w) => '${w.id}${w.level}${w.evo}').join(','), //
      p.perks.map((k) => '${k.id}${k.level}').join(','),
    ],
  ];
}

const _fields = [
  'tick',
  'rng',
  'nextId',
  'kills',
  'wave',
  'enemies',
  'projectiles',
  'pickups',
  'zones',
  'hazards',
  'eproj',
  'ex',
  'ey',
  'ehp',
];
const _playerFields = ['x', 'y', 'hp', 'xp', 'level', 'weapons', 'perks'];

String _field(int i) => i < _fields.length ? _fields[i] : 'p${(i - _fields.length) ~/ 7}.${_playerFields[(i - _fields.length) % 7]}';

/// Describes the first difference between two fingerprints, or null.
String? diffFingerprints(List<Object?> got, List<Object?> want) {
  if (got.length != want.length) return 'length ${got.length} vs ${want.length}';
  for (var i = 0; i < want.length; i++) {
    final a = got[i], b = want[i];
    final equal = a is num && b is num ? a.toDouble() == b.toDouble() : a == b;
    if (!equal) return '${_field(i)} dart=$a ts=$b';
  }
  return null;
}

GameState setupScenario(Map<String, Object?> sc) {
  final chars = (sc['chars'] as List).cast<String>();
  final s = createGame(
    sc['seed'] as int,
    [for (var i = 0; i < chars.length; i++) PlayerSetup('p$i', chars[i])],
    godMode: sc['godMode'] as bool,
    waveDuration: (sc['waveDuration'] as num).toDouble(),
  );
  if (sc['secret'] case final Map<Object?, Object?> secret) s.secret = SecretState.fromJson(secret);
  if (sc['wave'] case final int wave) {
    s.enemies = [];
    startWave(s, wave);
  }
  for (final p in s.players) {
    if (sc['weapons'] case final List<Object?> ws) {
      p.weapons = [
        for (final w in ws.cast<List<Object?>>())
          WeaponInst(id: w[0] as String, level: w[1] as int, evolved: w[2] != '', evo: w[2] as String),
      ];
    }
    if (sc['perks'] case final List<Object?> ks) {
      p.perks = [
        for (final k in ks.cast<List<Object?>>()) PerkInst(id: k[0] as String, level: k[1] as int, power: (k[2] as num).toDouble()),
      ];
    }
    refreshStats(p);
  }
  return s;
}

/// Runs the scenario; [onSample] gets every sampled fingerprint, [onSave]
/// may replace the state with a restored save at `saveAt`.
GameState runScenario(Map<String, Object?> sc, int sample, void Function(GameState s) onSample, {GameState Function(GameState s)? onSave}) {
  var s = setupScenario(sc);
  final saveAt = sc['saveAt'] as int?;
  onSample(s);
  for (var i = 1; i <= (sc['ticks'] as int) && !s.gameOver; i++) {
    step(s, {for (final p in s.players) p.id: botInput(s, p.id)});
    if (saveAt == i) s = onSave != null ? onSave(s) : restore(roundTrip(snapshot(s, 1700000000000)))!;
    if (i % sample == 0 || s.gameOver) onSample(s);
  }
  return s;
}
