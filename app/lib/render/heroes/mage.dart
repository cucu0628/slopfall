// Mage: robe, beard, pointy hat, staff.

import 'dart:math' as math;

import '../sprites.dart';
import 'shared.dart';

void mage(Pen p, double walk, double a, double ly, String accent, double t) {
  final ctx = p.ctx, r = p.r;
  feet(p, walk, '#2a1f5c');
  // robe
  roundBody(ctx, r, -r * 0.08, r * 1.0, r * 0.95, r * 1.45);
  paint(p, '#4b34c9', -r * 0.1, r);
  ctx.fillStyle = p.flash ? '#fff' : '#ffd166';
  ctx.fillRect(-r * 0.7, r * 0.84, r * 1.4, r * 0.09);
  ctx.fillRect(-r * 0.47, r * 0.3, r * 0.94, r * 0.08);
  if (!p.flash) {
    ctx.fillStyle = rgba(accent, 0.8);
    for (final (sx, sy) in [(-0.3, 0.6), (0.25, 0.15), (0.35, 0.65)]) {
      ellipse(ctx, sx * r, sy * r, r * 0.05, r * 0.05);
      ctx.fill();
    }
  }
  final (hx, hy) = head(p);
  eyes(p, hx, hy + r * 0.02, ly);
  // beard
  ctx.beginPath();
  ctx.moveTo(hx - r * 0.2, hy + r * 0.2);
  ctx.quadraticCurveTo(hx + r * 0.2, hy + r * 0.33, hx + r * 0.6, hy + r * 0.2);
  ctx.quadraticCurveTo(hx + r * 0.45, hy + r * 0.88, hx + r * 0.12, hy + r * 0.98);
  ctx.quadraticCurveTo(hx - r * 0.15, hy + r * 0.65, hx - r * 0.2, hy + r * 0.2);
  ctx.closePath();
  paint(p, '#e9e8f2', hy, hy + r);
  // hat
  final sway = math.sin(t * 3) * r * 0.08;
  ctx.beginPath();
  ctx.moveTo(hx - r * 0.62, hy - r * 0.46);
  ctx.quadraticCurveTo(hx - r * 0.1, hy - r * 1.12, hx - r * 0.55 + sway, hy - r * 1.88);
  ctx.quadraticCurveTo(hx + r * 0.2, hy - r * 1.18, hx + r * 0.68, hy - r * 0.46);
  ctx.closePath();
  paint(p, '#3b2a8f', hy - r * 1.9, hy - r * 0.45);
  ellipse(ctx, hx, hy - r * 0.46, r * 0.95, r * 0.2);
  paint(p, '#33247d', hy - r * 0.66, hy - r * 0.26);
  ctx.fillStyle = p.flash ? '#fff' : '#ffd166';
  ctx.beginPath();
  ctx.moveTo(hx - r * 0.5, hy - r * 0.62);
  ctx.lineTo(hx + r * 0.52, hy - r * 0.62);
  ctx.lineTo(hx + r * 0.45, hy - r * 0.74);
  ctx.lineTo(hx - r * 0.42, hy - r * 0.74);
  ctx.closePath();
  ctx.fill();
  // staff
  held(p, r * 0.62, r * 0.4, a * 0.35 - 1.3, () {
    ctx.beginPath();
    ctx.roundRect(-r * 0.75, -r * 0.07, r * 2.1, r * 0.14, r * 0.07);
    paint(p, '#7a5230', -r * 0.07, r * 0.07);
    final pulse = 1 + math.sin(t * 5) * 0.08;
    ellipse(ctx, r * 1.45, 0, r * 0.26 * pulse, r * 0.26 * pulse);
    paint(p, accent, -r * 0.26, r * 0.26);
    if (!p.flash) {
      ctx.fillStyle = 'rgba(255,255,255,0.85)';
      ellipse(ctx, r * 1.4, -r * 0.08, r * 0.08, r * 0.08);
      ctx.fill();
    }
  });
  hand(p, r * 0.62, r * 0.4);
}
