import 'dart:js_interop';

import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web/web.dart' as web;

/// The browser draws the window: no title bar of our own.
Future<bool> initDesktopWindow() async => false;

/// Phones: web/index.html enters fullscreen and locks landscape on the first
/// tap (the browser only allows it in response to one).
Future<void> initMobileScreen() async {}

Future<void> toggleFullscreen() async {
  try {
    if (web.document.fullscreenElement != null) {
      await web.document.exitFullscreen().toDart;
    } else {
      await web.document.documentElement?.requestFullscreen().toDart;
    }
  } catch (_) {}
}

Future<void> enterGame() async {
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
