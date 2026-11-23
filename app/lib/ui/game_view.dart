// The game canvas: a ticker advances the session every frame and a custom
// painter draws it. Mouse position and buttons feed the input.

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/session.dart';

class GameView extends StatefulWidget {
  final Session session;
  /// Called on any pointer press (audio unlock, touch detection).
  final void Function(PointerDownEvent e)? onPointerDown;

  /// An overlay (level up, pause, game over) covers the run: the last frame
  /// is kept as one blurred image instead of redrawing the whole world every
  /// frame, so the overlay's own animations stay smooth on phones.
  final bool frozen;

  const GameView({super.key, required this.session, this.onPointerDown, this.frozen = false});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final _Still _still = _Still();
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    widget.session.update(dt);
    if (!widget.frozen || _still.image == null) _frame.value++;
  }

  @override
  void didUpdateWidget(GameView old) {
    super.didUpdateWidget(old);
    if (!identical(old.session, widget.session)) {
      // a new run: restart the clock so the first frame doesn't jump
      _ticker.stop();
      _last = Duration.zero;
      _ticker.start();
    }
    if (old.frozen != widget.frozen || !identical(old.session, widget.session)) {
      _still.clear();
      _frame.value++;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _still.clear();
    super.dispose();
  }

  void _mouse(PointerEvent e) {
    if (e.kind != PointerDeviceKind.mouse) return;
    final inp = widget.session.input;
    if (inp == null) return;
    inp.mouseX = e.localPosition.dx;
    inp.mouseY = e.localPosition.dy;
    inp.mouseSeen = true;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: _mouse,
      onPointerMove: _mouse,
      onPointerDown: (e) {
        _mouse(e);
        widget.onPointerDown?.call(e);
        if (e.kind == PointerDeviceKind.mouse && e.buttons & kSecondaryMouseButton != 0) widget.session.input?.rmb = true;
      },
      onPointerUp: (e) {
        if (e.kind == PointerDeviceKind.mouse && e.buttons & kSecondaryMouseButton == 0) widget.session.input?.rmb = false;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        child: LayoutBuilder(
          builder: (context, c) {
            widget.session.renderer
              ..resize(c.maxWidth, c.maxHeight)
              ..dpr = MediaQuery.devicePixelRatioOf(context);
            return RepaintBoundary(
              child: CustomPaint(
                size: Size(c.maxWidth, c.maxHeight),
                painter: _GamePainter(widget.session, _frame, widget.frozen ? _still : null),
                isComplex: true,
                willChange: !widget.frozen,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  final Session session;
  final _Still? still;
  _GamePainter(this.session, Listenable frame, this.still) : super(repaint: frame);

  @override
  void paint(Canvas canvas, Size size) {
    session.renderer.resize(size.width, size.height);
    final s = still;
    if (s != null) {
      final img = s.capture(session, size, session.renderer.dpr);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low,
      );
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    session.paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GamePainter old) => !identical(old.session, session) || old.still != still;
}

/// The frozen frame behind an overlay, blurred like a CSS backdrop filter.
class _Still {
  ui.Image? image;
  Size _size = Size.zero;
  double _dpr = 0;

  ui.Image capture(Session session, Size size, double dpr) {
    final cached = image;
    if (cached != null && size == _size && dpr == _dpr) return cached;
    clear();
    final w = (size.width * dpr).ceil().clamp(1, 16384), h = (size.height * dpr).ceil().clamp(1, 16384);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(dpr)
      ..clipRect(Offset.zero & size);
    session.paint(c);
    final pic = rec.endRecording();
    final sharp = pic.toImageSync(w, h);
    pic.dispose();
    final rec2 = ui.PictureRecorder();
    Canvas(rec2).drawImage(sharp, Offset.zero, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 3 * dpr, sigmaY: 3 * dpr, tileMode: TileMode.clamp));
    final pic2 = rec2.endRecording();
    final img = pic2.toImageSync(w, h);
    pic2.dispose();
    sharp.dispose();
    _size = size;
    _dpr = dpr;
    return image = img;
  }

  void clear() {
    image?.dispose();
    image = null;
  }
}
