import 'dart:math' as math;

import '../js.dart';
import '../types.dart';

class WStats {
  double dmg;
  double cd;
  double amount;
  double area;
  double speed;
  double pierce;
  double duration;
  double knock;

  WStats({
    required this.dmg,
    required this.cd,
    required this.amount,
    required this.area,
    required this.speed,
    required this.pierce,
    required this.duration,
    required this.knock,
  });

  WStats copy() => WStats(dmg: dmg, cd: cd, amount: amount, area: area, speed: speed, pierce: pierce, duration: duration, knock: knock);

  double operator [](String k) => switch (k) {
    'dmg' => dmg,
    'cd' => cd,
    'amount' => amount,
    'area' => area,
    'speed' => speed,
    'pierce' => pierce,
    'duration' => duration,
    'knock' => knock,
    _ => throw ArgumentError('unknown weapon stat $k'),
  };

  void operator []=(String k, double v) {
    switch (k) {
      case 'dmg':
        dmg = v;
      case 'cd':
        cd = v;
      case 'amount':
        amount = v;
      case 'area':
        area = v;
      case 'speed':
        speed = v;
      case 'pierce':
        pierce = v;
      case 'duration':
        duration = v;
      case 'knock':
        knock = v;
      default:
        throw ArgumentError('unknown weapon stat $k');
    }
  }
}

/// Partial weapon stats (level and evolution deltas).
typedef WDelta = Map<String, double>;

class EvoDef {
  final String id;
  final String perk;
  final String name;
  final String desc;
  final WDelta stats;
  const EvoDef({required this.id, required this.perk, required this.name, required this.desc, required this.stats});
}

class WeaponDef {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String desc;
  final WDelta base;
  final List<WDelta> levels; // deltas for levels 2..8
  /// Evolution paths. Each needs its perk owned; when several qualify the player picks one.
  final List<EvoDef> evos;

  /// Only granted by the secret boss: never offered as a new weapon and takes no slot.
  final bool unique;

  const WeaponDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.desc,
    required this.base,
    required this.levels,
    required this.evos,
    this.unique = false,
  });
}

const int maxWeaponLevel = 8;

