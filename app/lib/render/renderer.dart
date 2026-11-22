// Draws a GameState: world, entities, effects and the HUD, in that order.

import 'dart:math' as math;
import 'dart:ui' show Canvas;

import 'package:nightfall_sim/nightfall_sim.dart';

import 'canvas2d.dart';
import 'effects.dart';
import 'entities/allies.dart';
import 'entities/enemies.dart';
import 'entities/hostile.dart';
import 'entities/pickups.dart';
import 'entities/projectiles.dart';
import 'entities/shared.dart' show rnd;
import 'entities/zones.dart';
import 'heroes/index.dart';
import 'hud.dart';
import 'map.dart';
import 'minimap.dart';
import 'sprites.dart';

const double _viewW = 1400;
const double _viewH = 800;
const double _viewWPortrait = 1300;

double _lerp(double a, double b, double t) => a + (b - a) * t;

class AimPreview {
  final double x, y, r;
  const AimPreview(this.x, this.y, this.r);
}

class Renderer {
  double w = 0;
  double h = 0;
  double scale = 1;
  double camX = 0;
  double camY = 0;
  final WorldRenderer _world = WorldRenderer();
  final Minimap minimap = Minimap();

  /// Device pixels per logical pixel (set by the game view).
  double dpr = 1;

  /// Highest resolution (pixels per world unit) of the cached ground; phones
  /// use less to spare GPU memory and fill rate.
  double maxGroundRes = 2;

  /// Phones/tablets: HUD laid out around the touch controls.
  bool touchMode = false;

  /// When set, [draw] adds the time spent per phase (µs) here (benchmarks).
  Map<String, int>? profile;

  /// Worst single-frame time per phase (µs), alongside [profile].
  final Map<String, int> profileWorst = {};
  final Stopwatch _sw = Stopwatch();
  void _mark(String phase) {
    final p = profile;
    if (p == null) return;
    final us = _sw.elapsedMicroseconds;
    p[phase] = (p[phase] ?? 0) + us;
    if (us > (profileWorst[phase] ?? 0)) profileWorst[phase] = us;
    _sw.reset();
  }

  /// Touch aiming: where the ability will land (world coords).
  AimPreview? aimPreview;

  /// Logical size of the view (Flutter takes care of the device pixel ratio).
  void resize(double width, double height) {
    w = width;
    h = height;
    // portrait screens (phones) get a tall view instead of a wide one
    scale = h > w ? math.max(w / _viewH, h / _viewWPortrait) : math.max(w / _viewW, h / _viewH);
  }

  /// Screen position (logical px) of a world point.
  (double, double) screenOf(double wx, double wy) => ((wx - camX) * scale + w / 2, (wy - camY) * scale + h / 2);

