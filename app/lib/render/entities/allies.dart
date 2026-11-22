// Turrets and raised minions.

import 'dart:math' as math;

import 'package:nightfall_sim/nightfall_sim.dart';

import '../canvas2d.dart';
import 'shared.dart';

void drawTurret(Ctx2D ctx, Turret tu, double t) {
  final fade = tu.life < 1.5 && (t * 8).floor() % 2 == 0 ? 0.5 : 1.0;
  ctx.globalAlpha = fade;
  ctx.fillStyle = '#2b3a40';
  ctx.fillRect(tu.x - 11, tu.y - 11, 22, 22);
  ctx.strokeStyle = '#7dffcf';
  ctx.lineWidth = 2;
  ctx.strokeRect(tu.x - 11, tu.y - 11, 22, 22);
  ctx.strokeStyle = '#c8fff0';
  ctx.lineWidth = 5;
  ctx.beginPath();
  ctx.moveTo(tu.x, tu.y);
  ctx.lineTo(tu.x + math.cos(tu.ang) * 18, tu.y + math.sin(tu.ang) * 18);
  ctx.stroke();
  ctx.fillStyle = '#7dffcf';
  circle(ctx, tu.x, tu.y, 5);
  ctx.fill();
  ctx.globalAlpha = 1;
}

void drawMinion(Ctx2D ctx, Minion m, double x, double y, double t) {
  ctx.globalAlpha = math.min(1, m.life) * 0.75;
  ctx.fillStyle = '#c084ff';
  ctx.beginPath();
  ctx.arc(x, y - 3, 10, math.pi, tau);
  for (var i = 0; i <= 3; i++) {
    ctx.lineTo(x + 10 - (i * 20) / 3, y + 8 + math.sin(t * 10 + i + m.id) * 2);
  }
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = '#2a0d40';
  circle(ctx, x - 3.5, y - 4, 2);
  ctx.fill();
  circle(ctx, x + 3.5, y - 4, 2);
  ctx.fill();
  ctx.globalAlpha = 1;
}
