import 'package:nightfall_sim/nightfall_sim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('determinism (required for multiplayer)', () {
    test('is deterministic for the same seed and inputs', () {
      final a = createGame(1234, [const PlayerSetup('p1', 'mage')]);
      final b = createGame(1234, [const PlayerSetup('p1', 'mage')]);
      run(a, 3000);
      run(b, 3000);
      expect(a.tick, b.tick);
      expect(stateHash(a), stateHash(b));
    });

    test('diverges for different seeds', () {
      final a = createGame(1, [const PlayerSetup('p1', 'knight')]);
      final b = createGame(2, [const PlayerSetup('p1', 'knight')]);
      run(a, 1200);
      run(b, 1200);
      expect(stateHash(a), isNot(stateHash(b)));
    });

    test('survives a JSON round trip and continues identically', () {
      final a = createGame(99, [const PlayerSetup('p1', 'ranger')]);
      run(a, 1500);
      final b = GameState.fromJson(roundTrip(a.toJson()));
      run(a, 1500);
      run(b, 1500);
      expect(stateHash(a), stateHash(b));
    });

    test('runs every character and supports multiple players', () {
      final s = createGame(7, [for (var i = 0; i < characterIds.length; i++) PlayerSetup('p$i', characterIds[i])], godMode: true);
      run(s, 4000);
      for (final p in s.players) {
        expect(p.level, greaterThan(1));
        expect(p.x.isFinite && p.hp.isFinite, isTrue);
      }
      expect(s.kills, greaterThan(50));
    });
  });
}
