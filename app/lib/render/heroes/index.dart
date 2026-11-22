// Hero figures: small "chibi" characters with feet, body, head, gear and a
// held weapon that follows the aim. Drawn facing right and mirrored when
// aiming left. Each hero has its own file in this folder.

import 'dart:math' as math;

import 'package:nightfall_sim/nightfall_sim.dart';

import '../canvas2d.dart';
import '../sprites.dart';
import 'berserker.dart';
import 'engineer.dart';
import 'knight.dart';
import 'mage.dart';
import 'necro.dart';
import 'ranger.dart';
import 'shared.dart';

/// Shared by the in-game player and the character select portraits.
/// [walk] is the walk-cycle phase (0 when idle).
void drawCharacterBody(Ctx2D ctx, String charId, double x, double y, double r, double ex, double ey, double t,
    [double walk = 0, bool flash = false]) {
  final c = characterDefs[charId]!;
  final p = Pen(ctx, r, flash);
  final bob = walk != 0 ? -math.sin(walk).abs() * r * 0.08 : math.sin(t * 3) * r * 0.03;
  ctx.save();
  ctx.translate(x, y + bob);
  if (ex < 0) ctx.scale(-1, 1);
  final a = math.max(-1.15, math.min(1.15, math.atan2(ey, ex.abs())));
  final ly = math.max(-1.0, math.min(1.0, ey));
  switch (charId) {
    case 'knight':
      knight(p, walk, a, ly, c.accent);
    case 'mage':
      mage(p, walk, a, ly, c.accent, t);
    case 'ranger':
      ranger(p, walk, a, ly);
    case 'necro':
      necro(p, walk, a, ly, c.accent, t);
    case 'engineer':
      engineer(p, walk, a, ly, t);
    case 'berserker':
      berserker(p, walk, a, ly);
  }
  ctx.restore();
}

void drawPlayer(Ctx2D ctx, Player pl, double x, double y, double t) {
  final c = characterDefs[pl.charId]!;
  final r = pl.radius * 1.2; // drawn a bit larger than the hitbox for readability
  final aim = math.atan2(pl.ay, pl.ax);
  final ex = math.cos(aim), ey = math.sin(aim);
  ctx.save();
  if (pl.invuln > 0 && pl.hurtT <= 0 && pl.dashT <= 0 && (t * 20).floor() % 2 == 0 && pl.abilityT <= 0) ctx.globalAlpha = 0.55;
  ctx.fillStyle = 'rgba(0,0,0,0.38)';
  ellipse(ctx, x, y + r * 1.02, r * 0.95, r * 0.32);
  ctx.fill();

  final moving = hypot(pl.x - pl.px, pl.y - pl.py) > 0.3;
  final walk = moving ? t * 14 : 0.0;
  drawCharacterBody(ctx, pl.charId, x, y, r, ex, ey, t, walk, pl.hurtT > 0.12);

  if (pl.slowT > 0) {
    // stuck in a web
    ctx.strokeStyle = 'rgba(235,235,245,0.75)';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    for (var i = 0; i < 6; i++) {
      final a = (i * tau) / 6 + 0.3;
      ctx.moveTo(x, y);
      ctx.lineTo(x + math.cos(a) * r * 1.5, y + math.sin(a) * r * 1.5);
    }
    ctx.stroke();
    ellipse(ctx, x, y, r * 0.9, r * 0.9);
    ctx.stroke();
  }
  if (pl.abilityT > 0) {
    if (pl.charId == 'knight') {
      ctx.strokeStyle = rgba(c.accent, 0.8);
      ctx.lineWidth = 3;
      ellipse(ctx, x, y - r * 0.2, r * 1.6 + math.sin(t * 12) * 2, r * 1.6 + math.sin(t * 12) * 2);
      ctx.stroke();
      ctx.fillStyle = rgba(c.accent, 0.1);
      ctx.fill();
    } else if (pl.charId == 'berserker') {
      ctx.strokeStyle = 'rgba(255,40,40,0.7)';
      ctx.lineWidth = 2;
      for (var i = 0; i < 6; i++) {
        final a = t * 4 + (i * tau) / 6;
        ctx.beginPath();
        ctx.moveTo(x + math.cos(a) * (r + 6), y + math.sin(a) * (r + 6));
        ctx.lineTo(x + math.cos(a) * (r + 14), y + math.sin(a) * (r + 14) - 6);
        ctx.stroke();
      }
    }
  }
  ctx.restore();
}
