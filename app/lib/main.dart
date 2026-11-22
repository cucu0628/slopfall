// Nightfall Survivors – © 2026 cucu0628. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'storage/run_storage.dart';
import 'storage/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // right click is the ability button: no browser context menu on the web
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  final storage = await RunStorage.open();
  runApp(NightfallApp(storage: storage, settings: Settings(storage.store)));
}
