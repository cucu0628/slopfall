// Design tokens (from the original base.css) and the shared UI primitives:
// panels, buttons, labels, keys and screen titles. Screens build on these;
// avoid raw sizes or colours elsewhere.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../render/canvas2d.dart' show iconFallback, serifFont, uiFont;

abstract final class Nf {
  // ---- colour
  static const bg = Color(0xff0b0d17);
  static const surfaceTop = Color.fromRGBO(27, 32, 62, 0.96);
  static const surfaceBottom = Color.fromRGBO(13, 16, 32, 0.96);
  static const well = Color.fromRGBO(255, 255, 255, 0.045);
  static const line = Color.fromRGBO(130, 150, 255, 0.22);
  static const lineStrong = Color.fromRGBO(143, 176, 255, 0.5);
  static const lineFaint = Color.fromRGBO(130, 150, 255, 0.09);
  static const text = Color(0xffe6e9f5);
  static const muted = Color(0xff9aa3c4);
  static const faint = Color(0xff6b7290);
  static const accent = Color(0xff4fa3ff);
  static const gold = Color(0xffffd166);
  static const goldLine = Color.fromRGBO(255, 209, 102, 0.32);
  static const red = Color(0xffff4d6d);
  static const green = Color(0xff34c38f);

  // ---- type
  static const fsXs = 11.0;
  static const fsSm = 13.0;
  static const fsMd = 15.0;
  static const fsLg = 18.0;
  static const fsXl = 24.0;
  static double fsTitle(double width) => (width * 0.04).clamp(28.0, 38.0);

  // ---- space and shape
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const rSm = 6.0;
  static const rMd = 10.0;
  static const rLg = 14.0;

  static const shadow1 = [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.38), blurRadius: 28, offset: Offset(0, 10))];
  static const shadow2 = [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.55), blurRadius: 64, offset: Offset(0, 24))];
  static const fast = Duration(milliseconds: 120);
  static const ease = Cubic(0.2, 0.7, 0.3, 1);

  static TextStyle ui({double size = fsMd, FontWeight weight = FontWeight.w400, Color color = text, double? spacing, double? height}) =>
      TextStyle(
        fontFamily: uiFont,
        fontFamilyFallback: iconFallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: height,
      );

  static TextStyle display({double size = fsLg, FontWeight weight = FontWeight.w700, Color color = text, double? spacing, bool italic = false}) =>
      TextStyle(
        fontFamily: serifFont,
        fontFamilyFallback: iconFallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );

  /// `color-mix(in srgb, c p%, transparent)`.
  static Color mix(Color c, double p) => c.withValues(alpha: c.a * p);
}

ThemeData nightfallTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Nf.bg,
      fontFamily: uiFont,
      fontFamilyFallback: iconFallback,
      colorScheme: const ColorScheme.dark(primary: Nf.accent, secondary: Nf.gold, surface: Nf.bg),
      focusColor: Nf.gold.withValues(alpha: 0.3),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Nf.line.withValues(alpha: 0.35 / 0.22 * 0.22)),
        thickness: const WidgetStatePropertyAll(6),
      ),
      tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
    );

// ------------------------------------------------------------------ panel

/// `.panel` / `.panel.accent`: a rounded card; [accent] tints it with a soft
/// wash from the top and a 2px inner rim.
class Panel extends StatelessWidget {
  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final List<BoxShadow>? glow;
  final double? width;

  const Panel({super.key, required this.child, this.accent, this.padding = EdgeInsets.zero, this.borderColor, this.glow, this.width});

