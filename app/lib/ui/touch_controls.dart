// On-screen controls for phones/tablets: a floating joystick on the left 60%
// of the screen, ability / dash buttons bottom right and a pause button next
// to the minimap.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/touch.dart';
import '../render/canvas2d.dart' show cssColor;

class TouchControls extends StatefulWidget {
  final TouchState state;
  final String abilityColor;
  final double abilityCd; // 0 = ready, 1 = just used
  final double dashCd;
  final VoidCallback onPause;

  const TouchControls({super.key, required this.state, required this.abilityColor, required this.abilityCd, required this.dashCd, required this.onPause});

  @override
  State<TouchControls> createState() => _TouchControlsState();
}

class _TouchControlsState extends State<TouchControls> {
  TouchState get t => widget.state;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final mm = math.min(160.0, size.width * 0.18);
    return Stack(
      children: [
        // joystick area
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) {
              if (t.stickPointer != -1 || e.localPosition.dx > size.width * 0.6) return;
              setState(() => t.stickStart(e.pointer, e.localPosition.dx, e.localPosition.dy));
            },
            onPointerMove: (e) => setState(() => t.stickMove(e.pointer, e.localPosition.dx, e.localPosition.dy)),
            onPointerUp: (e) => setState(() => t.stickEnd(e.pointer)),
            onPointerCancel: (e) => setState(() => t.stickEnd(e.pointer)),
            child: const SizedBox.expand(),
          ),
        ),
        if (t.stickPointer != -1)
          Positioned(
            left: t.ox - 62,
            top: t.oy - 62,
            child: IgnorePointer(child: CustomPaint(size: const Size(124, 124), painter: _Stick(t.knobX, t.knobY))),
          ),
        // ability: tap, or drag to aim (Mage) and release to cast
        Positioned(
          right: 22 + pad.right,
          bottom: 26 + pad.bottom,
          child: Listener(
            onPointerDown: (_) => setState(t.abilityDown),
            onPointerMove: (e) => setState(() => t.abilityDrag(e.localPosition.dx - 44, e.localPosition.dy - 44)),
            onPointerUp: (_) => setState(() => t.abilityUp(fire: true)),
            onPointerCancel: (_) => setState(() => t.abilityUp(fire: false)),
            child: _RoundButton(
              size: 88,
              label: '★',
              cd: widget.abilityCd,
              color: t.aiming ? const Color(0xffffb46b) : cssColor(widget.abilityColor),
              pressed: t.ability || t.aiming,
            ),
          ),
        ),
        Positioned(
          right: 124 + pad.right,
          bottom: 30 + pad.bottom,
          child: Listener(
            onPointerDown: (_) => setState(() => t.dash = true),
            onPointerUp: (_) => setState(() => t.dash = false),
            onPointerCancel: (_) => setState(() => t.dash = false),
            child: _RoundButton(size: 66, label: '»', cd: widget.dashCd, color: const Color(0xff9ad8ff), pressed: t.dash),
          ),
        ),
        Positioned(
          right: mm + 22 + pad.right,
          top: 84 + pad.top,
          child: Listener(
            onPointerDown: (_) => widget.onPause(),
            child: const _RoundButton(size: 44, label: '❚❚', cd: 0, color: Color(0x40ffffff), pressed: false, fontSize: 14, glow: false),
          ),
        ),
      ],
    );
  }
}

class _Stick extends CustomPainter {
  final double kx, ky;
  _Stick(this.kx, this.ky);

  @override
  void paint(Canvas c, Size s) {
    const center = Offset(62, 62);
    c.drawCircle(center, 61, Paint()..color = const Color(0x0fffffff));
    c.drawCircle(
        center,
        61,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x33ffffff));
    final knob = center + Offset(kx, ky);
    c.drawCircle(knob, 27, Paint()..color = const Color.fromRGBO(130, 170, 255, 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    c.drawCircle(knob, 27, Paint()..color = const Color(0x4dffffff));
  }

  @override
  bool shouldRepaint(_Stick old) => old.kx != kx || old.ky != ky;
}

class _RoundButton extends StatelessWidget {
  final double size, cd;
  final String label;
  final Color color;
  final bool pressed;
  final double fontSize;
  final bool glow;

  const _RoundButton({required this.size, required this.label, required this.cd, required this.color, required this.pressed, this.fontSize = 30, this.glow = true});

  @override
  Widget build(BuildContext context) {
    final ready = cd <= 0;
    return AnimatedScale(
      scale: pressed ? 0.94 : 1,
      duration: const Duration(milliseconds: 80),
      child: CustomPaint(
        size: Size.square(size),
        painter: _Cooldown(cd, ready && glow ? color : const Color(0x40ffffff), ready && glow),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: Text(label, style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w700))),
        ),
      ),
    );
  }
}

/// Conic cooldown fill: the dark sector is the remaining cooldown.
class _Cooldown extends CustomPainter {
  final double cd;
  final Color border;
  final bool glow;
  _Cooldown(this.cd, this.border, this.glow);

  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero);
    final r = s.width / 2;
    if (glow) {
      c.drawCircle(center, r, Paint()..color = border.withValues(alpha: 0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    }
    c.drawCircle(center, r, Paint()..color = const Color.fromRGBO(36, 46, 86, 0.8));
    if (cd > 0) {
      c.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, math.pi * 2 * cd.clamp(0, 1), true,
          Paint()..color = const Color.fromRGBO(6, 8, 18, 0.85));
    }
    c.drawCircle(
        center,
        r - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = border);
  }

  @override
  bool shouldRepaint(_Cooldown old) => old.cd != cd || old.border != border || old.glow != glow;
}
