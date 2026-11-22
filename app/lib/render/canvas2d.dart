// A small subset of the HTML CanvasRenderingContext2D API on top of
// Flutter's Canvas. The game's artwork was written for Canvas 2D (paths,
// gradients, dashes, additive glows, text); keeping the same API lets it be
// ported line by line, so heroes, enemies and effects look exactly as before.
//
// Differences from the browser API, on purpose:
// * Paths are built in local coordinates and drawn with the transform active
//   at fill/stroke time (the art never changes the transform mid-path).
// * Colours may be given as CSS strings ('#rgb', '#rrggbb', '#rrggbbaa',
//   'rgb()', 'rgba()') or as Flutter [Color]s; parsed strings are cached.

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

const double _tau = math.pi * 2;

// ------------------------------------------------------------------ colours

final _colorCache = HashMap<String, Color>();

Color _hex(String s) {
  var h = s.substring(1);
  if (h.length == 3 || h.length == 4) h = h.split('').map((c) => '$c$c').join();
  final v = int.tryParse(h, radix: 16) ?? 0;
  if (h.length == 8) return Color(((v & 0xff) << 24) | (v >> 8));
  return Color(0xff000000 | v);
}

Color _rgbFn(String s) {
  final open = s.indexOf('('), close = s.lastIndexOf(')');
  final parts = s.substring(open + 1, close).split(',');
  double p(int i) => double.tryParse(parts[i].trim()) ?? 0;
  final a = parts.length > 3 ? p(3).clamp(0.0, 1.0) : 1.0;
  return Color.fromRGBO(p(0).round().clamp(0, 255), p(1).round().clamp(0, 255), p(2).round().clamp(0, 255), a);
}

/// Parses a CSS colour string (cached).
Color cssColor(String s) {
  final hit = _colorCache[s];
  if (hit != null) return hit;
  final Color c;
  if (s.startsWith('#')) {
    c = _hex(s);
  } else if (s.startsWith('rgb')) {
    c = _rgbFn(s);
  } else {
    c = switch (s) {
      'white' => const Color(0xffffffff),
      'black' => const Color(0xff000000),
      'transparent' => const Color(0x00000000),
      _ => const Color(0xffff00ff),
    };
  }
  if (_colorCache.length > 8192) _colorCache.clear();
  _colorCache[s] = c;
  return c;
}

/// `rgba(hex, a)` as a Flutter colour.
Color withAlpha(String hex, double a) => cssColor(hex).withValues(alpha: a.clamp(0.0, 1.0));

// ---------------------------------------------------------------- gradients

/// CanvasGradient: linear or (two-circle, same centre) radial.
class Gradient2D {
  final bool radial;
  final double x0, y0, r0, x1, y1, r1;
  final List<double> _stops = [];
  final List<Color> _colors = [];
  ui.Shader? _shader;

  Gradient2D.linear(this.x0, this.y0, this.x1, this.y1)
      : radial = false,
        r0 = 0,
        r1 = 0;

  Gradient2D.radial(this.x0, this.y0, this.r0, this.x1, this.y1, this.r1) : radial = true;

  void addColorStop(num offset, Object color) {
    _stops.add(offset.toDouble().clamp(0.0, 1.0));
    _colors.add(color is Color ? color : cssColor(color as String));
    _shader = null;
  }

  ui.Shader get shader {
    final s = _shader;
    if (s != null) return s;
    final colors = _colors.isEmpty ? const [Color(0x00000000), Color(0x00000000)] : _colors;
    final stops = _colors.isEmpty ? const [0.0, 1.0] : _stops;
    final ui.Shader created;
    if (!radial) {
      created = ui.Gradient.linear(Offset(x0, y0), Offset(x1, y1), colors, stops);
    } else if (r0 <= 0 && x0 == x1 && y0 == y1) {
      created = ui.Gradient.radial(Offset(x1, y1), r1, colors, stops);
    } else {
      created = ui.Gradient.radial(Offset(x1, y1), r1, colors, stops, TileMode.clamp, null, Offset(x0, y0), r0);
    }
    return _shader = created;
  }
}

