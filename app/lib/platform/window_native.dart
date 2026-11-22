import 'dart:io';

import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

bool get _desktop => Platform.isLinux || Platform.isWindows;

/// Desktop: the game draws its own title bar (ui/window_frame.dart). Returns
/// whether it should be shown.
Future<bool> initDesktopWindow() async {
  if (!_desktop) return false;
  try {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      title: 'Nightfall Survivors',
      minimumSize: Size(640, 400),
      backgroundColor: Color(0xff0b0d17),
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    return true;
  } catch (_) {
    return false; // keep the system title bar
  }
}

/// Desktop: toggles fullscreen. Mobile is always fullscreen.
Future<void> toggleFullscreen() async {
  if (!_desktop) return;
  try {
    await windowManager.setFullScreen(!await windowManager.isFullScreen());
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
