import 'package:nightfall_sim/nightfall_sim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('map, movement and anti-AFK', () {
    test('generates the same obstacles for the same seed and keeps entities out of them', () {
      final s = createGame(77, [const PlayerSetup('p1', 'knight')], godMode: true);
      final a = getChunk(s.mapSeed, 3, -2).obstacles.map((o) => [o.x, o.y, o.r]).toList();
      final b = getChunk(s.mapSeed, 3, -2).obstacles.map((o) => [o.x, o.y, o.r]).toList();
      expect(a, b);
      expect(isBlocked(s.mapSeed, 0, 0, 300), isFalse);
      var total = 0;
      for (var cx = -4; cx <= 4; cx++) {
        for (var cy = -4; cy <= 4; cy++) {
          total += getChunk(s.mapSeed, cx, cy).obstacles.length;
        }
      }
      expect(total, greaterThan(30));
      run(s, 3000);
      final p = s.players[0];
      expect(isBlocked(s.mapSeed, p.x, p.y, p.radius - 1), isFalse);
    });

    test('dashes on input with a cooldown', () {
      final s = createGame(4, [const PlayerSetup('p1', 'knight')]);
      final p = s.players[0];
      final cmd = idleCmd(mx: 1, dash: true);
      step(s, {'p1': cmd});
      expect(p.dashT, greaterThan(0));
      for (var i = 0; i < 12; i++) {
        step(s, {'p1': cmd});
      }
      expect(p.x, greaterThan(150));
      expect(p.dashCd, greaterThan(0));
    });

    test('drops meteors on a player who stands still, but not on one who moves', () {
      final idle = createGame(12, [const PlayerSetup('p1', 'knight')]);
      final meteors = <int>{};
      for (var i = 0; i < 60 * 14; i++) {
        step(idle, {'p1': idleCmd(choose: idle.players[0].choices != null ? 0 : -1)});
        for (final h in idle.hazards) {
          if (h.kind == 'skyfall') meteors.add(h.id);
        }
      }
      expect(meteors.length, greaterThanOrEqualTo(2));

      final mover = createGame(12, [const PlayerSetup('p1', 'knight')]);
      for (var i = 0; i < 60 * 14; i++) {
        step(mover, {'p1': botInput(mover, 'p1').copyWith(mx: jsCos(i / 40), my: jsSin(i / 40) * 0.3 + 0.7, ability: false)});
        expect(mover.hazards.any((h) => h.kind == 'skyfall'), isFalse);
      }
    });

    test('does not drop meteors on a player who keeps dodging inside a small area', () {
      InputCmd cmd(GameState s, double mx, double my) => idleCmd(mx: mx, my: my, choose: s.players[0].choices != null ? 0 : -1);
      // strafing left-right, 1 s each way: never more than ~150 px from where it started
      final strafe = createGame(13, [const PlayerSetup('p1', 'knight')], godMode: true);
      for (var i = 0; i < 60 * 20; i++) {
        step(strafe, {'p1': cmd(strafe, (i ~/ 60) % 2 != 0 ? -1 : 1, 0)});
        expect(strafe.hazards.any((h) => h.kind == 'skyfall'), isFalse);
      }
      // tight circles around one spot
      final circle = createGame(14, [const PlayerSetup('p1', 'knight')], godMode: true);
      for (var i = 0; i < 60 * 20; i++) {
        step(circle, {'p1': cmd(circle, jsCos(i / 25), jsSin(i / 25))});
        expect(circle.hazards.any((h) => h.kind == 'skyfall'), isFalse);
      }
    });

    test('still punishes camping with an occasional tap', () {
      final s = createGame(15, [const PlayerSetup('p1', 'knight')], godMode: true);
      final meteors = <int>{};
      for (var i = 0; i < 60 * 24; i++) {
        final tap = i % 120 < 12; // moves 0.2 s out of every 2 s
        step(s, {'p1': idleCmd(mx: tap ? (i % 240 < 120 ? 1 : -1) : 0, choose: s.players[0].choices != null ? 0 : -1)});
        for (final h in s.hazards) {
          if (h.kind == 'skyfall') meteors.add(h.id);
        }
      }
      expect(meteors, isNotEmpty);
    });
  });
}
