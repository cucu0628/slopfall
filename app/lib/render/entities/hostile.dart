// Enemy projectiles and boss hazards (slams, shockwaves, lasers, meteors).

import 'dart:math' as math;

import 'package:nightfall_sim/nightfall_sim.dart';

import '../canvas2d.dart';
import 'pickups.dart';
import 'shared.dart';

String eprojColor(String kind) => switch (kind) {
      'arrow' => '#ffe9b0',
      'skull' => '#b26bff',
      'web' => '#e8e8f0',
      'ice' => '#9ad8ff',
      _ => '#ff2e88',
    };

void drawEnemyProjectile(Ctx2D ctx, EnemyProjectile b, double x, double y) {
  if (b.kind == 'web') {
    ctx.strokeStyle = 'rgba(235,235,245,0.9)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    for (var i = 0; i < 6; i++) {
      final a = (i * tau) / 6;
      ctx.moveTo(x, y);
      ctx.lineTo(x + math.cos(a) * b.r * 1.3, y + math.sin(a) * b.r * 1.3);
    }
    ctx.stroke();
    circle(ctx, x, y, b.r * 0.55);
    ctx.stroke();
    circle(ctx, x, y, b.r);
    ctx.stroke();
    return;
  }
  if (b.kind == 'ice') {
    final a = math.atan2(b.vy, b.vx);
    ctx.fillStyle = '#c8f0ff';
    ctx.beginPath();
    ctx.moveTo(x + math.cos(a) * b.r * 2, y + math.sin(a) * b.r * 2);
    ctx.lineTo(x + math.cos(a + 1.7) * b.r * 0.7, y + math.sin(a + 1.7) * b.r * 0.7);
    ctx.lineTo(x - math.cos(a) * b.r * 1.2, y - math.sin(a) * b.r * 1.2);
    ctx.lineTo(x + math.cos(a - 1.7) * b.r * 0.7, y + math.sin(a - 1.7) * b.r * 0.7);
    ctx.closePath();
    ctx.fill();
    return;
  }
  if (b.kind == 'arrow') {
    var sp = hypot(b.vx, b.vy);
    if (sp == 0) sp = 1;
    ctx.strokeStyle = '#ffe9b0';
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x - (b.vx / sp) * 16, y - (b.vy / sp) * 16);
    ctx.stroke();
    ctx.fillStyle = '#ff6a6a';
    circle(ctx, x, y, 3);
    ctx.fill();
    return;
  }
  ctx.fillStyle = eprojColor(b.kind);
  circle(ctx, x, y, b.r);
  ctx.fill();
  ctx.fillStyle = '#ffffff';
  circle(ctx, x, y, b.r * 0.45);
  ctx.fill();
}

double _orOne(double v) => v == 0 ? 1 : v;

void drawHazard(Ctx2D ctx, Hazard h, double t) {
  switch (h.kind) {
    case 'skyfall':
      if (h.warn <= 0) break;
      final p = 1 - h.warn / _orOne(h.maxWarn);
      ctx.fillStyle = 'rgba(255,110,30,0.14)';
      circle(ctx, h.x, h.y, h.r);
      ctx.fill();
      ctx.strokeStyle = withAlpha('#ff8c28', 0.6 + math.sin(t * 24) * 0.3);
      ctx.lineWidth = 3;
      ctx.stroke();
      ctx.fillStyle = 'rgba(255,110,30,0.28)';
      circle(ctx, h.x, h.y, h.r * p);
      ctx.fill();
      // the falling rock
      final my = h.y - (1 - p) * 650, mx = h.x + (1 - p) * 220;
      ctx.strokeStyle = 'rgba(255,170,80,0.55)';
      ctx.lineWidth = 14;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(mx, my);
      ctx.lineTo(mx + 55, my - 150);
      ctx.stroke();
      ctx.fillStyle = '#5a4030';
      circle(ctx, mx, my, 15);
      ctx.fill();
      ctx.strokeStyle = '#ffb347';
      ctx.lineWidth = 3;
      ctx.stroke();
    case 'slam':
      if (h.warn > 0) {
        final p = 1 - h.warn / _orOne(h.maxWarn);
        ctx.fillStyle = 'rgba(255,40,40,0.12)';
        circle(ctx, h.x, h.y, h.r);
        ctx.fill();
        ctx.strokeStyle = withAlpha('#ff3c3c', 0.5 + math.sin(t * 20) * 0.3);
        ctx.lineWidth = 3;
        ctx.stroke();
        ctx.fillStyle = 'rgba(255,40,40,0.25)';
        circle(ctx, h.x, h.y, h.r * p);
        ctx.fill();
      }
    case 'coin':
      // a fake coin looks exactly like a real one until a player steps close
      final yy = h.y + math.sin(t * 4 + h.id) * 2;
      if (h.speed == 0) {
        drawCoin(ctx, h.x, yy, 7, t + h.id);
        break;
      }
      final p = 1 - h.warn / _orOne(h.maxWarn);
      ctx.fillStyle = 'rgba(255,60,40,0.14)';
      circle(ctx, h.x, h.y, h.r);
      ctx.fill();
      ctx.strokeStyle = withAlpha('#ff503c', 0.5 + math.sin(t * 30) * 0.4);
      ctx.lineWidth = 3;
      ctx.stroke();
      ctx.fillStyle = 'rgba(255,60,40,0.28)';
      circle(ctx, h.x, h.y, h.r * p);
      ctx.fill();
      drawCoin(ctx, h.x, yy, 7 + p * 4, t * 3, math.sin(t * 40) > 0 ? '#ff4d4d' : '#ffc83d');
    case 'ring':
      if (h.warn > 0) return;
      ctx.strokeStyle = 'rgba(255,90,60,0.85)';
      ctx.lineWidth = h.w * 2;
      circle(ctx, h.x, h.y, h.r);
      ctx.stroke();
      ctx.strokeStyle = 'rgba(255,220,180,0.9)';
      ctx.lineWidth = 3;
      ctx.stroke();
    case 'laser':
      final x2 = h.x + math.cos(h.ang) * h.len, y2 = h.y + math.sin(h.ang) * h.len;
      ctx.lineCap = 'round';
      if (h.warn > 0) {
        ctx.strokeStyle = withAlpha('#ff2e88', 0.25 + math.sin(t * 25) * 0.15);
        ctx.lineWidth = h.w;
        ctx.setLineDash([16, 12]);
        ctx.beginPath();
        ctx.moveTo(h.x, h.y);
        ctx.lineTo(x2, y2);
        ctx.stroke();
        ctx.setLineDash([]);
      } else {
        for (final (w, c) in [(h.w * 2.2, 'rgba(255,46,136,0.25)'), (h.w, 'rgba(255,90,170,0.85)'), (h.w * 0.35, '#ffffff')]) {
          ctx.strokeStyle = c;
          ctx.lineWidth = w;
          ctx.beginPath();
          ctx.moveTo(h.x, h.y);
          ctx.lineTo(x2, y2);
          ctx.stroke();
        }
      }
  }
}
