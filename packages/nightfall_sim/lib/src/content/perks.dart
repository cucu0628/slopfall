import 'dart:math' as math;

import '../js.dart';
import '../types.dart';

class PerkDef {
  final String id;
  final String name;
  final String icon;
  final String color;
  final int max;

  /// Whether level-ups of this perk can roll Rare / Epic.
  final bool rarity;

  /// Effect of one level-up; `m` is the rarity multiplier (1 = common).
  final String Function(double m) desc;

  /// `power` = sum of all taken level-ups weighted by their rarity.
  final void Function(Stats s, double power) apply;

  /// Only granted by the secret boss: never offered on level-up and takes no slot.
  final bool unique;

  const PerkDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.max,
    required this.rarity,
    required this.desc,
    required this.apply,
    this.unique = false,
  });
}

class Rarity {
  final String name;
  final double mul;
  final double chance;
  final String color;
  const Rarity(this.name, this.mul, this.chance, this.color);
}

/// Common / Rare / Epic: effect multiplier and roll chance of a perk level-up.
const List<Rarity> rarities = [
  Rarity('Common', 1, 0.81, '#9aa3c4'),
  Rarity('Rare', 1.4, 0.15, '#4fa3ff'),
  Rarity('Epic', 1.8, 0.04, '#c084ff'),
];

String _pct(double v) => '${jsNum(jsRound(v * 10) / 10)}%';

String _regenDesc(double m) {
  final s = (0.4 * m).toStringAsFixed(2);
  return '+${s.endsWith('0') ? s.substring(0, s.length - 1) : s} HP per second';
}

final _defs = <PerkDef>[
  PerkDef(
    id: 'might',
    name: 'Might',
    icon: '✊',
    color: '#ff5d5d',
    max: 5,
    rarity: true,
    desc: (m) => '+${_pct(10 * m)} damage',
    apply: (s, p) => s.might += 0.1 * p,
  ),
  PerkDef(
    id: 'haste',
    name: 'Haste',
    icon: '⌛',
    color: '#ffd166',
    max: 5,
    rarity: true,
    desc: (m) => '-${_pct(8 * m)} weapon & ability cooldown',
    apply: (s, p) => s.cooldown *= math.max(0.5, 1 - 0.08 * p),
  ),
  PerkDef(
    id: 'swift',
    name: 'Swiftness',
    icon: '»',
    color: '#7ae7ff',
    max: 5,
    rarity: true,
    desc: (m) => '+${_pct(8 * m)} movement speed',
    apply: (s, p) => s.speed *= 1 + 0.08 * p,
  ),
  PerkDef(
    id: 'vitality',
    name: 'Vitality',
    icon: '♥',
    color: '#ff6b9a',
    max: 5,
    rarity: true,
    desc: (m) => '+${roundInt(20 * m)} max HP',
    apply: (s, p) => s.maxHp += 20 * p,
  ),
  PerkDef(
    id: 'regen',
    name: 'Regeneration',
    icon: '✚',
    color: '#6bff8f',
    max: 5,
    rarity: true,
    desc: _regenDesc,
    apply: (s, p) => s.regen += 0.4 * p,
  ),
  PerkDef(
    id: 'armor',
    name: 'Armor',
    icon: '⬢',
    color: '#b0b8c8',
    max: 5,
    rarity: true,
    desc: (m) => '-${_pct(6 * m)} damage taken (max 60%)',
    apply: (s, p) => s.dr += 0.06 * p,
  ),
  PerkDef(
    id: 'magnet',
    name: 'Magnet',
    icon: '∪',
    color: '#5d9bff',
    max: 5,
    rarity: true,
    desc: (m) => '+${_pct(30 * m)} pickup range',
    apply: (s, p) => s.magnet *= 1 + 0.3 * p,
  ),
  PerkDef(
    id: 'area',
    name: 'Area',
    icon: '◎',
    color: '#ff9f43',
    max: 5,
    rarity: true,
    desc: (m) => '+${_pct(10 * m)} area of effect',
    apply: (s, p) => s.area += 0.1 * p,
  ),
  PerkDef(
    id: 'duration',
    name: 'Duration',
    icon: '∞',
    color: '#c38bff',
    max: 5,
    rarity: true,
    desc: (m) => '+${_pct(12 * m)} effect duration',
    apply: (s, p) => s.duration += 0.12 * p,
  ),
  PerkDef(
    id: 'multishot',
    name: 'Multishot',
    icon: '⁂',
    color: '#ffe66d',
    max: 2,
    rarity: false,
    desc: (_) => '+1 projectile amount',
    apply: (s, p) => s.amount += jsRound(p),
  ),
  PerkDef(
    id: 'crit',
    name: 'Critical',
    icon: '✷',
    color: '#ff4fd8',
    max: 5,
    rarity: true,
    desc: (m) => '+${_pct(5 * m)} critical hit chance',
    apply: (s, p) => s.crit += 0.05 * p,
  ),
  PerkDef(
    id: 'growth',
    name: 'Growth',
    icon: '❖',
    color: '#9dff6b',
    max: 5,
    rarity: true,
    desc: (m) => '+${_pct(10 * m)} experience gained',
    apply: (s, p) => s.growth += 0.1 * p,
  ),
  PerkDef(
    id: 'lifesteal',
    name: 'Vampirism',
    icon: '❣',
    color: '#e0315f',
    max: 5,
    rarity: true,
    desc: (m) => 'Heal ${_pct(1.2 * m)} of damage dealt (up to ${_pct(1.8 * m)} max HP/s)',
    apply: (s, p) {
      s.lifesteal += 0.012 * p;
      s.lifestealCap += 0.018 * p;
    },
  ),
  PerkDef(
    id: 'burn',
    name: 'Ignite',
    icon: '♨',
    color: '#ff7a1a',
    max: 5,
    rarity: true,
    desc: (m) => '+${_pct(8 * m)} chance to set enemies on fire (3s burn)',
    apply: (s, p) => s.burn += 0.08 * p,
  ),
  PerkDef(
    id: 'goldpurse',
    name: "Goldfang's Purse",
    icon: r'$',
    color: '#ffc83d',
    max: 1,
    rarity: false,
    unique: true,
    desc: (_) => '+25% experience, 5% chance for a gem to count twice, but -10% max HP (the sack is heavy)',
    apply: (s, _) {
      s.growth += 0.25;
      s.gemDouble += 0.05;
      s.maxHpMul *= 0.9;
    },
  ),
];

