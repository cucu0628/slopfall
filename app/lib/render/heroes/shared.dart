// Drawing primitives for the hero figures: shaded, outlined shapes, feet,
// eyes, head, hands and a helper to draw held weapons.

import 'dart:math' as math;

import '../canvas2d.dart';

const double tau = math.pi * 2;

const String outline = '#0a0c14';

const String skin = '#f0c39d';

class Pen {
  final Ctx2D ctx;
  final double r;
  final bool flash;
  const Pen(this.ctx, this.r, this.flash);
}

/// Fills the current path with a colour + shading overlay, then outlines it.
void paint(Pen p, Object color, double y0, double y1, [bool withOutline = true]) {
  final ctx = p.ctx;
  ctx.fillStyle = p.flash ? '#ffffff' : color;
  ctx.fill();
  if (!p.flash) {
    final g = ctx.createLinearGradient(0, y0, 0, y1);
    g.addColorStop(0, 'rgba(255,255,255,0.2)');
    g.addColorStop(0.45, 'rgba(255,255,255,0)');
    g.addColorStop(1, 'rgba(0,0,0,0.32)');
    ctx.fillStyle = g;
    ctx.fill();
  }
  if (withOutline) {
    ctx.strokeStyle = outline;
    ctx.lineWidth = p.r * 0.11;
    ctx.lineJoin = 'round';
    ctx.stroke();
  }
}

void ellipse(Ctx2D ctx, double x, double y, double rx, double ry, [double rot = 0]) {
  ctx.beginPath();
  ctx.ellipse(x, y, rx, ry, rot, 0, tau);
}

void roundBody(Ctx2D ctx, double r, double top, double bottom, double wTop, double wBottom) {
  ctx.beginPath();
  ctx.moveTo(-wTop / 2, top + r * 0.12);
  ctx.quadraticCurveTo(-wTop / 2, top, -wTop / 2 + r * 0.15, top);
  ctx.lineTo(wTop / 2 - r * 0.15, top);
  ctx.quadraticCurveTo(wTop / 2, top, wTop / 2, top + r * 0.12);
  ctx.lineTo(wBottom / 2, bottom - r * 0.1);
  ctx.quadraticCurveTo(wBottom / 2, bottom, wBottom / 2 - r * 0.15, bottom);
  ctx.lineTo(-wBottom / 2 + r * 0.15, bottom);
  ctx.quadraticCurveTo(-wBottom / 2, bottom, -wBottom / 2, bottom - r * 0.1);
  ctx.closePath();
}

void feet(Pen p, double walk, String color) {
  final ctx = p.ctx, r = p.r;
  final s = math.sin(walk);
  for (final (side, ph) in [(-1.0, s), (1.0, -s)]) {
    ellipse(ctx, side * r * 0.3 + ph * r * 0.18, r * 0.95 - math.max(0, ph) * r * 0.1, r * 0.26, r * 0.17);
    paint(p, color, r * 0.8, r * 1.1);
  }
}

void eyes(Pen p, double hx, double hy, double ly, [String color = '#141824']) {
  final ctx = p.ctx, r = p.r;
  // Looking down moves the eyes down; looking up barely moves them so they
  // never slide under a hat brim. The glint shows the look direction instead.
  final ey = hy + (ly > 0 ? ly * 0.1 : ly * 0.03) * r;
  ctx.fillStyle = p.flash ? '#ffffff' : color;
  for (final dx in [0.02, 0.32]) {
    ellipse(ctx, hx + dx * r, ey, r * 0.07, r * 0.11);
    ctx.fill();
  }
  if (!p.flash) {
    ctx.fillStyle = 'rgba(255,255,255,0.9)';
    for (final dx in [0.04, 0.34]) {
      ellipse(ctx, hx + dx * r, ey - r * 0.04 + math.min(0, ly) * r * 0.035, r * 0.025, r * 0.035);
      ctx.fill();
    }
  }
}

(double, double) head(Pen p, [String color = skin]) {
  final ctx = p.ctx, r = p.r;
  final hx = r * 0.04, hy = -r * 0.5;
  ellipse(ctx, hx, hy, r * 0.6, r * 0.57);
  paint(p, color, hy - r * 0.6, hy + r * 0.6);
  // cheek blush
  if (!p.flash && color == skin) {
    ctx.fillStyle = 'rgba(230,110,110,0.3)';
    ellipse(ctx, hx + r * 0.35, hy + r * 0.18, r * 0.1, r * 0.06);
    ctx.fill();
  }
  return (hx, hy);
}

void hand(Pen p, double x, double y, [String color = skin]) {
  ellipse(p.ctx, x, y, p.r * 0.15, p.r * 0.15);
  paint(p, color, y - p.r * 0.15, y + p.r * 0.15);
}

/// Runs [fn] in a frame rotated around the weapon grip.
void held(Pen p, double gx, double gy, double a, void Function() fn) {
  final ctx = p.ctx;
  ctx.save();
  ctx.translate(gx, gy);
  ctx.rotate(a);
  fn();
  ctx.restore();
}
