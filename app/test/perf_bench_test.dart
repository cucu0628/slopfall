// Frame cost breakdown of a heavy scene (wave 20, two bosses, hundreds of
// enemies). Not a pass/fail test: prints where the time goes.
//   flutter test test/perf_bench_test.dart --reporter expanded

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightfall/game/input.dart';
import 'package:nightfall/game/session.dart';
import 'package:nightfall/game/touch.dart';
import 'package:nightfall/render/glyphs.dart';
import 'package:nightfall/render/renderer.dart';
import 'package:nightfall_sim/nightfall_sim.dart';

import 'render_snapshot_test.dart' show loadFonts;

void main() {
  testWidgets('frame cost', (tester) async {
    await tester.runAsync(() async {
      await loadFonts();
      await warmUpIconGlyphs();
      final r = Renderer()
        ..resize(1920, 1080)
        ..dpr = 1;
      final s = Session('engineer', r, input: Input(TouchState()), initial: createGame(5, [const PlayerSetup(localId, 'engineer')], godMode: true));
      s.state.enemies = [];
      startWave(s.state, 20);
      final p = s.state.players[0];
      // weapons that hit a lot (projectiles, damage numbers) but kill slowly,
      // so the screen fills up with enemies
      p.weapons = [
        WeaponInst(id: 'frost', level: 8),
        WeaponInst(id: 'orbs', level: 8),
        WeaponInst(id: 'aura', level: 1),
      ];
      p.perks = [PerkInst(id: 'might', level: 1, power: -9)];
      refreshStats(p);
      // warm up: let enemies pile in, the JIT settle and chunks get cached
      for (var i = 0; i < 3600; i++) {
        s.input!.keys
          ..clear()
          ..add((i ~/ 120) % 2 == 0 ? PhysicalKeyboardKey.keyD : PhysicalKeyboardKey.keyW);
        if (p.choices != null) s.input!.choose(0);
        s.update(1 / 60);
        if (i % 4 == 0) s.paint(ui.Canvas(ui.PictureRecorder()));
      }
      final prof = <String, int>{};
      r.profile = prof;
      final sim = Stopwatch(), draw = Stopwatch(), raster = Stopwatch();
      const frames = 300;
      var worst = 0;
      for (var i = 0; i < frames; i++) {
        s.input!.keys
          ..clear()
          ..add((i ~/ 120) % 2 == 0 ? PhysicalKeyboardKey.keyD : PhysicalKeyboardKey.keyW);
        if (p.choices != null) s.input!.choose(0);
        sim.start();
        s.update(1 / 60);
        sim.stop();
        final t0 = draw.elapsedMicroseconds;
        draw.start();
        final rec = ui.PictureRecorder();
        s.paint(ui.Canvas(rec));
        final pic = rec.endRecording();
        draw.stop();
        worst = (draw.elapsedMicroseconds - t0) > worst ? draw.elapsedMicroseconds - t0 : worst;
        if (i % 60 == 0) {
          raster.start();
          final img = await pic.toImage(1920, 1080);
          raster.stop();
          img.dispose();
        }
        pic.dispose();
      }
      final st = s.state;
      // ignore: avoid_print
      print('enemies ${st.enemies.length}, projectiles ${st.projectiles.length}, pickups ${st.pickups.length}, '
          'particles ${s.fx.particles.length}, texts ${s.fx.texts.length}');
      // ignore: avoid_print
      print('sim  ${(sim.elapsedMicroseconds / frames / 1000).toStringAsFixed(2)} ms/frame');
      // ignore: avoid_print
      print('draw ${(draw.elapsedMicroseconds / frames / 1000).toStringAsFixed(2)} ms/frame (worst ${(worst / 1000).toStringAsFixed(1)} ms)');
      // ignore: avoid_print
      print('  (chunk record total ${((prof['chunk record'] ?? 0) / 1000).toStringAsFixed(1)} ms, raster start total ${((prof['chunk raster start'] ?? 0) / 1000).toStringAsFixed(1)} ms over $frames frames)');
      prof.remove('chunk record');
      prof.remove('chunk raster start');
      for (final e in prof.entries) {
        // ignore: avoid_print
        print('  ${e.key.padRight(28)} ${(e.value / frames / 1000).toStringAsFixed(2)} ms   worst ${((r.profileWorst[e.key] ?? 0) / 1000).toStringAsFixed(1)} ms');
      }
      // ignore: avoid_print
      print('software raster ${(raster.elapsedMicroseconds / 5 / 1000).toStringAsFixed(1)} ms/frame (CPU, not the GPU path)');
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
