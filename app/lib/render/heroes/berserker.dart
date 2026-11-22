// Berserker: war paint, fur, horned helmet, great axe.

import 'dart:math' as math;

import 'shared.dart';

void berserker(Pen p, double walk, double a, double ly) {
  final ctx = p.ctx, r = p.r;
  // big axe behind
  held(p, r * 0.6, r * 0.35, a - 0.9, () {
    ctx.beginPath();
    ctx.roundRect(-r * 0.3, -r * 0.08, r * 1.9, r * 0.16, r * 0.08);
    paint(p, '#6b4a2b', -r * 0.08, r * 0.08);
    ctx.beginPath();
    ctx.moveTo(r * 1.15, -r * 0.08);
    ctx.quadraticCurveTo(r * 1.0, -r * 0.75, r * 1.65, -r * 0.85);
    ctx.quadraticCurveTo(r * 1.45, -r * 0.35, r * 1.7, r * 0.1);
    ctx.quadraticCurveTo(r * 1.45, r * 0.05, r * 1.15, r * 0.08);
    ctx.closePath();
    paint(p, '#c9d1de', -r * 0.85, r * 0.1);
  });
  feet(p, walk, '#4a3020');
  roundBody(ctx, r, -r * 0.05, r * 0.9, r * 1.2, r * 1.2);
  paint(p, '#d99a73', -r * 0.05, r * 0.9);
  // pants, belt, war paint stripes
  ctx.beginPath();
  ctx.rect(-r * 0.6, r * 0.5, r * 1.2, r * 0.38);
  paint(p, '#7a1f17', r * 0.5, r * 0.9, false);
  ctx.fillStyle = p.flash ? '#fff' : '#3a2416';
  ctx.fillRect(-r * 0.6, r * 0.44, r * 1.2, r * 0.12);
  ctx.fillStyle = p.flash ? '#fff' : '#c0392b';
  ctx.fillRect(r * 0.05, r * 0.08, r * 0.08, r * 0.3);
  ctx.fillRect(r * 0.22, r * 0.08, r * 0.08, r * 0.3);
  // fur pelt
  for (final (fx, fy) in [(-0.45, 0.0), (-0.15, -0.08), (0.2, -0.08), (0.48, 0.0)]) {
    ellipse(ctx, fx * r, fy * r, r * 0.24, r * 0.18);
    paint(p, '#8a6a4a', fy * r - r * 0.2, fy * r + r * 0.2);
  }
  final (hx, hy) = head(p);
  ctx.fillStyle = p.flash ? '#fff' : 'rgba(192,57,43,0.75)';
  ctx.fillRect(hx - r * 0.08, hy + r * 0.01, r * 0.6, r * 0.07);
  eyes(p, hx, hy + r * 0.04, ly);
  // beard with braid
  ctx.beginPath();
  ctx.moveTo(hx - r * 0.15, hy + r * 0.26);
  ctx.quadraticCurveTo(hx + r * 0.25, hy + r * 0.4, hx + r * 0.6, hy + r * 0.22);
  ctx.quadraticCurveTo(hx + r * 0.5, hy + r * 0.68, hx + r * 0.25, hy + r * 0.7);
  ctx.quadraticCurveTo(hx - r * 0.05, hy + r * 0.62, hx - r * 0.15, hy + r * 0.26);
  ctx.closePath();
  paint(p, '#d9662b', hy + r * 0.1, hy + r * 0.75);
  ellipse(ctx, hx + r * 0.25, hy + r * 0.84, r * 0.08, r * 0.12);
  paint(p, '#d9662b', hy + r * 0.66, hy + r * 0.96);
  // horned helmet
  ctx.beginPath();
  ctx.arc(hx, hy - r * 0.24, r * 0.6, math.pi, tau);
  ctx.closePath();
  paint(p, '#8e99ad', hy - r * 0.86, hy - r * 0.22);
  for (final s in [-1, 1]) {
    ctx.beginPath();
    ctx.moveTo(hx + s * r * 0.45, hy - r * 0.47);
    ctx.quadraticCurveTo(hx + s * r * 1.05, hy - r * 0.62, hx + s * r * 0.95, hy - r * 1.37);
    ctx.quadraticCurveTo(hx + s * r * 0.75, hy - r * 0.87, hx + s * r * 0.35, hy - r * 0.72);
    ctx.closePath();
    paint(p, '#efe3c8', hy - r * 1.37, hy - r * 0.47);
  }
  hand(p, r * 0.6, r * 0.35);
}
