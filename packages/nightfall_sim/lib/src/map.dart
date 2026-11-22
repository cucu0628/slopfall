// Procedural, deterministic world layout. The map is a pure function of
// (mapSeed, chunk coordinates), so it is never stored in GameState and every
// client/server derives exactly the same obstacles.

import 'fdlibm.dart';
import 'dart:math' as math;

import 'js.dart';
import 'types.dart';

const double chunkSize = 512;
const double _region = chunkSize * 3;
const double _spawnClear = 380;
const double _minGap = 40; // free space between obstacles, wider than the player

/// meadow | forest | graveyard | ruins
const List<String> biomes = ['meadow', 'forest', 'graveyard', 'ruins'];

/// tree | rock | pillar | tomb | deadtree | wall
class Obstacle {
  final double x, y, r;
  final String kind;
  final double v; // variant, 0..1
  const Obstacle(this.x, this.y, this.r, this.kind, this.v);
}

/// flowers | grass | mushrooms | puddle | bones | candles | torch | tiles | pebbles
class Decor {
  final double x, y;
  final String kind;
  final double v;
  final double s; // size
  const Decor(this.x, this.y, this.kind, this.v, this.s);
}

class Chunk {
  final int cx, cy;
  final String biome;
  final List<Obstacle> obstacles;
  final List<Decor> decor;
  const Chunk(this.cx, this.cy, this.biome, this.obstacles, this.decor);
}

/// 32-bit integer hash (unsigned result), identical to the TypeScript version.
int hash(int seed, int a, int b, [int c = 0]) {
  var h = i32(seed ^ imul(a, 0x27d4eb2d) ^ imul(b, 0x165667b1) ^ imul(c, 0x9e3779b1));
  h = imul(h ^ ushr(h, 15), 0x85ebca6b);
  h = imul(h ^ ushr(h, 13), 0xc2b2ae35);
  return u32(h ^ ushr(h, 16));
}

double Function() _makeRng(int h) {
  var s = i32(h);
  double next() {
    s = i32(s + 0x6d2b79f5);
    var t = u32(s);
    t = imul(t ^ ushr(t, 15), t | 1);
    t = u32(t ^ (t + imul(t ^ ushr(t, 7), t | 61)));
    return u32(t ^ ushr(t, 14)) / 4294967296;
  }

  return next;
}

/// Smooth value noise in [-1, 1].
double _valueNoise(int seed, double x, double y, int salt) {
  final x0 = x.floor(), y0 = y.floor();
  final fx = x - x0, fy = y - y0;
  final sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
  double v(int ix, int iy) => hash(seed, ix, iy, salt) / 2147483648 - 1;
  final a = v(x0, y0), b = v(x0 + 1, y0), c = v(x0, y0 + 1), d = v(x0 + 1, y0 + 1);
  return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy;
}

const double _warp = 260;

/// Biome at a world point: Voronoi regions with jittered centers, sampled
/// through a noise warp so the borders are wavy instead of straight lines.
String biomeAt(int seed, double x, double y) {
  x += (_valueNoise(seed, x / 420, y / 420, 21) + _valueNoise(seed, x / 160, y / 160, 22) * 0.35) * _warp;
  y += (_valueNoise(seed, x / 420, y / 420, 23) + _valueNoise(seed, x / 160, y / 160, 24) * 0.35) * _warp;
  final gx = (x / _region).floor(), gy = (y / _region).floor();
  var best = double.infinity;
  var bx = 0, by = 0;
  for (var dx = -1; dx <= 1; dx++) {
    for (var dy = -1; dy <= 1; dy++) {
      final cx = gx + dx, cy = gy + dy;
      final h = hash(seed, cx, cy, 11);
      final px = (cx + 0.15 + ((h & 0xffff) / 65536) * 0.7) * _region;
      final py = (cy + 0.15 + (ushr(h, 16) / 65536) * 0.7) * _region;
      final d = (px - x) * (px - x) + (py - y) * (py - y);
      if (d < best) {
        best = d;
        bx = cx;
        by = cy;
      }
    }
  }
  if (bx == 0 && by == 0) return 'meadow';
  return biomes[hash(seed, bx, by, 7) % biomes.length];
}

