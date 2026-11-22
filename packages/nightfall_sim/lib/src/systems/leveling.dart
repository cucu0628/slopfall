import 'dart:math' as math;

import '../combat.dart';
import '../content/characters.dart';
import '../content/perks.dart';
import '../content/weapons.dart';
import '../rng.dart';
import '../types.dart';

const int maxSlots = 6;

double xpForLevel(int level) => (6 + level * 6 + 0.32 * level * level).floorToDouble();

Stats computeStats(Player p) {
  final c = characterDefs[p.charId]!;
  final s = Stats()
    ..speed = c.speed
    ..maxHp = c.hp;
  s.maxHp += p.vigorHp;
  for (final e in c.mods.entries) {
    s[e.key] = s[e.key] + e.value;
  }
  for (final perk in p.perks) {
    perkDefs[perk.id]!.apply(s, perk.power);
  }
  for (final e in p.bonus.entries) {
    bonusDefs[e.key]!.apply(s, e.value);
  }
  s.maxHp *= s.maxHpMul;
  s.dr = math.min(0.6, s.dr);
  s.burn = math.min(1, s.burn);
  return s;
}

void refreshStats(Player p) {
  final oldMax = p.stats.maxHp;
  p.stats = computeStats(p);
  if (p.stats.maxHp > oldMax) p.hp += p.stats.maxHp - oldMax;
  p.hp = math.min(p.hp, p.stats.maxHp);
}

Player createPlayer(String id, String charId, double x, double y) {
  final c = characterDefs[charId]!;
  final p = Player(id: id, charId: charId, x: x, y: y)
    ..hp = c.hp
    ..xpNext = xpForLevel(1)
    ..weapons = [WeaponInst(id: c.weapon, cd: 0.5)]
    ..abilityMaxCd = c.ability.cd;
  p.stats = computeStats(p);
  p.hp = p.stats.maxHp;
  return p;
}

void addXp(GameState s, Player p, double amount) {
  if (p.dead) return;
  p.xp += amount * p.stats.growth;
  while (p.xp >= p.xpNext) {
    p.xp -= p.xpNext;
    p.level++;
    p.xpNext = xpForLevel(p.level);
    p.pendingLevels++;
    s.events.add(LevelUpEvent(p.id));
  }
}

WeaponInst? _weapon(Player p, String id) {
  for (final w in p.weapons) {
    if (w.id == id) return w;
  }
  return null;
}

PerkInst? _perk(Player p, String id) {
  for (final k in p.perks) {
    if (k.id == id) return k;
  }
  return null;
}

List<UpgradeOption> _upgradePool(Player p) {
  final pool = <UpgradeOption>[];
  final weaponSlots = slottedWeapons(p.weapons), perkSlots = slottedPerks(p.perks);
  // unique weapons (secret boss reward) level up like the others once owned
  for (final id in [...weaponIds, ...uniqueWeaponIds]) {
    final w = _weapon(p, id);
    if (w != null) {
      if (w.level < maxWeaponLevel) pool.add(UpgradeOption(kind: 'weapon', id: id, level: w.level + 1));
    } else if (weaponSlots < maxSlots && !weaponDefs[id]!.unique) {
      pool.add(UpgradeOption(kind: 'weapon', id: id, level: 1));
    }
  }
  for (final id in perkIds) {
    final k = _perk(p, id);
    if (k != null) {
      if (k.level < perkDefs[id]!.max) pool.add(UpgradeOption(kind: 'perk', id: id, level: k.level + 1));
    } else if (perkSlots < maxSlots) {
      pool.add(UpgradeOption(kind: 'perk', id: id, level: 1));
    }
  }
  if (p.abilityLevel < abilityMaxLevel) pool.add(UpgradeOption(kind: 'ability', id: 'ability', level: p.abilityLevel + 1));
  return pool;
}

double _optionWeight(UpgradeOption o) => o.kind == 'ability' ? 1.1 : (o.level > 1 ? 1.4 : 1);

int _rollRarity(GameState s) {
  var r = rand(s);
  for (var i = rarities.length - 1; i > 0; i--) {
    if (r < rarities[i].chance) return i;
    r -= rarities[i].chance;
  }
  return 0;
}

/// Bonus shards that have not hit their stack limit yet.
List<String> _availableBonuses(Player p) => [
  for (final id in bonusIds)
    if ((p.bonus[id] ?? 0) < (bonusDefs[id]!.max ?? 1 << 30)) id,
];

UpgradeOption _bonusOption(Player p, String id) => UpgradeOption(kind: 'bonus', id: id, level: (p.bonus[id] ?? 0) + 1);

/// Up to [count] distinct options. Once the regular pool runs dry the
/// remaining slots are filled with endless bonus shards, so a level-up is
/// never just a heal.
List<UpgradeOption> rollChoices(GameState s, Player p, [int count = 3]) {
  final pool = _upgradePool(p);
  final out = <UpgradeOption>[];
  while (out.length < count && pool.isNotEmpty) {
    final o = weightedPick(s, pool, _optionWeight);
    pool.removeAt(pool.indexOf(o));
    out.add(o.kind == 'perk' && perkDefs[o.id]!.rarity ? o.withRarity(_rollRarity(s)) : o);
  }
  if (out.length < count) {
    final bonus = _availableBonuses(p);
    while (out.length < count && bonus.isNotEmpty) {
      final id = bonus.removeAt((rand(s) * bonus.length).floor());
      out.add(_bonusOption(p, id));
    }
    if (p.hp < p.stats.maxHp * 0.5 && out.isNotEmpty) {
      out[out.length - 1] = const UpgradeOption(kind: 'heal', id: 'heal', level: 0);
    }
  }
  return out;
}

