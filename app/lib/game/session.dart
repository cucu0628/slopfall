// Runs one game: fixed-timestep simulation, event -> effects translation and
// rendering. In demo mode a simple bot drives the player (main menu backdrop).

import 'dart:math' as math;
import 'dart:ui' show Canvas;

import 'package:nightfall_sim/nightfall_sim.dart';

import '../render/effects.dart';
import '../render/renderer.dart';
import 'input.dart';
import 'touch.dart';

const String localId = 'p1';

/// What the session needs from the audio engine.
abstract interface class SoundSink {
  void play(String name);
}

class Session {
  final String charId;
  final Renderer renderer;
  final Input? input;
  final SoundSink? sound;
  final void Function(GameState s)? onFrame;
  final void Function(GameState s)? onGameOver;
  late final GameState state;
  final Effects fx = Effects();
  bool paused = false;
  double _acc = 0;
  double _overT = 0;
  bool _overFired = false;
  double _lastDodge = -1;

  bool get demo => input == null;

  Session(this.charId, this.renderer, {this.input, this.sound, this.onFrame, this.onGameOver, GameState? initial}) {
    final seed = math.Random().nextInt(1 << 31);
    state = initial ?? createGame(seed, [PlayerSetup(localId, charId)], godMode: input == null);
  }

  InputCmd _command() {
    final s = state;
    final me = s.players[0];
    final inp = input;
    if (inp == null) return _botCommand();
    final (sx, sy) = renderer.screenOf(me.x, me.y);
    final cmd = inp.sample(sx, sy, renderer.scale);
    if (inp.usingTouch) {
      final cast = inp.lastCast;
      if (cast != null && cast.dragged) {
        // aimed by dragging the ability button
        final (ax, ay) = _touchAimOffset(cast.dx, cast.dy);
        cmd
          ..ax = ax
          ..ay = ay;
      } else {
        // no mouse on touch screens: aim at the nearest enemy, else straight ahead
        final e = nearestEnemy(s, me.x, me.y, 700);
        cmd
          ..ax = e != null ? e.x - me.x : me.fx * 120
          ..ay = e != null ? e.y - me.y : me.fy * 120;
      }
    }
    return cmd;
  }

  /// Ability-button drag (px) to a world offset; full drag = max meteor range,
  /// kept inside the visible area so the target is always on screen.
  (double, double) _touchAimOffset(double dx, double dy) {
    const k = meteorRange / aimDrag;
    final r = renderer;
    final hw = (r.w / 2 / r.scale) * 0.9, hh = (r.h / 2 / r.scale) * 0.9;
    return (math.max(-hw, math.min(hw, dx * k)), math.max(-hh, math.min(hh, dy * k)));
  }

  /// Target marker while the player drags the ability button.
  void _updateAimPreview() {
    final t = input?.touch;
    final me = state.players[0];
    if (t == null || !t.aiming || !t.aimDragged || me.dead) {
      renderer.aimPreview = null;
      return;
    }
    final (ax, ay) = _touchAimOffset(t.aimDX, t.aimDY);
    final r = 170 * me.stats.area * (1 + 0.12 * (me.abilityLevel - 1));
    renderer.aimPreview = AimPreview(me.x + ax, me.y + ay, r);
  }

  InputCmd _botCommand() {
    final s = state;
    final p = s.players[0];
    var rx = math.cos(s.time / 4), ry = math.sin(s.time / 4);
    for (final e in s.enemies) {
      final dx = p.x - e.x, dy = p.y - e.y, d2 = dx * dx + dy * dy;
      if (d2 < 160 * 160) {
        rx += (dx / d2) * 300;
        ry += (dy / d2) * 300;
      }
    }
    final e = nearestEnemy(s, p.x, p.y, 500);
    return InputCmd(
      mx: rx,
      my: ry,
      ax: e != null ? e.x - p.x : 100,
      ay: e != null ? e.y - p.y : 0,
      ability: e != null && s.tick % 600 < 5,
      choose: p.choices != null ? s.tick % 3 : -1,
    );
  }