  void draw(Canvas canvas, GameState s, String localId, double alpha, Effects fx, {bool hud = true}) {
    final ctx = Ctx2D(canvas);
    if (profile != null) _sw..reset()..start();
    final t = fx.time;
    final me = s.players.firstWhere((p) => p.id == localId, orElse: () => s.players[0]);
    camX = _lerp(me.px, me.x, alpha);
    camY = _lerp(me.py, me.y, alpha);
    final shx = (rnd() - 0.5) * fx.shake, shy = (rnd() - 0.5) * fx.shake;

    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.fillStyle = '#0b0d17';
    ctx.fillRect(0, 0, w, h);

    final sc = scale;
    ctx.setTransform(sc, 0, 0, sc, w / 2 - (camX + shx) * sc, h / 2 - (camY + shy) * sc);

    final hw = w / 2 / scale + 80, hh = h / 2 / scale + 80;
    final minX = camX - hw, maxX = camX + hw, minY = camY - hh, maxY = camY + hh;
    bool vis(double x, double y, [double m = 0]) => x > minX - m && x < maxX + m && y > minY - m && y < maxY + m;

    final seed = s.mapSeed;
    _mark('setup');
    _world.profile = profile;
    _world.drawGround(ctx, seed, minX, minY, maxX, maxY, scale * dpr, maxGroundRes);
    _mark('ground');

    // ground telegraphs
    for (final hz in s.hazards) {
      if (hz.kind == 'slam' || hz.kind == 'skyfall' || hz.kind == 'coin') drawHazard(ctx, hz, t);
    }
    for (final z in s.zones) {
      if (z.kind == 'meteor' || z.kind == 'rain') drawZone(ctx, z, t);
    }

    // auras
    for (final p in s.players) {
      if (p.dead) continue;
      for (final wp in p.weapons) {
        if (wp.id != 'aura') continue;
        final x = _lerp(p.px, p.x, alpha), y = _lerp(p.py, p.y, alpha);
        final col = wp.evolved ? '#fff2b0' : '#ffe08a';
        ctx.fillStyle = rgba(col, 0.08 + math.sin(t * 3) * 0.02);
        ctx.beginPath();
        ctx.arc(x, y, wp.r, 0, math.pi * 2);
        ctx.fill();
        ctx.strokeStyle = rgba(col, 0.35);
        ctx.lineWidth = 2;
        ctx.setLineDash([10, 8]);
        ctx.lineDashOffset = -t * 30;
        ctx.stroke();
        ctx.setLineDash([]);
      }
    }

    _world.drawObstacles(ctx, seed, minX, minY, maxX, maxY);
    final a = aimPreview;
    if (a != null) {
      ctx.fillStyle = 'rgba(255,140,60,0.12)';
      ctx.beginPath();
      ctx.arc(a.x, a.y, a.r, 0, math.pi * 2);
      ctx.fill();
      ctx.strokeStyle = 'rgba(255,190,110,0.9)';
      ctx.lineWidth = 3;
      ctx.setLineDash([12, 8]);
      ctx.lineDashOffset = -t * 40;
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.beginPath();
      ctx.moveTo(a.x - 14, a.y);
      ctx.lineTo(a.x + 14, a.y);
      ctx.moveTo(a.x, a.y - 14);
      ctx.lineTo(a.x, a.y + 14);
      ctx.stroke();
    }
    _world.drawLights(ctx, seed, minX, minY, maxX, maxY, t);

    // dash afterimages
    for (final g in fx.ghosts) {
      ctx.globalAlpha = (g.life / g.max) * 0.45;
      ctx.fillStyle = g.color;
      ctx.beginPath();
      ctx.arc(g.x, g.y, g.r, 0, math.pi * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;

    _mark('telegraphs/obstacles/lights');
    // glow under pickups and enemies
    ctx.globalCompositeOperation = 'lighter';
    _world.drawLightGlows(ctx, seed, minX, minY, maxX, maxY, t);
    for (final pk in s.pickups) {
      final x = _lerp(pk.px, pk.x, alpha), y = _lerp(pk.py, pk.y, alpha);
      if (!vis(x, y)) continue;
      glow(ctx, pickupColor(pk), x, y, pk.kind == 'chest' || pk.kind == 'relic' ? 50 : (pk.kind == 'xp' ? 16 : 26), 0.6);
    }
    for (final e in s.enemies) {
      if (!(e.boss || e.elite || e.type == 'exploder' || e.type == 'shaman')) continue;
      final x = _lerp(e.px, e.x, alpha), y = _lerp(e.py, e.y, alpha);
      if (!vis(x, y, e.radius)) continue;
      glow(ctx, e.elite ? '#ffd166' : enemyColor(e), x, y, e.radius * 2.6, e.boss ? 0.5 : 0.4);
    }
    for (final p in s.players) {
      if (p.dead) continue;
      glow(ctx, characterDefs[p.charId]!.accent, _lerp(p.px, p.x, alpha), _lerp(p.py, p.y, alpha), 46, 0.35);
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';

    for (final pk in s.pickups) {
      final x = _lerp(pk.px, pk.x, alpha), y = _lerp(pk.py, pk.y, alpha);
      if (vis(x, y)) drawPickup(ctx, pk, x, y, t);
    }
    for (final z in s.zones) {
      if (z.kind == 'nova' || z.kind == 'nova2' || z.kind == 'nova3' || z.kind == 'bash' || z.kind == 'raise') drawZone(ctx, z, t);
    }
    for (final tu in s.turrets) {
      if (vis(tu.x, tu.y)) drawTurret(ctx, tu, t);
    }

    _mark('glows+pickups+zones');
    // enemies, nearest local player provides the facing direction
    for (final e in s.enemies) {
      final x = _lerp(e.px, e.x, alpha), y = _lerp(e.py, e.y, alpha);
      if (!vis(x, y, e.radius * 2)) continue;
      final dx = me.x - x, dy = me.y - y;
      var d = hypot(dx, dy);
      if (d == 0) d = 1;
      drawEnemy(ctx, e, x, y, t + e.id * 0.1, dx / d, dy / d);
    }
    for (final m in s.minions) {
      drawMinion(ctx, m, _lerp(m.px, m.x, alpha), _lerp(m.py, m.y, alpha), t);
    }

    for (final p in s.players) {
      if (p.dead) continue;
      final x = _lerp(p.px, p.x, alpha), y = _lerp(p.py, p.y, alpha);
      drawPlayer(ctx, p, x, y, t);
      _drawPlayerBar(ctx, p, x, y);
    }

    _mark('enemies+players');
    _world.drawCanopies(ctx, seed, minX, minY, maxX, maxY, camX, camY, t);

    for (final z in s.zones) {
      if (z.kind == 'slash' || z.kind == 'slash2' || z.kind == 'slash3' || z.kind == 'bolt') drawZone(ctx, z, t);
    }

    for (final pr in s.projectiles) {
      final x = _lerp(pr.px, pr.x, alpha), y = _lerp(pr.py, pr.y, alpha);
      if (vis(x, y)) drawProjectile(ctx, pr, x, y);
    }
    for (final b in s.eprojectiles) {
      final x = _lerp(b.px, b.x, alpha), y = _lerp(b.py, b.y, alpha);
      if (vis(x, y)) drawEnemyProjectile(ctx, b, x, y);
    }
    for (final hz in s.hazards) {
      if (hz.kind == 'ring' || hz.kind == 'laser') drawHazard(ctx, hz, t);
    }

    _mark('canopies+projectiles');
    // additive glow on top of projectiles
    ctx.globalCompositeOperation = 'lighter';
    for (final pr in s.projectiles) {
      final x = _lerp(pr.px, pr.x, alpha), y = _lerp(pr.py, pr.y, alpha);
      if (vis(x, y)) glow(ctx, projectileColor(pr.kind), x, y, pr.radius * 3.2, 0.55);
    }
    for (final b in s.eprojectiles) {
      final x = _lerp(b.px, b.x, alpha), y = _lerp(b.py, b.y, alpha);
      if (vis(x, y)) glow(ctx, eprojColor(b.kind), x, y, b.r * 3.5, 0.6);
    }
    for (final p in fx.particles) {
      ctx.globalAlpha = math.max(0, p.life / p.max);
      ctx.fillStyle = p.color;
      ctx.fillRect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size);
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';

    for (final r in fx.rings) {
      final k = r.life / r.max;
      ctx.strokeStyle = rgba(r.color, k);
      ctx.lineWidth = r.width * k + 1;
      ctx.beginPath();
      ctx.arc(r.x, r.y, r.r + (r.maxR - r.r) * (1 - k * k), 0, math.pi * 2);
      ctx.stroke();
    }

    _mark('proj glows+particles+rings');
    ctx.textAlign = 'center';
    ctx.lineJoin = 'round';
    for (final ft in fx.texts) {
      final k = ft.life / ft.max;
      ctx.globalAlpha = math.min(1, k * 2);
      ctx.font = 'bold ${jsNum(ft.size)}px system-ui, sans-serif';
      ctx.lineWidth = 3;
      ctx.strokeStyle = 'rgba(0,0,0,0.7)';
      ctx.strokeText(ft.text, ft.x, ft.y);
      ctx.fillStyle = ft.color;
      ctx.fillText(ft.text, ft.x, ft.y);
    }
    ctx.globalAlpha = 1;

    ctx.setTransform(1, 0, 0, 1, 0, 0);
    _mark('float texts');
    _world.drawVignette(ctx, w, h);
    if (hud) drawHud(ctx, this, s, me, fx);
    _mark('hud+minimap');
    ctx.dispose();
  }

  void _drawPlayerBar(Ctx2D ctx, Player p, double x, double y) {
    if (p.hp >= p.stats.maxHp) return;
    const bw = 34.0;
    final k = math.max(0.0, p.hp / p.stats.maxHp);
    ctx.fillStyle = 'rgba(0,0,0,0.6)';
    ctx.fillRect(x - bw / 2 - 1, y + p.radius + 7, bw + 2, 6);
    ctx.fillStyle = k > 0.3 ? '#ff4d6d' : '#ff2020';
    ctx.fillRect(x - bw / 2, y + p.radius + 8, bw * k, 4);
  }

  void dispose() {
    _world.dispose();
    minimap.dispose();
  }
}
