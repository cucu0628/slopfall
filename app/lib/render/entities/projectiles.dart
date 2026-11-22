// Player projectiles (bolts, arrows, axes, shells, ...).

import 'dart:math' as math;

import 'package:nightfall_sim/nightfall_sim.dart';

import '../canvas2d.dart';
import '../sprites.dart';
import 'pickups.dart';
import 'shared.dart';

String projectileColor(String kind) => switch (kind) {
      'bolt' => '#6ee7ff',
      'bolt2' => '#b47cff',
      'arrow' => '#b6ff7a',
      'arrow2' => '#e6ffd0',
      'orb' => '#c084ff',
      'orb2' => '#ff7ae0',
      'axe' => '#ffb347',
      'axe2' => '#ff6a3d',
      'axe3' => '#ff4d8a',
      'prism' => '#fff6d6',
      'shell' => '#ffb347',
      'bullet' => '#7dffcf',
      'shard' => '#9ad8ff',
      'shard2' => '#e0f6ff',
      'coin' => '#ffc83d',
      _ => '#ffffff',
    };

double _or1(double v) => v == 0 || v.isNaN ? 1 : v;

void drawProjectile(Ctx2D ctx, Projectile p, double x, double y) {
  final col = projectileColor(p.kind);
  final r = p.radius;
  switch (p.kind) {
    case 'coin':
      drawCoin(ctx, x, y, r, p.age * 2);
    case 'bolt':
    case 'bolt2':
    case 'bullet':
      final sp = _or1(hypot(p.vx, p.vy));
      ctx.strokeStyle = rgba(col, 0.5);
      ctx.lineWidth = r * 1.2;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x - (p.vx / sp) * r * 3, y - (p.vy / sp) * r * 3);
      ctx.stroke();
      ctx.fillStyle = '#ffffff';
      circle(ctx, x, y, r * 0.6);
      ctx.fill();
    case 'arrow':
    case 'arrow2':
      final sp = _or1(hypot(p.vx, p.vy));
      final ux = p.vx / sp, uy = p.vy / sp;
      ctx.strokeStyle = col;
      ctx.lineWidth = p.kind == 'arrow2' ? 3 : 2;
      ctx.beginPath();
      ctx.moveTo(x - ux * 22, y - uy * 22);
      ctx.lineTo(x, y);
      ctx.stroke();
      ctx.fillStyle = col;
      ctx.beginPath();
      ctx.moveTo(x + ux * 6, y + uy * 6);
      ctx.lineTo(x - uy * 4, y + ux * 4);
      ctx.lineTo(x + uy * 4, y - ux * 4);
      ctx.closePath();
      ctx.fill();
    case 'orb':
    case 'orb2':
      ctx.fillStyle = col;
      circle(ctx, x, y, r);
      ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,0.8)';
      circle(ctx, x - r * 0.3, y - r * 0.3, r * 0.35);
      ctx.fill();
    case 'prism':
      final sp = _or1(hypot(p.vx, p.vy));
      final ux = p.vx / sp, uy = p.vy / sp;
      ctx.lineCap = 'round';
      for (final (w, c) in [(r * 2.2, 'rgba(180,140,255,0.35)'), (r * 1.3, 'rgba(110,231,255,0.6)'), (r * 0.6, '#ffffff')]) {
        ctx.strokeStyle = c;
        ctx.lineWidth = w;
        ctx.beginPath();
        ctx.moveTo(x - ux * r * 5, y - uy * r * 5);
        ctx.lineTo(x + ux * r, y + uy * r);
        ctx.stroke();
      }
    case 'shell':
      final prog = math.min(1, p.age / math.max(0.01, p.maxLife));
      final lift = math.sin(prog * math.pi) * 60;
      ctx.fillStyle = 'rgba(0,0,0,0.3)';
      ctx.beginPath();
      ctx.ellipse(x, y, r, r * 0.4, 0, 0, tau);
      ctx.fill();
      ctx.fillStyle = '#3a3a44';
      circle(ctx, x, y - lift, r);
      ctx.fill();
      ctx.strokeStyle = col;
      ctx.lineWidth = 2;
      ctx.stroke();
    case 'axe':
    case 'axe2':
    case 'axe3':
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(p.ang);
      ctx.fillStyle = '#6b4a2b';
      ctx.fillRect(-r * 0.15, -r, r * 0.3, r * 2);
      ctx.fillStyle = col;
      for (final s in [-1, 1]) {
        ctx.beginPath();
        ctx.moveTo(0, s * r * 0.9);
        ctx.quadraticCurveTo(r * 1.1, s * r * 0.9, r * 0.9, s * r * 0.1);
        ctx.lineTo(0, s * r * 0.35);
        ctx.closePath();
        ctx.fill();
      }
      ctx.restore();
    case 'shard':
    case 'shard2':
      final a = math.atan2(p.vy, p.vx);
      ctx.fillStyle = col;
      ctx.beginPath();
      ctx.moveTo(x + math.cos(a) * r * 1.8, y + math.sin(a) * r * 1.8);
      ctx.lineTo(x + math.cos(a + 1.6) * r * 0.6, y + math.sin(a + 1.6) * r * 0.6);
      ctx.lineTo(x - math.cos(a) * r * 1.2, y - math.sin(a) * r * 1.2);
      ctx.lineTo(x + math.cos(a - 1.6) * r * 0.6, y + math.sin(a - 1.6) * r * 0.6);
      ctx.closePath();
      ctx.fill();
    default:
      ctx.fillStyle = col;
      circle(ctx, x, y, r);
      ctx.fill();
  }
}
