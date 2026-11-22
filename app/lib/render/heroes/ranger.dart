// Ranger: hood, quiver, bow.

import 'dart:math' as math;

import 'shared.dart';

void ranger(Pen p, double walk, double a, double ly) {
  final ctx = p.ctx, r = p.r;
  // quiver
  held(p, -r * 0.45, r * 0.2, -0.5, () {
    ctx.beginPath();
    ctx.roundRect(-r * 0.17, -r * 0.75, r * 0.34, r * 1.1, r * 0.1);
    paint(p, '#7a5230', -r * 0.75, r * 0.35);
    for (var i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.moveTo(-r * 0.12 + i * r * 0.12, -r * 0.75);
      ctx.lineTo(-r * 0.18 + i * r * 0.12, -r * 1.05);
      ctx.lineTo(-r * 0.04 + i * r * 0.12, -r * 0.95);
      ctx.closePath();
      paint(p, '#b6ff7a', -r, -r * 0.75, false);
    }
  });
  // cloak tail
  ctx.beginPath();
  ctx.moveTo(-r * 0.4, 0);
  ctx.quadraticCurveTo(-r * 0.95, r * 0.6, -r * 0.7, r * 0.95);
  ctx.lineTo(r * 0.1, r * 0.8);
  ctx.closePath();
  paint(p, '#24552a', 0, r);
  feet(p, walk, '#5a3f26');
  roundBody(ctx, r, -r * 0.05, r * 0.88, r * 0.95, r * 1.15);
  paint(p, '#2e6b31', -r * 0.05, r * 0.9);
  ctx.fillStyle = p.flash ? '#fff' : '#6b4a2b';
  ctx.fillRect(-r * 0.55, r * 0.4, r * 1.1, r * 0.12);
  ctx.fillStyle = p.flash ? '#fff' : '#d9b26a';
  ctx.fillRect(r * 0.05, r * 0.38, r * 0.16, r * 0.16);
  // hood back, face, hood rim
  ellipse(ctx, -r * 0.02, -r * 0.55, r * 0.68, r * 0.64);
  paint(p, '#3b8a3f', -r * 1.2, 0);
  ellipse(ctx, r * 0.18, -r * 0.45, r * 0.42, r * 0.42);
  paint(p, skin, -r * 0.9, 0, false);
  eyes(p, r * 0.05, -r * 0.47, ly);
  ctx.beginPath();
  ctx.arc(-r * 0.02, -r * 0.55, r * 0.68, math.pi * 1.02, math.pi * 1.88);
  ctx.quadraticCurveTo(r * 0.2, -r * 0.95, -r * 0.3, -r * 0.4);
  ctx.closePath();
  paint(p, '#3b8a3f', -r * 1.2, -r * 0.4);
  ctx.beginPath();
  ctx.moveTo(-r * 0.6, -r * 0.95);
  ctx.quadraticCurveTo(-r * 0.9, -r * 1.35, -r * 0.35, -r * 1.25);
  ctx.lineTo(-r * 0.3, -r * 1.0);
  ctx.closePath();
  paint(p, '#3b8a3f', -r * 1.35, -r * 0.95);
  // bow
  held(p, r * 0.7, r * 0.3, a, () {
    ctx.strokeStyle = p.flash ? '#fff' : outline;
    ctx.lineWidth = r * 0.24;
    ctx.beginPath();
    ctx.arc(-r * 0.3, 0, r * 0.95, -1.15, 1.15);
    ctx.stroke();
    ctx.strokeStyle = p.flash ? '#fff' : '#a0703a';
    ctx.lineWidth = r * 0.13;
    ctx.stroke();
    ctx.strokeStyle = p.flash ? '#fff' : 'rgba(230,230,230,0.8)';
    ctx.lineWidth = r * 0.04;
    ctx.beginPath();
    ctx.moveTo(-r * 0.3 + math.cos(-1.15) * r * 0.95, math.sin(-1.15) * r * 0.95);
    ctx.lineTo(-r * 0.3 + math.cos(1.15) * r * 0.95, math.sin(1.15) * r * 0.95);
    ctx.stroke();
  });
  hand(p, r * 0.62, r * 0.3);
}
