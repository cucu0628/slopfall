// Small drawing helpers shared by the entity renderers.

import 'dart:math' as math;

import '../canvas2d.dart';

const double tau = math.pi * 2;

void circle(Ctx2D ctx, num x, num y, num r) {
  ctx.beginPath();
  ctx.arc(x, y, r, 0, tau);
}

void eyes(Ctx2D ctx, double x, double y, double r, double dx, double dy, String color, double size) {
  ctx.fillStyle = color;
  circle(ctx, x - r * 0.3 + dx * 1.5, y + dy * 1.5, size);
  ctx.fill();
  circle(ctx, x + r * 0.3 + dx * 1.5, y + dy * 1.5, size);
  ctx.fill();
}

final math.Random fxRandom = math.Random();

/// Math.random() for purely visual jitter.
double rnd() => fxRandom.nextDouble();
