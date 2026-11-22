import 'dart:math' as math;
import 'dart:typed_data';

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
class Minimap {
  Image2D? _terrain;
  double _tx = double.nan;
  double _ty = double.nan;
  int _seed = -1;

  void _refreshTerrain(int seed, double cx, double cy) {
    const half = _range + _margin;
    final n = ((half * 2) / _sample).ceil();
    final px = Uint8List(n * n * 4);
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final rgb = _rgb[biomeAt(seed, cx - half + (i + 0.5) * _sample, cy - half + (j + 0.5) * _sample)]!;
        final o = (j * n + i) * 4;
        px[o] = rgb[0];
        px[o + 1] = rgb[1];
        px[o + 2] = rgb[2];
        px[o + 3] = 255;
      }
    }
    _terrain?.dispose();
    _terrain = imageFromPixels(n, n, px);
    _tx = cx;
    _ty = cy;
    _seed = seed;
  }

  void draw(Ctx2D ctx, GameState s, Player me, double x, double y, double size, double t) {
    final seed = s.mapSeed;
    if (seed != _seed || !((me.x - _tx).abs() <= _margin * 0.7) || !((me.y - _ty).abs() <= _margin * 0.7)) {
      _refreshTerrain(seed, me.x, me.y);
    }
    final k = size / (_range * 2); // world -> minimap pixels
    final cx = x + size / 2, cy = y + size / 2;
    (double, double) map(double wx, double wy) => (cx + (wx - me.x) * k, cy + (wy - me.y) * k);

    ctx.save();
    ctx.beginPath();
    ctx.roundRect(x, y, size, size, 10);
    ctx.clip();

    // terrain
    const half = _range + _margin;
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    ctx.globalAlpha = 0.9;
    final (tx0, ty0) = map(_tx - half, _ty - half);
    ctx.drawImage(_terrain!, tx0, ty0, half * 2 * k, half * 2 * k);
    ctx.globalAlpha = 1;

    // obstacles
    ctx.fillStyle = 'rgba(150,155,175,0.55)';
    final c0x = ((me.x - _range) / chunkSize).floor(), c1x = ((me.x + _range) / chunkSize).floor();
    final c0y = ((me.y - _range) / chunkSize).floor(), c1y = ((me.y + _range) / chunkSize).floor();
    for (var gx = c0x; gx <= c1x; gx++) {
      for (var gy = c0y; gy <= c1y; gy++) {
        for (final o in getChunk(seed, gx, gy).obstacles) {
          final (ox, oy) = map(o.x, o.y);
          final r = math.max(1.0, o.r * k);
          ctx.fillRect(ox - r, oy - r, r * 2, r * 2);
        }
      }
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

  void dispose() => _terrain?.dispose();
}
