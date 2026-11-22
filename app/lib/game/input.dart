// Keyboard / mouse state turned into simulation input commands.

import 'package:flutter/services.dart';
import 'package:nightfall_sim/nightfall_sim.dart';

import 'touch.dart';

final _up = {PhysicalKeyboardKey.keyW, PhysicalKeyboardKey.arrowUp, PhysicalKeyboardKey.keyZ};
final _down = {PhysicalKeyboardKey.keyS, PhysicalKeyboardKey.arrowDown};
final _left = {PhysicalKeyboardKey.keyA, PhysicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.keyQ};
final _right = {PhysicalKeyboardKey.keyD, PhysicalKeyboardKey.arrowRight};

class Input {
  final Set<PhysicalKeyboardKey> keys = {};
  double mouseX = 0;
  double mouseY = 0;
  bool mouseSeen = false;
  bool rmb = false;
  int _pendingChoose = -1;
  final TouchState touch;

  /// Touch aim-and-release cast picked up by the last sample (if any).
  TouchCast? lastCast;

  Input(this.touch);

  /// True while the on-screen touch controls drive the player (aim is automatic).
  bool get usingTouch => touch.active;

  void choose(int i) => _pendingChoose = i;

  void clear() {
    keys.clear();
    rmb = false;
  }

  bool _any(Set<PhysicalKeyboardKey> codes) => codes.any(keys.contains);

  /// [px], [py] are the player's on-screen position, [scale] the world-to-screen scale.
  InputCmd sample(double px, double py, double scale) {
    var mx = (_any(_right) ? 1.0 : 0.0) - (_any(_left) ? 1.0 : 0.0);
    var my = (_any(_down) ? 1.0 : 0.0) - (_any(_up) ? 1.0 : 0.0);
    final t = usingTouch ? touch : null;
    lastCast = t?.consumeCast();
    if (t != null && (t.moveX != 0 || t.moveY != 0)) {
      mx = t.moveX;
      my = t.moveY;
    }
    // until the mouse moves, aim a bit to the right of the player
    final ax = mouseSeen ? (mouseX - px) / scale : 100 / scale;
    final ay = mouseSeen ? (mouseY - py) / scale : 0.0;
    final cmd = InputCmd(
      mx: mx,
      my: my,
      ax: ax,
      ay: ay,
      ability: keys.contains(PhysicalKeyboardKey.space) || rmb || (t?.ability ?? false) || lastCast != null,
      dash: keys.contains(PhysicalKeyboardKey.shiftLeft) || keys.contains(PhysicalKeyboardKey.shiftRight) || (t?.dash ?? false),
      choose: _pendingChoose,
    );
    _pendingChoose = -1;
    return cmd;
  }
}
