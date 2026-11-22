// Regular enemies (one case per enemy type) and burning flames.

import 'dart:math' as math;

import 'package:nightfall_sim/nightfall_sim.dart';

import '../canvas2d.dart';
import 'bosses.dart';
import 'shared.dart';

String enemyColor(Enemy e) => enemyDefs[e.type]?.color ?? '#ffffff';

void drawEnemy(Ctx2D ctx, Enemy e, double x, double y, double t, double dx, double dy) {
  drawEnemyBody(ctx, e, x, y, t, dx, dy);
  if (e.burnT > 0) drawFlames(ctx, x, y, e.radius, t);
}

/// Little flickering flames on a burning enemy.
void drawFlames(Ctx2D ctx, double x, double y, double r, double t) {
  final n = r > 30 ? 5 : 3;
  for (var i = 0; i < n; i++) {
    final fx = x + (i - (n - 1) / 2) * r * 0.45;
    final h = r * (0.55 + 0.25 * math.sin(t * 17 + i * 2.1));
    final fy = y - r * 0.55;
    ctx.fillStyle = 'rgba(255,110,30,0.85)';
    ctx.beginPath();
    ctx.moveTo(fx - r * 0.18, fy);
    ctx.quadraticCurveTo(fx - r * 0.2, fy - h * 0.6, fx, fy - h);
    ctx.quadraticCurveTo(fx + r * 0.2, fy - h * 0.6, fx + r * 0.18, fy);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = 'rgba(255,220,120,0.9)';
    ctx.beginPath();
    ctx.ellipse(fx, fy - h * 0.3, r * 0.07, h * 0.25, 0, 0, tau);
    ctx.fill();
  }
}