void applyOption(GameState s, Player p, UpgradeOption o) {
  switch (o.kind) {
    case 'weapon':
      final w = _weapon(p, o.id);
      if (w != null) {
        w.level = o.level;
      } else {
        p.weapons.add(WeaponInst(id: o.id, cd: 0.2));
      }
    case 'perk':
      final k = _perk(p, o.id);
      final gain = o.rarity >= 0 && o.rarity < rarities.length ? rarities[o.rarity].mul : 1.0;
      if (k != null) {
        k.level = o.level;
        k.power += gain;
      } else {
        p.perks.add(PerkInst(id: o.id, power: gain));
      }
      refreshStats(p);
    case 'ability':
      p.abilityLevel = o.level;
    case 'evo':
      final w = _weapon(p, o.id);
      final evos = weaponDefs[o.id]!.evos;
      final e = o.level >= 0 && o.level < evos.length ? evos[o.level] : null;
      if (w != null && e != null && !w.evolved) {
        w.evolved = true;
        w.evo = e.id;
        s.events.add(EvolveEvent(p.id, e.name));
      }
    case 'bonus':
      p.bonus[o.id] = o.level;
      refreshStats(p);
    default:
      healPlayer(s, p, p.stats.maxHp * 0.5);
  }
}

void chooseUpgrade(GameState s, Player p, int index) {
  final choices = p.choices;
  if (choices == null || choices.isEmpty) return;
  final o = choices[math.max(0, math.min(index, choices.length - 1))];
  applyOption(s, p, o);
  p.choices = null;
  s.events.add(const SfxEvent('select'));
}

/// Evolutions of a weapon whose required perk the player owns.
List<UpgradeOption> evoChoices(Player p, String weaponId) {
  final out = <UpgradeOption>[];
  final evos = weaponDefs[weaponId]!.evos;
  for (var i = 0; i < evos.length; i++) {
    final e = evos[i];
    if (p.perks.any((k) => k.id == e.perk)) out.add(UpgradeOption(kind: 'evo', id: weaponId, level: i));
  }
  return out;
}

bool _canEvolve(Player p, WeaponInst w) =>
    !w.evolved && w.level >= maxWeaponLevel && !p.evoQueue.contains(w.id) && evoChoices(p, w.id).isNotEmpty;

void updateLeveling(GameState s, Player p) {
  if (p.dead || p.choices != null) return;
  // A pending evolution pick comes before regular level-ups.
  while (p.evoQueue.isNotEmpty) {
    final id = p.evoQueue.removeAt(0);
    final opts = evoChoices(p, id);
    if (opts.isNotEmpty && !(_weapon(p, id)?.evolved ?? false)) {
      p.choices = opts;
      return;
    }
  }
  if (p.pendingLevels > 0) {
    p.pendingLevels--;
    p.choices = rollChoices(s, p);
  }
}

String optionName(UpgradeOption o) {
  switch (o.kind) {
    case 'weapon':
      return '${weaponDefs[o.id]!.name} ${o.level > 1 ? 'Lv ${o.level}' : '(new)'}';
    case 'perk':
      return '${o.rarity > 0 ? '${rarities[o.rarity].name} ' : ''}${perkDefs[o.id]!.name} ${o.level > 1 ? 'Lv ${o.level}' : '(new)'}';
    case 'ability':
      return 'Ability Lv ${o.level}';
    case 'evo':
      return weaponDefs[o.id]!.evos[o.level].name;
    case 'bonus':
      return bonusDefs[o.id]!.name;
    default:
      return 'Heal';
  }
}

/// Chest: unlocks an evolution if a max level weapon qualifies (the player
/// then picks which one), otherwise grants random upgrades.
void openChest(GameState s, Player p, bool big) {
  final items = <String>[];
  var count = big ? 3 : 1;
  WeaponInst? w;
  for (final x in p.weapons) {
    if (_canEvolve(p, x)) {
      w = x;
      break;
    }
  }
  if (w != null) {
    p.evoQueue.add(w.id);
    items.add('Evolution unlocked: ${weaponDefs[w.id]!.name}!');
    count--;
  }
  for (var i = 0; i < count; i++) {
    final pool = _upgradePool(p).where((o) => o.level > 1).toList();
    final opts = pool.isNotEmpty ? pool : _upgradePool(p);
    final bonus = _availableBonuses(p);
    final UpgradeOption? o = opts.isNotEmpty
        ? opts[(rand(s) * opts.length).floor()]
        : bonus.isNotEmpty
        ? _bonusOption(p, bonus[(rand(s) * bonus.length).floor()])
        : null;
    if (o == null) {
      healPlayer(s, p, p.stats.maxHp * 0.3);
      items.add('Heal');
      continue;
    }
    applyOption(s, p, o);
    items.add(optionName(o));
  }
  s.events.add(ChestEvent(p.id, items));
}
