// Renders a few seconds of demo play into PNG files so the artwork can be
// checked by eye. Writes to $SNAPSHOT_DIR (skipped when unset).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightfall/game/input.dart';
import 'package:nightfall/game/session.dart';
import 'package:nightfall/game/touch.dart';
import 'package:nightfall/render/renderer.dart';
import 'package:nightfall_sim/nightfall_sim.dart';

Future<void> loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await family('NightfallSans', ['NightfallSans-Regular.ttf', 'NightfallSans-SemiBold.ttf', 'NightfallSans-Bold.ttf', 'NightfallSans-ExtraBold.ttf', 'NightfallSans-Black.ttf']);
  await family('NightfallSerif', ['NightfallSerif-Regular.ttf', 'NightfallSerif-Italic.ttf', 'NightfallSerif-Bold.ttf']);
  for (final c in ['A', 'B', 'C', 'D']) {
    await family('NightfallIcons$c', ['NightfallIcons$c.ttf']);
  }
}

Future<void> snap(Session s, double w, double h, String path) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  s.renderer.resize(w, h);
  // ground chunks are created two per frame: warm the cache first
  for (var i = 0; i < 12; i++) {
    s.paint(ui.Canvas(ui.PictureRecorder()));
  }
  s.paint(canvas);
  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  final dir = Platform.environment['SNAPSHOT_DIR'];

  testWidgets('renders gameplay', (tester) async {
    await tester.runAsync(() async {
      await loadFonts();
      for (final (name, charId, seconds, wave) in [('knight', 'knight', 20.0, 3), ('mage', 'mage', 12.0, 5), ('necro', 'necro', 14.0, 20)]) {
        final r = Renderer()..resize(1280, 720);
        final s = Session(charId, r, input: Input(TouchState()), initial: createGame(11 + wave, [PlayerSetup(localId, charId)], godMode: true));
        if (wave > 1) {
          s.state.enemies = [];
          startWave(s.state, wave);
        }
        for (var i = 0; i < seconds * 60; i++) {
          final p = s.state.players[0];
          if (p.choices != null) s.input!.choose(0);
          s.input!.keys
            ..clear()
            ..add((i ~/ 90) % 2 == 0 ? PhysicalKeyboardKey.keyD : PhysicalKeyboardKey.keyS);
          if (i % 300 == 0) s.input!.keys.add(PhysicalKeyboardKey.space);
          s.update(1 / 60);
        }
        if (dir != null) await snap(s, 1280, 720, '$dir/$name.png');
        if (dir != null && name == 'mage') await snap(s, 390, 844, '$dir/${name}_portrait.png');
        expect(s.state.tick, greaterThan(0));
      }
    });
  });
}