// --------------------------------------------------------------------- text

class _TextKey {
  final String text;
  final double size;
  final int weight;
  final int color;
  final double stroke; // 0 = fill
  final String family;
  const _TextKey(this.text, this.size, this.weight, this.color, this.stroke, this.family);

  @override
  bool operator ==(Object o) =>
      o is _TextKey &&
      o.text == text &&
      o.size == size &&
      o.weight == weight &&
      o.color == color &&
      o.stroke == stroke &&
      o.family == family;

  @override
  int get hashCode => Object.hash(text, size, weight, color, stroke, family);
}

// ignore: prefer_collection_literals
final _paragraphs = LinkedHashMap<_TextKey, ui.Paragraph>();
const int _maxParagraphs = 700;

/// Fonts for canvas text: [uiFont] stands in for `system-ui`, [serifFont] for
/// `serif`; [iconFallback] supplies the weapon / perk symbols.
const String uiFont = 'NightfallSans';
const String serifFont = 'NightfallSerif';
const List<String> iconFallback = ['NightfallIconsB', 'NightfallIconsA', 'NightfallIconsC', 'NightfallIconsD'];

ui.Paragraph _paragraph(_TextKey k) {
  final hit = _paragraphs.remove(k);
  if (hit != null) {
    _paragraphs[k] = hit; // refresh LRU position
    return hit;
  }
  final weight = FontWeight.values[((k.weight ~/ 100) - 1).clamp(0, 8)];
  final style = ui.TextStyle(
    fontSize: k.size,
    fontWeight: weight,
    fontFamily: k.family == 'serif' ? serifFont : uiFont,
    fontFamilyFallback: iconFallback,
    foreground: k.stroke > 0
        ? (Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = k.stroke
          ..strokeJoin = StrokeJoin.round
          ..color = Color(k.color))
        : (Paint()..color = Color(k.color)),
  );
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(maxLines: 1))
    ..pushStyle(style)
    ..addText(k.text);
  final p = b.build()..layout(const ui.ParagraphConstraints(width: double.infinity));
  if (_paragraphs.length >= _maxParagraphs) _paragraphs.remove(_paragraphs.keys.first);
  _paragraphs[k] = p;
  return p;
}

// ------------------------------------------------------------------- images

/// An offscreen canvas turned into an image (HTMLCanvasElement stand-in).
class Image2D {
  final ui.Image image;
  Image2D(this.image);
  int get width => image.width;
  int get height => image.height;
  void dispose() => image.dispose();
}

/// Draws into a fresh [w]×[h] offscreen canvas and returns it as an image.
Image2D offscreen(int w, int h, void Function(Ctx2D g) draw) {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  draw(Ctx2D(canvas));
  final pic = rec.endRecording();
  final img = pic.toImageSync(w, h);
  pic.dispose();
  return Image2D(img);
}

/// An image from raw RGBA pixels drawn as 1×1 rects (synchronous, for tiny images).
Image2D imageFromPixels(int w, int h, Uint8List rgba) {
  return offscreen(w, h, (g) {
    final paint = Paint();
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        paint.color = Color.fromARGB(rgba[o + 3], rgba[o], rgba[o + 1], rgba[o + 2]);
        g.canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }
  });
}

// ------------------------------------------------------------------ context

class _State {
  Object fillStyle = const Color(0xff000000);
  Object strokeStyle = const Color(0xff000000);
  double lineWidth = 1;
  double globalAlpha = 1;
  BlendMode blend = BlendMode.srcOver;
  StrokeCap lineCap = StrokeCap.butt;
  StrokeJoin lineJoin = StrokeJoin.miter;
  List<double> dash = const [];
  double dashOffset = 0;
  double fontSize = 10;
  int fontWeight = 400;
  String fontFamily = '';
  String textAlign = 'start';
  String textBaseline = 'alphabetic';
  bool smoothing = true;
  FilterQuality quality = FilterQuality.medium;

