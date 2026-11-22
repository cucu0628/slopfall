import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:nightfall_sim/nightfall_sim.dart';

import 'canvas2d.dart';
import 'map.dart';

const double _range = 1500; // world units from the player to the minimap edge
const double _sample = 48; // world units per terrain sample
const double _margin = 400; // terrain is rendered a bit larger so it can scroll before a refresh

final Map<String, List<int>> _rgb = {
  for (final e in minimapRgb.entries)
    e.key: [
      (int.parse(e.value.substring(1), radix: 16) >> 16) & 255,
      (int.parse(e.value.substring(1), radix: 16) >> 8) & 255,
      int.parse(e.value.substring(1), radix: 16) & 255,
    ],
};

/// Top-right minimap: terrain, obstacles, enemies, bosses, pickups and players.
///
/// The terrain (thousands of biome samples) is re-sampled a slice per frame
/// while the old one is still shown, and drawn as one colour mesh; static
/// obstacles are recorded once per refresh. Nothing here stalls a frame.
class Minimap {
  ui.Vertices? _mesh;
  ui.Picture? _obstacles;
  double _obstaclesK = 0;
  double _tx = double.nan;
  double _ty = double.nan;
  int _seed = -1;
  _Sampling? _job;

  static const double _half = _range + _margin;
  static final int _n = ((_half * 2) / _sample).ceil();

  bool _needsRefresh(int seed, Player me) =>
      seed != _seed || !((me.x - _tx).abs() <= _margin * 0.5) || !((me.y - _ty).abs() <= _margin * 0.5);

