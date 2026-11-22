// The game's own window title bar on Linux and Windows, replacing the GTK
// header bar / Windows caption: the bat icon and the name in the display
// serif on the left, hairline window buttons on the right. Drag to move,
// double-click to maximize; it disappears in fullscreen.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'theme.dart';

const double titleBarHeight = 34;

/// Wraps the app with the title bar (and resize edges where the window
/// manager gives none).
class WindowFrame extends StatefulWidget {
  final Widget child;
  const WindowFrame({super.key, required this.child});

  @override
  State<WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<WindowFrame> with WindowListener {
  bool _maximized = false;
  bool _fullScreen = false;
  bool _focused = true;
  // the frame sits above the app's Navigator, so it brings its own overlay
  // (for the button tooltips); the entry is rebuilt when the window changes
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => _frame());

  void _update(VoidCallback fn) {
    setState(fn);
    _entry.markNeedsBuild();
  }

  @override
  void didUpdateWidget(WindowFrame old) {
    super.didUpdateWidget(old);
    _entry.markNeedsBuild();
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _sync();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _sync() async {
    final m = await windowManager.isMaximized();
    final f = await windowManager.isFullScreen();
    if (!mounted) return;
    _update(() {
      _maximized = m;
      _fullScreen = f;
    });
  }

  @override
  void onWindowMaximize() => _update(() => _maximized = true);
  @override
  void onWindowUnmaximize() => _update(() => _maximized = false);
  @override
  void onWindowEnterFullScreen() => _update(() => _fullScreen = true);
  @override
  void onWindowLeaveFullScreen() => _update(() => _fullScreen = false);
  @override
  void onWindowFocus() => _update(() => _focused = true);
  @override
  void onWindowBlur() => _update(() => _focused = false);

  @override
  // transparency Material: text styles and ink for the bar, which sits outside the app's pages
  Widget build(BuildContext context) => Material(type: MaterialType.transparency, child: Overlay(initialEntries: [_entry]));

  Widget _frame() {
    final content = Column(
      children: [
        if (!_fullScreen) _TitleBar(maximized: _maximized, focused: _focused),
        Expanded(child: widget.child),
      ],
    );
    // Windows keeps its native resize borders; an undecorated GTK window on
    // X11 has none, so give it edges of its own.
    if (Platform.isLinux && !_maximized && !_fullScreen) return DragToResizeArea(resizeEdgeSize: 5, child: content);
    return content;
  }
}

class _TitleBar extends StatelessWidget {
  final bool maximized;
  final bool focused;
  const _TitleBar({required this.maximized, required this.focused});

  @override
  Widget build(BuildContext context) {
    final ink = focused ? Nf.muted : Nf.faint;
    return Container(
      height: titleBarHeight,
      decoration: const BoxDecoration(
        color: Color(0xff0e1020),
        border: Border(bottom: BorderSide(color: Nf.lineFaint)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Row(
                children: [
                  const SizedBox(width: Nf.s3),
                  Opacity(
                    opacity: focused ? 1 : 0.6,
                    child: Image.asset('assets/icon/app_icon.png', width: 18, height: 18, filterQuality: FilterQuality.medium),
                  ),
                  const SizedBox(width: Nf.s2),
                  Text('Nightfall Survivors', style: Nf.display(size: 13, color: ink, spacing: 0.4)),
                  const Spacer(),
                ],
              ),
            ),
          ),
          _CaptionButton(icon: _Glyph.minimize, tooltip: 'Minimize', ink: ink, onTap: windowManager.minimize),
          _CaptionButton(
            icon: maximized ? _Glyph.restore : _Glyph.maximize,
            tooltip: maximized ? 'Restore' : 'Maximize',
            ink: ink,
            onTap: () => maximized ? windowManager.unmaximize() : windowManager.maximize(),
          ),
          _CaptionButton(icon: _Glyph.close, tooltip: 'Close', ink: ink, onTap: windowManager.close, danger: true),
        ],
      ),
    );
  }
}

enum _Glyph { minimize, maximize, restore, close }

class _CaptionButton extends StatefulWidget {
  final _Glyph icon;
  final String tooltip;
  final Color ink;
  final VoidCallback onTap;
  final bool danger;
  const _CaptionButton({required this.icon, required this.tooltip, required this.ink, required this.onTap, this.danger = false});

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final Color bg;
    final Color fg;
    if (w.danger && (_hover || _down)) {
      bg = _down ? const Color(0xffa8243a) : const Color(0xffc8304a);
      fg = Colors.white;
    } else {
      bg = _down ? const Color.fromRGBO(255, 255, 255, 0.10) : (_hover ? const Color.fromRGBO(255, 255, 255, 0.06) : Colors.transparent);
      fg = _hover ? Nf.text : w.ink;
    }
    return Tooltip(
      message: w.tooltip,
      waitDuration: const Duration(milliseconds: 700),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = _down = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: w.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            width: 46,
            height: titleBarHeight,
            color: bg,
            child: CustomPaint(painter: _GlyphPainter(w.icon, fg)),
          ),
        ),
      ),
    );
  }
}

/// Hairline window glyphs, 10 px, pixel-snapped so they stay crisp.
class _GlyphPainter extends CustomPainter {
  final _Glyph glyph;
  final Color color;
  _GlyphPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = glyph == _Glyph.close;
    final cx = (size.width / 2).floorToDouble() + 0.5, cy = (size.height / 2).floorToDouble() + 0.5;
    const r = 5.0;
    switch (glyph) {
      case _Glyph.minimize:
        canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), p);
      case _Glyph.maximize:
        canvas.drawRect(Rect.fromLTRB(cx - r, cy - r, cx + r, cy + r), p);
      case _Glyph.restore:
        canvas.drawRect(Rect.fromLTRB(cx - r, cy - r + 2, cx + r - 2, cy + r), p);
        canvas.drawPath(
          Path()
            ..moveTo(cx - r + 2, cy - r + 2)
            ..lineTo(cx - r + 2, cy - r)
            ..lineTo(cx + r, cy - r)
            ..lineTo(cx + r, cy + r - 2)
            ..lineTo(cx + r - 2, cy + r - 2),
          p,
        );
      case _Glyph.close:
        p.strokeWidth = 1.1;
        canvas.drawLine(Offset(cx - r, cy - r), Offset(cx + r, cy + r), p);
        canvas.drawLine(Offset(cx + r, cy - r), Offset(cx - r, cy + r), p);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph || old.color != color;
}
