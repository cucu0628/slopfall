// Shared helpers for the simulation tests.

import 'dart:convert';

import 'package:nightfall_sim/nightfall_sim.dart';

/// Deterministic bot: circles around, always uses its ability, picks the first upgrade.
InputCmd botInput(GameState s, String id) {
  final p = s.players.firstWhere((x) => x.id == id);
  final a = s.tick / 120;
  return InputCmd(mx: jsCos(a), my: jsSin(a), ax: 200, ay: 50, ability: true, dash: s.tick % 200 == 0, choose: p.choices != null ? 0 : -1);
}

void run(GameState s, int ticks) {
  for (var i = 0; i < ticks && !s.gameOver; i++) {
    step(s, {for (final p in s.players) p.id: botInput(s, p.id)});
  }
}

String stateHash(GameState s) => jsonEncode(s.toJson());

InputCmd idleCmd({double mx = 0, double my = 0, double ax = 1, double ay = 0, bool ability = false, bool dash = false, int choose = -1}) =>
    InputCmd(mx: mx, my: my, ax: ax, ay: ay, ability: ability, dash: dash, choose: choose);

/// JSON round trip, like JSON.parse(JSON.stringify(x)) in the TypeScript tests.
Object? roundTrip(Object? json) => jsonDecode(jsonEncode(json));
