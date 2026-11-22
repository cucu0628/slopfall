import 'package:nightfall_sim/nightfall_sim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

final _idle = idleCmd(choose: 0);

/// A run that is on Goldfang's wave, with nothing else around.
GameState goldfangRun([int seed = 3, String reward = 'weapon']) {
  final s = createGame(seed, [const PlayerSetup('p1', 'mage')], godMode: true);
  s.secret = SecretState(wave: 10, reward: reward);
  s.enemies = [];
  startWave(s, 10);
  s.wave.spawnAcc = -1e9; // no regular spawns
  return s;
}

Enemy? goldfangOf(GameState s) {
  for (final e in s.enemies) {
    if (e.type == 'goldfang') return e;
  }
  return null;
}

void killAndCollect(GameState s) {
  final g = goldfangOf(s)!;
  damageEnemy(s, g, g.hp + 1, s.players[0], 'test');
  final relic = s.pickups.firstWhere((p) => p.kind == 'relic');
  s.players[0].x = relic.x;
  s.players[0].y = relic.y;
  for (var i = 0; i < 30 && !relic.dead; i++) {
    step(s, {'p1': _idle});
  }
  expect(relic.dead, isTrue);
}

void main() {
  group('secret boss: Goldfang', () {
    test('is rolled from the seed: rare, at most once, never on the first boss wave', () {
      expect(rollSecret(1234), rollSecret(1234));
      var early = 0;
      final rewards = <String>{};
      for (var seed = 0; seed < 4000; seed++) {
        final r = rollSecret(seed);
        rewards.add(r.reward);
        if (r.wave == 0) continue;
        expect(r.wave % bossEvery, 0);
        expect(r.wave, greaterThanOrEqualTo(secretFirstWave));
        if (r.wave <= 30) early++;
      }
      // 5 boss waves from 10 to 30 at 3% each: about 14% of runs
      expect(early / 4000, greaterThan(0.09));
      expect(early / 4000, lessThan(0.2));
      expect(rewards.toList()..sort(), ['perk', 'weapon']);
    });

    test('replaces the whole boss lineup on its wave only', () {
      final s = createGame(3, [const PlayerSetup('p1', 'mage')], godMode: true);
      s.secret = const SecretState(wave: 20, reward: 'perk');
      startWave(s, 20);
      expect(s.enemies.where((e) => e.boss).map((e) => e.type).toList(), ['goldfang']);
      expect(s.events.any((e) => e is BossEvent && e.id == 'goldfang' && e.name == 'Goldfang the Greedy'), isTrue);
      s.enemies = [];
      startWave(s, 25);
      final later = s.enemies.where((e) => e.boss).map((e) => e.type).toList();
      expect(later, hasLength(2));
      expect(later, isNot(contains('goldfang')));
    });

    test('escapes with his treasure if he is not caught in time', () {
      final s = goldfangRun();
      var escaped = false;
      for (var i = 0; i < 60 * (goldfangEscape + 1); i++) {
        step(s, {'p1': _idle});
        if (s.events.any((e) => e is EscapeEvent)) escaped = true;
      }
      expect(escaped, isTrue);
      expect(goldfangOf(s), isNull);
      expect(s.pickups.any((p) => p.kind == 'relic' || p.kind == 'chest'), isFalse);
      expect(s.wave.n, 11);
    });

    test('runs from the player and never deals contact damage', () {
      final s = goldfangRun();
      final g = goldfangOf(s)!;
      g.x = s.players[0].x + 100;
      g.y = s.players[0].y;
      for (var i = 0; i < 60; i++) {
        step(s, {'p1': _idle});
      }
      expect(hypot(g.x - s.players[0].x, g.y - s.players[0].y), greaterThan(200));
      expect(g.dmg, 0);
    });

    test('drops a relic that grants his unique weapon without using a slot', () {
      final s = goldfangRun(3, 'weapon');
      final p = s.players[0];
      p.weapons = [
        for (final id in ['bolt', 'arrow', 'axe', 'nova', 'frost', 'aura']) WeaponInst(id: id, level: 2, cd: 1),
      ];
      killAndCollect(s);
      expect(s.pickups.any((pk) => pk.kind == 'chest'), isFalse);
      expect(p.weapons, hasLength(maxSlots + 1));
      expect(p.weapons.any((w) => w.id == secretWeapon), isTrue);
      // it levels up like any weapon, but is never offered to someone who doesn't own it
      final offered = [for (var i = 0; i < 60; i++) ...rollChoices(s, p)];
      expect(offered.any((o) => o.kind == 'weapon' && o.id == secretWeapon && o.level == 2), isTrue);
      final fresh = createGame(4, [const PlayerSetup('p1', 'mage')]);
      final freshOffers = [for (var i = 0; i < 200; i++) ...rollChoices(fresh, fresh.players[0])];
      expect(freshOffers.any((o) => o.id == secretWeapon || o.id == secretPerk), isFalse);
    });

    test('drops a relic that grants his unique perk', () {
      final s = goldfangRun(3, 'perk');
      final p = s.players[0];
      killAndCollect(s);
      expect(p.perks.map((k) => k.id), contains(secretPerk));
      // the HP penalty applies after every flat bonus, whatever order the perks were taken in
      final without = computeStats(p.copy()..perks.removeWhere((k) => k.id == secretPerk));
      expect(p.stats.growth, closeTo(without.growth + 0.25, 1e-9));
      expect(p.stats.maxHp, closeTo(without.maxHp * 0.9, 1e-9));
      expect(p.stats.gemDouble, closeTo(0.05, 1e-9));
      expect(s.events.any((e) => e is UniqueEvent && e.pid == 'p1'), isTrue);
    });

    test("keeps Goldfang's clock and an uncollected relic across a save", () {
      final s = goldfangRun();
      for (var i = 0; i < 60 * 5; i++) {
        step(s, {'p1': _idle});
      }
      final left = goldfangOf(s)!.t;
      final r = restore(roundTrip(snapshot(s, 0)))!;
      expect(goldfangOf(r)!.t, closeTo(left, 1e-9));
      expect(r.secret, s.secret);

      final g = goldfangOf(s)!;
      damageEnemy(s, g, g.hp + 1, null, 'test');
      final r2 = restore(roundTrip(snapshot(s, 0)))!;
      expect(r2.pickups.where((p) => p.kind == 'relic'), hasLength(1));
      expect(r2.enemies.any((e) => e.type == 'goldfang'), isFalse);
    });

    test('fake coins explode when stepped near, real coins give XP', () {
      final s = goldfangRun();
      s.enemies = [];
      s.cfg.godMode = false;
      final p = s.players[0];
      final hp = p.hp;
      addHazard(s, 'coin', x: p.x + 30, y: p.y, r: 65, dmg: 20, warn: 8, life: 0.05);
      for (var i = 0; i < 60; i++) {
        step(s, {'p1': _idle});
      }
      expect(p.hp, lessThan(hp));

      final xp = p.xp + p.level * 1000;
      addPickup(s, 'coin', p.x + 40, p.y, 5);
      for (var i = 0; i < 60; i++) {
        step(s, {'p1': _idle});
      }
      expect(p.xp + p.level * 1000, greaterThan(xp));
    });

    test('coins ricochet from enemy to enemy', () {
      final s = createGame(9, [const PlayerSetup('p1', 'mage')], godMode: true);
      final p = s.players[0];
      p.weapons = [WeaponInst(id: secretWeapon)];
      refreshStats(p);
      s.enemies = [];
      s.wave.spawnAcc = -1e9;
      final tough = waveScale(1).copyWith(hp: 50);
      final foes = [for (var i = 0; i < 3; i++) spawnEnemy(s, 'zombie', p.x + 150 + i * 70, p.y + (i % 2) * 60, tough)];
      for (final e in foes) {
        e.speed = 0;
      }
      for (var i = 0; i < 30; i++) {
        s.wave.spawnAcc = -1e9;
        step(s, {'p1': _idle});
      }
      expect(foes.where((e) => e.hp < e.maxHp).length, greaterThanOrEqualTo(2));
      expect(p.dmgDealt[secretWeapon], greaterThan(0));
    });
  });
}