  _State copy() => _State()
    ..fillStyle = fillStyle
    ..strokeStyle = strokeStyle
    ..lineWidth = lineWidth
    ..globalAlpha = globalAlpha
    ..blend = blend
    ..lineCap = lineCap
    ..lineJoin = lineJoin
    ..dash = dash
    ..dashOffset = dashOffset
    ..fontSize = fontSize
    ..fontWeight = fontWeight
    ..fontFamily = fontFamily
    ..textAlign = textAlign
    ..textBaseline = textBaseline
    ..smoothing = smoothing
    ..quality = quality;
}

/// CanvasRenderingContext2D over a Flutter [Canvas].
class Ctx2D {
  final Canvas canvas;
  final int _baseSave;
  _State _s = _State();
  final List<_State> _stack = [];
  Path _path = Path();
  bool _hasPoint = false;
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  Ctx2D(this.canvas) : _baseSave = canvas.getSaveCount();

  // ---- state

  Object get fillStyle => _s.fillStyle;
  set fillStyle(Object v) => _s.fillStyle = v;
  Object get strokeStyle => _s.strokeStyle;
  set strokeStyle(Object v) => _s.strokeStyle = v;
  double get lineWidth => _s.lineWidth;
  set lineWidth(num v) => _s.lineWidth = v.toDouble();
  double get globalAlpha => _s.globalAlpha;
  set globalAlpha(num v) => _s.globalAlpha = v.toDouble().clamp(0.0, 1.0);

  set globalCompositeOperation(String v) => _s.blend = v == 'lighter' ? BlendMode.plus : BlendMode.srcOver;

  set lineCap(String v) => _s.lineCap = switch (v) {
        'round' => StrokeCap.round,
        'square' => StrokeCap.square,
        _ => StrokeCap.butt,
      };

  set lineJoin(String v) => _s.lineJoin = switch (v) {
        'round' => StrokeJoin.round,
        'bevel' => StrokeJoin.bevel,
        _ => StrokeJoin.miter,
      };

  void setLineDash(List<num> d) => _s.dash = [for (final x in d) x.toDouble()];
  set lineDashOffset(num v) => _s.dashOffset = v.toDouble();

