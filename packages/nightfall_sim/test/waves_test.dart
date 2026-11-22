import 'package:nightfall_sim/nightfall_sim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('waves and bosses', () {
    test('progresses through waves and spawns bosses every 5th wave', () {
      final s = createGame(5, [const PlayerSetup('p1', 'berserker')], godMode: true, waveDuration: 5);
      final bosses = <int, List<String>>{};
      for (var i = 0; i < 60 * 600 && s.wave.n < 13; i++) {
        step(s, {'p1': botInput(s, 'p1')});
        for (final ev in s.events) {
          if (ev is BossEvent) (bosses[s.wave.n] ??= []).add(ev.name);
        }
        // Speed the test up: bosses lose health quickly
        for (final e in [...s.enemies]) {
          if (e.boss && s.tick % 60 == 0) damageEnemy(s, e, e.maxHp * 0.1, null, 'test');
        }
      }
      expect(s.wave.n, greaterThanOrEqualTo(13));
      expect(bosses[5], ['Slime King']);
      expect(bosses[10], ['Necro Lord']);
    });

    test('shaman heals on a boss do not stack', () {
      final s = createGame(6, [const PlayerSetup('p1', 'knight')], godMode: true);
      startWave(s, 15);
      final boss = s.enemies.firstWhere((e) => e.boss);
      s.enemies = [boss];
      boss.x = boss.px = s.players[0].x + 2500;
      boss.y = boss.py = s.players[0].y;
      boss.hp = boss.maxHp * 0.5;
      double healed() => (boss.hp - boss.maxHp * 0.5) / boss.maxHp;
      for (var i = 0; i < 10; i++) {
        spawnEnemy(s, 'shaman', boss.x + i, boss.y, waveScale(15));
      }
      step(s, {'p1': botInput(s, 'p1')});
      expect(healed(), greaterThan(0));
      expect(healed(), lessThanOrEqualTo(0.0101));
      for (var i = 0; i < 60 * bossHealEvery * 3; i++) {
        step(s, {'p1': botInput(s, 'p1')});
      }
      expect(healed(), lessThanOrEqualTo(0.041));
    });

    test('scales enemies up with the wave number', () {
      expect(waveScale(10).hp, greaterThan(waveScale(1).hp));
      expect(waveScale(50).dmg, greaterThan(waveScale(10).dmg));
      expect(waveScale(1).hp, 1);
    });

    test('drops few chests: at most one champion and one boss chest per 5 waves', () {
      final s = createGame(21, [const PlayerSetup('p1', 'mage')], godMode: true, waveDuration: 6);
      var chests = 0;
      for (var i = 0; i < 60 * 400 && s.wave.n <= 10; i++) {
        step(s, {'p1': botInput(s, 'p1')});
        for (final ev in s.events) {
          if (ev is ChestEvent) chests++;
        }
        for (final e in [...s.enemies]) {
          if ((e.boss || e.elite) && s.tick % 30 == 0) damageEnemy(s, e, e.maxHp * 0.2, null, 'test');
        }
        for (final pk in s.pickups) {
          if (pk.kind == 'chest') {
            pk.x = s.players[0].x;
            pk.y = s.players[0].y;
          }
        }
      }
      expect(s.wave.n, greaterThan(10));
      expect(chests, greaterThanOrEqualTo(2));
      expect(chests, lessThanOrEqualTo(4));
    });

    test('spawns the new bosses in rotation and they fight', () {
      for (final (wave, type) in [(15, 'broodmother'), (25, 'wyrm')]) {
        final s = createGame(17, [const PlayerSetup('p1', 'knight')], godMode: true);
        startWave(s, wave);
        final boss = s.enemies.firstWhere((e) => e.boss);
        expect(boss.type, type);
        var attacks = 0;
        for (var i = 0; i < 60 * 20; i++) {
          step(s, {'p1': botInput(s, 'p1')});
          attacks += s.eprojectiles.length + s.hazards.length;
          if (boss.dead) break;
        }
        expect(attacks, greaterThan(0));
        expect(boss.x.isFinite && boss.y.isFinite, isTrue);
        if (type == 'broodmother') expect(s.enemies.any((e) => e.type == 'egg') || s.kills > 0, isTrue);
        if (type == 'wyrm' && !boss.dead) expect(boss.trail.length, greaterThan(4));
      }
    });

    test('grants max HP after every 5th wave without any perk', () {
      final s = createGame(9, [const PlayerSetup('p1', 'mage')], godMode: true);
      final p = s.players[0];
      final base = p.stats.maxHp;
      startWave(s, 5);
      expect(p.stats.maxHp, base);
      p.hp = 20;
      startWave(s, 6);
      expect(p.stats.maxHp, base + vigorHpGain);
      expect(p.hp, 20 + vigorHpGain);
      expect(s.events.any((e) => e is VigorEvent && e.v == vigorHpGain), isTrue);
      startWave(s, 7);
      expect(p.stats.maxHp, base + vigorHpGain);
      startWave(s, 16);
      expect(p.stats.maxHp, base + 3 * vigorHpGain);
    });
  });
}