final Map<String, PerkDef> perkDefs = {for (final d in _defs) d.id: d};

/// Perks that level-ups may offer; unique ones are excluded.
final List<String> perkIds = [
  for (final d in _defs)
    if (!d.unique) d.id,
];

/// Owned perks that count against MAX_SLOTS.
int slottedPerks(List<PerkInst> ks) => ks.where((k) => !perkDefs[k.id]!.unique).length;

/// Endless stackable upgrades offered once every weapon and perk is maxed.
class BonusDef {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String desc;
  final int? max; // stack limit (null = endless)
  final void Function(Stats s, int count) apply;
  const BonusDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.desc,
    this.max,
    required this.apply,
  });
}

final _bonusDefs = <BonusDef>[
  BonusDef(
    id: 'power',
    name: 'Power Shard',
    icon: '◆',
    color: '#ff5d5d',
    desc: '+5% damage (stacks forever)',
    apply: (s, n) => s.might += 0.05 * n,
  ),
  BonusDef(
    id: 'life',
    name: 'Life Shard',
    icon: '♥',
    color: '#ff6b9a',
    desc: '+15 max HP (stacks forever)',
    apply: (s, n) => s.maxHp += 15 * n,
  ),
  BonusDef(
    id: 'time',
    name: 'Time Shard',
    icon: '⌛',
    color: '#ffd166',
    desc: '-3% cooldowns (stacks up to 15 times)',
    max: 15,
    apply: (s, n) => s.cooldown *= math.pow(0.97, math.min(n, 15)).toDouble(),
  ),
  BonusDef(
    id: 'reach',
    name: 'Reach Shard',
    icon: '◎',
    color: '#ff9f43',
    desc: '+5% area (stacks forever)',
    apply: (s, n) => s.area += 0.05 * n,
  ),
  BonusDef(
    id: 'fortune',
    name: 'Fortune Shard',
    icon: '✷',
    color: '#ff4fd8',
    desc: '+3% crit chance (stacks forever)',
    apply: (s, n) => s.crit += 0.03 * n,
  ),
];

final Map<String, BonusDef> bonusDefs = {for (final d in _bonusDefs) d.id: d};
final List<String> bonusIds = [for (final d in _bonusDefs) d.id];