  /// CSS font shorthand, e.g. `bold 13px system-ui, sans-serif` or `900 46px serif`.
  set font(String v) {
    var weight = 400;
    double size = 10;
    final parts = v.split(' ');
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (p == 'bold') {
        weight = 700;
      } else if (p == 'normal') {
        weight = 400;
      } else if (p.endsWith('px')) {
        size = double.tryParse(p.substring(0, p.length - 2)) ?? size;
        final family = parts.sublist(i + 1).join(' ');
        _s.fontFamily = family.contains('serif') && !family.contains('sans') ? 'serif' : '';
        break;
      } else if (int.tryParse(p) case final w?) {
        weight = w;
      }
    }
    _s.fontWeight = weight;
    _s.fontSize = size;
  }

  set textAlign(String v) => _s.textAlign = v;
  set textBaseline(String v) => _s.textBaseline = v;
  set imageSmoothingEnabled(bool v) => _s.smoothing = v;

  /// 'high' upscales with bicubic filtering (like browsers), 'low' with bilinear.
  set imageSmoothingQuality(String v) => _s.quality = switch (v) {
        'high' => FilterQuality.high,
        'low' => FilterQuality.low,
        _ => FilterQuality.medium,
      };

  void save() {
    _stack.add(_s.copy());
    canvas.save();
  }

  void restore() {
    if (_stack.isEmpty) return;
    _s = _stack.removeLast();
    canvas.restore();
  }

  // ---- transforms

  void translate(num x, num y) => canvas.translate(x.toDouble(), y.toDouble());
  void rotate(num a) => canvas.rotate(a.toDouble());
  void scale(num x, num y) => canvas.scale(x.toDouble(), y.toDouble());

  /// Replaces the current transform (relative to the canvas this context was created on).
  void setTransform(num a, num b, num c, num d, num e, num f) {
    canvas.restoreToCount(_baseSave);
    _stack.clear();
    canvas.save();
    canvas.transform(Float64List.fromList([
      a.toDouble(), b.toDouble(), 0, 0, //
      c.toDouble(), d.toDouble(), 0, 0,
      0, 0, 1, 0,
      e.toDouble(), f.toDouble(), 0, 1,
    ]));
  }

  /// Undoes everything this context left on the canvas.
  void dispose() => canvas.restoreToCount(_baseSave);

  // ---- paths

  void beginPath() {
    _path = Path();
    _hasPoint = false;
  }

  void moveTo(num x, num y) {
    _path.moveTo(x.toDouble(), y.toDouble());
    _hasPoint = true;
  }

  void lineTo(num x, num y) {
    if (!_hasPoint) return moveTo(x, y);
    _path.lineTo(x.toDouble(), y.toDouble());
  }

  void quadraticCurveTo(num cx, num cy, num x, num y) {
    if (!_hasPoint) moveTo(cx, cy);
    _path.quadraticBezierTo(cx.toDouble(), cy.toDouble(), x.toDouble(), y.toDouble());
  }

  void bezierCurveTo(num c1x, num c1y, num c2x, num c2y, num x, num y) {
    if (!_hasPoint) moveTo(c1x, c1y);
    _path.cubicTo(c1x.toDouble(), c1y.toDouble(), c2x.toDouble(), c2y.toDouble(), x.toDouble(), y.toDouble());
  }

  void closePath() {
    if (_hasPoint) _path.close();
  }

  void rect(num x, num y, num w, num h) {
    _path.addRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()));
    _path.moveTo(x.toDouble(), y.toDouble());
    _hasPoint = true;
  }

  void roundRect(num x, num y, num w, num h, num r) {
    final rr = math.max(0.0, math.min(r.toDouble(), math.min(w.abs(), h.abs()) / 2));
    _path.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()), Radius.circular(rr)));
    _path.moveTo(x.toDouble(), y.toDouble());
    _hasPoint = true;
  }

  /// Canvas 2D arc sweep rules (full circle when the span reaches 2π).
  static double _sweep(double start, double end, bool ccw) {
    if (!ccw) {
      if (end - start >= _tau) return _tau;
      var s = (end - start) % _tau;
      if (s < 0) s += _tau;
      return s;
    }
    if (start - end >= _tau) return -_tau;
    var s = (start - end) % _tau;
    if (s < 0) s += _tau;
    return -s;
  }

  void _arcInto(Path p, Rect oval, double start, double sweep, bool connect) {
    if (sweep.abs() >= _tau - 1e-9) {
      // a single 360° arcTo draws nothing: split it in two halves
      final half = sweep / 2;
      p.arcTo(oval, start, half, !connect);
      p.arcTo(oval, start + half, half, false);
    } else {
      p.arcTo(oval, start, sweep, !connect);
    }
  }

  void arc(num x, num y, num r, num start, num end, [bool ccw = false]) {
    final rr = r.toDouble().abs();
    final oval = Rect.fromCircle(center: Offset(x.toDouble(), y.toDouble()), radius: rr);
    _arcInto(_path, oval, start.toDouble(), _sweep(start.toDouble(), end.toDouble(), ccw), _hasPoint);
    _hasPoint = true;
  }

  void ellipse(num x, num y, num rx, num ry, num rot, num start, num end, [bool ccw = false]) {
    final sweep = _sweep(start.toDouble(), end.toDouble(), ccw);
    final oval = Rect.fromCenter(center: Offset.zero, width: rx.toDouble().abs() * 2, height: ry.toDouble().abs() * 2);
    if (rot == 0) {
      _arcInto(_path, oval.shift(Offset(x.toDouble(), y.toDouble())), start.toDouble(), sweep, _hasPoint);
    } else {
      final sub = Path();
      _arcInto(sub, oval, start.toDouble(), sweep, false);
      final c = math.cos(rot.toDouble()), s = math.sin(rot.toDouble());
      // column-major: rotate, then translate to (x, y)
      final moved = sub.transform(Float64List.fromList([c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, x.toDouble(), y.toDouble(), 0, 1]));
      if (_hasPoint) {
        _path.extendWithPath(moved, Offset.zero);
      } else {
        _path.addPath(moved, Offset.zero);
      }
    }
    _hasPoint = true;
  }

  // ---- painting

  Paint _fillPaint() {
    final p = _fill
      ..blendMode = _s.blend
      ..filterQuality = _s.smoothing ? FilterQuality.medium : FilterQuality.none;
    final style = _s.fillStyle;
    if (style is Gradient2D) {
      p
        ..shader = style.shader
        ..color = Color.fromRGBO(0, 0, 0, _s.globalAlpha);
    } else {
      final c = style is Color ? style : cssColor(style as String);
      p
        ..shader = null
        ..color = _s.globalAlpha == 1 ? c : c.withValues(alpha: c.a * _s.globalAlpha);
    }
    return p;
  }

  Paint _strokePaint() {
    final p = _stroke
      ..blendMode = _s.blend
      ..strokeWidth = _s.lineWidth
      ..strokeCap = _s.lineCap
      ..strokeJoin = _s.lineJoin;
    final style = _s.strokeStyle;
    if (style is Gradient2D) {
      p
        ..shader = style.shader
        ..color = Color.fromRGBO(0, 0, 0, _s.globalAlpha);
    } else {
      final c = style is Color ? style : cssColor(style as String);
      p
        ..shader = null
        ..color = _s.globalAlpha == 1 ? c : c.withValues(alpha: c.a * _s.globalAlpha);
    }
    return p;
  }

  void fill() => canvas.drawPath(_path, _fillPaint());

  void stroke() {
    if (_s.dash.isEmpty) {
      canvas.drawPath(_path, _strokePaint());
    } else {
      canvas.drawPath(_dashed(_path, _s.dash, _s.dashOffset), _strokePaint());
    }
  }

  void clip() => canvas.clipPath(_path);

  void fillRect(num x, num y, num w, num h) =>
      canvas.drawRect(Rect.fromPoints(Offset(x.toDouble(), y.toDouble()), Offset((x + w).toDouble(), (y + h).toDouble())), _fillPaint());

  void strokeRect(num x, num y, num w, num h) {
    final r = Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble());
    if (_s.dash.isEmpty) {
      canvas.drawRect(r, _strokePaint());
    } else {
      canvas.drawPath(_dashed(Path()..addRect(r), _s.dash, _s.dashOffset), _strokePaint());
    }
  }

  void clearRect(num x, num y, num w, num h) => canvas.drawRect(
      Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
      Paint()
        ..blendMode = BlendMode.clear
        ..color = const Color(0x00000000));

  static Path _dashed(Path src, List<double> dash, double offset) {
    final out = Path();
    var total = 0.0;
    for (final d in dash) {
      total += d;
    }
    if (total <= 0) return src;
    for (final m in src.computeMetrics()) {
      // position within the dash pattern at the start of this contour
      var pos = offset % total;
      if (pos < 0) pos += total;
      var i = 0;
      while (pos >= dash[i % dash.length]) {
        pos -= dash[i % dash.length];
        i++;
      }
      var d = 0.0;
      var left = dash[i % dash.length] - pos;
      while (d < m.length) {
        final len = math.min(left, m.length - d);
        if (i.isEven) out.addPath(m.extractPath(d, d + len), Offset.zero);
        d += len;
        i++;
        left = dash[i % dash.length];
      }
    }
    return out;
  }

  // ---- text

  ui.Paragraph _text(String text, Object style, double stroke) {
    final base = style is Color ? style : (style is String ? cssColor(style) : const Color(0xffffffff));
    // alpha is quantised so fading texts reuse a handful of cached layouts
    final a = (base.a * _s.globalAlpha * 32).round() / 32;
    final c = base.withValues(alpha: a);
    return _paragraph(_TextKey(text, _s.fontSize, _s.fontWeight, c.toARGB32(), stroke, _s.fontFamily));
  }

  Offset _textOrigin(ui.Paragraph p, double x, double y) {
    final w = p.longestLine;
    final dx = switch (_s.textAlign) {
      'center' => -w / 2,
      'right' || 'end' => -w,
      _ => 0.0,
    };
    final dy = switch (_s.textBaseline) {
      'middle' => -p.height / 2,
      'top' || 'hanging' => 0.0,
      'bottom' || 'ideographic' => -p.height,
      _ => -p.alphabeticBaseline,
    };
    return Offset(x + dx, y + dy);
  }

  void fillText(String text, num x, num y) {
    if (text.isEmpty) return;
    final p = _text(text, _s.fillStyle, 0);
    if (_s.blend != BlendMode.srcOver) {
      canvas.saveLayer(null, Paint()..blendMode = _s.blend);
      canvas.drawParagraph(p, _textOrigin(p, x.toDouble(), y.toDouble()));
      canvas.restore();
    } else {
      canvas.drawParagraph(p, _textOrigin(p, x.toDouble(), y.toDouble()));
    }
  }

  void strokeText(String text, num x, num y) {
    if (text.isEmpty) return;
    final p = _text(text, _s.strokeStyle, _s.lineWidth);
    // stroked glyphs are wider by half the line width on each side: align on the fill
    final fill = _text(text, _s.strokeStyle, 0);
    final o = _textOrigin(fill, x.toDouble(), y.toDouble());
    canvas.drawParagraph(p, o);
  }

  double measureText(String text) => _text(text, const Color(0xffffffff), 0).longestLine;

  // ---- images

  void drawImage(Image2D img, num dx, num dy, [num? dw, num? dh]) {
    final w = (dw ?? img.width).toDouble(), h = (dh ?? img.height).toDouble();
    canvas.drawImageRect(
      img.image,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(dx.toDouble(), dy.toDouble(), w, h),
      _imagePaint(),
    );
  }

  void drawImageRegion(Image2D img, num sx, num sy, num sw, num sh, num dx, num dy, num dw, num dh) {
    canvas.drawImageRect(
      img.image,
      Rect.fromLTWH(sx.toDouble(), sy.toDouble(), sw.toDouble(), sh.toDouble()),
      Rect.fromLTWH(dx.toDouble(), dy.toDouble(), dw.toDouble(), dh.toDouble()),
      _imagePaint(),
    );
  }

  final Paint _img = Paint();

  Paint _imagePaint() => _img
    ..blendMode = _s.blend
    ..filterQuality = _s.smoothing ? _s.quality : FilterQuality.none
    ..color = Color.fromRGBO(0, 0, 0, _s.globalAlpha);

  // ---- gradients

  Gradient2D createLinearGradient(num x0, num y0, num x1, num y1) =>
      Gradient2D.linear(x0.toDouble(), y0.toDouble(), x1.toDouble(), y1.toDouble());

  Gradient2D createRadialGradient(num x0, num y0, num r0, num x1, num y1, num r1) =>
      Gradient2D.radial(x0.toDouble(), y0.toDouble(), r0.toDouble(), x1.toDouble(), y1.toDouble(), r1.toDouble());
}
