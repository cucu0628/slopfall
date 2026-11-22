// Weapon / perk symbols centred on their ink. The symbol fonts place glyphs
// at different heights inside the text line (♨ sits high, ◎ low), so centring
// the line box is not enough: each glyph is drawn once offscreen, its visible
// bounds measured, and the correction cached.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:nightfall_sim/nightfall_sim.dart';

import 'canvas2d.dart' show iconFallback, uiFont;

const double _ref = 100; // measuring size
final Map<String, Offset> _offsets = {}; // ink centre correction, in font sizes

/// How far to move [glyph] (in font sizes) so its ink is centred on its line box.
Offset glyphInkOffset(String glyph) => _offsets[glyph] ?? Offset.zero;

TextStyle glyphStyle(double size, Color color) =>
    TextStyle(fontFamily: uiFont, fontFamilyFallback: iconFallback, fontSize: size, color: color, height: 1);

Future<Offset> _measure(String glyph) async {
  final tp = TextPainter(text: TextSpan(text: glyph, style: glyphStyle(_ref, const Color(0xffffffff))), textDirection: TextDirection.ltr)..layout();
  const box = _ref * 2;
  final rec = ui.PictureRecorder();
  final origin = Offset((box - tp.width) / 2, (box - tp.height) / 2);
  tp.paint(Canvas(rec), origin);
  final img = await rec.endRecording().toImage(box.toInt(), box.toInt());
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  img.dispose();
  const w = box ~/ 1;
  var x0 = w, y0 = w, x1 = -1, y1 = -1;
  for (var y = 0; y < w; y++) {
    for (var x = 0; x < w; x++) {
      if (data[(y * w + x) * 4 + 3] < 40) continue;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  if (x1 < 0) return Offset.zero;
  // where the line box centre is vs. where the ink centre is
  final ink = Offset((x0 + x1 + 1) / 2, (y0 + y1 + 1) / 2);
  return (const Offset(box / 2, box / 2) - ink) / _ref;
}

/// Measures every symbol the UI shows (call once at startup; safe to repeat).
Future<void> warmUpIconGlyphs() async {
  final glyphs = {
    for (final d in weaponDefs.values) d.icon,
    for (final d in perkDefs.values) d.icon,
    for (final d in bonusDefs.values) d.icon,
    '★', '✚', '🔒',
  };
  for (final g in glyphs) {
    if (_offsets.containsKey(g)) continue;
    try {
      _offsets[g] = await _measure(g);
    } catch (_) {
      _offsets[g] = Offset.zero;
    }
  }
}

final Map<(String, double, int), TextPainter> _painters = {};

/// Paints [glyph] with its ink centred on [center] (HUD slots).
void paintGlyph(Canvas canvas, String glyph, Offset center, double size, Color color) {
  final key = (glyph, size, color.toARGB32());
  final tp = _painters[key] ??= TextPainter(
    text: TextSpan(text: glyph, style: glyphStyle(size, color)),
    textDirection: TextDirection.ltr,
  )..layout();
  if (_painters.length > 400) _painters.clear();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2) + glyphInkOffset(glyph) * size);
}
