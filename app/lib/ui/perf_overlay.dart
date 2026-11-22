// F3: frame timing readout (fps, UI thread and raster thread time, average
// and worst over the last second). Uses the engine's FrameTiming reports, so
// it works in release builds too.

import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

class PerfOverlay extends StatefulWidget {
  const PerfOverlay({super.key});

  @override
  State<PerfOverlay> createState() => _PerfOverlayState();
}

class _PerfOverlayState extends State<PerfOverlay> {
  final List<FrameTiming> _window = [];
  String _text = 'measuring…';
  int _lastUpdate = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    _window.addAll(timings);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastUpdate < 1000 || _window.isEmpty) return;
    final span = (_window.last.timestampInMicroseconds(FramePhase.vsyncStart) - _window.first.timestampInMicroseconds(FramePhase.vsyncStart)) / 1e6;
    final fps = span > 0 ? (_window.length - 1) / span : 0;
    double avg(Duration Function(FrameTiming t) f) => _window.fold<int>(0, (a, t) => a + f(t).inMicroseconds) / _window.length / 1000;
    double worst(Duration Function(FrameTiming t) f) => _window.fold<int>(0, (a, t) => f(t).inMicroseconds > a ? f(t).inMicroseconds : a) / 1000;
    final slow = _window.where((t) => t.totalSpan.inMicroseconds > 1000000 ~/ 60 * 1.5).length;
    setState(() {
      _text = '${fps.toStringAsFixed(0)} fps   slow frames $slow/${_window.length}\n'
          'UI     ${avg((t) => t.buildDuration).toStringAsFixed(1)} ms   worst ${worst((t) => t.buildDuration).toStringAsFixed(1)}\n'
          'raster ${avg((t) => t.rasterDuration).toStringAsFixed(1)} ms   worst ${worst((t) => t.rasterDuration).toStringAsFixed(1)}';
    });
    _window.clear();
    _lastUpdate = now;
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Nf.s2, vertical: Nf.s1),
          decoration: BoxDecoration(color: const Color.fromRGBO(5, 7, 15, 0.82), borderRadius: BorderRadius.circular(Nf.rSm)),
          child: Text(_text, style: Nf.ui(size: 11, color: Nf.text).copyWith(fontFeatures: const [FontFeature.tabularFigures()], height: 1.4)),
        ),
      );
}
