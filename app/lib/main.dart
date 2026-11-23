// Nightfall Survivors – © 2026 cucu0628. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'platform/window.dart';
import 'storage/run_storage.dart';
import 'storage/settings.dart';
import 'ui/icon_glyph.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // right click is the ability button: no browser context menu on the web
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  await initMobileScreen();
  final frame = await initDesktopWindow();
  final storage = await RunStorage.open();
  await warmUpIconGlyphs();
  runApp(NightfallApp(storage: storage, settings: Settings(storage.store), windowFrame: frame));
}
