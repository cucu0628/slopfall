// Master volume (top-right corner of the main menu and pause screen), like a
// video player's: only the speaker shows; the slider slides out of it to the
// left on hover or keyboard focus. Touch screens have no hover: the first tap opens the slider (it
// closes again after a few seconds), a tap on the open control mutes.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Places the volume in a screen's top-right corner (see `ScreenLayer.corners`).
Widget volumeCorner(Widget volume) => Positioned(top: Nf.s3, right: Nf.s4, child: volume);

class VolumeControl extends StatefulWidget {
  final double volume; // 0..1
  final bool muted;
  final ValueChanged<double> onChanged;
  final VoidCallback onToggleMute;

  const VolumeControl({super.key, required this.volume, required this.muted, required this.onChanged, required this.onToggleMute});

  /// Width of the slider when it is out.
  static const sliderWidth = 120.0;

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  static const _touchOpenFor = Duration(seconds: 3);

  bool _hover = false;
  bool _focus = false;
  bool _dragging = false;
  bool _touchOpen = false;
  bool _keyFocus = false; // keyboard focus ring on the speaker
  PointerDeviceKind? _lastKind;
  Timer? _close;

  bool get _open => _hover || _focus || _dragging || _touchOpen;

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  /// Touch: keeps the slider out a little longer after each interaction.
  void _keepOpen() {
    if (_lastKind == PointerDeviceKind.mouse) return;
    _close?.cancel();
    _close = Timer(_touchOpenFor, () {
      if (mounted) setState(() => _touchOpen = false);
    });
    if (!_touchOpen) setState(() => _touchOpen = true);
  }

  void _tapIcon() {
    if (_lastKind != PointerDeviceKind.mouse && !_open) return _keepOpen();
    widget.onToggleMute();
    if (_touchOpen) _keepOpen();
  }

  @override
  Widget build(BuildContext context) {
    final silent = widget.muted || widget.volume == 0;
    final icon = silent ? Icons.volume_off_rounded : (widget.volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded);
    final open = _open;
    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        activeTrackColor: silent ? Nf.faint : Nf.text,
        inactiveTrackColor: Nf.line,
        thumbColor: silent ? Nf.muted : Colors.white,
        overlayColor: Nf.text.withValues(alpha: 0.1),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      ),
      child: Slider(
        value: widget.volume,
        onChangeStart: (_) => setState(() => _dragging = true),
        onChangeEnd: (_) => setState(() => _dragging = false),
        onChanged: (v) {
          widget.onChanged(v);
          _keepOpen();
        },
        semanticFormatterCallback: (v) => 'Volume ${(v * 100).round()} %',
      ),
    );
    // one button-styled pill: the slider grows out of it to the left, so the
    // control belongs in a top-right corner
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (e) => _lastKind = e.kind,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (f) => setState(() => _focus = f),
          child: AnimatedContainer(
            duration: Nf.fast,
            curve: Nf.ease,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Nf.rMd),
              border: Border.all(color: _keyFocus ? Nf.gold : (open ? Nf.lineStrong : Nf.line), width: _keyFocus ? 2 : 1),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: open
                    ? const [Color.fromRGBO(62, 72, 124, 0.97), Color.fromRGBO(36, 43, 78, 0.97)]
                    : const [Color.fromRGBO(46, 54, 96, 0.95), Color.fromRGBO(25, 30, 56, 0.95)],
              ),
              boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.3), blurRadius: 14, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // hidden it takes no room and no focus
                ClipRect(
                  child: AnimatedAlign(
                    duration: Nf.fast,
                    curve: Nf.ease,
                    alignment: Alignment.centerRight,
                    widthFactor: open ? 1 : 0,
                    child: AnimatedOpacity(
                      duration: Nf.fast,
                      opacity: open ? 1 : 0,
                      child: ExcludeFocus(
                        excluding: !open,
                        child: IgnorePointer(
                          ignoring: !open,
                          child: Padding(
                            padding: const EdgeInsets.only(left: Nf.s1),
                            child: SizedBox(width: VolumeControl.sliderWidth, child: slider),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: silent ? 'Sound on (M)' : 'Mute (M)',
                  child: FocusableActionDetector(
                    mouseCursor: SystemMouseCursors.click,
                    onShowFocusHighlight: (v) => setState(() => _keyFocus = v),
                    actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _tapIcon())},
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _tapIcon,
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: Icon(icon, color: silent ? Nf.faint : Nf.text, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
