// Replays scenarios recorded from the original TypeScript simulation
// (test/fixtures/ts_golden.json, see tool/ts_golden/README.md) and checks the
// Dart port reproduces them bit for bit: same RNG state, same entity counts,
// same positions and HP. Also restores a save written by the TypeScript game.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:nightfall_sim/nightfall_sim.dart';
import 'package:test/test.dart';

import 'golden_runner.dart';
import 'helpers.dart';

void main() {
  final data = jsonDecode(File('test/fixtures/ts_golden.json').readAsStringSync()) as Map<String, Object?>;
  final sample = data['sample'] as int;
  final rows = (data['rows'] as Map).cast<String, Object?>();
  final saves = (data['saves'] as Map).cast<String, Object?>();

  group('parity with the TypeScript simulation', () {
    for (final sc in (data['scenarios'] as List).cast<Map<String, Object?>>()) {
      final name = sc['name'] as String;
      test(name, () {
        final want = (rows[name] as List).cast<List<Object?>>();
        var row = 0;
        runScenario(
          sc,
          sample,
          (s) {
            final diff = diffFingerprints(fingerprint(s), want[row++]);
            if (diff != null) fail('diverged at tick ${s.tick}: $diff');
          },
          onSave: (s) {
            // continue from the save the TypeScript game wrote at this point
            expect(roundTrip(snapshot(s, 1700000000000)), saves[name], reason: 'Dart writes the same save file');
            return restore(saves[name])!;
          },
        );
        expect(row, want.length);
      });
    }
  });
}
