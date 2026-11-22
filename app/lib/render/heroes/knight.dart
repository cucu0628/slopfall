// Knight: armour, cape, shield, sword.

import 'shared.dart';

void knight(Pen p, double walk, double a, double ly, String accent) {
  final ctx = p.ctx, r = p.r;
  // cape
  ctx.beginPath();
  ctx.moveTo(-r * 0.45, -r * 0.02);
  ctx.quadraticCurveTo(-r * 1.0, r * 0.5, -r * 0.85, r * 1.0);
  ctx.lineTo(r * 0.1, r * 0.92);
  ctx.lineTo(r * 0.2, 0);
  ctx.closePath();
  paint(p, '#2c4fae', 0, r);
  feet(p, walk, '#59647a');
  roundBody(ctx, r, -r * 0.05, r * 0.88, r * 1.05, r * 1.25);
  paint(p, '#b8c2d4', -r * 0.05, r * 0.9);
  // tabard + belt
  ctx.beginPath();
  ctx.rect(-r * 0.05, r * 0.02, r * 0.42, r * 0.8);
  paint(p, accent, 0, r * 0.8, false);
  ctx.fillStyle = p.flash ? '#fff' : '#ffd166';
  ctx.fillRect(-r * 0.55, r * 0.42, r * 1.1, r * 0.1);
  // shield on the off hand
  ctx.beginPath();
  ctx.moveTo(-r * 0.95, r * 0.05);
  ctx.lineTo(-r * 0.3, r * 0.05);
  ctx.quadraticCurveTo(-r * 0.3, r * 0.75, -r * 0.62, r * 1.0);
  ctx.quadraticCurveTo(-r * 0.95, r * 0.75, -r * 0.95, r * 0.05);
  ctx.closePath();
  paint(p, '#3157c4', 0, r);
  ctx.fillStyle = p.flash ? '#fff' : '#ffd166';
  ctx.fillRect(-r * 0.66, r * 0.15, r * 0.08, r * 0.6);
  ctx.fillRect(-r * 0.85, r * 0.35, r * 0.45, r * 0.08);
  // helmet
  final (hx, hy) = head(p, '#cfd7e6');
  ctx.fillStyle = p.flash ? '#fff' : '#141824';
  ctx.beginPath();
  ctx.roundRect(hx - r * 0.05, hy - r * 0.08 + ly * r * 0.08, r * 0.62, r * 0.17, r * 0.06);
  ctx.fill();
  ctx.strokeStyle = p.flash ? '#fff' : '#8e99ad';
  ctx.lineWidth = r * 0.07;
  ctx.beginPath();
  ctx.moveTo(hx + r * 0.05, hy - r * 0.55);
  ctx.lineTo(hx + r * 0.05, hy + r * 0.45);
  ctx.stroke();
  // plume
  ctx.beginPath();
  ctx.moveTo(hx - r * 0.05, hy - r * 0.55);
  ctx.quadraticCurveTo(hx - r * 0.3, hy - r * 1.25, hx - r * 0.95, hy - r * 0.75);
  ctx.quadraticCurveTo(hx - r * 0.45, hy - r * 0.85, hx + r * 0.15, hy - r * 0.5);
  ctx.closePath();
  paint(p, accent, hy - r * 1.2, hy - r * 0.5);
  // sword
  held(p, r * 0.6, r * 0.35, a - 0.5, () {
    ctx.beginPath();
    ctx.moveTo(r * 0.25, -r * 0.09);
    ctx.lineTo(r * 1.55, -r * 0.06);
    ctx.lineTo(r * 1.75, 0);
    ctx.lineTo(r * 1.55, r * 0.06);
    ctx.lineTo(r * 0.25, r * 0.09);
    ctx.closePath();
    paint(p, '#e8eef8', -r * 0.1, r * 0.1);
    ctx.beginPath();
    ctx.roundRect(r * 0.15, -r * 0.32, r * 0.13, r * 0.64, r * 0.05);
    paint(p, '#ffd166', -r * 0.3, r * 0.3);
    ctx.beginPath();
    ctx.rect(-r * 0.12, -r * 0.06, r * 0.28, r * 0.12);
    paint(p, '#6b4a2b', -r * 0.06, r * 0.06);
  });
  hand(p, r * 0.6, r * 0.35, '#9aa7bd');
}