const _defs = <WeaponDef>[
  WeaponDef(
    id: 'sword',
    name: 'Sword Arc',
    icon: '⚔',
    color: '#e8f1ff',
    desc: 'Slashes in a wide arc toward your aim.',
    base: {'dmg': 20, 'cd': 1.2, 'amount': 1, 'area': 1, 'speed': 0, 'pierce': 999, 'duration': 0.2, 'knock': 260},
    levels: [
      {'dmg': 6},
      {'area': 0.15},
      {'dmg': 8},
      {'cd': -0.15},
      {'amount': 1},
      {'dmg': 10, 'area': 0.15},
      {'dmg': 15},
    ],
    evos: [
      EvoDef(
        id: 'holyblade',
        perk: 'armor',
        name: 'Holy Blade',
        desc: 'Spins a full circle of radiant steel.',
        stats: {'dmg': 25, 'area': 0.4},
      ),
      EvoDef(
        id: 'bladedancer',
        perk: 'crit',
        name: 'Blade Dancer',
        desc: 'A rapid flurry of crimson slashes all around you.',
        stats: {'amount': 2, 'cd': -0.45, 'dmg': 12},
      ),
    ],
  ),
  WeaponDef(
    id: 'bolt',
    name: 'Magic Bolt',
    icon: '✦',
    color: '#6ee7ff',
    desc: 'Fires homing bolts at the nearest enemy.',
    base: {'dmg': 11, 'cd': 1.0, 'amount': 1, 'area': 1, 'speed': 430, 'pierce': 0, 'duration': 2.2, 'knock': 80},
    levels: [
      {'amount': 1},
      {'dmg': 5},
      {'cd': -0.15},
      {'amount': 1},
      {'dmg': 6},
      {'pierce': 1},
      {'amount': 1},
    ],
    evos: [
      EvoDef(
        id: 'arcanestorm',
        perk: 'haste',
        name: 'Arcane Storm',
        desc: 'A relentless torrent of seeking bolts.',
        stats: {'cd': -0.4, 'amount': 2, 'dmg': 8, 'pierce': 1},
      ),
      EvoDef(
        id: 'prism',
        perk: 'area',
        name: 'Prism Lance',
        desc: 'Huge lances of light that pierce everything in their path.',
        stats: {'dmg': 24, 'pierce': 40, 'area': 0.9, 'speed': 180, 'cd': 0.1},
      ),
    ],
  ),
  WeaponDef(
    id: 'arrow',
    name: 'Piercing Arrow',
    icon: '➶',
    color: '#b6ff7a',
    desc: 'Fast arrows that pierce through enemies.',
    base: {'dmg': 14, 'cd': 0.9, 'amount': 1, 'area': 1, 'speed': 760, 'pierce': 2, 'duration': 1.2, 'knock': 60},
    levels: [
      {'dmg': 5},
      {'amount': 1},
      {'pierce': 2},
      {'cd': -0.15},
      {'amount': 1},
      {'dmg': 8},
      {'pierce': 3},
    ],
    evos: [
      EvoDef(
        id: 'phantom',
        perk: 'crit',
        name: 'Phantom Volley',
        desc: 'Endless spectral arrows that never stop.',
        stats: {'amount': 3, 'pierce': 30, 'dmg': 10},
      ),
    ],
  ),
  WeaponDef(
    id: 'orbs',
    name: 'Soul Orbs',
    icon: '◉',
    color: '#c084ff',
    desc: 'Orbs circle around you, hitting enemies.',
    base: {'dmg': 10, 'cd': 4, 'amount': 2, 'area': 1, 'speed': 3.2, 'pierce': 999, 'duration': 3, 'knock': 140},
    levels: [
      {'amount': 1},
      {'area': 0.15, 'speed': 0.4},
      {'dmg': 6},
      {'duration': 1},
      {'amount': 1},
      {'dmg': 8},
      {'amount': 1},
    ],
    evos: [
      EvoDef(
        id: 'eternal',
        perk: 'duration',
        name: 'Eternal Souls',
        desc: 'The orbs never fade.',
        stats: {'dmg': 10, 'area': 0.2, 'speed': 0.8},
      ),
    ],
  ),
  WeaponDef(
    id: 'axe',
    name: 'Boomerang Axe',
    icon: '⟲',
    color: '#ffb347',
    desc: 'Throws an axe toward your aim that returns.',
    base: {'dmg': 24, 'cd': 1.6, 'amount': 1, 'area': 1, 'speed': 560, 'pierce': 999, 'duration': 1.3, 'knock': 180},
    levels: [
      {'dmg': 8},
      {'amount': 1},
      {'area': 0.2},
      {'cd': -0.2},
      {'dmg': 10},
      {'amount': 1},
      {'dmg': 12},
    ],
    evos: [
      EvoDef(
        id: 'whirlwind',
        perk: 'might',
        name: 'Whirlwind',
        desc: 'Huge spinning axes shred everything.',
        stats: {'amount': 2, 'area': 0.5, 'dmg': 18},
      ),
      EvoDef(
        id: 'twinreavers',
        perk: 'multishot',
        name: 'Twin Reavers',
        desc: 'Axes fly out in every direction at once.',
        stats: {'amount': 4, 'dmg': 12, 'duration': 0.3},
      ),
    ],
  ),
  WeaponDef(
    id: 'lightning',
    name: 'Chain Lightning',
    icon: 'ϟ',
    color: '#fff36b',
    desc: 'Strikes a random enemy and chains to others.',
    base: {'dmg': 15, 'cd': 1.8, 'amount': 1, 'area': 1, 'speed': 0, 'pierce': 2, 'duration': 0, 'knock': 0},
    levels: [
      {'pierce': 1},
      {'dmg': 5},
      {'amount': 1},
      {'cd': -0.2},
      {'pierce': 1},
      {'dmg': 6},
      {'amount': 1},
    ],
    evos: [
      EvoDef(
        id: 'thunderstorm',
        perk: 'multishot',
        name: 'Thunderstorm',
        desc: 'The sky itself rains lightning.',
        stats: {'amount': 2, 'pierce': 2, 'dmg': 10},
      ),
    ],
  ),
  WeaponDef(
    id: 'aura',
    name: 'Holy Aura',
    icon: '☀',
    color: '#ffe08a',
    desc: 'Damages all enemies around you.',
    base: {'dmg': 6, 'cd': 0.5, 'amount': 0, 'area': 1, 'speed': 0, 'pierce': 0, 'duration': 0, 'knock': 40},
    levels: [
      {'area': 0.15},
      {'dmg': 3},
      {'area': 0.15},
      {'cd': -0.08},
      {'dmg': 4},
      {'area': 0.2},
      {'dmg': 5},
    ],
    evos: [
      EvoDef(
        id: 'sanctuary',
        perk: 'vitality',
        name: 'Sanctuary',
        desc: 'A vast holy field that also heals you.',
        stats: {'area': 0.35, 'dmg': 8},
      ),
    ],
  ),
  WeaponDef(
    id: 'nova',
    name: 'Fire Nova',
    icon: '✹',
    color: '#ff7043',
    desc: 'Releases an expanding ring of fire.',
    base: {'dmg': 22, 'cd': 3.0, 'amount': 1, 'area': 1, 'speed': 0, 'pierce': 999, 'duration': 0.6, 'knock': 220},
    levels: [
      {'dmg': 8},
      {'area': 0.2},
      {'cd': -0.4},
      {'amount': 1},
      {'dmg': 12},
      {'area': 0.25},
      {'cd': -0.4},
    ],
    evos: [
      EvoDef(
        id: 'inferno',
        perk: 'area',
        name: 'Inferno',
        desc: 'Waves of hellfire engulf the battlefield.',
        stats: {'amount': 2, 'dmg': 22, 'area': 0.4},
      ),
      EvoDef(
        id: 'supernova',
        perk: 'might',
        name: 'Supernova',
        desc: 'One colossal blast with enormous damage and knockback.',
        stats: {'dmg': 75, 'area': 0.9, 'cd': 1.2, 'knock': 300},
      ),
    ],
  ),
  WeaponDef(
    id: 'turret',
    name: 'Turret',
    icon: '♜',
    color: '#7dffcf',
    desc: 'Deploys an auto-firing turret.',
    base: {'dmg': 8, 'cd': 5, 'amount': 1, 'area': 1, 'speed': 640, 'pierce': 0, 'duration': 10, 'knock': 40},
    levels: [
      {'dmg': 4},
      {'amount': 1},
      {'duration': 4},
      {'cd': -1},
      {'dmg': 5},
      {'amount': 1},
      {'dmg': 6},
    ],
    evos: [
      EvoDef(id: 'tesla', perk: 'magnet', name: 'Tesla Array', desc: 'Turrets fire chain lightning.', stats: {'amount': 1, 'dmg': 10}),
      EvoDef(
        id: 'mortar',
        perk: 'area',
        name: 'Mortar Battery',
        desc: 'Turrets lob explosive shells that blast whole groups.',
        stats: {'dmg': 24, 'amount': 1},
      ),
    ],
  ),
  WeaponDef(
    id: 'frost',
    name: 'Frost Ring',
    icon: '❄',
    color: '#9ad8ff',
    desc: 'Bursts of ice shards that slow enemies.',
    base: {'dmg': 9, 'cd': 2.4, 'amount': 6, 'area': 1, 'speed': 380, 'pierce': 1, 'duration': 0.7, 'knock': 40},
    levels: [
      {'amount': 2},
      {'dmg': 4},
      {'cd': -0.3},
      {'amount': 2},
      {'pierce': 1},
      {'dmg': 6},
      {'amount': 4},
    ],
    evos: [
      EvoDef(
        id: 'abszero',
        perk: 'swift',
        name: 'Absolute Zero',
        desc: 'Shards freeze enemies solid.',
        stats: {'amount': 8, 'dmg': 12, 'pierce': 3},
      ),
    ],
  ),
  // pierce = ricochets; a coin that kills gets a bonus ricochet (systems/weapons/coins.dart)
  WeaponDef(
    id: 'coins',
    name: "Goldfang's Coin Toss",
    icon: '¤',
    color: '#ffc83d',
    unique: true,
    desc: 'Tosses a fan of gold coins that ricochet between enemies. Kills earn extra bounces.',
    base: {'dmg': 15, 'cd': 1.1, 'amount': 3, 'area': 1, 'speed': 620, 'pierce': 2, 'duration': 1.4, 'knock': 50},
    levels: [
      {'dmg': 5},
      {'amount': 1},
      {'pierce': 1},
      {'cd': -0.15},
      {'dmg': 7},
      {'amount': 1},
      {'dmg': 8, 'pierce': 2},
    ],
    evos: [],
  ),
];