double _sq(double v) => v * v;

Chunk _generate(int seed, int cx, int cy) {
  final rnd = _makeRng(hash(seed, cx, cy, 1));
  double range(double a, double b) => a + rnd() * (b - a);
  int integer(int a, int b) => range(a.toDouble(), b + 1.0).floor();
  final ox = cx * chunkSize, oy = cy * chunkSize;
  final biome = biomeAt(seed, ox + chunkSize / 2, oy + chunkSize / 2);
  final obstacles = <Obstacle>[];
  final groups = <int>[];
  final decor = <Decor>[];
  var group = 0;

  // Obstacles stay away from chunk edges so neighbouring chunks never block each other.
  bool fits(double x, double y, double r, int g) {
    final m = r + _minGap / 2;
    if (x < ox + m || x > ox + chunkSize - m || y < oy + m || y > oy + chunkSize - m) return false;
    if (x * x + y * y < _sq(_spawnClear + r)) return false;
    for (var i = 0; i < obstacles.length; i++) {
      if (groups[i] == g) continue;
      final o = obstacles[i];
      if (_sq(o.x - x) + _sq(o.y - y) < _sq(o.r + r + _minGap)) return false;
    }
    return true;
  }

  bool add(double x, double y, double r, String kind, [int? g]) {
    final gg = g ?? ++group;
    if (!fits(x, y, r, gg)) return false;
    obstacles.add(Obstacle(x, y, r, kind, rnd()));
    groups.add(gg);
    return true;
  }

  void scatter(int n, String kind, double r0, double r1) {
    for (var i = 0; i < n; i++) {
      for (var tries = 0; tries < 6; tries++) {
        // argument order matters: x, y, then radius come off the RNG in that order
        final x = ox + rnd() * chunkSize;
        final y = oy + rnd() * chunkSize;
        if (add(x, y, range(r0, r1), kind)) break;
      }
    }
  }

  void deco(int n, String kind, double s0, double s1) {
    for (var i = 0; i < n; i++) {
      // keep decor fully inside its chunk so the pre-rendered ground never clips it
      final fx = rnd(), fy = rnd(), v = rnd(), sz = range(s0, s1), m = sz + 4;
      decor.add(Decor(ox + m + fx * (chunkSize - 2 * m), oy + m + fy * (chunkSize - 2 * m), kind, v, sz));
    }
  }

  switch (biome) {
    case 'meadow':
      scatter(integer(1, 3), 'rock', 16, 30);
      if (rnd() < 0.5) scatter(1, 'tree', 20, 26);
      deco(integer(5, 10), 'flowers', 10, 22);
      deco(integer(10, 18), 'grass', 6, 12);
      if (rnd() < 0.35) deco(1, 'puddle', 40, 70);
    case 'forest':
      scatter(integer(5, 8), 'tree', 18, 28);
      scatter(integer(0, 2), 'rock', 14, 22);
      deco(integer(3, 7), 'mushrooms', 6, 10);
      deco(integer(12, 20), 'grass', 6, 12);
    case 'graveyard':
      // rows of tombstones
      final rows = integer(1, 3);
      for (var r = 0; r < rows; r++) {
        final x0 = ox + range(60, chunkSize - 290);
        final y0 = oy + range(60, chunkSize - 60);
        final n = integer(3, 5), g = ++group;
        for (var i = 0; i < n; i++) {
          add(x0 + i * 58, y0 + range(-4, 4), 12, 'tomb', g);
        }
      }
      scatter(integer(0, 2), 'deadtree', 15, 18);
      deco(integer(1, 2), 'candles', 8, 12);
      deco(integer(3, 6), 'bones', 8, 14);
      if (rnd() < 0.5) deco(1, 'torch', 10, 10);
    case 'ruins':
      final pattern = rnd();
      final ccx = ox + chunkSize / 2 + range(-60, 60);
      final ccy = oy + chunkSize / 2 + range(-60, 60);
      if (pattern < 0.4) {
        // ring of pillars around a courtyard
        final n = integer(6, 8);
        final bigR = range(120, 160);
        final g = ++group;
        for (var i = 0; i < n; i++) {
          final a = (i * math.pi * 2) / n;
          add(ccx + jsCos(a) * bigR, ccy + jsSin(a) * bigR, 16, 'pillar', g);
        }
        decor.add(Decor(ccx, ccy, 'torch', rnd(), 12));
        decor.add(Decor(ccx, ccy, 'tiles', rnd(), bigR + 30));
      } else if (pattern < 0.8) {
        // broken L-shaped wall with a gap
        final g = ++group;
        final len = integer(6, 9), gapAt = integer(2, len - 2);
        final dir = rnd() < 0.5 ? 1 : -1;
        for (var i = 0; i < len; i++) {
          if (i == gapAt) continue;
          add(ccx - 110 + i * 24, ccy - 90, 14, 'wall', g);
        }
        for (var i = 1; i < 6; i++) {
          add(ccx - 110 + (dir > 0 ? 0 : (len - 1) * 24), ccy - 90 + i * 24, 14, 'wall', g);
        }
        decor.add(Decor(ccx, ccy - 20, 'tiles', rnd(), 140));
        if (rnd() < 0.7) {
          final tx = ccx + range(-60, 60);
          final ty = ccy + range(0, 60);
          decor.add(Decor(tx, ty, 'torch', rnd(), 12));
        }
      } else {
        scatter(integer(3, 6), 'pillar', 14, 18);
        deco(1, 'tiles', 90, 140);
      }
      scatter(integer(0, 2), 'rock', 12, 18);
      deco(integer(4, 8), 'pebbles', 4, 8);
  }
  return Chunk(cx, cy, biome, obstacles, decor);
}