  @override
  Widget build(BuildContext context) {
    final a = accent;
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Nf.rLg),
        border: Border.all(color: borderColor ?? Nf.line),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Nf.surfaceTop, Nf.surfaceBottom]),
        boxShadow: [...Nf.shadow1, ...?glow],
      ),
      foregroundDecoration: a == null
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(Nf.rLg),
              border: Border(top: BorderSide(color: Nf.mix(a, 0.65), width: 2)),
            ),
      // passthrough: a panel stretched by its parent (grid rows) passes the height on
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (a != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Nf.rLg),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.5],
                    colors: [Nf.mix(a, 0.12), a.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- buttons

enum BtnKind { normal, primary, success }

enum BtnSize { sm, md, lg }

/// `.btn` with its variants and sizes; lifts on hover, sinks when pressed.
class NfButton extends StatefulWidget {
  final String label;
  final Widget? sub;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final BtnSize size;
  final bool expand;
  final double? minWidth;
  final bool autofocus;

  const NfButton(this.label,
      {super.key, this.onPressed, this.kind = BtnKind.normal, this.size = BtnSize.md, this.sub, this.expand = false, this.minWidth, this.autofocus = false});

  @override
  State<NfButton> createState() => _NfButtonState();
}

class _NfButtonState extends State<NfButton> {
  bool _hover = false;
  bool _down = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final (List<Color> colors, Color border, List<BoxShadow> shadow) = switch (w.kind) {
      BtnKind.primary => (
          _hover ? const [Color(0xff6b98ff), Color(0xff4669e0)] : const [Color(0xff5b8cff), Color(0xff3d5fd6)],
          _hover ? const Color(0xffb4caff) : const Color(0xff8fb0ff),
          [BoxShadow(color: Color.fromRGBO(79, 140, 255, _hover ? 0.7 : 0.4), blurRadius: _hover ? 34 : 24)],
        ),
      BtnKind.success => (
          _hover ? const [Color(0xff40d29c), Color(0xff229a71)] : const [Color(0xff34c38f), Color(0xff1f8f68)],
          const Color(0xff7df0c4),
          [BoxShadow(color: Color.fromRGBO(52, 195, 143, _hover ? 0.7 : 0.4), blurRadius: _hover ? 34 : 24)],
        ),
      BtnKind.normal => (
          _hover
              ? const [Color.fromRGBO(62, 72, 124, 0.97), Color.fromRGBO(36, 43, 78, 0.97)]
              : const [Color.fromRGBO(46, 54, 96, 0.95), Color.fromRGBO(25, 30, 56, 0.95)],
          _hover ? Nf.lineStrong : Nf.line,
          const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.3), blurRadius: 14, offset: Offset(0, 4))],
        ),
    };
    final (double h, double pad, double fs) = switch (w.size) {
      BtnSize.sm => (36.0, Nf.s4, Nf.fsSm),
      BtnSize.md => (44.0, Nf.s5, Nf.fsMd),
      BtnSize.lg => (54.0, Nf.s6, Nf.fsLg),
    };
    final enabled = w.onPressed != null;
    final dy = !enabled ? 0.0 : (_down ? 1.0 : (_hover ? -1.0 : 0.0));
    Widget label = Text(
      w.label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Nf.ui(size: fs, weight: FontWeight.w700, spacing: fs * 0.08),
    );
    if (w.sub != null) label = Column(mainAxisSize: MainAxisSize.min, children: [label, const SizedBox(height: 2), w.sub!]);
    return FocusableActionDetector(
      enabled: enabled,
      autofocus: w.autofocus,
      mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => w.onPressed?.call())},
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: w.onPressed,
        child: AnimatedContainer(
          duration: Nf.fast,
          curve: Nf.ease,
          transform: Matrix4.translationValues(0, dy, 0),
          constraints: BoxConstraints(minHeight: w.sub != null ? 64 : h, minWidth: w.minWidth ?? 0),
          width: w.expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: pad),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Nf.rMd),
            border: Border.all(color: _focus ? Nf.gold : border, width: _focus ? 2 : 1),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
            boxShadow: shadow,
          ),
          // shrink-wraps the label (an aligned Container would fill the row)
          child: Center(widthFactor: w.expand ? null : 1, heightFactor: 1, child: Opacity(opacity: enabled ? 1 : 0.5, child: label)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ text bits

/// `h3` / `.label`: the one uppercase micro style.
class NfLabel extends StatelessWidget {
  final String text;
  final Color color;
  const NfLabel(this.text, {super.key, this.color = Nf.muted});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Nf.ui(size: Nf.fsXs, weight: FontWeight.w700, color: color, spacing: Nf.fsXs * 0.14));
}

