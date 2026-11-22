// Engineer: overalls, hard hat, goggles, backpack, wrench.

import 'dart:math' as math;

import 'shared.dart';

void engineer(Pen p, double walk, double a, double ly, double t) {
  final ctx = p.ctx, r = p.r;
  // backpack with antenna
  ctx.beginPath();
  ctx.roundRect(-r * 0.85, -r * 0.05, r * 0.5, r * 0.75, r * 0.1);
  paint(p, '#5d6573', -r * 0.05, r * 0.7);
  ctx.strokeStyle = p.flash ? '#fff' : '#2b2f38';
  ctx.lineWidth = r * 0.06;
  ctx.beginPath();
  ctx.moveTo(-r * 0.7, -r * 0.05);
  ctx.lineTo(-r * 0.85, -r * 0.7);
  ctx.stroke();
  ctx.fillStyle = p.flash ? '#fff' : ((t * 3).floor() % 2 != 0 ? '#ff4d4d' : '#7dffcf');
  ellipse(ctx, -r * 0.85, -r * 0.72, r * 0.08, r * 0.08);
  ctx.fill();
  feet(p, walk, '#3a3a3a');
  roundBody(ctx, r, -r * 0.05, r * 0.88, r * 1.0, r * 1.15);
  paint(p, '#e8892c', -r * 0.05, r * 0.9);
  ctx.fillStyle = p.flash ? '#fff' : '#a85b17';
  ctx.fillRect(-r * 0.3, -r * 0.04, r * 0.1, r * 0.5);
  ctx.fillRect(r * 0.2, -r * 0.04, r * 0.1, r * 0.5);
  ctx.fillStyle = p.flash ? '#fff' : '#4a3a2a';
  ctx.fillRect(-r * 0.52, r * 0.45, r * 1.04, r * 0.13);
  ctx.fillStyle = p.flash ? '#fff' : '#9aa3b5';
  ctx.fillRect(-r * 0.15, r * 0.47, r * 0.1, r * 0.25);
  ctx.fillRect(r * 0.1, r * 0.47, r * 0.08, r * 0.2);
  final (hx, hy) = head(p);
  eyes(p, hx, hy + r * 0.1, ly);
  // hard hat + goggles
  ctx.beginPath();
  ctx.arc(hx, hy - r * 0.24, r * 0.62, math.pi, tau);
  ctx.closePath();
  paint(p, '#ffd166', hy - r * 0.87, hy - r * 0.22);
  ctx.beginPath();
  ctx.roundRect(hx - r * 0.7, hy - r * 0.32, r * 1.5, r * 0.14, r * 0.07);
  paint(p, '#f2b84b', hy - r * 0.32, hy - r * 0.18);
  for (final dx in [0.0, 0.36]) {
    ellipse(ctx, hx + dx * r, hy - r * 0.44, r * 0.15, r * 0.12);
    paint(p, '#7dffcf', hy - r * 0.57, hy - r * 0.32);
  }
  // wrench
  held(p, r * 0.62, r * 0.38, a - 0.3, () {
    ctx.beginPath();
    ctx.roundRect(-r * 0.1, -r * 0.08, r * 1.1, r * 0.16, r * 0.06);
    paint(p, '#9aa3b5', -r * 0.08, r * 0.08);
    ctx.beginPath();
    ctx.arc(r * 1.1, 0, r * 0.25, 0.7, tau - 0.7);
    ctx.lineTo(r * 1.1, 0);
    ctx.closePath();
    paint(p, '#b8c0d0', -r * 0.25, r * 0.25);
  });
  hand(p, r * 0.62, r * 0.38, '#3a3a3a');
}
