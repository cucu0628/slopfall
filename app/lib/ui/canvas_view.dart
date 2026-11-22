import 'package:flutter/widgets.dart';

import '../render/canvas2d.dart';
import '../render/heroes/index.dart';

/// Paints with the Canvas 2D port (hero portraits, enemy plates).
class CanvasView extends StatelessWidget {
  final double width, height;
  final void Function(Ctx2D g, Size size) draw;
  const CanvasView({super.key, required this.width, required this.height, required this.draw});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(width, height), painter: _Painter(draw));
}

class _Painter extends CustomPainter {
  final void Function(Ctx2D g, Size size) draw;
  _Painter(this.draw);

  @override
  void paint(Canvas canvas, Size size) {
    final g = Ctx2D(canvas);
    draw(g, size);
    g.dispose();
  }

  @override
  bool shouldRepaint(covariant _Painter old) => false;
}

/// A hero standing on a shadow, as on the character select screen.
class HeroPortrait extends StatelessWidget {
  final String charId;
  final double size;
  const HeroPortrait(this.charId, {super.key, this.size = 88});

  @override
  Widget build(BuildContext context) => CanvasView(
        width: size,
        height: size,
        draw: (g, s) {
          g.scale(s.width / 72, s.width / 72);
          g.fillStyle = 'rgba(0,0,0,0.35)';
          g.beginPath();
          g.ellipse(32, 60, 16, 5, 0, 0, 6.283185307179586);
          g.fill();
          drawCharacterBody(g, charId, 32, 45, 15, 0.8, 0.25, 0);
        },
      );
}
