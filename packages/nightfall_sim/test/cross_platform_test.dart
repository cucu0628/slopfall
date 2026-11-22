// Determinism across platforms: the simulation must give bit-identical
// results on the Dart VM, compiled to JavaScript and to WebAssembly.
//
//   dart test -p vm,node test/cross_platform_test.dart
//   dart test -p node -c dart2wasm test/cross_platform_test.dart

import 'package:test/test.dart';

import 'fixtures/ts_golden_final.dart';
import 'golden_runner.dart';

void main() {
  group('same results as the TypeScript simulation on this platform', () {
    for (final sc in goldenScenarios) {
      final name = sc['name'] as String;
      test(name, () {
        final s = runScenario(sc, goldenSample, (_) {});
        expect(diffFingerprints(fingerprint(s), goldenFinal[name]!), isNull);
      });
    }
  });
}
