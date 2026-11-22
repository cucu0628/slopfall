import 'dart:math' as math;

import 'package:nightfall_sim/nightfall_sim.dart';

import 'canvas2d.dart';
import 'effects.dart';
import 'renderer.dart';
import 'sprites.dart';

const String _font = 'system-ui, "Segoe UI", sans-serif';

final Stopwatch _clock = Stopwatch()..start();

String fmtTime(double sec) {
  final m = (sec / 60).floor(), s = (sec % 60).floor();
  return '$m:${s.toString().padLeft(2, '0')}';
}

void _text(Ctx2D ctx, String str, double x, double y, double size, String color, [String align = 'left', String weight = 'bold']) {
  ctx.font = '$weight ${jsNum(size)}px $_font';
  ctx.textAlign = align;
  ctx.lineWidth = math.max(2, size / 5);
  ctx.strokeStyle = 'rgba(0,0,0,0.75)';
  ctx.strokeText(str, x, y);
  ctx.fillStyle = color;
  ctx.fillText(str, x, y);
}

void _bar(Ctx2D ctx, double x, double y, double w, double h, double k, String color, [String bg = 'rgba(0,0,0,0.55)']) {
  ctx.fillStyle = bg;
  ctx.fillRect(x, y, w, h);
  ctx.fillStyle = color;
  ctx.fillRect(x, y, w * math.max(0, math.min(1, k)), h);
  ctx.strokeStyle = 'rgba(255,255,255,0.18)';
  ctx.lineWidth = 1;
  ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
}

void drawHud(Ctx2D ctx, Renderer r, GameState s, Player me, Effects fx) {
  final w0 = r.w, h0 = r.h;
  ctx.textBaseline = 'alphabetic';

  // damage vignette
  final low = 1 - me.hp / me.stats.maxHp;
  final vig = math.max(fx.hurtFlash, low > 0.65 ? (low - 0.65) * 1.5 * (0.7 + math.sin(fx.time * 6) * 0.3) : 0.0);
  if (vig > 0.01) {
    final g = ctx.createRadialGradient(w0 / 2, h0 / 2, math.min(w0, h0) * 0.3, w0 / 2, h0 / 2, math.max(w0, h0) * 0.7);
    g.addColorStop(0, 'rgba(255,0,0,0)');
    g.addColorStop(1, withAlpha('#ff001e', math.min(0.55, vig)));
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, w0, h0);
  }

  // XP bar
  _bar(ctx, 0, 0, w0, 12, me.xp / me.xpNext, '#4fa3ff', 'rgba(10,14,30,0.85)');
  _text(ctx, 'LV ${me.level}', w0 - 10, 30, 16, '#bfe0ff', 'right');

  // HP
  final hpW = math.min(260.0, w0 * 0.3);
  _bar(ctx, 16, 22, hpW, 16, me.hp / me.stats.maxHp, '#ff4d6d');
  _text(ctx, '${me.hp.ceil()} / ${roundInt(me.stats.maxHp)}', 16 + hpW / 2, 35, 12, '#fff', 'center');
  final c = characterDefs[me.charId]!;
  _text(ctx, c.name, 16, 56, 13, c.accent);

  // Wave and time
  final w = s.wave;
  _text(ctx, w.bossWave ? 'WAVE ${w.n} · BOSS' : 'WAVE ${w.n}', w0 / 2, 38, 22, w.bossWave ? '#ff5d7a' : '#ffffff', 'center');
  final secret = w.bossWave && s.enemies.any((e) => e.type == 'goldfang');
  final sub = secret ? 'Catch him before he escapes!' : (w.bossWave ? 'Defeat the boss!' : 'next wave in ${w.timer.ceil()}s');
  _text(ctx, sub, w0 / 2, 56, 12, secret ? '#ffc83d' : '#aab4d4', 'center', 'normal');
  _text(ctx, fmtTime(s.time), w0 - 10, 52, 15, '#ffffff', 'right');
  _text(ctx, '☠ ${s.kills}', w0 - 10, 72, 14, '#ffb3b3', 'right');
  final mm = jsRound(math.min(160, w0 * 0.18));
  r.minimap.draw(ctx, s, me, w0 - mm - 12, 84, mm, fx.time);

  // Boss bars
  final bosses = s.enemies.where((e) => e.boss).toList();
  for (var i = 0; i < bosses.length; i++) {
    final b = bosses[i];
    final bw = math.min(520.0, w0 * 0.6), bx = (w0 - bw) / 2, by = 80.0 + i * 34;
    if (b.type == 'goldfang') {
      // the secret boss runs on a clock: b.t is his escape timer
      _text(ctx, '${enemyDefs[b.type]!.name.toUpperCase()} · ESCAPES IN ${math.max(0.0, b.t).ceil()}s', w0 / 2, by - 2, 13, '#ffe08a', 'center');
      _bar(ctx, bx, by + 3, bw, 12, b.hp / b.maxHp, '#ffc83d');
      continue;
    }
    _text(ctx, enemyDefs[b.type]!.name.toUpperCase(), w0 / 2, by - 2, 13, '#ffd0dc', 'center');
    _bar(ctx, bx, by + 3, bw, 12, b.hp / b.maxHp, b.hp < b.maxHp * 0.5 ? '#ff2e5a' : '#d63a7a');
  }

  // anti-AFK warning
  if (!me.dead && me.idleT > idleGrace - idleWarning) {
    final blink = 0.55 + math.sin(fx.time * 10) * 0.45;
    ctx.globalAlpha = blink;
    _text(ctx, me.idleT >= idleGrace ? 'METEORS INCOMING — MOVE!' : 'MOVE! Standing still draws meteors', w0 / 2, h0 * 0.22, 20, '#ff9a3d', 'center');
    ctx.globalAlpha = 1;
  }

  if (r.touchMode) {
    _drawSlots(ctx, me, 16, 66, 26); // bottom of the screen belongs to the thumbs
  } else {
    _drawSlots(ctx, me, 16, h0 - 36 * 2 - 5 - 16, 36);
    _drawAbility(ctx, me, w0, h0);
  }
  _drawIndicators(ctx, r, s, me);

  // banners
  for (final b in fx.banners) {
    final k = b.life / b.max;
    final a = math.min(1.0, math.min(k * 4, (1 - k) * 8));
    ctx.globalAlpha = a;
    _text(ctx, b.text, w0 / 2, h0 * 0.3, 46, b.color, 'center', '900');
    if (b.sub.isNotEmpty) _text(ctx, b.sub, w0 / 2, h0 * 0.3 + 34, 18, '#e6e9f5', 'center');
    ctx.globalAlpha = 1;
  }
  for (var i = 0; i < fx.toasts.length; i++) {
    final b = fx.toasts[i];
    final k = b.life / b.max;
    ctx.globalAlpha = math.min(1, k * 4);
    final y = h0 * 0.62 + i * 46;
    _text(ctx, b.text, w0 / 2, y, 20, b.color, 'center');
    if (b.sub.isNotEmpty) _text(ctx, b.sub, w0 / 2, y + 20, 13, '#ffffff', 'center', 'normal');
    ctx.globalAlpha = 1;
  }
}

