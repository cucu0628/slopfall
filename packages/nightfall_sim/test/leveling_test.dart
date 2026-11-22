import 'package:nightfall_sim/nightfall_sim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('leveling, upgrades and evolutions', () {
    test('offers valid, distinct level-up choices', () {
      final s = createGame(3, [const PlayerSetup('p1', 'engineer')]);
      final p = s.players[0];
      for (var i = 0; i < 50; i++) {
        final c = rollChoices(s, p);
        expect(c.length, 3);
        expect(c.map((o) => o.kind + o.id).toSet().length, 3);
      }
    });

    test('caps slots and offers endless bonus shards once everything is maxed', () {
      final s = createGame(11, [const PlayerSetup('p1', 'knight')], godMode: true);
      final p = s.players[0];
      for (var i = 0; i < 300; i++) {
        p.choices = rollChoices(s, p);
        step(s, {'p1': idleCmd(choose: 0)});
      }
      expect(p.weapons.length, lessThanOrEqualTo(maxSlots));
      expect(p.perks.length, lessThanOrEqualTo(maxSlots));
      expect(p.abilityLevel, abilityMaxLevel);
      final c = rollChoices(s, p);
      expect(c.length, 3);
      expect(c.every((o) => o.kind == 'bonus'), isTrue);
      expect(p.bonus.values.fold<int>(0, (a, b) => a + b), greaterThan(0));
    });

    test('lets the player choose between evolutions they qualify for', () {
      final s = createGame(8, [const PlayerSetup('p1', 'mage')]);
      final p = s.players[0];
      p.weapons[0].level = 8;
      openChest(s, p, false);
      expect(p.evoQueue, isEmpty); // no qualifying perk yet

      p.perks.addAll([PerkInst(id: 'haste'), PerkInst(id: 'area')]);
      openChest(s, p, false);
      step(s, {'p1': idleCmd()});
      expect(p.choices?.map((o) => o.kind).toList(), ['evo', 'evo']);
      expect(p.choices?.map((o) => weaponDefs['bolt']!.evos[o.level].id).toList(), ['arcanestorm', 'prism']);

      step(s, {'p1': idleCmd(choose: 1)});
      expect(p.weapons[0].evolved, isTrue);
      expect(p.weapons[0].evo, 'prism');
      expect(s.events.any((e) => e is EvolveEvent && e.name == 'Prism Lance'), isTrue);

      // simulation keeps running with the chosen evolution
      for (var i = 0; i < 600; i++) {
        step(s, {'p1': idleCmd(choose: p.choices != null ? 0 : -1)});
      }
      expect(s.projectiles.any((pr) => pr.kind == 'prism'), isTrue);
    });

    test('runs every alternative evolution without errors', () {
      for (final (weapon, evo) in [('sword', 'bladedancer'), ('axe', 'twinreavers'), ('nova', 'supernova'), ('turret', 'mortar')]) {
        final s = createGame(31, [const PlayerSetup('p1', 'knight')], godMode: true);
        final p = s.players[0];
        p.weapons = [WeaponInst(id: weapon, level: 8, evolved: true, evo: evo)];
        run(s, 1500);
        expect(s.kills, greaterThan(10), reason: evo);
        expect(p.x.isFinite, isTrue);
      }
    });

    test('perk rarity scales the effect of a level-up', () {
      final s = createGame(40, [const PlayerSetup('p1', 'knight')]);
      final p = s.players[0];
      p.choices = [const UpgradeOption(kind: 'perk', id: 'might', level: 1, rarity: 2)];
      step(s, {'p1': idleCmd(choose: 0)});
      expect(p.perks[0].power, closeTo(rarities[2].mul, 1e-9));
      expect(p.stats.might, closeTo(1 + 0.1 * rarities[2].mul, 1e-9));
      // rarity rolls stay mostly common
      final counts = [0, 0, 0];
      for (var i = 0; i < 400; i++) {
        for (final o in rollChoices(s, p)) {
          if (o.kind == 'perk' && perkDefs[o.id]!.rarity) counts[o.rarity]++;
        }
      }
      expect(counts[0], greaterThan(counts[1]));
      expect(counts[1], greaterThan(counts[2]));
    });

    test('stops offering Time Shards at their 15 stack limit', () {
      final s = createGame(41, [const PlayerSetup('p1', 'knight')], godMode: true);
      final p = s.players[0];
      for (var i = 0; i < 300; i++) {
        p.choices = rollChoices(s, p);
        step(s, {'p1': idleCmd(choose: 0)});
      }
      p.bonus['time'] = 15;
      for (var i = 0; i < 100; i++) {
        expect(rollChoices(s, p).any((o) => o.kind == 'bonus' && o.id == 'time'), isFalse);
      }
    });

    test('formats descriptions like the TypeScript version', () {
      expect(levelDesc(weaponDefs['sword']!, 5), '-0.15s cooldown');
      expect(levelDesc(weaponDefs['sword']!, 7), '+10 damage, +15% area');
      expect(perkDefs['regen']!.desc(1), '+0.4 HP per second');
      expect(perkDefs['regen']!.desc(1.4), '+0.56 HP per second');
      expect(perkDefs['might']!.desc(1.4), '+14% damage');
      expect(perkDefs['haste']!.desc(1.8), '-14.4% weapon & ability cooldown');
    });
  });
}
