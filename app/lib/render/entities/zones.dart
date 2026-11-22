// Player area effects: slashes, novas, meteors, arrow rain, lightning, ability rings.

import 'dart:math' as math;

import 'package:nightfall_sim/nightfall_sim.dart';

import '../canvas2d.dart';
import 'shared.dart';

void drawZone(Ctx2D ctx, Zone z, double t) {
  final k = z.maxLife > 0 ? math.max(0.0, z.life / z.maxLife) : 0.0;
  switch (z.kind) {
    case 'slash':
    case 'slash3':
      final a0 = z.ang - z.arc / 2, a1 = z.ang + z.arc / 2;
      final sweep = a0 + (a1 - a0) * math.min(1, (1 - k) * 2.2);
      ctx.strokeStyle = z.kind == 'slash3' ? withAlpha('#ff466e', 0.9 * k) : withAlpha('#e8f1ff', 0.85 * k);
      ctx.lineWidth = z.r * 0.28;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.arc(z.x, z.y, z.r * 0.78, a0, sweep);
      ctx.stroke();
    case 'slash2':
      ctx.strokeStyle = withAlpha('#ffe08a', 0.9 * k);
      ctx.lineWidth = z.r * 0.3;
      ctx.beginPath();
      ctx.arc(z.x, z.y, z.r * 0.8, z.ang + t * 20, z.ang + t * 20 + tau * (1 - k * 0.5));
      ctx.stroke();
    case 'nova':
    case 'nova2':
    case 'nova3':
      if (z.delay > 0) return;
      final prog = 1 - k;
      final cur = z.r0 + (z.r - z.r0) * prog;
      ctx.strokeStyle = z.kind == 'nova3'
          ? withAlpha('#fff0be', k)
          : (z.kind == 'nova2' ? withAlpha('#ff3c1e', k) : withAlpha('#ff823c', k));
      ctx.lineWidth = (z.kind == 'nova3' ? 22 : 10) + 12 * k;
      circle(ctx, z.x, z.y, cur);
      ctx.stroke();
      ctx.fillStyle = withAlpha('#ff7828', 0.12 * k);
      ctx.fill();
    case 'meteor':
      if (z.delay > 0) {
        final p = 1 - z.delay / 0.7;
        ctx.fillStyle = 'rgba(255,80,30,0.15)';
        circle(ctx, z.x, z.y, z.r);
        ctx.fill();
        ctx.strokeStyle = 'rgba(255,120,40,0.8)';
        ctx.lineWidth = 2;
        ctx.stroke();
        ctx.fillStyle = 'rgba(255,120,40,0.25)';
        circle(ctx, z.x, z.y, z.r * p);
        ctx.fill();
        final my = z.y - (1 - p) * 700, mx = z.x + (1 - p) * 250;
        ctx.strokeStyle = 'rgba(255,190,90,0.6)';
        ctx.lineWidth = 16;
        ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(mx, my);
        ctx.lineTo(mx + 60, my - 160);
        ctx.stroke();
        ctx.fillStyle = '#ffdb8a';
        circle(ctx, mx, my, 16);
        ctx.fill();
      }
    case 'rain':
      if (z.delay > 0) {
        ctx.strokeStyle = 'rgba(182,255,122,0.5)';
        ctx.lineWidth = 2;
        circle(ctx, z.x, z.y, z.r * 0.5);
        ctx.stroke();
        final h = z.delay * 900;
        ctx.strokeStyle = '#d8ffb0';
        ctx.beginPath();
        for (var i = -1; i <= 1; i++) {
          ctx.moveTo(z.x + i * 12, z.y - h);
          ctx.lineTo(z.x + i * 12, z.y - h - 30);
        }
        ctx.stroke();
      }
    case 'bolt':
      if (z.pts.length < 4) return;
      for (final (w, c) in [(7.0, withAlpha('#fff36b', 0.35 * k)), (2.5, withAlpha('#ffffff', k))]) {
        ctx.strokeStyle = c;
        ctx.lineWidth = w;
        ctx.beginPath();
        ctx.moveTo(z.pts[0], z.pts[1]);
        for (var i = 2; i < z.pts.length; i += 2) {
          final x0 = z.pts[i - 2], y0 = z.pts[i - 1], x1 = z.pts[i], y1 = z.pts[i + 1];
          for (var j = 1; j <= 4; j++) {
            final f = j / 4;
            final jit = j == 4 ? 0 : (rnd() - 0.5) * 18;
            ctx.lineTo(x0 + (x1 - x0) * f + jit, y0 + (y1 - y0) * f + jit);
          }
        }
        ctx.stroke();
      }
    case 'bash':
    case 'raise':
      ctx.strokeStyle = withAlpha(z.kind == 'bash' ? '#5b8cff' : '#c084ff', k);
      ctx.lineWidth = 8 * k + 2;
      circle(ctx, z.x, z.y, z.r * (1 - k * 0.7));
      ctx.stroke();
  }
}
