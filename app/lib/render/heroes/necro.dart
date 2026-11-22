// Necromancer: tattered robe, skull face, scythe, soul wisps.

import 'dart:math' as math;

import '../sprites.dart';
import 'shared.dart';

void necro(Pen p, double walk, double a, double ly, String accent, double t) {
  final ctx = p.ctx, r = p.r;
  // scythe behind the body
  held(p, r * 0.55, r * 0.4, a * 0.3 - 1.45, () {
    ctx.beginPath();
    ctx.roundRect(-r * 0.8, -r * 0.06, r * 2.4, r * 0.12, r * 0.06);
    paint(p, '#3a2a22', -r * 0.06, r * 0.06);
    ctx.beginPath();
    ctx.moveTo(r * 1.55, -r * 0.05);
    ctx.quadraticCurveTo(r * 1.4, r * 0.9, r * 0.6, r * 1.15);
    ctx.quadraticCurveTo(r * 1.15, r * 0.7, r * 1.35, -r * 0.05);
    ctx.closePath();
    paint(p, '#cfd3dc', -r * 0.05, r * 1.1);
  });
  feet(p, walk, '#120c1c');
  // tattered robe
  ctx.beginPath();
  ctx.moveTo(-r * 0.45, -r * 0.08);
  ctx.lineTo(r * 0.45, -r * 0.08);
  ctx.lineTo(r * 0.72, r * 0.85);
  for (var i = 0; i <= 6; i++) {
    ctx.lineTo(r * 0.72 - (i * r * 1.44) / 6, r * (i % 2 != 0 ? 0.88 : 1.05));
  }
  ctx.closePath();
  paint(p, '#241833', -r * 0.1, r * 1.05);
  ctx.strokeStyle = p.flash ? '#fff' : rgba(accent, 0.7);
  ctx.lineWidth = r * 0.07;
  ctx.beginPath();
  ctx.moveTo(r * 0.12, 0);
  ctx.lineTo(r * 0.2, r * 0.85);
  ctx.stroke();
  // hood + skull face
  ellipse(ctx, 0, -r * 0.55, r * 0.7, r * 0.68);
  paint(p, '#1b1226', -r * 1.25, 0);
  ctx.beginPath();
  ctx.moveTo(-r * 0.15, -r * 1.15);
  ctx.quadraticCurveTo(-r * 0.2, -r * 1.55, -r * 0.65, -r * 1.35);
  ctx.quadraticCurveTo(-r * 0.4, -r * 1.2, -r * 0.45, -r * 1.0);
  ctx.closePath();
  paint(p, '#1b1226', -r * 1.5, -r);
  ellipse(ctx, r * 0.15, -r * 0.45, r * 0.38, r * 0.4);
  paint(p, '#e8e2d0', -r * 0.85, -r * 0.05, false);
  ctx.fillStyle = p.flash ? '#fff' : '#0c0812';
  for (final dx in [0.02, 0.3]) {
    ellipse(ctx, r * dx, -r * 0.5 + ly * r * 0.06, r * 0.1, r * 0.12);
    ctx.fill();
  }
  if (!p.flash) {
    final pulse = 0.7 + math.sin(t * 6) * 0.3;
    ctx.fillStyle = rgba(accent, pulse);
    for (final dx in [0.02, 0.3]) {
      ellipse(ctx, r * dx, -r * 0.5 + ly * r * 0.06, r * 0.05, r * 0.06);
      ctx.fill();
    }
    ctx.fillStyle = '#0c0812';
    ctx.fillRect(r * 0.05, -r * 0.2, r * 0.22, r * 0.05);
  }
  hand(p, r * 0.55, r * 0.4, '#d8d2bd');
  // soul wisps
  if (!p.flash) {
    for (var i = 0; i < 2; i++) {
      final wa = t * 2.2 + i * math.pi;
      ctx.fillStyle = rgba(accent, 0.75);
      ellipse(ctx, math.cos(wa) * r * 1.05, -r * 0.3 + math.sin(wa) * r * 0.45, r * 0.11, r * 0.11);
      ctx.fill();
    }
  }
}
