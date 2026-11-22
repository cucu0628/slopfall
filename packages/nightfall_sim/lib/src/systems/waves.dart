import 'dart:math' as math;

import '../combat.dart';
import '../content/enemies.dart';
import '../entities.dart';
import '../fdlibm.dart';
import '../rng.dart';
import '../types.dart';
import 'bosses/index.dart';
import 'leveling.dart';

const int enemyCap = 500;
const int bossEvery = 5;

/// Every this many cleared waves each hero gains vigorHp max HP, so late waves don't one-shot builds without HP perks.
const int vigorEvery = 5;
const double vigorHpGain = 5;

/// Max HP a hero has earned from waves by the time wave [n] starts.
double vigorHpAt(int n) => ((n - 1) / vigorEvery).floorToDouble() * vigorHpGain;

(double, double) _spawnPoint(GameState s, Player target, double dist) {
  final a = rand(s) * math.pi * 2;
  final d = dist + rand(s) * 80;
  return (target.x + jsCos(a) * d, target.y + jsSin(a) * d);
}

/// Extra HP for bosses on top of the normal wave scaling. It grows with the
/// wave because builds grow much faster than a linear curve: a typical build
/// should need roughly 30-45 s for a boss.
double bossHpFactor(int n) => n <= 10 ? math.max(0.6, 0.2 * n - 0.1) : 1.9 + 0.12 * (n - 10);

void startWave(GameState s, int n) {
  final w = s.wave;
  w.n = n;
  w.timer = s.cfg.waveDuration;
  w.bossWave = n % bossEvery == 0;
  w.eliteSpawned = false;
  s.events.add(WaveEvent(n, w.bossWave));
  _grantVigor(s, n);
  if (!w.bossWave) return;

  final alive = s.players.where((p) => !p.dead).toList();
  if (alive.isEmpty) return;
  final k = n ~/ bossEvery - 1;
  var ids = [bossOrder[k % bossOrder.length]];
  if (n >= 20) ids.add(bossOrder[(k + 1) % bossOrder.length]);
  if (n == s.secret.wave) ids = ['goldfang']; // the secret boss comes alone
  final sc = waveScale(n);
  final hpMul = sc.hp * bossHpFactor(n) * (ids.length > 1 ? 0.75 : 1) * alive.length;
  for (final id in ids) {
    final (x, y) = _spawnPoint(s, pick(s, alive), 600);
    final e = spawnEnemy(s, id, x, y, EnemyScale(hp: hpMul, dmg: sc.dmg, speed: 1));
    initBoss(e);
    s.events.add(BossEvent(id, enemyDefs[id]!.name));
  }
}

void _grantVigor(GameState s, int n) {
  final want = vigorHpAt(n);
  for (final p in s.players) {
    if (p.dead || p.vigorHp >= want) continue;
    final gain = want - p.vigorHp;
    p.vigorHp = want;
    refreshStats(p); // raises current HP by the same amount
    s.events.add(VigorEvent(p.id, gain));
  }
}

void updateWaves(GameState s, double dt) {
  final w = s.wave;
  if (w.bossWave) {
    if (!s.enemies.any((e) => e.boss && !e.dead)) startWave(s, w.n + 1);
  } else {
    w.timer -= dt;
    if (w.timer <= 0) startWave(s, w.n + 1);
  }

  final alive = s.players.where((p) => !p.dead).toList();
  if (alive.isEmpty) return;
  final sc = waveScale(w.n);
  final rate = (1.8 + 0.8 * w.n + 0.035 * w.n * w.n) * (w.bossWave ? 0.35 : 1) * (0.6 + 0.4 * alive.length);
  w.spawnAcc += rate * dt;

  final types = waveEnemyIds.where((id) => enemyDefs[id]!.unlock <= w.n).toList();
  var live = 0;
  for (final e in s.enemies) {
    if (!e.dead) live++;
  }

  while (w.spawnAcc > 0 && live < enemyCap) {
    final type = weightedPick(s, types, (id) => 1 + (enemyDefs[id]!.cost >= 3 ? w.n * 0.04 : 0));
    final def = enemyDefs[type]!;
    final count = randInt(s, def.group.$1, def.group.$2);
    w.spawnAcc -= def.cost * count;
    final target = pick(s, alive);
    final (cx, cy) = _spawnPoint(s, target, 780);
    final eliteChance = math.min(0.01, 0.0005 * w.n);
    for (var i = 0; i < count; i++) {
      final x = cx + randRange(s, -45, 45);
      final y = cy + randRange(s, -45, 45);
      spawnEnemy(s, type, x, y, sc, rand(s) < eliteChance);
      live++;
    }
  }

  // One mid-wave elite from wave 3. Only the "champion" (once per boss
  // cycle) carries a chest, so chests stay rare: one champion + one boss
  // chest every 5 waves.
  if (!w.bossWave && !w.eliteSpawned && w.n >= 3 && w.timer < s.cfg.waveDuration * 0.5) {
    w.eliteSpawned = true;
    final type = pick(s, types.where((t) => t != 'swarm').toList());
    final (x, y) = _spawnPoint(s, pick(s, alive), 800);
    final e = spawnEnemy(s, type, x, y, sc, true);
    e.chest = w.n % bossEvery == 3;
  }
}