final _cache = <int, Chunk>{};
int _cacheSeed = 0;

Chunk getChunk(int seed, int cx, int cy) {
  if (seed != _cacheSeed) {
    _cache.clear();
    _cacheSeed = seed;
  }
  final key = (cx + 32768) * 65536 + (cy + 32768);
  var c = _cache[key];
  if (c == null) {
    if (_cache.length > 4000) _cache.clear();
    c = _generate(seed, cx, cy);
    _cache[key] = c;
  }
  return c;
}

void forObstaclesNear(int seed, double x, double y, double r, void Function(Obstacle o) fn) {
  final x0 = ((x - r) / chunkSize).floor(), x1 = ((x + r) / chunkSize).floor();
  final y0 = ((y - r) / chunkSize).floor(), y1 = ((y + r) / chunkSize).floor();
  for (var cx = x0; cx <= x1; cx++) {
    for (var cy = y0; cy <= y1; cy++) {
      for (final o in getChunk(seed, cx, cy).obstacles) {
        final rr = o.r + r;
        if (_sq(o.x - x) + _sq(o.y - y) < rr * rr) fn(o);
      }
    }
  }
}

/// Pushes a circle out of any obstacle it overlaps. Returns the summed push
/// normal ((0, 0) when free) so movers can slide around obstacles.
(double, double) resolveObstacles(int seed, Pos e, double r) {
  var nx = 0.0, ny = 0.0;
  forObstaclesNear(seed, e.x, e.y, r, (o) {
    var dx = e.x - o.x, dy = e.y - o.y;
    var d = hypot(dx, dy);
    if (d < 0.001) {
      dx = 1;
      dy = 0;
      d = 1;
    }
    final push = o.r + r - d;
    if (push <= 0) return;
    e.x += (dx / d) * push;
    e.y += (dy / d) * push;
    nx += dx / d;
    ny += dy / d;
  });
  return (nx, ny);
}

bool isBlocked(int seed, double x, double y, double r) {
  var hit = false;
  forObstaclesNear(seed, x, y, r, (_) => hit = true);
  return hit;
}