void _slot(Ctx2D ctx, double x, double y, double size, String icon, String color, int level, int max, bool evolved) {
  ctx.fillStyle = 'rgba(12,16,30,0.8)';
  ctx.fillRect(x, y, size, size);
  ctx.strokeStyle = evolved ? cssColor('#ffd166') : rgba(color, 0.7);
  ctx.lineWidth = evolved ? 2.5 : 1.5;
  ctx.strokeRect(x + 0.5, y + 0.5, size - 1, size - 1);
  ctx.font = 'bold ${jsNum(size * 0.55)}px $_font';
  ctx.textAlign = 'center';
  ctx.fillStyle = color;
  ctx.fillText(icon, x + size / 2, y + size * 0.62);
  ctx.font = 'bold ${jsNum(size * 0.3)}px $_font';
  ctx.textAlign = 'right';
  ctx.fillStyle = level >= max ? '#ffd166' : '#ffffff';
  ctx.fillText(level >= max ? (evolved ? '★' : 'MAX') : '$level', x + size - 3, y + size - 3);
}

void _drawSlots(Ctx2D ctx, Player me, double x0, double y1, double size) {
  const gap = 5.0;
  var x = x0;
  final y2 = y1 + size + gap;
  for (final w in me.weapons) {
    final d = weaponDefs[w.id]!;
    _slot(ctx, x, y1, size, d.icon, d.color, w.level, maxWeaponLevel, w.evolved);
    x += size + gap;
  }
  x = x0;
  for (final k in me.perks) {
    final d = perkDefs[k.id]!;
    _slot(ctx, x, y2, size, d.icon, d.color, k.level, d.max, false);
    x += size + gap;
  }
}

