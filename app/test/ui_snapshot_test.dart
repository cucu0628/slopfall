// Walks through every screen and writes PNGs to $SNAPSHOT_DIR for review.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightfall/app.dart';
import 'package:nightfall/storage/run_storage.dart';
import 'package:nightfall/ui/screens/codex.dart' show codexPortraitBytes;
import 'package:shared_preferences/shared_preferences.dart';

import 'render_snapshot_test.dart' show loadFonts;

final _key = GlobalKey();

Future<void> shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['SNAPSHOT_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final b = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> frames(WidgetTester tester, [int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('every screen renders', (tester) async {
    await tester.runAsync(loadFonts);
    SharedPreferences.setMockInitialValues({});
    final storage = await tester.runAsync(RunStorage.open);
    for (final size in [const Size(1280, 720), const Size(390, 844)]) {
      final tag = size.width > size.height ? 'wide' : 'phone';
      final kind = tag == 'wide' ? PointerDeviceKind.mouse : PointerDeviceKind.touch;
      await tester.binding.setSurfaceSize(size);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(RepaintBoundary(key: _key, child: NightfallApp(storage: storage!, audio: false)));
      await frames(tester, 60);
      await shot(tester, '${tag}_menu');

      await tester.tap(find.text('NEW RUN'), kind: kind);
      await frames(tester);
      await shot(tester, '${tag}_chars');

      await tester.tap(find.text('Mage'), kind: kind);
      await frames(tester, 240);
      await shot(tester, '${tag}_game');

      // force a level-up choice
      final shell = tester.state(find.byType(GameShell));
      final s = (shell as dynamic).debugState;
      expect(s, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(tester);
      await shot(tester, '${tag}_pause');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(tester, 10);

      (shell as dynamic).debugLevelUp();
      await frames(tester, 30);
      await shot(tester, '${tag}_levelup');
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await frames(tester, 10);

      (shell as dynamic).debugKill();
      await frames(tester, 140);
      await shot(tester, '${tag}_over');

      await tester.tap(find.text('MAIN MENU'), kind: kind);
      await frames(tester, 20);
      await tester.runAsync(() => codexPortraitBytes('bat'));
      await tester.tap(find.text('CODEX'), kind: kind);
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      await frames(tester, 20);
      await shot(tester, '${tag}_codex');
      await tester.tap(find.text('BACK'), kind: kind, warnIfMissed: false);
      await frames(tester, 20);
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 5);
    }
  });
}