  /// Advances by [real] seconds of wall time (capped) and lets the renderer catch up.
  void update(double real) {
    real = math.min(0.1, real);
    final s = state;
    if (!paused) {
      _acc += real;
      var n = 0;
      while (_acc >= dt60 && n < 5) {
        step(s, {localId: _command()});
        _handleEvents(s.events);
        for (final p in s.players) {
          if (p.dashT > 0 && s.tick % 2 == 0) fx.ghost(p.x, p.y, p.radius, characterDefs[p.charId]!.accent);
        }
        _acc -= dt60;
        n++;
      }
      if (n == 5) _acc = 0;
      fx.update(real);
    }
    if (input != null) _updateAimPreview();
    onFrame?.call(s);

    if (s.gameOver && !_overFired) {
      _overT += real;
      if (_overT > 1.6) {
        _overFired = true;
        onGameOver?.call(s);
      }
    }
  }

  void paint(Canvas canvas) {
    final s = state;
    final alpha = paused || isFrozen(s) || s.gameOver ? 1.0 : _acc / dt60;
    renderer.draw(canvas, s, localId, alpha, fx, hud: input != null);
  }

  void _handleEvents(List<SimEvent> events) {
    final snd = sound, s = state;
    final me = s.players[0];
    for (final ev in events) {
      switch (ev) {
        case HitEvent():
          if ((ev.x - me.x).abs() < 900 && (ev.y - me.y).abs() < 600) {
            if (ev.dot) {
              fx.text(ev.x, ev.y, '${ev.v}', '#ff9a3d', 11, 0.5);
            } else {
              fx.text(ev.x, ev.y, '${ev.v}', ev.crit ? '#ffd166' : '#ffffff', ev.crit ? 18 : 13);
            }
            if (ev.crit) fx.burst(ev.x, ev.y, '#ffd166', 3, 120, 2, 0.3);
          }
          snd?.play('hit');
        case KillEvent():
          final color = enemyDefs[ev.type]?.color ?? '#fff';
          if (ev.boss && ev.type == 'goldfang') {
            fx.burst(ev.x, ev.y, '#ffc83d', 90, 520, 6, 1.3);
            fx.ring(ev.x, ev.y, 260, '#ffc83d', 0.8, 12);
            fx.addShake(18);
            fx.banner('GOLDFANG CAUGHT!', 'He dropped his treasure. Grab it!', '#ffc83d', 3);
            snd?.play('victory');
            snd?.play('coin');
          } else if (ev.boss) {
            fx.burst(ev.x, ev.y, color, 80, 500, 7, 1.2);
            fx.burst(ev.x, ev.y, '#ffffff', 40, 300, 4, 0.8);
            fx.ring(ev.x, ev.y, 300, color, 0.8, 14);
            fx.addShake(22);
            fx.banner('BOSS DEFEATED', '${enemyDefs[ev.type]!.name} has fallen', '#ffd166', 3);
            snd?.play('victory');
            snd?.play('explode');
          } else {
            fx.burst(ev.x, ev.y, color, ev.elite ? 30 : 7, ev.elite ? 260 : 150, ev.elite ? 5 : 3);
            snd?.play('kill');
          }
        case PlayerHurtEvent():
          if (ev.pid == localId) {
            fx.hurtFlash = 0.55;
            fx.addShake(5);
            fx.text(me.x, me.y - 24, '-${ev.v}', '#ff4d4d', 16);
            snd?.play('hurt');
          }
        case PlayerDeathEvent():
          fx.burst(me.x, me.y, characterDefs[me.charId]!.accent, 60, 300, 5, 1.2);
          fx.addShake(16);
          snd?.play('death');
        case HealEvent():
          if (ev.pid == localId) fx.text(me.x, me.y - 24, '+${ev.v}', '#6bff8f', 15);
        case VigorEvent():
          if (ev.pid != localId) break;
          fx.toast('+${jsNum(ev.v)} MAX HP', 'Surviving the night hardens you', '#6bff8f');
          fx.ring(me.x, me.y, 110, '#6bff8f', 0.6, 6);
        case LevelUpEvent():
          if (ev.pid == localId) {
            fx.ring(me.x, me.y, 120, '#4fa3ff', 0.5, 6);
            snd?.play('levelup');
          }
        case WaveEvent():
          if (!ev.boss) {
            fx.banner('WAVE ${ev.n}', ev.n == 1 ? 'Survive the night' : 'They grow stronger...', '#ffffff', 2.2);
            snd?.play('wave');
          }
        case BossEvent():
          if (ev.id == 'goldfang') {
            fx.banner(ev.name.toUpperCase(), 'A secret merchant! Catch him before he escapes', '#ffc83d', 3.5);
            snd?.play('coin');
            break;
          }
          fx.banner(ev.name.toUpperCase(), 'Wave ${s.wave.n} boss', '#ff2e88', 3);
          fx.addShake(10);
          snd?.play('boss');
        case EscapeEvent():
          fx.burst(ev.x, ev.y, '#ffc83d', 50, 300, 4, 0.9);
          fx.banner('HE GOT AWAY!', '${ev.name} vanished with all his gold...', '#aab4d4', 3);
          snd?.play('coin');
        case UniqueEvent():
          if (ev.pid != localId) break;
          fx.banner('UNIQUE ITEM!', ev.name, '#ffc83d', 3.5);
          fx.toast(ev.name.toUpperCase(), ev.desc);
          fx.ring(me.x, me.y, 220, '#ffc83d', 0.8, 10);
          fx.burst(me.x, me.y, '#ffc83d', 60, 320, 5, 1);
          snd?.play('chest');
        case ExplodeEvent():
          fx.ring(ev.x, ev.y, ev.r, ev.color, 0.45, ev.r > 300 ? 20 : 8);
          if (ev.color != '#2ee6c5') {
            fx.burst(ev.x, ev.y, ev.color, math.min(50, 10 + ev.r / 8), ev.r * 2.5, 4, 0.5);
            snd?.play('explode');
          }
        case PickupEvent():
          if (ev.pid != localId) break;
          if (ev.kind == 'xp') {
            snd?.play('gem');
          } else if (ev.kind == 'coin') {
            snd?.play('coin');
          } else if (ev.kind != 'chest' && ev.kind != 'relic') {
            snd?.play('pickup');
            final label = ev.kind == 'heal' ? 'HEAL' : (ev.kind == 'magnet' ? 'MAGNET' : 'BOMB!');
            fx.text(me.x, me.y - 34, label, '#ffffff', 16, 1);
          }
        case ChestEvent():
          if (ev.pid != localId) break;
          snd?.play('chest');
          fx.toast('TREASURE CHEST', ev.items.join('  ·  '));
          fx.burst(me.x, me.y, '#ffd166', 40, 260, 4, 0.9);
        case EvolveEvent():
          if (ev.pid != localId) break;
          fx.banner('EVOLUTION!', ev.name, '#ffd166', 3);
          fx.ring(me.x, me.y, 200, '#ffd166', 0.7, 10);
          snd?.play('victory');
        case AbilityEvent():
          if (ev.pid == localId) {
            fx.ring(me.x, me.y, 90, characterDefs[me.charId]!.accent, 0.35, 6);
            snd?.play('ability');
          }
        case DashEvent():
          if (ev.pid == localId) snd?.play('dash');
        case DodgeEvent():
          if (ev.pid == localId && fx.time - _lastDodge > 0.4) {
            _lastDodge = fx.time;
            fx.text(me.x, me.y - 30, 'DODGE!', '#9ad8ff', 17, 0.8);
            snd?.play('select');
          }
        case SfxEvent():
          snd?.play(ev.name);
        case ShakeEvent():
          fx.addShake(ev.v);
      }
    }
  }
}