void drawEnemyBody(Ctx2D ctx, Enemy e, double x, double y, double t, double dx, double dy) {
  final r = e.radius;
  final col = e.flash > 0.06 ? '#ffffff' : enemyColor(e);
  if (e.boss) return drawBoss(ctx, e, x, y, t, dx, dy, col);

  ctx.fillStyle = 'rgba(0,0,0,0.3)';
  ctx.beginPath();
  ctx.ellipse(x, y + r * 0.85, r * 0.85, r * 0.3, 0, 0, tau);
  ctx.fill();

  if (e.elite) {
    ctx.strokeStyle = withAlpha('#ffd166', 0.6 + math.sin(t * 6) * 0.3);
    ctx.lineWidth = 3;
    circle(ctx, x, y, r + 5);
    ctx.stroke();
  }
  ctx.fillStyle = col;
  switch (e.type) {
    case 'bat':
      final flap = math.sin(t * 22 + e.id) * 0.6;
      ctx.beginPath();
      for (final s in [-1, 1]) {
        ctx.moveTo(x, y);
        ctx.lineTo(x + s * r * 2, y - r * (0.6 + flap));
        ctx.lineTo(x + s * r * 1.3, y + r * 0.4);
        ctx.closePath();
      }
      ctx.fill();
      circle(ctx, x, y, r * 0.7);
      ctx.fill();
      eyes(ctx, x, y - 1, r * 0.6, dx, dy, '#ff2b4a', 1.6);
    case 'zombie':
      ctx.fillRect(x - r, y - r, r * 2, r * 2);
      ctx.fillStyle = '#3f7a2c';
      ctx.fillRect(x - r, y + r * 0.3, r * 2, r * 0.7);
      ctx.strokeStyle = col;
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(x + dx * r * 0.5 - dy * r * 0.6, y + dy * r * 0.5 + dx * r * 0.6);
      ctx.lineTo(x + dx * r * 1.6 - dy * r * 0.6, y + dy * r * 1.6 + dx * r * 0.6);
      ctx.moveTo(x + dx * r * 0.5 + dy * r * 0.6, y + dy * r * 0.5 - dx * r * 0.6);
      ctx.lineTo(x + dx * r * 1.6 + dy * r * 0.6, y + dy * r * 1.6 - dx * r * 0.6);
      ctx.stroke();
      eyes(ctx, x, y - r * 0.3, r, dx, dy, '#ff3030', 2.2);
    case 'swarm':
      final a = t * 6 + e.id;
      ctx.beginPath();
      for (var i = 0; i < 4; i++) {
        final aa = a + (i * tau) / 4;
        final rr = i % 2 == 0 ? r * 1.3 : r * 0.8;
        ctx.lineTo(x + math.cos(aa) * rr, y + math.sin(aa) * rr);
      }
      ctx.closePath();
      ctx.fill();
    case 'archer':
    case 'skeleton':
      circle(ctx, x, y, r);
      ctx.fill();
      ctx.fillStyle = '#1b1b22';
      circle(ctx, x - r * 0.35 + dx * 2, y - r * 0.15, r * 0.25);
      ctx.fill();
      circle(ctx, x + r * 0.35 + dx * 2, y - r * 0.15, r * 0.25);
      ctx.fill();
      ctx.fillRect(x - r * 0.4, y + r * 0.4, r * 0.8, r * 0.15);
      if (e.type == 'archer') {
        ctx.strokeStyle = '#a0784a';
        ctx.lineWidth = 2;
        final a = math.atan2(dy, dx);
        ctx.beginPath();
        ctx.arc(x + dx * r, y + dy * r, r * 0.9, a - 1.2, a + 1.2);
        ctx.stroke();
      }
    case 'slime':
    case 'slimelet':
      final sq = math.sin(t * 8 + e.id) * 0.12;
      ctx.beginPath();
      ctx.ellipse(x, y + r * 0.1, r * (1.1 + sq), r * (0.9 - sq), 0, math.pi, tau);
      ctx.lineTo(x + r * (1.1 + sq), y + r * 0.6);
      ctx.lineTo(x - r * (1.1 + sq), y + r * 0.6);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,0.45)';
      circle(ctx, x - r * 0.4, y - r * 0.3, r * 0.2);
      ctx.fill();
      eyes(ctx, x, y, r, dx, dy, '#0b2a4a', r * 0.14);
    case 'charger':
      final a = e.state == 2 ? math.atan2(e.ty, e.tx) : math.atan2(dy, dx);
      final shake = e.state == 1 ? (rnd() - 0.5) * 4 : 0.0;
      if (e.state == 1) ctx.fillStyle = (t * 20).floor() % 2 != 0 ? '#ffffff' : col;
      ctx.beginPath();
      ctx.moveTo(x + shake + math.cos(a) * r * 1.5, y + math.sin(a) * r * 1.5);
      ctx.lineTo(x + shake + math.cos(a + 2.4) * r, y + math.sin(a + 2.4) * r);
      ctx.lineTo(x + shake - math.cos(a) * r * 0.4, y - math.sin(a) * r * 0.4);
      ctx.lineTo(x + shake + math.cos(a - 2.4) * r, y + math.sin(a - 2.4) * r);
      ctx.closePath();
      ctx.fill();
      if (e.state == 1) {
        ctx.strokeStyle = 'rgba(255,80,40,0.35)';
        ctx.lineWidth = r * 1.4;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x + e.tx * 260, y + e.ty * 260);
        ctx.stroke();
      }
    case 'exploder':
      final fuse = e.state == 1;
      final pulse = 1 + math.sin(t * (fuse ? 40 : 8)) * (fuse ? 0.15 : 0.06);
      ctx.fillStyle = fuse && (t * 16).floor() % 2 != 0 ? '#ffffff' : col;
      circle(ctx, x, y, r * pulse * (fuse ? 1.2 : 1));
      ctx.fill();
      ctx.strokeStyle = '#3a1010';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(x, y - r);
      ctx.quadraticCurveTo(x + 4, y - r - 6, x + 2, y - r - 10);
      ctx.stroke();
      ctx.fillStyle = '#ffd166';
      circle(ctx, x + 2, y - r - 10, 2 + rnd() * 2);
      ctx.fill();
    case 'ghost':
      ctx.globalAlpha = e.intangible ? 0.22 : 0.85;
      ctx.beginPath();
      ctx.arc(x, y - r * 0.2, r, math.pi, tau);
      for (var i = 0; i <= 4; i++) {
        final xx = x + r - (i * 2 * r) / 4;
        ctx.lineTo(xx, y + r * 0.8 + math.sin(t * 8 + i + e.id) * 3);
      }
      ctx.closePath();
      ctx.fill();
      eyes(ctx, x, y - r * 0.3, r, dx, dy, '#223', r * 0.16);
      ctx.globalAlpha = 1;
    case 'egg':
      final k = math.min(1.0, e.t2 / eggHatch);
      final pulse = 1 + math.sin(t * (6 + k * 20)) * 0.06 * (0.3 + k);
      ctx.fillStyle = e.flash > 0.06 ? '#ffffff' : col;
      ctx.beginPath();
      ctx.ellipse(x, y, r * 0.85 * pulse, r * 1.05 * pulse, 0, 0, tau);
      ctx.fill();
      ctx.strokeStyle = withAlpha('#a02850', 0.35 + k * 0.5);
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(x - r * 0.4, y - r * 0.6);
      ctx.quadraticCurveTo(x, y - r * 0.1, x - r * 0.2, y + r * 0.7);
      ctx.moveTo(x + r * 0.45, y - r * 0.4);
      ctx.quadraticCurveTo(x + r * 0.1, y + r * 0.2, x + r * 0.35, y + r * 0.8);
      ctx.stroke();
      if (k > 0.6) {
        ctx.strokeStyle = '#2a1018';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(x - r * 0.3, y - r * 0.2);
        ctx.lineTo(x, y);
        ctx.lineTo(x - r * 0.1, y + r * 0.3);
        ctx.stroke();
      }
    case 'shaman':
      ctx.beginPath();
      for (var i = 0; i < 6; i++) {
        final a = (i * tau) / 6 + math.pi / 6;
        ctx.lineTo(x + math.cos(a) * r, y + math.sin(a) * r);
      }
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = '#0c3b33';
      ctx.fillRect(x - r * 0.5, y - r * 0.25, r, r * 0.3);
      ctx.strokeStyle = '#7a5a3a';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(x + r * 1.1, y + r);
      ctx.lineTo(x + r * 1.1, y - r * 1.4);
      ctx.stroke();
      ctx.fillStyle = '#7dfff0';
      circle(ctx, x + r * 1.1, y - r * 1.5, 3 + math.sin(t * 6) * 1);
      ctx.fill();
    default:
      circle(ctx, x, y, r);
      ctx.fill();
  }
}
