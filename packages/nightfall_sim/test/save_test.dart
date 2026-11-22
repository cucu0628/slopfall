import 'package:nightfall_sim/nightfall_sim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Map<String, Object?> _save(GameState s) => (roundTrip(snapshot(s, 0)) as Map).cast<String, Object?>();

Map<String, Object?> _m(Object? v) => (v as Map).cast<String, Object?>();

void main() {
  group('saving runs', () {
    test('saves and restores a run without enemies', () {
      final s = createGame(46, [const PlayerSetup('p1', 'ranger')], godMode: true);
      run(s, 2400);
      final save = (roundTrip(snapshot(s, 123)) as Map).cast<String, Object?>();
      expect((_m(save['state'])['enemies'] as List).length, 0);
      final r = restore(save)!;
      expect(r.wave.n, s.wave.n);
      expect(r.mapSeed, s.mapSeed);
      expect(r.players[0].weapons, s.players[0].weapons);
      expect(r.players[0].level, s.players[0].level);
      run(r, 600);
      expect(r.enemies, isNotEmpty);
      expect(restore({...save, 'v': -1}), isNull);

      final b = createGame(47, [const PlayerSetup('p1', 'knight')]);
      startWave(b, 10);
      final rb = restore(_save(b))!;
      expect(rb.enemies.any((e) => e.boss), isTrue);
    });

    test('keeps boss HP and does not bring back a killed boss', () {
      final s = createGame(48, [const PlayerSetup('p1', 'knight')], godMode: true);
      startWave(s, 20);
      final bosses = s.enemies.where((e) => e.boss).toList();
      final a = bosses[0], b = bosses[1];
      damageEnemy(s, a, a.hp + 1, null, 'test');
      damageEnemy(s, b, b.maxHp * 0.4, null, 'test');
      final r = restore(_save(s))!;
      final left = r.enemies.where((e) => e.boss).toList();
      expect(left.map((e) => e.id).toList(), [b.id]);
      expect(left[0].hp, closeTo(b.hp, 1e-6));
      expect(r.wave.n, 20);
    });

    test('upgrades a v3 save by granting the wave max HP it predates', () {
      final s = createGame(49, [const PlayerSetup('p1', 'knight')], godMode: true);
      s.wave.n = 12;
      final save = _save(s);
      save['v'] = 3;
      _m((_m(save['state'])['players'] as List)[0]).remove('vigorHp');
      final r = restore(save)!;
      expect(r.players[0].vigorHp, 10);
      expect(r.players[0].stats.maxHp, s.players[0].stats.maxHp + 10);
    });

    test('upgrades a v4 save that predates the secret boss', () {
      final s = createGame(50, [const PlayerSetup('p1', 'mage')], godMode: true);
      s.wave.n = 12;
      final save = _save(s);
      save['v'] = 4;
      final state = _m(save['state']);
      state.remove('secret');
      final stats = _m(_m((state['players'] as List)[0])['stats']);
      stats.remove('gemDouble');
      stats.remove('maxHpMul');
      final r = restore(save)!;
      expect(r.secret.wave == 0 || r.secret.wave > 12, isTrue);
      expect(r.players[0].stats.gemDouble, 0);
      expect(r.players[0].stats.maxHp, s.players[0].stats.maxHp);
    });

    test('rejects garbage', () {
      expect(restore(null), isNull);
      expect(restore('nope'), isNull);
      expect(
        restore({
          'v': 5,
          'state': {'players': 'x'},
        }),
        isNull,
      );
      expect(
        restore({
          'v': 5,
          'state': {'players': []},
        }),
        isNull,
      );
    });
  });
}
