import 'dart:math' as math;

import '../entities.dart';
import '../js.dart';
import '../types.dart';

// Anti-AFK: a player who stays within idleRadius of the same spot without
// really moving for idleGrace seconds gets meteors dropped on them, each
// stronger than the last. Moving counts even inside the radius: dodging back
// and forth or circling a boss must not look like standing still.
const double idleRadius = 160;
const double idleGrace = 8;
const double idleWarning = 3; // HUD warns this many seconds before the first meteor
/// A tick counts as moving when the player covers this share of their own speed (web slow is 0.55).
const double _movingShare = 0.3;

/// Moving winds the idle timer back this many times faster than standing winds it up.
const double _moveDrain = 1.5;
const double _skyfallEvery = 2.5;
const double _skyfallRadius = 110;
const double _skyfallWarn = 1.1;

const double _necroHealPerSec = 4;

void updateIdle(GameState s, Player p, double dt) {
  if (p.charId == 'necro') p.healBudget = math.min(_necroHealPerSec, p.healBudget + _necroHealPerSec * dt);
  final lsCap = p.stats.maxHp * p.stats.lifestealCap;
  p.lsBudget = math.min(lsCap, p.lsBudget + lsCap * dt);

  final ax = p.x - p.anchorX, ay = p.y - p.anchorY;
  if (ax * ax + ay * ay > idleRadius * idleRadius) {
    p.anchorX = p.x;
    p.anchorY = p.y;
    p.idleT = 0;
    p.skyfallCd = 0;
    p.skyfallN = 0;
    return;
  }
  // px/py hold the position from the start of this tick; pushing into a wall barely moves you, so it still counts as idle
  final moved = hypot(p.x - p.px, p.y - p.py);
  if (moved >= p.stats.speed * dt * _movingShare) {
    p.idleT = math.max(0, p.idleT - dt * _moveDrain);
  } else {
    p.idleT += dt;
  }
  if (p.idleT < idleGrace) {
    // back out of the danger zone: the next idle streak starts with the weakest meteor again
    p.skyfallCd = 0;
    p.skyfallN = 0;
    return;
  }
  p.skyfallCd -= dt;
  if (p.skyfallCd > 0) return;
  p.skyfallCd = _skyfallEvery;
  p.skyfallN++;
  // % of max HP so it matters at any point of the run; armor is added back so it can't be tanked
  final dmg = (p.stats.maxHp * (0.25 + 0.1 * (p.skyfallN - 1)) + p.stats.armor) / (1 - p.stats.dr);
  addHazard(s, 'skyfall', x: p.x, y: p.y, r: _skyfallRadius, warn: _skyfallWarn, life: 0.3, dmg: dmg);
  s.events.add(const SfxEvent('warn'));
}
