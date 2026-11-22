// Nightfall Survivors – © 2026 cucu0628. All rights reserved.

import 'package:flutter/material.dart';

import 'app.dart';
import 'storage/run_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await RunStorage.open();
  runApp(NightfallApp(storage: storage));
}
