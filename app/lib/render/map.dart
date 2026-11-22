// Draws the procedural map: biome ground (pre-rendered per chunk), obstacles,
// tree canopies and animated decor (torches, candles).

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:nightfall_sim/nightfall_sim.dart';

import 'canvas2d.dart';
import 'sprites.dart';

const double _tau = math.pi * 2;
const int _chunk = 512;

class _Palette {
  final String base, blot, dark, detail;
  const _Palette(this.base, this.blot, this.dark, this.detail);
}

const Map<String, _Palette> _palette = {
  'meadow': _Palette('#15231a', '#1b2d1f', '#0f1913', '#2f5233'),
  'forest': _Palette('#0e1b13', '#122418', '#09130d', '#22412a'),
  'graveyard': _Palette('#1a1622', '#221c2c', '#110e17', '#3c3449'),
  'ruins': _Palette('#1a1b21', '#22232b', '#121318', '#3c3e49'),
};

const int _blob = 128;
const int _fieldStep = 32;

List<int> _hexRgb(String h) {
  final n = int.parse(h.substring(1), radix: 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

final Map<String, List<int>> _baseRgb = {for (final e in _palette.entries) e.key: _hexRgb(e.value.base)};

/// Brighter biome colours for the minimap.
const Map<String, String> minimapRgb = {
  'meadow': '#2b4a33',
  'forest': '#1d3d28',
  'graveyard': '#3a3046',
  'ruins': '#3a3b45',
};

/// GPU memory budget for cached ground chunks, in 512×512 (1×) chunks.
const int _cacheBudget = 48;
const int _maxNewPerFrame = 2;
/// Chunk bitmaps being made on the raster thread at once.
const int _maxRasterizing = 3;
const double _chunkD = 512;

int _chunkKey(int cx, int cy) => (cx + 32768) * 65536 + (cy + 32768);

/// Tiny decorative RNG (visual only).
double Function() rngFrom(int h) {
  var s = i32(h);
  return () {
    s = i32(imul(s ^ ushr(s, 15), 0x2c1b3c6d) + 0x9e3779b9);
    return u32(s ^ ushr(s, 13)) / 4294967296;
  };
}

/// One cached ground chunk: drawn from its vector recording right away and
/// replaced by a bitmap once the raster thread has finished it, so a new
/// chunk never stalls a frame.
class _GroundTile {
  ui.Picture? picture;
  Image2D? image;
  final double res;
  bool disposed = false;
  _GroundTile(this.picture, this.res);

  void dispose() {
    disposed = true;
    picture?.dispose();
    picture = null;
    image?.dispose();
    image = null;
  }
}

class WorldRenderer {
  // insertion order = LRU order
  final LinkedHashMap<int, _GroundTile> _ground = LinkedHashMap();
  int _seed = -1;
  double _res = 1; // pixels per world unit of the cached ground
  int _rasterizing = 0;
  Gradient2D? _vignette;

  /// Benchmarks: time (µs) spent recording new chunks / starting rasterization.
  Map<String, int>? profile;
  final Stopwatch _sw = Stopwatch();
  String _vigSize = '';

  // -------------------------------------------------------------- ground

  /// The chunk's ground, recorded in chunk-local world units (0..512).
  ui.Picture _recordChunk(int seed, int cx, int cy) {
    final ox = cx * _chunk, oy = cy * _chunk;
    final chunk = getChunk(seed, cx, cy);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, _chunkD, _chunkD));
    // half a unit of overlap with the neighbours, no anti-aliased edge: no seams
    canvas.clipRect(const Rect.fromLTWH(-0.5, -0.5, _chunkD + 1, _chunkD + 1), doAntiAlias: false);
    final g = Ctx2D(canvas);

    // Base colour field: biome colours sampled on a world-aligned grid (the
    // samples on a chunk edge are shared with the neighbour) and blended
    // across a triangle mesh, so there are no seams and biomes blend softly.
    const n = _chunk ~/ _fieldStep + 1;
    final pos = Float32List(n * n * 2);
    final cols = Int32List(n * n);
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final k = j * n + i;
        pos[k * 2] = (i * _fieldStep).toDouble();
        pos[k * 2 + 1] = (j * _fieldStep).toDouble();
        final rgb = _baseRgb[biomeAt(seed, (ox + i * _fieldStep).toDouble(), (oy + j * _fieldStep).toDouble())]!;
        cols[k] = (0xff << 24) | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2];
      }
    }
    final idx = Uint16List((n - 1) * (n - 1) * 6);
    var q = 0;
    for (var j = 0; j < n - 1; j++) {
      for (var i = 0; i < n - 1; i++) {
        final a = j * n + i, b = a + 1, c = a + n, d = c + 1;
        idx.setAll(q, [a, b, c, b, d, c]);
        q += 6;
      }
    }
    final field = ui.Vertices.raw(VertexMode.triangles, pos, colors: cols, indices: idx);
    canvas.drawVertices(field, BlendMode.dst, Paint());
    field.dispose();

    // Soft detail blobs on a global grid, coloured by the biome at their
    // centre, so they continue seamlessly across chunk edges.
    final gx0 = (ox / _blob).floor() - 1, gx1 = ((ox + _chunk) / _blob).floor() + 1;
    final gy0 = (oy / _blob).floor() - 1, gy1 = ((oy + _chunk) / _blob).floor() + 1;
    for (var gx = gx0; gx <= gx1; gx++) {
      for (var gy = gy0; gy <= gy1; gy++) {
        final r = rngFrom(hash(seed, gx, gy, 4));
        final bx = (gx + r()) * _blob, by = (gy + r()) * _blob;
        final rad = 30 + r() * 50;
        final pal = _palette[biomeAt(seed, bx, by)]!;
        final col = r() < 0.5 ? pal.blot : pal.dark;
        final lx = bx - ox, ly = by - oy;
        if (lx < -rad || ly < -rad || lx > _chunk + rad || ly > _chunk + rad) continue;
        final grad = g.createRadialGradient(lx, ly, rad * 0.2, lx, ly, rad);
        grad.addColorStop(0, col);
        grad.addColorStop(1, '${col}00');
        g.fillStyle = grad;
        g.globalAlpha = 0.6;
        g.beginPath();
        g.arc(lx, ly, rad, 0, _tau);
        g.fill();
      }
    }
    g.globalAlpha = 1;

    for (final d in chunk.decor) {
      _drawGroundDecor(g, d, d.x - ox, d.y - oy, _palette[chunk.biome]!);
    }
    g.dispose();
    return rec.endRecording();
  }

  /// Turns the tile's recording into a bitmap on the raster thread.
  void _rasterize(_GroundTile t) {
    final pic = t.picture;
    if (pic == null) return;
    final px = (_chunk * t.res).round();
    final rec = ui.PictureRecorder();
    Canvas(rec)
      ..scale(t.res)
      ..drawPicture(pic);
    final scaled = rec.endRecording();
    _rasterizing++;
    scaled.toImage(px, px).then((img) {
      scaled.dispose();
      _rasterizing--;
      if (t.disposed) {
        img.dispose();
        return;
      }
      t.image = Image2D(img);
      t.picture?.dispose();
      t.picture = null;
    }, onError: (Object _) {
      scaled.dispose();
      _rasterizing--;
    });
  }

  /// [pixelScale] is screen pixels per world unit (view scale × device pixel ratio).
  void drawGround(Ctx2D ctx, int seed, double minX, double minY, double maxX, double maxY, double pixelScale, [double maxRes = 2]) {
    // cache the ground at (about) the resolution it is shown at, up to maxRes
    final res = (pixelScale * 2).ceil().clamp(2, (maxRes * 2).round()) / 2;
    if (seed != _seed || res != _res) {
      for (final t in _ground.values) {
        t.dispose();
      }
      _ground.clear();
      _seed = seed;
      _res = res;
    }
    final visible = (((maxX - minX) / _chunk).ceil() + 1) * (((maxY - minY) / _chunk).ceil() + 1);
    final maxCached = math.max(visible + 8, _cacheBudget ~/ (res * res));
    // bicubic only when the bitmap is magnified; otherwise bilinear + mipmaps
    ctx.imageSmoothingQuality = pixelScale > res ? 'high' : 'medium';
    var created = 0;
    for (var cx = (minX / _chunk).floor(); cx * _chunk < maxX; cx++) {
      for (var cy = (minY / _chunk).floor(); cy * _chunk < maxY; cy++) {
        final key = _chunkKey(cx, cy);
        var t = _ground.remove(key);
        if (t != null) {
          _ground[key] = t; // refresh LRU order
        } else if (created < _maxNewPerFrame) {
          created++;
          _sw
            ..reset()
            ..start();
          t = _GroundTile(_recordChunk(seed, cx, cy), res);
          final p = profile;
          if (p != null) p['chunk record'] = (p['chunk record'] ?? 0) + _sw.elapsedMicroseconds;
          _ground[key] = t;
          while (_ground.length > maxCached) {
            _ground.remove(_ground.keys.first)?.dispose();
          }
        }
        if (t != null && t.image == null && t.picture != null && _rasterizing < _maxRasterizing) {
          _sw
            ..reset()
            ..start();
          _rasterize(t);
          final p = profile;
          if (p != null) p['chunk raster start'] = (p['chunk raster start'] ?? 0) + _sw.elapsedMicroseconds;
        }
        final img = t?.image, pic = t?.picture;
        if (img != null) {
          ctx.drawImage(img, cx * _chunk, cy * _chunk, _chunk + 0.5, _chunk + 0.5);
        } else if (pic != null) {
          ctx.canvas
            ..save()
            ..translate((cx * _chunk).toDouble(), (cy * _chunk).toDouble())
            ..drawPicture(pic)
            ..restore();
        } else {
          ctx.fillStyle = _palette[biomeAt(seed, (cx + 0.5) * _chunk, (cy + 0.5) * _chunk)]!.base;
          ctx.fillRect(cx * _chunk, cy * _chunk, _chunk, _chunk);
        }
      }
    }
    ctx.imageSmoothingQuality = 'medium';
  }

  void _drawGroundDecor(Ctx2D g, Decor d, double x, double y, _Palette pal) {
    final r = rngFrom((d.v * 1e9).floor());
    switch (d.kind) {
      case 'grass':
        g.strokeStyle = pal.detail;
        g.lineWidth = 1.5;
        g.beginPath();
        for (var i = 0; i < 4; i++) {
          final bx = x + (r() - 0.5) * d.s * 1.5;
          g.moveTo(bx, y);
          g.lineTo(bx + (r() - 0.5) * 5, y - d.s * (0.6 + r() * 0.6));
        }
        g.stroke();
      case 'flowers':
        const colors = ['#c06a8e', '#c9b45a', '#7d8fd6', '#d0d0e0'];
        for (var i = 0; i < 5; i++) {
          g.fillStyle = colors[(r() * colors.length).floor()];
          g.globalAlpha = 0.55;
          g.beginPath();
          final fx = x + (r() - 0.5) * d.s * 2;
          final fy = y + (r() - 0.5) * d.s * 2;
          g.arc(fx, fy, 1.5 + r() * 1.5, 0, _tau);
          g.fill();
        }
        g.globalAlpha = 1;
      case 'mushrooms':
        for (var i = 0; i < 3; i++) {
          final mx = x + (r() - 0.5) * 18, my = y + (r() - 0.5) * 12, s = d.s * (0.4 + r() * 0.4);
          g.fillStyle = '#d8cfc0';
          g.fillRect(mx - 1, my, 2, s * 0.6);
          g.fillStyle = r() < 0.5 ? '#9b3b3b' : '#6a5ab8';
          g.beginPath();
          g.ellipse(mx, my, s * 0.6, s * 0.35, 0, math.pi, _tau);
          g.fill();
        }
      case 'puddle':
        g.fillStyle = 'rgba(40,60,90,0.35)';
        g.beginPath();
        g.ellipse(x, y, d.s, d.s * 0.55, d.v * 3, 0, _tau);
        g.fill();
        g.strokeStyle = 'rgba(140,170,220,0.12)';
        g.lineWidth = 2;
        g.stroke();
      case 'bones':
        g.strokeStyle = 'rgba(210,200,180,0.35)';
        g.lineWidth = 2.5;
        g.lineCap = 'round';
        for (var i = 0; i < 2; i++) {
          final a = r() * _tau;
          g.beginPath();
          g.moveTo(x - math.cos(a) * d.s * 0.5, y - math.sin(a) * d.s * 0.5);
          g.lineTo(x + math.cos(a) * d.s * 0.5, y + math.sin(a) * d.s * 0.5);
          g.stroke();
        }
        g.fillStyle = 'rgba(210,200,180,0.3)';
        g.beginPath();
        g.arc(x + d.s * 0.6, y - d.s * 0.3, d.s * 0.25, 0, _tau);
        g.fill();
      case 'tiles':
        const t = 34.0;
        final n = (d.s / t).ceil();
        for (var i = -n; i <= n; i++) {
          for (var j = -n; j <= n; j++) {
            final tx = x + i * t, ty = y + j * t;
            final dist = hypot(i * t, j * t);
            if (dist > d.s || r() < 0.18 + (dist / d.s) * 0.5) continue;
            g.fillStyle = r() < 0.5 ? 'rgba(90,92,108,0.28)' : 'rgba(70,72,88,0.3)';
            g.fillRect(tx - t / 2 + 1, ty - t / 2 + 1, t - 2, t - 2);
          }
        }
      case 'pebbles':
        g.fillStyle = 'rgba(120,124,140,0.3)';
        for (var i = 0; i < 4; i++) {
          g.beginPath();
          final px = x + (r() - 0.5) * 20;
          final py = y + (r() - 0.5) * 14;
          g.arc(px, py, d.s * (0.3 + r() * 0.3), 0, _tau);
          g.fill();
        }
      default:
        break;
    }
  }

  // -------------------------------------------------------------- obstacles

  void _forVisible(int seed, double minX, double minY, double maxX, double maxY, void Function(Obstacle o) fn) {
    for (var cx = ((minX - 80) / _chunk).floor(); cx * _chunk < maxX + 80; cx++) {
      for (var cy = ((minY - 80) / _chunk).floor(); cy * _chunk < maxY + 80; cy++) {
        for (final o in getChunk(seed, cx, cy).obstacles) {
          if (o.x + o.r * 2 < minX || o.x - o.r * 2 > maxX || o.y + o.r * 2 < minY || o.y - o.r * 2 > maxY) continue;
          fn(o);
        }
      }
    }
  }

  /// Obstacle bodies, drawn below entities.
  void drawObstacles(Ctx2D ctx, int seed, double minX, double minY, double maxX, double maxY) {
    _forVisible(seed, minX, minY, maxX, maxY, (o) {
      ctx.fillStyle = 'rgba(0,0,0,0.35)';
      ctx.beginPath();
      ctx.ellipse(o.x + o.r * 0.25, o.y + o.r * 0.45, o.r * 1.05, o.r * 0.6, 0, 0, _tau);
      ctx.fill();
      switch (o.kind) {
        case 'tree':
          ctx.fillStyle = '#3b2a1e';
          ctx.beginPath();
          ctx.arc(o.x, o.y, o.r * 0.5, 0, _tau);
          ctx.fill();
        case 'deadtree':
          ctx.strokeStyle = '#3a3030';
          ctx.lineCap = 'round';
          ctx.lineWidth = 6;
          ctx.beginPath();
          ctx.arc(o.x, o.y, o.r * 0.4, 0, _tau);
          ctx.stroke();
          final r = rngFrom((o.v * 1e9).floor());
          ctx.lineWidth = 3;
          ctx.beginPath();
          for (var i = 0; i < 5; i++) {
            final a = r() * _tau, l = o.r * (1.2 + r() * 0.9);
            ctx.moveTo(o.x, o.y);
            final mx = o.x + math.cos(a) * l * 0.6, my = o.y + math.sin(a) * l * 0.6;
            ctx.lineTo(mx, my);
            ctx.lineTo(mx + math.cos(a + 0.6) * l * 0.4, my + math.sin(a + 0.6) * l * 0.4);
            ctx.moveTo(mx, my);
            ctx.lineTo(mx + math.cos(a - 0.5) * l * 0.35, my + math.sin(a - 0.5) * l * 0.35);
          }
          ctx.stroke();
        case 'rock':
          final r = rngFrom((o.v * 1e9).floor());
          final pts = <double>[];
          for (var i = 0; i < 8; i++) {
            final a = (i * _tau) / 8 + r() * 0.3, rr = o.r * (0.85 + r() * 0.3);
            pts.addAll([o.x + math.cos(a) * rr, o.y + math.sin(a) * rr]);
          }
          ctx.fillStyle = '#454955';
          ctx.beginPath();
          for (var i = 0; i < pts.length; i += 2) {
            ctx.lineTo(pts[i], pts[i + 1]);
          }
          ctx.closePath();
          ctx.fill();
          ctx.fillStyle = '#5a5f6d';
          ctx.beginPath();
          ctx.ellipse(o.x - o.r * 0.15, o.y - o.r * 0.25, o.r * 0.6, o.r * 0.4, -0.3, 0, _tau);
          ctx.fill();
          ctx.strokeStyle = '#2b2e36';
          ctx.lineWidth = 2;
          ctx.beginPath();
          for (var i = 0; i < pts.length; i += 2) {
            ctx.lineTo(pts[i], pts[i + 1]);
          }
          ctx.closePath();
          ctx.stroke();
        case 'pillar':
          final broken = o.v < 0.3;
          ctx.fillStyle = '#4f4d5b';
          ctx.beginPath();
          ctx.arc(o.x, o.y, o.r, 0, _tau);
          ctx.fill();
          ctx.strokeStyle = '#2f2e38';
          ctx.lineWidth = 2;
          ctx.stroke();
          ctx.fillStyle = broken ? '#3d3c47' : '#6a6878';
          ctx.beginPath();
          ctx.arc(o.x - 2, o.y - 3, o.r * 0.72, 0, _tau);
          ctx.fill();
          ctx.strokeStyle = 'rgba(30,30,40,0.6)';
          ctx.lineWidth = 1.5;
          ctx.beginPath();
          ctx.arc(o.x - 2, o.y - 3, o.r * 0.45, 0, _tau);
          ctx.stroke();
          if (broken) {
            ctx.fillStyle = '#56545f';
            ctx.fillRect(o.x + o.r * 0.8, o.y + o.r * 0.3, 7, 5);
            ctx.fillRect(o.x - o.r * 1.2, o.y + o.r * 0.6, 5, 4);
          }
        case 'wall':
          final s = o.r * 2;
          ctx.fillStyle = '#4a4955';
          ctx.fillRect(o.x - s / 2, o.y - s / 2, s, s);
          ctx.fillStyle = '#5e5d6b';
          ctx.fillRect(o.x - s / 2, o.y - s / 2, s, s * 0.35);
          ctx.strokeStyle = '#2c2b34';
          ctx.lineWidth = 1.5;
          ctx.beginPath();
          ctx.moveTo(o.x - s / 2, o.y);
          ctx.lineTo(o.x + s / 2, o.y);
          ctx.moveTo(o.x + (o.v - 0.5) * s * 0.6, o.y);
          ctx.lineTo(o.x + (o.v - 0.5) * s * 0.6, o.y + s / 2);
          ctx.stroke();
        case 'tomb':
          ctx.fillStyle = 'rgba(60,45,40,0.6)';
          ctx.beginPath();
          ctx.ellipse(o.x, o.y + 10, 14, 7, 0, 0, _tau);
          ctx.fill();
          ctx.fillStyle = '#5b5866';
          ctx.beginPath();
          ctx.moveTo(o.x - 10, o.y + 8);
          ctx.lineTo(o.x - 10, o.y - 10);
          ctx.arc(o.x, o.y - 10, 10, math.pi, _tau);
          ctx.lineTo(o.x + 10, o.y + 8);
          ctx.closePath();
          ctx.fill();
          ctx.strokeStyle = '#2f2d37';
          ctx.lineWidth = 2;
          ctx.stroke();
          ctx.strokeStyle = '#3a3844';
          ctx.beginPath();
          ctx.moveTo(o.x, o.y - 14);
          ctx.lineTo(o.x, o.y);
          ctx.moveTo(o.x - 5, o.y - 9);
          ctx.lineTo(o.x + 5, o.y - 9);
          ctx.stroke();
      }
    });
  }

  /// Tree canopies above entities; they fade when the player walks under them.
  void drawCanopies(Ctx2D ctx, int seed, double minX, double minY, double maxX, double maxY, double px, double py, double t) {
    _forVisible(seed, minX, minY, maxX, maxY, (o) {
      if (o.kind != 'tree') return;
      final bigR = o.r * 1.7;
      final under = (px - o.x) * (px - o.x) + (py - o.y) * (py - o.y) < bigR * bigR;
      ctx.globalAlpha = under ? 0.35 : 0.95;
      final sway = math.sin(t * 0.8 + o.v * 10) * 1.5;
      ctx.fillStyle = '#163222';
      ctx.beginPath();
      ctx.arc(o.x + sway, o.y - o.r * 0.3, bigR, 0, _tau);
      ctx.fill();
      ctx.fillStyle = '#1f4430';
      ctx.beginPath();
      ctx.arc(o.x - o.r * 0.35 + sway, o.y - o.r * 0.6, bigR * 0.68, 0, _tau);
      ctx.arc(o.x + o.r * 0.45 + sway, o.y - o.r * 0.2, bigR * 0.55, 0, _tau);
      ctx.fill();
      ctx.fillStyle = '#2a5a3c';
      ctx.beginPath();
      ctx.arc(o.x - o.r * 0.5 + sway, o.y - o.r * 0.85, bigR * 0.32, 0, _tau);
      ctx.fill();
    });
    ctx.globalAlpha = 1;
  }

  // -------------------------------------------------------------- lights

  void _forVisibleDecor(int seed, double minX, double minY, double maxX, double maxY, void Function(Decor d) fn) {
    for (var cx = (minX / _chunk).floor(); cx * _chunk < maxX; cx++) {
      for (var cy = (minY / _chunk).floor(); cy * _chunk < maxY; cy++) {
        for (final d in getChunk(seed, cx, cy).decor) {
          if (d.kind == 'torch' || d.kind == 'candles') fn(d);
        }
      }
    }
  }

  /// Torch and candle bodies (normal blending).
  void drawLights(Ctx2D ctx, int seed, double minX, double minY, double maxX, double maxY, double t) {
    _forVisibleDecor(seed, minX, minY, maxX, maxY, (d) {
      final flick = math.sin(t * 13 + d.v * 50) * 1.5 + math.sin(t * 7.3 + d.v * 20);
      if (d.kind == 'torch') {
        ctx.fillStyle = '#3a2a1e';
        ctx.fillRect(d.x - 3, d.y - 18, 6, 22);
        ctx.fillStyle = '#5c5c66';
        ctx.fillRect(d.x - 7, d.y - 22, 14, 5);
        ctx.fillStyle = '#ffb347';
        ctx.beginPath();
        ctx.ellipse(d.x, d.y - 28, 5 + flick * 0.3, 9 + flick, 0, 0, _tau);
        ctx.fill();
        ctx.fillStyle = '#fff1c2';
        ctx.beginPath();
        ctx.ellipse(d.x, d.y - 26, 2.5, 5, 0, 0, _tau);
        ctx.fill();
      } else {
        for (var i = 0; i < 3; i++) {
          final x = d.x + (i - 1) * 9, y = d.y + (i % 2) * 5;
          ctx.fillStyle = '#e8e0cc';
          ctx.fillRect(x - 2, y - 8, 4, 8);
          ctx.fillStyle = '#ffd166';
          ctx.beginPath();
          ctx.ellipse(x, y - 11, 2, 3.5 + flick * 0.3, 0, 0, _tau);
          ctx.fill();
        }
      }
    });
  }

  /// Additive light glows. Caller sets 'lighter' compositing.
  void drawLightGlows(Ctx2D ctx, int seed, double minX, double minY, double maxX, double maxY, double t) {
    _forVisibleDecor(seed, minX, minY, maxX, maxY, (d) {
      final flick = 0.85 + math.sin(t * 11 + d.v * 40) * 0.08 + math.sin(t * 5.1 + d.v * 9) * 0.07;
      if (d.kind == 'torch') {
        glow(ctx, '#ff9a3d', d.x, d.y - 24, 130 * flick, 0.45);
      } else {
        glow(ctx, '#ffcf6b', d.x, d.y - 8, 60 * flick, 0.4);
      }
    });
  }

  /// Night vignette in screen space.
  void drawVignette(Ctx2D ctx, double w, double h) {
    final key = '${w}x$h';
    if (_vignette == null || _vigSize != key) {
      final g = ctx.createRadialGradient(w / 2, h / 2, math.min(w, h) * 0.35, w / 2, h / 2, hypot(w, h) * 0.6);
      g.addColorStop(0, 'rgba(3,4,12,0)');
      g.addColorStop(1, 'rgba(3,4,12,0.62)');
      _vignette = g;
      _vigSize = key;
    }
    ctx.fillStyle = _vignette!;
    ctx.fillRect(0, 0, w, h);
  }

  void dispose() {
    for (final t in _ground.values) {
      t.dispose();
    }
    _ground.clear();
  }
}