final Map<String, WeaponDef> weaponDefs = {for (final d in _defs) d.id: d};

/// Weapons that level-ups may offer as new; unique ones are excluded.
final List<String> weaponIds = [
  for (final d in _defs)
    if (!d.unique) d.id,
];
final List<String> uniqueWeaponIds = [
  for (final d in _defs)
    if (d.unique) d.id,
];

/// Owned weapons that count against MAX_SLOTS.
int slottedWeapons(List<WeaponInst> ws) => ws.where((w) => !weaponDefs[w.id]!.unique).length;

const List<String> statKeys = ['dmg', 'cd', 'amount', 'area', 'speed', 'pierce', 'duration', 'knock'];

EvoDef? evoDef(String weaponId, String evoId) {
  for (final e in weaponDefs[weaponId]?.evos ?? const <EvoDef>[]) {
    if (e.id == evoId) return e;
  }
  return null;
}

/// Display name: the evolution's name once evolved.
String weaponName(WeaponInst w) => evoDef(w.id, w.evo)?.name ?? weaponDefs[w.id]!.name;

/// Weapon stats from its level only (no player modifiers).
WStats baseWeaponStats(WeaponDef def, int level, [String evo = '']) {
  final b = def.base;
  final s = WStats(
    dmg: b['dmg']!,
    cd: b['cd']!,
    amount: b['amount']!,
    area: b['area']!, //
    speed: b['speed']!,
    pierce: b['pierce']!,
    duration: b['duration']!,
    knock: b['knock']!,
  );
  for (var i = 0; i < level - 1 && i < def.levels.length; i++) {
    final d = def.levels[i];
    for (final k in statKeys) {
      s[k] = s[k] + (d[k] ?? 0);
    }
  }
  for (final e in def.evos) {
    if (e.id != evo) continue;
    for (final k in statKeys) {
      s[k] = s[k] + (e.stats[k] ?? 0);
    }
    break;
  }
  return s;
}

/// Weapon stats with player modifiers applied.
WStats weaponStats(Player p, WeaponInst w) {
  final s = baseWeaponStats(weaponDefs[w.id]!, w.level, w.evo);
  s.cd = math.max(0.05, s.cd * p.stats.cooldown);
  s.amount += p.stats.amount;
  s.area *= p.stats.area;
  s.duration *= p.stats.duration;
  return s;
}

const _labels = {
  'dmg': 'damage', 'cd': 's cooldown', 'amount': 'amount', 'area': 'area', 'speed': 'speed', //
  'pierce': 'pierce', 'duration': 's duration', 'knock': 'knockback',
};

String levelDesc(WeaponDef def, int level) {
  if (level <= 1) return def.desc;
  final d = def.levels[level - 2];
  final parts = <String>[];
  for (final k in statKeys) {
    final v = d[k];
    if (v == null || v == 0) continue;
    if (k == 'area') {
      parts.add('+${roundInt(v * 100)}% area');
    } else if (k == 'cd') {
      parts.add('${jsNum(v)}${_labels[k]}');
    } else {
      parts.add('${v > 0 ? '+' : ''}${jsNum(v)} ${_labels[k]}');
    }
  }
  return parts.join(', ');
}
