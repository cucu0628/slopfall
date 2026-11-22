import 'package:nightfall_sim/nightfall_sim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('combat, abilities and perks', () {
    test('scales ability damage with the wave and ability level', () {
      final s = createGame(4, [const PlayerSetup('p1', 'mage')]);
      final p = s.players[0];
      final early = abilityPower(s, p);
      s.wave.n = 20;
      p.abilityLevel = 5;
      expect(abilityPower(s, p), greaterThan(early * 10));
    });

    test('webs slow the player unless they dash', () {
      final s = createGame(19, [const PlayerSetup('p1', 'knight')]);
      final p = s.players[0];
      addEnemyProjectile(s, 'web', p.x + 30, p.y, -200, 0, 1, 10, 2);
      for (var i = 0; i < 10; i++) {
        step(s, {'p1': idleCmd()});
      }
      expect(p.slowT, greaterThan(0));
    });

    test('shockwave rings hurt when standing still but can be dashed through', () {
      double runRing(bool dash) {
        final s = createGame(9, [const PlayerSetup('p1', 'knight')]);
        final p = s.players[0];
        addHazard(s, 'ring', x: 220, y: 0, r: 10, w: 14, speed: 320, life: 2, dmg: 40);
        final hp = p.hp;
        for (var i = 0; i < 90; i++) {
          // start the dash just before the ring reaches the player
          final near = s.hazards.isNotEmpty && (hypot(p.x - 220, p.y) - s.hazards[0].r).abs() < 70;
          step(s, {'p1': idleCmd(mx: dash ? 1 : 0, dash: dash && near)});
        }
        return hp - p.hp;
      }

      expect(runRing(false), greaterThan(0));
      expect(runRing(true), 0);
    });

    test('caps the necromancer kill heal per second', () {
      final s = createGame(13, [const PlayerSetup('p1', 'necro')]);
      final p = s.players[0];
      step(s, {'p1': idleCmd()});
      p.healBudget = 4;
      p.hp = 10;
      for (var i = 0; i < 30; i++) {
        final e = spawnEnemy(s, 'bat', p.x + 300, p.y, const EnemyScale(hp: 1, dmg: 1, speed: 1));
        damageEnemy(s, e, 999, p, 'test');
      }
      expect(p.hp, 14);
    });

    test('caps lifesteal healing per second and Rage no longer heals', () {
      final s = createGame(42, [const PlayerSetup('p1', 'berserker')]);
      final p = s.players[0];
      p.abilityT = 5; // raging
      p.hp = 10;
      final e = spawnEnemy(s, 'zombie', p.x + 400, p.y, const EnemyScale(hp: 1000, dmg: 1, speed: 0));
      damageEnemy(s, e, 500, p, 'test');
      expect(p.hp, 10); // no lifesteal from Rage
      p.perks.add(PerkInst(id: 'lifesteal', level: 5, power: 5));
      refreshStats(p);
      p.hp = 10;
      p.lsBudget = p.stats.maxHp * p.stats.lifestealCap;
      for (var i = 0; i < 20; i++) {
        damageEnemy(s, e, 500, p, 'test');
      }
      final healed = p.hp - 10;
      expect(healed, greaterThan(0));
      expect(healed, lessThanOrEqualTo(p.stats.maxHp * p.stats.lifestealCap + 1e-6));
    });

    test('armor reduces damage by a percentage', () {
      final s = createGame(43, [const PlayerSetup('p1', 'mage')]);
      final p = s.players[0];
      p.perks.add(PerkInst(id: 'armor', level: 5, power: 5));
      refreshStats(p);
      expect(p.stats.dr, closeTo(0.3, 1e-9));
      final hp = p.hp;
      hurtPlayer(s, p, 50);
      expect(hp - p.hp, closeTo(35, 1e-9));
    });

    test('ignite sets enemies on fire and burns them over time; the meteor ignites too', () {
      final s = createGame(44, [const PlayerSetup('p1', 'mage')]);
      final p = s.players[0];
      p.perks.add(PerkInst(id: 'burn', level: 5, power: 20));
      refreshStats(p);
      expect(p.stats.burn, 1);
      final e = spawnEnemy(s, 'zombie', p.x + 600, p.y, const EnemyScale(hp: 100, dmg: 1, speed: 0));
      damageEnemy(s, e, 10, p, 'test');
      expect(e.burnT, greaterThan(0));
      final before = e.hp;
      for (var i = 0; i < 60; i++) {
        step(s, {'p1': idleCmd()});
      }
      expect(e.hp, lessThan(before));
      expect(p.dmgDealt['burn'], greaterThan(0));

      final s2 = createGame(45, [const PlayerSetup('p1', 'mage')]);
      final p2 = s2.players[0];
      final target = spawnEnemy(s2, 'zombie', p2.x + 200, p2.y, const EnemyScale(hp: 1000, dmg: 1, speed: 0));
      for (var i = 0; i < 70; i++) {
        step(s2, {'p1': idleCmd(ax: 200, ability: i == 0)});
      }
      expect(target.burnT, greaterThan(0));
    });
  });
}
