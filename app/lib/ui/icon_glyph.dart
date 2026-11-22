// A weapon / perk symbol centred on its ink (see render/glyphs.dart).

import 'package:flutter/material.dart';

import '../render/glyphs.dart';

export '../render/glyphs.dart' show warmUpIconGlyphs;

/// A symbol centred on its visible shape within its box.
class IconGlyph extends StatelessWidget {
  final String glyph;
  final double size;
  final Color color;
  final List<Shadow>? shadows;
  const IconGlyph(this.glyph, {super.key, required this.size, required this.color, this.shadows});

  @override
  Widget build(BuildContext context) => Transform.translate(
        offset: glyphInkOffset(glyph) * size,
        child: Text(glyph, textAlign: TextAlign.center, style: glyphStyle(size, color).copyWith(shadows: shadows)),
      );
}