void _drawAbility(Ctx2D ctx, Player me, double w0, double h0) {
  final c = characterDefs[me.charId]!;
  const bigR = 30.0;
  final cx = w0 / 2, cy = h0 - bigR - 22;
  final ready = me.abilityCd <= 0;
  ctx.fillStyle = 'rgba(12,16,30,0.85)';
  ctx.beginPath();
  ctx.arc(cx, cy, bigR, 0, math.pi * 2);
  ctx.fill();
  if (!ready) {
    final k = me.abilityCd / math.max(0.01, me.abilityMaxCd);
    ctx.fillStyle = 'rgba(255,255,255,0.12)';
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, bigR, -math.pi / 2, -math.pi / 2 + math.pi * 2 * (1 - k));
    ctx.closePath();
    ctx.fill();
  }
  ctx.strokeStyle = ready ? c.accent : 'rgba(255,255,255,0.25)';
  ctx.lineWidth = ready ? 3 : 2;
  ctx.beginPath();
  ctx.arc(cx, cy, bigR, 0, math.pi * 2);
  ctx.stroke();
  if (ready) {
    ctx.strokeStyle = rgba(c.accent, 0.4 + math.sin(_clock.elapsedMilliseconds / 150) * 0.2);
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.arc(cx, cy, bigR + 4, 0, math.pi * 2);
    ctx.stroke();
  }
  _text(ctx, ready ? 'READY' : me.abilityCd.toStringAsFixed(1), cx, cy + 5, ready ? 12 : 16, ready ? c.accent : '#fff', 'center');
  _text(ctx, '${c.ability.name}  [SPACE]', cx, cy - bigR - 8, 12, '#dfe6ff', 'center');

  // ability level pips
  for (var i = 0; i < abilityMaxLevel; i++) {
    ctx.fillStyle = i < me.abilityLevel ? c.accent : 'rgba(255,255,255,0.18)';
    ctx.beginPath();
    ctx.arc(cx - ((abilityMaxLevel - 1) * 9) / 2 + i * 9, cy + bigR + 9, 3, 0, math.pi * 2);
    ctx.fill();
  }

  // dash
  const dr = 20.0;
  final dx = cx + bigR + 38, dy = cy + 6;
  final dReady = me.dashCd <= 0;
  ctx.fillStyle = 'rgba(12,16,30,0.85)';
  ctx.beginPath();
  ctx.arc(dx, dy, dr, 0, math.pi * 2);
  ctx.fill();
  if (!dReady) {
    ctx.fillStyle = 'rgba(255,255,255,0.12)';
    ctx.beginPath();
    ctx.moveTo(dx, dy);
    ctx.arc(dx, dy, dr, -math.pi / 2, -math.pi / 2 + math.pi * 2 * (1 - me.dashCd / math.max(0.01, me.dashMaxCd)));
    ctx.closePath();
    ctx.fill();
  }
  ctx.strokeStyle = dReady ? '#9ad8ff' : 'rgba(255,255,255,0.25)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(dx, dy, dr, 0, math.pi * 2);
  ctx.stroke();
  _text(ctx, '»', dx, dy + 6, 18, dReady ? '#9ad8ff' : '#8890a8', 'center');
  _text(ctx, 'SHIFT', dx, dy - dr - 6, 10, '#dfe6ff', 'center');
}

/// Arrows at the screen edge pointing to offscreen bosses and chests.
void _drawIndicators(Ctx2D ctx, Renderer r, GameState s, Player me) {
  final targets = <(double, double, String)>[];
  for (final e in s.enemies) {
    if (e.boss) targets.add((e.x, e.y, '#ff2e88'));
  }
  for (final p in s.pickups) {
    if (p.kind == 'chest' || p.kind == 'relic') targets.add((p.x, p.y, '#ffd166'));
  }
  for (final (tx, ty, color) in targets) {
    final (sx, sy) = r.screenOf(tx, ty);
    if (sx > 0 && sx < r.w && sy > 0 && sy < r.h) continue;
    final a = math.atan2(ty - me.y, tx - me.x);
    const m = 40.0;
    final ex = math.max(m, math.min(r.w - m, r.w / 2 + math.cos(a) * r.w));
    final ey = math.max(m + 60, math.min(r.h - m, r.h / 2 + math.sin(a) * r.h));
    ctx.save();
    ctx.translate(ex, ey);
    ctx.rotate(a);
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(16, 0);
    ctx.lineTo(-8, -10);
    ctx.lineTo(-4, 0);
    ctx.lineTo(-8, 10);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }
}
