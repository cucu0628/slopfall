// Pure simulation types. Everything in GameState is plain data that turns
// into JSON and back (toJson / fromJson), so runs can be saved and later sent
// over the network. The JSON layout is the one the TypeScript version used,
// so its saves load here; fromJson fills in defaults for missing fields.

import 'js.dart';
import 'rng.dart';

typedef PlayerId = String;

const double dt60 = 1 / 60;

/// Anything with a position (obstacle collision works on these).
abstract interface class Pos {
  abstract double x;
  abstract double y;
}

/// Things whose previous position is kept for render interpolation.
abstract interface class Moving implements Pos {
  abstract double px;
  abstract double py;
}

class InputCmd {
  double mx; // movement direction, -1..1
  double my;
  double ax; // aim offset from the player, in world units
  double ay;
  bool ability; // ability button held
  bool dash; // dash button held
  int choose; // level-up choice index, -1 = none

  InputCmd({this.mx = 0, this.my = 0, this.ax = 1, this.ay = 0, this.ability = false, this.dash = false, this.choose = -1});

  InputCmd copyWith({double? mx, double? my, double? ax, double? ay, bool? ability, bool? dash, int? choose}) => InputCmd(
    mx: mx ?? this.mx,
    my: my ?? this.my,
    ax: ax ?? this.ax,
    ay: ay ?? this.ay,
    ability: ability ?? this.ability,
    dash: dash ?? this.dash,
    choose: choose ?? this.choose,
  );
}

class Stats {
  double might = 1;
  double cooldown = 1;
  double speed = 0;
  double maxHp = 0;
  double regen = 0;
  double armor = 0;
  double magnet = 75;
  double area = 1;
  double duration = 1;
  double amount = 0;
  double crit = 0.05;
  double growth = 1;
  double lifesteal = 0; // fraction of damage dealt healed
  double lifestealCap = 0; // max lifesteal healing per second, as a fraction of max HP
  double dr = 0; // damage reduction fraction (armor perk)
  double burn = 0; // chance to ignite on hit
  double gemDouble = 0; // chance for a collected XP pickup to count twice
  double maxHpMul = 1; // applied after every flat max HP bonus

  Stats();

  static const keys = [
    'might', 'cooldown', 'speed', 'maxHp', 'regen', 'armor', 'magnet', 'area', 'duration', 'amount', 'crit', //
    'growth', 'lifesteal', 'lifestealCap', 'dr', 'burn', 'gemDouble', 'maxHpMul',
  ];

  double operator [](String k) => switch (k) {
    'might' => might,
    'cooldown' => cooldown,
    'speed' => speed,
    'maxHp' => maxHp,
    'regen' => regen,
    'armor' => armor,
    'magnet' => magnet,
    'area' => area,
    'duration' => duration,
    'amount' => amount,
    'crit' => crit,
    'growth' => growth,
    'lifesteal' => lifesteal,
    'lifestealCap' => lifestealCap,
    'dr' => dr,
    'burn' => burn,
    'gemDouble' => gemDouble,
    'maxHpMul' => maxHpMul,
    _ => throw ArgumentError('unknown stat $k'),
  };

  void operator []=(String k, double v) {
    switch (k) {
      case 'might':
        might = v;
      case 'cooldown':
        cooldown = v;
      case 'speed':
        speed = v;
      case 'maxHp':
        maxHp = v;
      case 'regen':
        regen = v;
      case 'armor':
        armor = v;
      case 'magnet':
        magnet = v;
      case 'area':
        area = v;
      case 'duration':
        duration = v;
      case 'amount':
        amount = v;
      case 'crit':
        crit = v;
      case 'growth':
        growth = v;
      case 'lifesteal':
        lifesteal = v;
      case 'lifestealCap':
        lifestealCap = v;
      case 'dr':
        dr = v;
      case 'burn':
        burn = v;
      case 'gemDouble':
        gemDouble = v;
      case 'maxHpMul':
        maxHpMul = v;
      default:
        throw ArgumentError('unknown stat $k');
    }
  }

  Map<String, Object?> toJson() => {for (final k in keys) k: this[k]};

  /// Missing stats keep their defaults (refreshStats recomputes them anyway).
  factory Stats.fromJson(Object? json) {
    final m = jmap(json);
    final s = Stats();
    for (final k in keys) {
      if (m[k] is num) s[k] = jnum(m[k]);
    }
    return s;
  }
}

class WeaponInst {
  String id;
  int level;
  bool evolved;
  String evo; // id of the chosen evolution ('' while not evolved)
  double cd;
  double t; // weapon-specific timer / angle
  double r; // weapon-specific radius (used by aura rendering)

  WeaponInst({required this.id, this.level = 1, this.evolved = false, this.evo = '', this.cd = 0, this.t = 0, this.r = 0});

