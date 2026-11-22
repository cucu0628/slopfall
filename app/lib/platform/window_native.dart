import 'dart:io';

import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const _channel = MethodChannel('nightfall/window');

/// Desktop: toggles fullscreen (the runners implement it). Mobile is always fullscreen.
Future<void> toggleFullscreen() async {
  if (!(Platform.isLinux || Platform.isWindows)) return;
  try {
    await _channel.invokeMethod<void>('toggleFullscreen');
  } catch (_) {}
}

/// A run is on screen: hide the system bars on phones and keep the screen on.
Future<void> enterGame() async {
  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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

/// Phones and tablets get the on-screen controls from the start.
bool get isTouchPlatform => Platform.isAndroid || Platform.isIOS;
