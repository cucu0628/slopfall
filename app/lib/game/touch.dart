// State of the on-screen controls for phones/tablets: a floating joystick on
// the left, ability / dash buttons on the right. The widget that drives it
// lives in ui/touch_controls.dart.

import 'dart:math' as math;

import 'package:nightfall_sim/nightfall_sim.dart' show hypot;

const double stickRadius = 56;
/// Drag distance (px) on the ability button that maps to the maximum aim range.
const double aimDrag = 80;
const double _aimDeadzone = 14;

class TouchCast {
  final double dx, dy; // drag offset in px; meaningful when `dragged`
  final bool dragged; // false = quick tap, use auto-aim
  const TouchCast(this.dx, this.dy, this.dragged);
}

class TouchState {
  /// Touch controls are shown (a touch device, or a touch happened).
  bool enabled = false;
  /// Interactive only while a run is on screen.
  bool visible = false;
  double moveX = 0;
  double moveY = 0;
  bool ability = false;
  bool dash = false;
  /// Aim mode: the ability button is dragged to aim and fires on release.
  bool aimMode = false;
  bool aiming = false;
  double aimDX = 0;
  double aimDY = 0;
  TouchCast? _cast;

  // joystick origin and knob offset, for drawing
  int stickPointer = -1;
  double ox = 0, oy = 0, knobX = 0, knobY = 0;

  bool get active => enabled && visible;

  bool get aimDragged => hypot(aimDX, aimDY) > _aimDeadzone;

  void reset() {
    stickPointer = -1;
    moveX = moveY = 0;
    knobX = knobY = 0;
    ability = dash = false;
    aiming = false;
    _cast = null;
  }

  /// A finished aim-and-release cast, consumed once by the input sampler.
  TouchCast? consumeCast() {
    final c = _cast;
    _cast = null;
    return c;
  }

  void stickStart(int pointer, double x, double y) {
    stickPointer = pointer;
    ox = x;
    oy = y;
    stickMove(pointer, x, y);
  }

  void stickMove(int pointer, double x, double y) {
    if (pointer != stickPointer) return;
    final dx = x - ox, dy = y - oy;
    final d = hypot(dx, dy);
    final clamp = d > stickRadius ? stickRadius / d : 1.0;
    knobX = dx * clamp;
    knobY = dy * clamp;
    // small dead zone, then full speed quickly
    final k = d < 8 ? 0.0 : math.min(1.0, d / (stickRadius * 0.6));
    moveX = d > 0 ? (dx / d) * k : 0;
    moveY = d > 0 ? (dy / d) * k : 0;
  }

  void stickEnd(int pointer) {
    if (pointer != stickPointer) return;
    stickPointer = -1;
    moveX = moveY = 0;
    knobX = knobY = 0;
  }

  void abilityDown() {
    if (!aimMode) {
      ability = true;
      return;
    }
    aimDX = aimDY = 0;
    aiming = true;
  }

  /// Drag offset from the ability button centre.
  void abilityDrag(double dx, double dy) {
    if (!aiming) return;
    final d = hypot(dx, dy);
    if (d > aimDrag) {
      dx = (dx / d) * aimDrag;
      dy = (dy / d) * aimDrag;
    }
    aimDX = dx;
    aimDY = dy;
  }

  void abilityUp({required bool fire}) {
    ability = false;
    if (!aiming) return;
    aiming = false;
    if (fire) _cast = TouchCast(aimDX, aimDY, aimDragged);
  }
}
