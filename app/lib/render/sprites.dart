// Pre-rendered radial glow sprites, so we don't need blurs per entity.

import 'dart:ui';

import 'canvas2d.dart';

final _cache = <String, Image2D>{};

/// `rgba(r,g,b,a)` from a hex colour.
Color rgba(String hex, num a) => withAlpha(hex, a.toDouble());

Image2D _glowSprite(String color) {
  return _cache.putIfAbsent(color, () {
    // 128 px so large glows (torches, bosses) stay smooth when scaled up
    return offscreen(128, 128, (g) {
      final grad = g.createRadialGradient(64, 64, 0, 64, 64, 64);
      grad.addColorStop(0, rgba(color, 0.85));
      grad.addColorStop(0.3, rgba(color, 0.35));
      grad.addColorStop(1, rgba(color, 0));
      g.fillStyle = grad;
      g.fillRect(0, 0, 128, 128);
    });
  });
}

/// Draws an additive glow. Caller is expected to have set globalCompositeOperation = 'lighter'.
void glow(Ctx2D ctx, String color, num x, num y, num r, [num alpha = 1]) {
  ctx.globalAlpha = alpha;
  ctx.drawImage(_glowSprite(color), x - r, y - r, r * 2, r * 2);
}