/// `kbd`: a keyboard key.
class Kbd extends StatelessWidget {
  final String text;
  const Kbd(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 22),
        padding: const EdgeInsets.fromLTRB(6, 1, 6, 1),
        decoration: BoxDecoration(
          color: Nf.well,
          borderRadius: BorderRadius.circular(Nf.rSm),
          border: const Border(
            top: BorderSide(color: Nf.line),
            left: BorderSide(color: Nf.line),
            right: BorderSide(color: Nf.line),
            bottom: BorderSide(color: Nf.line, width: 2),
          ),
        ),
        child: Text(text, textAlign: TextAlign.center, style: Nf.ui(size: 12, weight: FontWeight.w600)),
      );
}

/// `h2`: display serif, uppercase, with the gold divider underneath.
class ScreenTitle extends StatelessWidget {
  final String text;
  final Color color;
  final List<Shadow>? glow;
  const ScreenTitle(this.text, {super.key, this.color = Nf.text, this.glow});

  static const blueGlow = [Shadow(color: Color.fromRGBO(79, 163, 255, 0.9), blurRadius: 20)];
  static const redGlow = [Shadow(color: Color.fromRGBO(255, 40, 70, 0.9), blurRadius: 22)];

  @override
  Widget build(BuildContext context) {
    final size = Nf.fsTitle(MediaQuery.sizeOf(context).width);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          style: Nf.display(size: size, spacing: size * 0.16, color: color).copyWith(height: 1.1, shadows: glow),
        ),
        const SizedBox(height: Nf.s2),
        const CustomPaint(size: Size(150, 10), painter: _Divider()),
      ],
    );
  }
}

class _Divider extends CustomPainter {
  const _Divider();

  @override
  void paint(Canvas c, Size s) {
    final line = Paint()
      ..color = Nf.gold.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    c.drawLine(const Offset(0, 5), const Offset(63, 5), line);
    c.drawLine(const Offset(87, 5), const Offset(150, 5), line);
    final dot = Paint()..color = Nf.gold.withValues(alpha: 0.75);
    Path diamond(double cx, double r) => Path()
      ..moveTo(cx, 5 - r)
      ..lineTo(cx + r, 5)
      ..lineTo(cx, 5 + r)
      ..lineTo(cx - r, 5)
      ..close();
    c.drawPath(diamond(75, 4), dot);
    c.drawPath(diamond(69, 2), dot);
    c.drawPath(diamond(85, 2), dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// A full-screen layer: centred content that scrolls when taller than the
/// screen, over the menu or overlay background.
class ScreenLayer extends StatelessWidget {
  final List<Widget> children;
  final bool overlay;
  final double gap;
  final Widget? corner;

  const ScreenLayer({super.key, required this.children, this.overlay = false, this.gap = Nf.s5, this.corner});

  @override
  Widget build(BuildContext context) {
    final bg = overlay
        ? const RadialGradient(radius: 0.9, colors: [Color.fromRGBO(5, 7, 15, 0.7), Color.fromRGBO(5, 7, 15, 0.9)])
        // menus: dark behind the centred text, lighter towards the edges so
        // the live demo run shows around them
        : const RadialGradient(radius: 0.85, colors: [Color.fromRGBO(11, 13, 23, 0.78), Color.fromRGBO(11, 13, 23, 0.5)]);
    final layer = DecoratedBox(
      decoration: BoxDecoration(gradient: bg),
      child: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.all(Nf.s4),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: math.max(0, c.maxHeight - Nf.s4 * 2)),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < children.length; i++) ...[
                          if (i > 0) SizedBox(height: gap),
                          children[i],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ?corner,
          ],
        ),
      ),
    );
    if (!overlay) return layer;
    // overlays blur the running game behind them
    return ClipRect(child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3), child: layer));
  }
}