  Map<String, Object?> toJson() => {'id': id, 'level': level, 'evolved': evolved, 'evo': evo, 'cd': cd, 't': t, 'r': r};

  factory WeaponInst.fromJson(Object? json) {
    final m = jmap(json);
    return WeaponInst(
      id: jstr(m['id']),
      level: jint(m['level'], 1),
      evolved: jbool(m['evolved']),
      evo: jstr(m['evo']),
      cd: jnum(m['cd']),
      t: jnum(m['t']),
      r: jnum(m['r']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WeaponInst &&
      other.id == id &&
      other.level == level &&
      other.evolved == evolved &&
      other.evo == evo &&
      other.cd == cd &&
      other.t == t &&
      other.r == r;

  @override
  int get hashCode => Object.hash(id, level, evolved, evo, cd, t, r);
}

class PerkInst {
  String id;
  int level;
  double power; // sum of level-ups weighted by rarity

  PerkInst({required this.id, this.level = 1, this.power = 1});

  Map<String, Object?> toJson() => {'id': id, 'level': level, 'power': power};

  factory PerkInst.fromJson(Object? json) {
    final m = jmap(json);
    return PerkInst(id: jstr(m['id']), level: jint(m['level'], 1), power: jnum(m['power'], 1));
  }
}

/// A level-up / chest option. `kind` is one of weapon, perk, ability, bonus,
/// evo (id = weapon id, level = index into its evolutions) or heal.
class UpgradeOption {
  final String kind;
  final String id;
  final int level;
  final int rarity; // perks only: index into RARITIES

  const UpgradeOption({required this.kind, required this.id, required this.level, this.rarity = 0});

  UpgradeOption withRarity(int r) => UpgradeOption(kind: kind, id: id, level: level, rarity: r);

  Map<String, Object?> toJson() => {'kind': kind, 'id': id, 'level': level, if (kind == 'perk') 'rarity': rarity};

  factory UpgradeOption.fromJson(Object? json) {
    final m = jmap(json);
    return UpgradeOption(kind: jstr(m['kind']), id: jstr(m['id']), level: jint(m['level']), rarity: jint(m['rarity']));
  }

  @override
  bool operator ==(Object other) =>
      other is UpgradeOption && other.kind == kind && other.id == id && other.level == level && other.rarity == rarity;

  @override
  int get hashCode => Object.hash(kind, id, level, rarity);

  @override
  String toString() => 'UpgradeOption($kind, $id, $level, $rarity)';
}

class Player implements Moving {
  PlayerId id;
  String charId;
  @override
  double x;
  @override
  double y;
  @override
  double px;
  @override
  double py;
  double fx = 1; // facing
  double fy = 0;
  double ax = 1; // last aim offset
  double ay = 0;
  double hp = 0;
  Stats stats = Stats();
  double radius = 14;
  int level = 1;
  double xp = 0;
  double xpNext = 0;
  List<WeaponInst> weapons = [];
  List<PerkInst> perks = [];
  int abilityLevel = 1;
  double abilityCd = 0;
  double abilityMaxCd = 0;
  double abilityT = 0; // remaining time of an active ability effect
  double invuln = 0;
  double hurtT = 0;
  double dashT = 0;
  double dashX = 0;
  double dashY = 0;
  double dashCd = 0;
  double dashMaxCd = 0;
  Map<String, int> bonus = {}; // stackable bonus upgrades taken after everything is maxed
  double vigorHp = 0; // max HP gained from surviving waves (see VIGOR_EVERY)
  double healBudget = 0; // necromancer kill-heal limiter
  double lsBudget = 0; // lifesteal healing still allowed this second
  double idleT = 0; // seconds spent near the same spot (anti-AFK)
  double anchorX;
  double anchorY;
  double skyfallCd = 0;
  int skyfallN = 0;
  double slowT = 0; // slowed by webs
  List<String> evoQueue = []; // weapons waiting for the player to pick an evolution
  int pendingLevels = 0;
  List<UpgradeOption>? choices;
  bool dead = false;
  int kills = 0;
  Map<String, double> dmgDealt = {};

  Player({required this.id, required this.charId, required this.x, required this.y}) : px = x, py = y, anchorX = x, anchorY = y;

  /// A shallow copy with its own lists (used by stat previews and tests).
  Player copy() => Player.fromJson(toJson());

  Map<String, Object?> toJson() => {
    'id': id, 'charId': charId, 'x': x, 'y': y, 'px': px, 'py': py, 'fx': fx, 'fy': fy, 'ax': ax, 'ay': ay, //
    'hp': hp, 'stats': stats.toJson(), 'radius': radius, 'level': level, 'xp': xp, 'xpNext': xpNext,
    'weapons': [for (final w in weapons) w.toJson()],
    'perks': [for (final k in perks) k.toJson()],
    'abilityLevel': abilityLevel, 'abilityCd': abilityCd, 'abilityMaxCd': abilityMaxCd, 'abilityT': abilityT,
    'invuln': invuln, 'hurtT': hurtT, 'dashT': dashT, 'dashX': dashX, 'dashY': dashY, 'dashCd': dashCd,
    'dashMaxCd': dashMaxCd, 'bonus': {...bonus}, 'vigorHp': vigorHp, 'healBudget': healBudget,
    'lsBudget': lsBudget, 'idleT': idleT, 'anchorX': anchorX, 'anchorY': anchorY, 'skyfallCd': skyfallCd,
    'skyfallN': skyfallN, 'slowT': slowT, 'evoQueue': [...evoQueue], 'pendingLevels': pendingLevels,
    'choices': choices == null ? null : [for (final o in choices!) o.toJson()],
    'dead': dead, 'kills': kills, 'dmgDealt': {...dmgDealt},
  };

  factory Player.fromJson(Object? json) {
    final m = jmap(json);
    final p = Player(id: jstr(m['id']), charId: jstr(m['charId']), x: jnum(m['x']), y: jnum(m['y']))
      ..px = jnum(m['px'], jnum(m['x']))
      ..py = jnum(m['py'], jnum(m['y']))
      ..fx = jnum(m['fx'], 1)
      ..fy = jnum(m['fy'])
      ..ax = jnum(m['ax'], 1)
      ..ay = jnum(m['ay'])
      ..hp = jnum(m['hp'])
      ..stats = Stats.fromJson(m['stats'])
      ..radius = jnum(m['radius'], 14)
      ..level = jint(m['level'], 1)
      ..xp = jnum(m['xp'])
      ..xpNext = jnum(m['xpNext'])
      ..weapons = [for (final w in jlist(m['weapons'])) WeaponInst.fromJson(w)]
      ..perks = [for (final k in jlist(m['perks'])) PerkInst.fromJson(k)]
      ..abilityLevel = jint(m['abilityLevel'], 1)
      ..abilityCd = jnum(m['abilityCd'])
      ..abilityMaxCd = jnum(m['abilityMaxCd'])
      ..abilityT = jnum(m['abilityT'])
      ..invuln = jnum(m['invuln'])
      ..hurtT = jnum(m['hurtT'])
      ..dashT = jnum(m['dashT'])
      ..dashX = jnum(m['dashX'])
      ..dashY = jnum(m['dashY'])
      ..dashCd = jnum(m['dashCd'])
      ..dashMaxCd = jnum(m['dashMaxCd'])
      ..bonus = {for (final e in jmap(m['bonus']).entries) e.key: jint(e.value)}
      ..vigorHp = jnum(m['vigorHp'])
      ..healBudget = jnum(m['healBudget'])
      ..lsBudget = jnum(m['lsBudget'])
      ..idleT = jnum(m['idleT'])
      ..anchorX = jnum(m['anchorX'], jnum(m['x']))
      ..anchorY = jnum(m['anchorY'], jnum(m['y']))
      ..skyfallCd = jnum(m['skyfallCd'])
      ..skyfallN = jint(m['skyfallN'])
      ..slowT = jnum(m['slowT'])
      ..evoQueue = [for (final s in jlist(m['evoQueue'])) jstr(s)]
      ..pendingLevels = jint(m['pendingLevels'])
      ..choices = m['choices'] is List ? [for (final o in jlist(m['choices'])) UpgradeOption.fromJson(o)] : null
      ..dead = jbool(m['dead'])
      ..kills = jint(m['kills'])
      ..dmgDealt = {for (final e in jmap(m['dmgDealt']).entries) e.key: jnum(e.value)};
    return p;
  }
}

Map<String, Object?> _hitsJson(Map<int, double> hits) => {for (final e in hits.entries) '${e.key}': e.value};

Map<int, double> _hitsFrom(Object? json) {
  final out = <int, double>{};
  for (final e in jmap(json).entries) {
    final k = int.tryParse(e.key);
    if (k != null) out[k] = jnum(e.value);
  }
  return out;
}

class Enemy implements Moving {
  int id;
  String type;
  @override
  double x;
  @override
  double y;
  @override
  double px;
  @override
  double py;
  double kx = 0; // knockback velocity
  double ky = 0;
  double hp = 0;
  double maxHp = 0;
  double dmg = 0;
  double speed = 0;
  double radius = 0;
  double xp = 0;
  bool elite = false;
  bool boss = false;
  bool chest = false; // drops a treasure chest
  double slowT = 0;
  double slowAmt = 0;
  double flash = 0;
  int state = 0;
  double t = 0;
  double t2 = 0;
  double t3 = 0;
  double tx = 0;
  double ty = 0;
  double sx = 0;
  double sy = 0;
  double ang = 0;
  double dmgAcc = 0;
  bool intangible = false;
  List<double> trail = []; // body segment positions (x, y pairs) for serpent bosses
  double burnT = 0; // remaining burn time
  double burnDps = 0; // base damage per second while burning
  double burnTick = 0;
  PlayerId burnOwner = '';
  double healReadyAt = 0; // game time when shamans may heal this boss again
  bool dead = false;

  Enemy({required this.id, required this.type, required this.x, required this.y}) : px = x, py = y;

  Map<String, Object?> toJson() => {
    'id': id, 'type': type, 'x': x, 'y': y, 'px': px, 'py': py, 'kx': kx, 'ky': ky, 'hp': hp, 'maxHp': maxHp, //
    'dmg': dmg, 'speed': speed, 'radius': radius, 'xp': xp, 'elite': elite, 'boss': boss, 'chest': chest,
    'slowT': slowT, 'slowAmt': slowAmt, 'flash': flash, 'state': state, 't': t, 't2': t2, 't3': t3, 'tx': tx,
    'ty': ty, 'sx': sx, 'sy': sy, 'ang': ang, 'dmgAcc': dmgAcc, 'intangible': intangible, 'trail': [...trail],
    'burnT': burnT, 'burnDps': burnDps, 'burnTick': burnTick, 'burnOwner': burnOwner,
    'healReadyAt': healReadyAt, 'dead': dead,
  };

  factory Enemy.fromJson(Object? json) {
    final m = jmap(json);
    return Enemy(id: jint(m['id']), type: jstr(m['type']), x: jnum(m['x']), y: jnum(m['y']))
      ..px = jnum(m['px'], jnum(m['x']))
      ..py = jnum(m['py'], jnum(m['y']))
      ..kx = jnum(m['kx'])
      ..ky = jnum(m['ky'])
      ..hp = jnum(m['hp'])
      ..maxHp = jnum(m['maxHp'])
      ..dmg = jnum(m['dmg'])
      ..speed = jnum(m['speed'])
      ..radius = jnum(m['radius'])
      ..xp = jnum(m['xp'])
      ..elite = jbool(m['elite'])
      ..boss = jbool(m['boss'])
      ..chest = jbool(m['chest'])
      ..slowT = jnum(m['slowT'])
      ..slowAmt = jnum(m['slowAmt'])
      ..flash = jnum(m['flash'])
      ..state = jint(m['state'])
      ..t = jnum(m['t'])
      ..t2 = jnum(m['t2'])
      ..t3 = jnum(m['t3'])
      ..tx = jnum(m['tx'])
      ..ty = jnum(m['ty'])
      ..sx = jnum(m['sx'])
      ..sy = jnum(m['sy'])
      ..ang = jnum(m['ang'])
      ..dmgAcc = jnum(m['dmgAcc'])
      ..intangible = jbool(m['intangible'])
      ..trail = jnums(m['trail'])
      ..burnT = jnum(m['burnT'])
      ..burnDps = jnum(m['burnDps'])
      ..burnTick = jnum(m['burnTick'])
      ..burnOwner = jstr(m['burnOwner'])
      ..healReadyAt = jnum(m['healReadyAt'])
      ..dead = jbool(m['dead']);
  }
}

class Projectile implements Moving {
  int id;
  PlayerId owner;
  String src; // weapon id, for damage stats
  String kind; // render kind
  @override
  double x;
  @override
  double y;
  @override
  double px;
  @override
  double py;
  double vx;
  double vy;
  double dmg;
  double radius;
  double pierce;
  double life;
  double maxLife;
  double knock;
  Map<int, double> hits = {}; // enemy id -> time when it can be hit again
  double hitRate; // 0 = each enemy only once
  double homing;
  double ang;
  double data;
  double slow;
  double age;
  double speed;
  bool dead = false;

  Projectile({
    required this.id,
    required this.owner,
    required this.src,
    required this.kind,
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.dmg = 0,
    this.radius = 8,
    this.pierce = 0,
    this.life = 1,
    this.knock = 0,
    this.hitRate = 0,
    this.homing = 0,
    this.ang = 0,
    this.data = 0,
    this.slow = 0,
    this.age = 0,
    this.speed = 0,
  }) : px = x,
       py = y,
       maxLife = life;

  Map<String, Object?> toJson() => {
    'id': id, 'owner': owner, 'src': src, 'kind': kind, 'x': x, 'y': y, 'px': px, 'py': py, 'vx': vx, //
    'vy': vy, 'dmg': dmg, 'radius': radius, 'pierce': pierce, 'life': life, 'maxLife': maxLife,
    'knock': knock, 'hits': _hitsJson(hits), 'hitRate': hitRate, 'homing': homing, 'ang': ang,
    'data': data, 'slow': slow, 'age': age, 'speed': speed, 'dead': dead,
  };

  factory Projectile.fromJson(Object? json) {
    final m = jmap(json);
    return Projectile(
        id: jint(m['id']),
        owner: jstr(m['owner']),
        src: jstr(m['src']),
        kind: jstr(m['kind']),
        x: jnum(m['x']),
        y: jnum(m['y']),
        vx: jnum(m['vx']),
        vy: jnum(m['vy']),
        dmg: jnum(m['dmg']),
        radius: jnum(m['radius'], 8),
        pierce: jnum(m['pierce']),
        life: jnum(m['life'], 1),
        knock: jnum(m['knock']),
        hitRate: jnum(m['hitRate']),
        homing: jnum(m['homing']),
        ang: jnum(m['ang']),
        data: jnum(m['data']),
        slow: jnum(m['slow']),
        age: jnum(m['age']),
        speed: jnum(m['speed']),
      )
      ..px = jnum(m['px'], jnum(m['x']))
      ..py = jnum(m['py'], jnum(m['y']))
      ..maxLife = jnum(m['maxLife'], jnum(m['life'], 1))
      ..hits = _hitsFrom(m['hits'])
      ..dead = jbool(m['dead']);
  }
}

class Zone implements Pos {
  int id;
  PlayerId owner;
  String src;
  String kind;
  @override
  double x;
  @override
  double y;
  double r;
  double r0;
  double life;
  double maxLife;
  double delay;
  double dmg;
  double knock;
  double slow;
  double ang;
  double arc;
  List<double> pts;
  Map<int, double> hits = {};
  double burn; // base burn damage per second applied to enemies hit (0 = none)
  bool fired = false;
  bool dead = false;

  Zone({
    required this.id,
    required this.owner,
    required this.src,
    required this.kind,
    required this.x,
    required this.y,
    required this.r,
    double? r0,
    this.life = 0.3,
    this.delay = 0,
    this.dmg = 0,
    this.knock = 0,
    this.slow = 0,
    this.ang = 0,
    this.arc = 0,
    List<double>? pts,
    this.burn = 0,
  }) : r0 = r0 ?? r,
       maxLife = life,
       pts = pts ?? [];

  Map<String, Object?> toJson() => {
    'id': id, 'owner': owner, 'src': src, 'kind': kind, 'x': x, 'y': y, 'r': r, 'r0': r0, 'life': life, //
    'maxLife': maxLife, 'delay': delay, 'dmg': dmg, 'knock': knock, 'slow': slow, 'ang': ang, 'arc': arc,
    'pts': [...pts], 'hits': _hitsJson(hits), 'burn': burn, 'fired': fired, 'dead': dead,
  };

  factory Zone.fromJson(Object? json) {
    final m = jmap(json);
    return Zone(
        id: jint(m['id']),
        owner: jstr(m['owner']),
        src: jstr(m['src']),
        kind: jstr(m['kind']),
        x: jnum(m['x']),
        y: jnum(m['y']),
        r: jnum(m['r']),
        r0: jnum(m['r0'], jnum(m['r'])),
        life: jnum(m['life'], 0.3),
        delay: jnum(m['delay']),
        dmg: jnum(m['dmg']),
        knock: jnum(m['knock']),
        slow: jnum(m['slow']),
        ang: jnum(m['ang']),
        arc: jnum(m['arc']),
        pts: jnums(m['pts']),
        burn: jnum(m['burn']),
      )
      ..maxLife = jnum(m['maxLife'], jnum(m['life'], 0.3))
      ..hits = _hitsFrom(m['hits'])
      ..fired = jbool(m['fired'])
      ..dead = jbool(m['dead']);
  }
}

class EnemyProjectile implements Moving {
  int id;
  String kind;
  @override
  double x;
  @override
  double y;
  @override
  double px;
  @override
  double py;
  double vx;
  double vy;
  double r;
  double dmg;
  double life;
  bool dead = false;

  EnemyProjectile({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r,
    required this.dmg,
    required this.life,
  }) : px = x,
       py = y;

  Map<String, Object?> toJson() => {
    'id': id, 'kind': kind, 'x': x, 'y': y, 'px': px, 'py': py, 'vx': vx, 'vy': vy, 'r': r, 'dmg': dmg, //
    'life': life, 'dead': dead,
  };

  factory EnemyProjectile.fromJson(Object? json) {
    final m = jmap(json);
    return EnemyProjectile(
        id: jint(m['id']),
        kind: jstr(m['kind']),
        x: jnum(m['x']),
        y: jnum(m['y']),
        vx: jnum(m['vx']),
        vy: jnum(m['vy']),
        r: jnum(m['r'], 7),
        dmg: jnum(m['dmg']),
        life: jnum(m['life'], 5),
      )
      ..px = jnum(m['px'], jnum(m['x']))
      ..py = jnum(m['py'], jnum(m['y']))
      ..dead = jbool(m['dead']);
  }
}

/// ring | slam | laser | skyfall | coin
class Hazard implements Pos {
  int id;
  String kind;
  int src; // enemy id the hazard is attached to (lasers)
  @override
  double x;
  @override
  double y;
  double r;
  double w;
  double speed;
  double ang;
  double angVel;
  double len;
  double warn;
  double maxWarn;
  double life;
  double dmg;
  Map<String, double> hit = {};
  bool fired = false;
  bool dead = false;

  Hazard({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.dmg,
    this.src = -1,
    this.r = 0,
    this.w = 16,
    this.speed = 0,
    this.ang = 0,
    this.angVel = 0,
    this.len = 0,
    this.warn = 0,
    this.life = 1,
  }) : maxWarn = warn;

  Map<String, Object?> toJson() => {
    'id': id, 'kind': kind, 'src': src, 'x': x, 'y': y, 'r': r, 'w': w, 'speed': speed, 'ang': ang, //
    'angVel': angVel, 'len': len, 'warn': warn, 'maxWarn': maxWarn, 'life': life, 'dmg': dmg,
    'hit': {...hit}, 'fired': fired, 'dead': dead,
  };

  factory Hazard.fromJson(Object? json) {
    final m = jmap(json);
    return Hazard(
        id: jint(m['id']),
        kind: jstr(m['kind']),
        x: jnum(m['x']),
        y: jnum(m['y']),
        dmg: jnum(m['dmg']),
        src: jint(m['src'], -1),
        r: jnum(m['r']),
        w: jnum(m['w'], 16),
        speed: jnum(m['speed']),
        ang: jnum(m['ang']),
        angVel: jnum(m['angVel']),
        len: jnum(m['len']),
        warn: jnum(m['warn']),
        life: jnum(m['life'], 1),
      )
      ..maxWarn = jnum(m['maxWarn'], jnum(m['warn']))
      ..hit = {for (final e in jmap(m['hit']).entries) e.key: jnum(e.value)}
      ..fired = jbool(m['fired'])
      ..dead = jbool(m['dead']);
  }
}

class Turret implements Pos {
  int id;
  PlayerId owner;
  @override
  double x;
  @override
  double y;
  double life;
  double maxLife;
  double cd;
  double ang;
  bool dead = false;

  Turret({required this.id, required this.owner, required this.x, required this.y, required this.life, required this.cd, required this.ang})
    : maxLife = life;

  Map<String, Object?> toJson() => {
    'id': id,
    'owner': owner,
    'x': x,
    'y': y,
    'life': life,
    'maxLife': maxLife,
    'cd': cd,
    'ang': ang,
    'dead': dead,
  };

  factory Turret.fromJson(Object? json) {
    final m = jmap(json);
    return Turret(
        id: jint(m['id']),
        owner: jstr(m['owner']),
        x: jnum(m['x']),
        y: jnum(m['y']),
        life: jnum(m['life']),
        cd: jnum(m['cd']),
        ang: jnum(m['ang']),
      )
      ..maxLife = jnum(m['maxLife'], jnum(m['life']))
      ..dead = jbool(m['dead']);
  }
}

class Minion implements Moving {
  int id;
  PlayerId owner;
  @override
  double x;
  @override
  double y;
  @override
  double px;
  @override
  double py;
  double life;
  double cd;
  double dmg;
  bool dead = false;

  Minion({required this.id, required this.owner, required this.x, required this.y, required this.life, required this.cd, required this.dmg})
    : px = x,
      py = y;

  Map<String, Object?> toJson() => {
    'id': id,
    'owner': owner,
    'x': x,
    'y': y,
    'px': px,
    'py': py,
    'life': life,
    'cd': cd,
    'dmg': dmg,
    'dead': dead,
  };

  factory Minion.fromJson(Object? json) {
    final m = jmap(json);
    return Minion(
        id: jint(m['id']),
        owner: jstr(m['owner']),
        x: jnum(m['x']),
        y: jnum(m['y']),
        life: jnum(m['life']),
        cd: jnum(m['cd']),
        dmg: jnum(m['dmg']),
      )
      ..px = jnum(m['px'], jnum(m['x']))
      ..py = jnum(m['py'], jnum(m['y']))
      ..dead = jbool(m['dead']);
  }
}

/// xp | heal | magnet | bomb | chest | coin | relic
class Pickup implements Moving {
  int id;
  String kind;
  @override
  double x;
  @override
  double y;
  @override
  double px;
  @override
  double py;
  double value;
  PlayerId target = ''; // '' = nobody
  double sp = 0;
  bool big; // boss chest
  bool dead = false;

  Pickup({required this.id, required this.kind, required this.x, required this.y, this.value = 0, this.big = false}) : px = x, py = y;

  Map<String, Object?> toJson() => {
    'id': id, 'kind': kind, 'x': x, 'y': y, 'px': px, 'py': py, 'value': value, 'target': target, 'sp': sp, //
    'big': big, 'dead': dead,
  };

  factory Pickup.fromJson(Object? json) {
    final m = jmap(json);
    return Pickup(id: jint(m['id']), kind: jstr(m['kind']), x: jnum(m['x']), y: jnum(m['y']), value: jnum(m['value']), big: jbool(m['big']))
      ..px = jnum(m['px'], jnum(m['x']))
      ..py = jnum(m['py'], jnum(m['y']))
      ..target = jstr(m['target'])
      ..sp = jnum(m['sp'])
      ..dead = jbool(m['dead']);
  }
}

class Corpse {
  double x;
  double y;
  double t;

  Corpse({required this.x, required this.y, required this.t});

  Map<String, Object?> toJson() => {'x': x, 'y': y, 't': t};

  factory Corpse.fromJson(Object? json) {
    final m = jmap(json);
    return Corpse(x: jnum(m['x']), y: jnum(m['y']), t: jnum(m['t']));
  }
}

class WaveState {
  int n;
  double timer;
  double spawnAcc;
  bool bossWave;
  bool eliteSpawned;

  WaveState({this.n = 0, this.timer = 0, this.spawnAcc = 8, this.bossWave = false, this.eliteSpawned = false});

  Map<String, Object?> toJson() => {'n': n, 'timer': timer, 'spawnAcc': spawnAcc, 'bossWave': bossWave, 'eliteSpawned': eliteSpawned};

  factory WaveState.fromJson(Object? json) {
    final m = jmap(json);
    return WaveState(
      n: jint(m['n']),
      timer: jnum(m['timer']),
      spawnAcc: jnum(m['spawnAcc']),
      bossWave: jbool(m['bossWave']),
      eliteSpawned: jbool(m['eliteSpawned']),
    );
  }
}

/// The secret boss of a run, rolled once from the seed when the run starts.
class SecretState {
  final int wave; // boss wave where Goldfang shows up instead of the regular boss (0 = never)
  final String reward; // 'weapon' | 'perk'

  const SecretState({required this.wave, required this.reward});

  Map<String, Object?> toJson() => {'wave': wave, 'reward': reward};

  factory SecretState.fromJson(Object? json) {
    final m = jmap(json);
    return SecretState(wave: jint(m['wave']), reward: jstr(m['reward'], 'weapon'));
  }

  @override
  bool operator ==(Object other) => other is SecretState && other.wave == wave && other.reward == reward;

  @override
  int get hashCode => Object.hash(wave, reward);
}

class SimConfig {
  bool pauseOnLevelUp;
  double waveDuration;
  bool godMode;

  SimConfig({this.pauseOnLevelUp = true, this.waveDuration = 45, this.godMode = false});

  Map<String, Object?> toJson() => {'pauseOnLevelUp': pauseOnLevelUp, 'waveDuration': waveDuration, 'godMode': godMode};

  factory SimConfig.fromJson(Object? json) {
    final m = jmap(json);
    return SimConfig(
      pauseOnLevelUp: jbool(m['pauseOnLevelUp'], true),
      waveDuration: jnum(m['waveDuration'], 45),
      godMode: jbool(m['godMode']),
    );
  }
}

// ------------------------------------------------------------------ events

/// Something the client should show or play. The sim never draws or plays
/// sounds itself; events are cleared at the start of every step.
sealed class SimEvent {
  const SimEvent();
}

class HitEvent extends SimEvent {
  final double x, y;
  final int v;
  final bool crit, dot;
  const HitEvent(this.x, this.y, this.v, this.crit, this.dot);
}

class KillEvent extends SimEvent {
  final double x, y, r;
  final String type;
  final bool elite, boss;
  const KillEvent(this.x, this.y, this.type, this.elite, this.boss, this.r);
}

class PlayerHurtEvent extends SimEvent {
  final PlayerId pid;
  final int v;
  const PlayerHurtEvent(this.pid, this.v);
}

class PlayerDeathEvent extends SimEvent {
  final PlayerId pid;
  const PlayerDeathEvent(this.pid);
}

class HealEvent extends SimEvent {
  final PlayerId pid;
  final int v;
  const HealEvent(this.pid, this.v);
}

class VigorEvent extends SimEvent {
  final PlayerId pid;
  final double v;
  const VigorEvent(this.pid, this.v);
}

class LevelUpEvent extends SimEvent {
  final PlayerId pid;
  const LevelUpEvent(this.pid);
}

class WaveEvent extends SimEvent {
  final int n;
  final bool boss;
  const WaveEvent(this.n, this.boss);
}

class BossEvent extends SimEvent {
  final String id, name;
  const BossEvent(this.id, this.name);
}

class EscapeEvent extends SimEvent {
  final double x, y;
  final String name;
  const EscapeEvent(this.x, this.y, this.name);
}

class UniqueEvent extends SimEvent {
  final PlayerId pid;
  final String name, desc;
  const UniqueEvent(this.pid, this.name, this.desc);
}

class ExplodeEvent extends SimEvent {
  final double x, y, r;
  final String color;
  const ExplodeEvent(this.x, this.y, this.r, this.color);
}

class PickupEvent extends SimEvent {
  final PlayerId pid;
  final String kind;
  const PickupEvent(this.pid, this.kind);
}

class ChestEvent extends SimEvent {
  final PlayerId pid;
  final List<String> items;
  const ChestEvent(this.pid, this.items);
}

class EvolveEvent extends SimEvent {
  final PlayerId pid;
  final String name;
  const EvolveEvent(this.pid, this.name);
}

class AbilityEvent extends SimEvent {
  final PlayerId pid;
  final String char;
  const AbilityEvent(this.pid, this.char);
}

class DashEvent extends SimEvent {
  final PlayerId pid;
  const DashEvent(this.pid);
}

class DodgeEvent extends SimEvent {
  final PlayerId pid;
  const DodgeEvent(this.pid);
}

class SfxEvent extends SimEvent {
  final String name;
  const SfxEvent(this.name);
}

class ShakeEvent extends SimEvent {
  final double v;
  const ShakeEvent(this.v);
}

// ------------------------------------------------------------------- state

class GameState implements RngHolder {
  SimConfig cfg;
  int mapSeed; // obstacles are a pure function of this seed
  @override
  int rng;
  int tick = 0;
  double time = 0;
  int nextId = 1;
  List<Player> players;
  List<Enemy> enemies = [];
  List<Projectile> projectiles = [];
  List<EnemyProjectile> eprojectiles = [];
  List<Zone> zones = [];
  List<Hazard> hazards = [];
  List<Turret> turrets = [];
  List<Minion> minions = [];
  List<Pickup> pickups = [];
  List<Corpse> corpses = [];
  WaveState wave = WaveState();
  SecretState secret;
  List<SimEvent> events = [];
  int kills = 0;
  bool gameOver = false;

  GameState({required this.cfg, required this.mapSeed, required this.rng, required this.players, required this.secret});

  /// Events are transient and never serialized.
  Map<String, Object?> toJson() => {
    'cfg': cfg.toJson(),
    'mapSeed': mapSeed,
    'rng': rng,
    'tick': tick,
    'time': time,
    'nextId': nextId,
    'players': [for (final x in players) x.toJson()],
    'enemies': [for (final x in enemies) x.toJson()],
    'projectiles': [for (final x in projectiles) x.toJson()],
    'eprojectiles': [for (final x in eprojectiles) x.toJson()],
    'zones': [for (final x in zones) x.toJson()],
    'hazards': [for (final x in hazards) x.toJson()],
    'turrets': [for (final x in turrets) x.toJson()],
    'minions': [for (final x in minions) x.toJson()],
    'pickups': [for (final x in pickups) x.toJson()],
    'corpses': [for (final x in corpses) x.toJson()],
    'wave': wave.toJson(),
    'secret': secret.toJson(),
    'events': const <Object?>[],
    'kills': kills,
    'gameOver': gameOver,
  };

  /// [secretFallback] is used when the JSON predates the secret boss.
  factory GameState.fromJson(Object? json, {SecretState? secretFallback}) {
    final m = jmap(json);
    return GameState(
        cfg: SimConfig.fromJson(m['cfg']),
        mapSeed: jint(m['mapSeed']),
        rng: i32(jint(m['rng'])),
        players: [for (final x in jlist(m['players'])) Player.fromJson(x)],
        secret: m['secret'] is Map ? SecretState.fromJson(m['secret']) : (secretFallback ?? const SecretState(wave: 0, reward: 'weapon')),
      )
      ..tick = jint(m['tick'])
      ..time = jnum(m['time'])
      ..nextId = jint(m['nextId'], 1)
      ..enemies = [for (final x in jlist(m['enemies'])) Enemy.fromJson(x)]
      ..projectiles = [for (final x in jlist(m['projectiles'])) Projectile.fromJson(x)]
      ..eprojectiles = [for (final x in jlist(m['eprojectiles'])) EnemyProjectile.fromJson(x)]
      ..zones = [for (final x in jlist(m['zones'])) Zone.fromJson(x)]
      ..hazards = [for (final x in jlist(m['hazards'])) Hazard.fromJson(x)]
      ..turrets = [for (final x in jlist(m['turrets'])) Turret.fromJson(x)]
      ..minions = [for (final x in jlist(m['minions'])) Minion.fromJson(x)]
      ..pickups = [for (final x in jlist(m['pickups'])) Pickup.fromJson(x)]
      ..corpses = [for (final x in jlist(m['corpses'])) Corpse.fromJson(x)]
      ..wave = WaveState.fromJson(m['wave'])
      ..kills = jint(m['kills'])
      ..gameOver = jbool(m['gameOver']);
  }

  GameState clone() => GameState.fromJson(toJson());
}
