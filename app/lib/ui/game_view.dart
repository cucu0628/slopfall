// The game canvas: a ticker advances the session every frame and a custom
// painter draws it. Mouse position and buttons feed the input.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/session.dart';

class GameView extends StatefulWidget {
  final Session session;
  /// Called on any pointer press (audio unlock, touch detection).
  final void Function(PointerDownEvent e)? onPointerDown;

  const GameView({super.key, required this.session, this.onPointerDown});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
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
    _frame.value++;
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
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
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
                painter: _GamePainter(widget.session, _frame),
                isComplex: true,
                willChange: true,
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
  _GamePainter(this.session, Listenable frame) : super(repaint: frame);

  @override
  void paint(Canvas canvas, Size size) {
    session.renderer.resize(size.width, size.height);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    session.paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GamePainter old) => !identical(old.session, session);
}
