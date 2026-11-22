import 'dart:js_interop';

import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web/web.dart' as web;

Future<void> toggleFullscreen() async {
  try {
    if (web.document.fullscreenElement != null) {
      await web.document.exitFullscreen().toDart;
    } else {
      await web.document.documentElement?.requestFullscreen().toDart;
    }
  } catch (_) {}
}

/// On phones a run asks for fullscreen (ignored where unsupported, e.g. iOS Safari).
Future<void> enterGame() async {
  if (isTouchPlatform && web.document.fullscreenElement == null) {
    try {
      await web.document.documentElement?.requestFullscreen().toDart;
    } catch (_) {}
  }
  try {
    await WakelockPlus.enable();
  } catch (_) {}
}

Future<void> leaveGame() async {
  try {
    await WakelockPlus.disable();
  } catch (_) {}
}

/// Coarse pointer and no hover: a phone or tablet browser.
bool get isTouchPlatform {
  final w = web.window;
  return w.matchMedia('(pointer: coarse)').matches || (w.navigator.maxTouchPoints > 0 && w.matchMedia('(hover: none)').matches);
}
