// XP gems, heals, magnets, bombs, chests and Goldfang's coins and treasure.

import 'dart:math' as math;

import 'package:nightfall_sim/nightfall_sim.dart';

import '../canvas2d.dart';
import 'shared.dart';

String gemColor(double v) {
  if (v >= 50) return '#ff5df2';
  if (v >= 10) return '#ff6b5d';
  if (v >= 3) return '#5dff8f';
  return '#5dc8ff';
}

String pickupColor(Pickup p) => switch (p.kind) {
      'xp' => gemColor(p.value),
      'heal' => '#ff4d6d',
      'magnet' => '#5d9bff',
      'bomb' => '#ffb347',
      'chest' => '#ffd166',
      _ => '#ffc83d',
    };

void drawPickup(Ctx2D ctx, Pickup p, double x, double y, double t) {
  final bob = math.sin(t * 4 + p.id) * 2;
  final yy = y + bob;
  switch (p.kind) {
    case 'xp':
      final s = p.value >= 50 ? 9.0 : (p.value >= 10 ? 7.0 : (p.value >= 3 ? 5.5 : 4.5));
      ctx.fillStyle = gemColor(p.value);
      ctx.beginPath();
      ctx.moveTo(x, yy - s * 1.3);
      ctx.lineTo(x + s, yy);
      ctx.lineTo(x, yy + s * 1.3);
      ctx.lineTo(x - s, yy);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,0.6)';
      ctx.beginPath();
      ctx.moveTo(x, yy - s * 1.3);
      ctx.lineTo(x + s * 0.4, yy - s * 0.2);
      ctx.lineTo(x - s * 0.3, yy);
      ctx.closePath();
      ctx.fill();
    case 'heal':
      ctx.fillStyle = '#ff4d6d';
      ctx.fillRect(x - 3.5, yy - 10, 7, 20);
      ctx.fillRect(x - 10, yy - 3.5, 20, 7);
    case 'magnet':
      ctx.strokeStyle = '#ff4d4d';
      ctx.lineWidth = 6;
      ctx.beginPath();
      ctx.arc(x, yy, 8, 0, math.pi);
      ctx.stroke();
      ctx.strokeStyle = '#e0e6f0';
      ctx.beginPath();
      ctx.moveTo(x - 8, yy);
      ctx.lineTo(x - 8, yy - 7);
      ctx.moveTo(x + 8, yy);
      ctx.lineTo(x + 8, yy - 7);
      ctx.stroke();
    case 'bomb':
      ctx.fillStyle = '#222632';
      circle(ctx, x, yy, 10);
      ctx.fill();
      ctx.strokeStyle = '#ffb347';
      ctx.lineWidth = 2;
      ctx.stroke();
      ctx.fillStyle = '#ffd166';
      circle(ctx, x + 6, yy - 11, 2 + rnd() * 2);
      ctx.fill();
    case 'chest':
      final s = p.big ? 1.4 : 1.0;
      ctx.fillStyle = '#8a5a2b';
      ctx.fillRect(x - 14 * s, yy - 8 * s, 28 * s, 18 * s);
      ctx.fillStyle = '#ffd166';
      ctx.fillRect(x - 14 * s, yy - 12 * s, 28 * s, 7 * s);
      ctx.fillRect(x - 3 * s, yy - 6 * s, 6 * s, 8 * s);
      ctx.strokeStyle = '#ffeaa0';
      ctx.lineWidth = 1.5;
      ctx.strokeRect(x - 14 * s, yy - 12 * s, 28 * s, 22 * s);
    case 'coin':
      drawCoin(ctx, x, yy, 7, t + p.id);
    case 'relic':
      // Goldfang's treasure sack, spilling light
      final pulse = 0.6 + math.sin(t * 5) * 0.4;
      ctx.strokeStyle = withAlpha('#ffc83d', 0.35 + pulse * 0.3);
      ctx.lineWidth = 3;
      for (var i = 0; i < 8; i++) {
        final a = t * 0.8 + (i * tau) / 8;
        ctx.beginPath();
        ctx.moveTo(x + math.cos(a) * 22, yy + math.sin(a) * 22);
        ctx.lineTo(x + math.cos(a) * (30 + pulse * 6), yy + math.sin(a) * (30 + pulse * 6));
        ctx.stroke();
      }
      ctx.fillStyle = '#8a5a2b';
      ctx.beginPath();
      ctx.moveTo(x - 6, yy - 12);
      ctx.quadraticCurveTo(x - 20, yy + 2, x - 14, yy + 14);
      ctx.lineTo(x + 14, yy + 14);
      ctx.quadraticCurveTo(x + 20, yy + 2, x + 6, yy - 12);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = '#ffc83d';
      ctx.fillRect(x - 7, yy - 14, 14, 4);
      ctx.font = 'bold 14px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(r'$', x, yy + 9);
  }
}

/// A spinning gold coin; also used for Goldfang's fake coins and the coin weapon.
void drawCoin(Ctx2D ctx, double x, double y, double r, double t, [String tint = '#ffc83d']) {
  final sx = math.max(0.2, math.cos(t * 4).abs());
  ctx.fillStyle = '#b8860b';
  ctx.beginPath();
  ctx.ellipse(x, y, r * sx, r, 0, 0, tau);
  ctx.fill();
  ctx.fillStyle = tint;
  ctx.beginPath();
  ctx.ellipse(x, y, r * sx * 0.78, r * 0.78, 0, 0, tau);
  ctx.fill();
  ctx.fillStyle = 'rgba(255,255,255,0.55)';
  ctx.beginPath();
  ctx.ellipse(x - r * sx * 0.25, y - r * 0.3, r * sx * 0.2, r * 0.25, 0, 0, tau);
  ctx.fill();
}