  void _advance(int budget) {
    final j = _job!;
    final n = _n;
    while (budget-- > 0 && j.next < n * n) {
      final i = j.next % n, k = j.next ~/ n;
      final rgb = _rgb[biomeAt(j.seed, j.cx - _half + (i + 0.5) * _sample, j.cy - _half + (k + 0.5) * _sample)]!;
      j.colors[j.next] = (0xe6 << 24) | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2]; // 90 % opaque
      j.next++;
    }
    if (j.next < n * n) return;
    // done: a mesh around the sampled centre, in world units relative to it
    final pos = Float32List(n * n * 2);
    for (var k = 0; k < n; k++) {
      for (var i = 0; i < n; i++) {
        final v = k * n + i;
        pos[v * 2] = -_half + (i + 0.5) * _sample;
        pos[v * 2 + 1] = -_half + (k + 0.5) * _sample;
      }
    }
    final idx = Uint16List((n - 1) * (n - 1) * 6);
    var q = 0;
    for (var k = 0; k < n - 1; k++) {
      for (var i = 0; i < n - 1; i++) {
        final a = k * n + i, b = a + 1, c = a + n, d = c + 1;
        idx.setAll(q, [a, b, c, b, d, c]);
        q += 6;
      }
    }
    _mesh?.dispose();
    _mesh = ui.Vertices.raw(VertexMode.triangles, pos, colors: j.colors, indices: idx);
    _tx = j.cx;
    _ty = j.cy;
    _seed = j.seed;
    _obstacles?.dispose();
    _obstacles = null;
    _job = null;
  }

  /// Obstacles around the sampled centre as small squares (at least 1 minimap pixel).
  ui.Picture _recordObstacles(double k) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final paint = Paint()..color = const Color.fromRGBO(150, 155, 175, 0.55);
    final c0x = ((_tx - _half) / chunkSize).floor(), c1x = ((_tx + _half) / chunkSize).floor();
    final c0y = ((_ty - _half) / chunkSize).floor(), c1y = ((_ty + _half) / chunkSize).floor();
    for (var gx = c0x; gx <= c1x; gx++) {
      for (var gy = c0y; gy <= c1y; gy++) {
        for (final o in getChunk(_seed, gx, gy).obstacles) {
          final r = math.max(1 / k, o.r);
          c.drawRect(Rect.fromLTWH(o.x - _tx - r, o.y - _ty - r, r * 2, r * 2), paint);
        }
      }
    }
    return rec.endRecording();
  }

  void draw(Ctx2D ctx, GameState s, Player me, double x, double y, double size, double t) {
    final seed = s.mapSeed;
    if (_job == null && _needsRefresh(seed, me)) _job = _Sampling(seed, me.x, me.y, Int32List(_n * _n));
    if (_job != null) _advance(_mesh == null || _job!.seed != _seed ? _n * _n : 700);
    final k = size / (_range * 2); // world -> minimap pixels
    final cx = x + size / 2, cy = y + size / 2;
    (double, double) map(double wx, double wy) => (cx + (wx - me.x) * k, cy + (wy - me.y) * k);

    ctx.save();
    ctx.beginPath();
    ctx.roundRect(x, y, size, size, 10);
    ctx.clip();

    // terrain and obstacles, one draw call each
    if (k != _obstaclesK) {
      _obstacles?.dispose();
      _obstacles = null;
      _obstaclesK = k;
    }
    final mesh = _mesh;
    if (mesh != null) {
      final obstacles = _obstacles ??= _recordObstacles(k);
      ctx.canvas
        ..save()
        ..translate(cx + (_tx - me.x) * k, cy + (_ty - me.y) * k)
        ..scale(k)
        ..drawVertices(mesh, BlendMode.dst, Paint())
        ..drawPicture(obstacles)
        ..restore();
    }

    // view rectangle hint
    ctx.strokeStyle = 'rgba(255,255,255,0.12)';
    ctx.lineWidth = 1;
    ctx.strokeRect(cx - 700 * k, cy - 400 * k, 1400 * k, 800 * k);

    // pickups that matter
    for (final p in s.pickups) {
      if (p.kind == 'xp' || p.kind == 'coin') continue;
      final (px, py) = map(p.x, p.y);
      ctx.fillStyle = p.kind == 'chest' || p.kind == 'relic'
          ? '#ffd166'
          : p.kind == 'heal'
              ? '#ff4d6d'
              : p.kind == 'magnet'
                  ? '#5d9bff'
                  : '#ffb347';
      final r = p.kind == 'chest' || p.kind == 'relic' ? 3.5 : 2.5;
      ctx.fillRect(px - r, py - r, r * 2, r * 2);
    }

    // enemies
    for (final e in s.enemies) {
      if (e.boss) continue;
      final (ex, ey) = map(e.x, e.y);
      if (e.elite) {
        ctx.fillStyle = '#ffd166';
        ctx.fillRect(ex - 2.5, ey - 2.5, 5, 5);
      } else {
        ctx.fillStyle = 'rgba(255,80,90,0.85)';
        ctx.fillRect(ex - 1, ey - 1, 2, 2);
      }
    }
    for (final e in s.enemies) {
      if (!e.boss) continue;
      var (ex, ey) = map(e.x, e.y);
      ex = math.max(x + 6, math.min(x + size - 6, ex));
      ey = math.max(y + 6, math.min(y + size - 6, ey));
      ctx.fillStyle = '#ff2e88';
      ctx.beginPath();
      ctx.arc(ex, ey, 5 + math.sin(t * 6) * 1, 0, math.pi * 2);
      ctx.fill();
      ctx.strokeStyle = '#fff';
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    // players (local one is an arrow in the centre)
    for (final p in s.players) {
      if (p.dead || identical(p, me)) continue;
      final (px, py) = map(p.x, p.y);
      ctx.fillStyle = '#7ae7ff';
      ctx.beginPath();
      ctx.arc(px, py, 3.5, 0, math.pi * 2);
      ctx.fill();
    }
    final a = math.atan2(me.fy, me.fx);
    ctx.translate(cx, cy);
    ctx.rotate(a);
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.moveTo(7, 0);
    ctx.lineTo(-5, -4.5);
    ctx.lineTo(-2.5, 0);
    ctx.lineTo(-5, 4.5);
    ctx.closePath();
    ctx.fill();
    ctx.restore();

    ctx.strokeStyle = 'rgba(130,150,255,0.35)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.roundRect(x + 0.5, y + 0.5, size - 1, size - 1, 10);
    ctx.stroke();
  }

  void dispose() {
    _mesh?.dispose();
    _obstacles?.dispose();
  }
}

/// A terrain re-sample in progress.
class _Sampling {
  final int seed;
  final double cx, cy;
  final Int32List colors;
  int next = 0;
  _Sampling(this.seed, this.cx, this.cy, this.colors);
}
