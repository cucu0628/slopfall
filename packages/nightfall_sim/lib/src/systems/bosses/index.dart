// Boss behaviours. Every boss has its own file; register it here by its
// enemy id (content/enemies.dart) and add it to bossOrder to make it spawn
// (the secret boss is spawned by systems/secret.dart instead).

import '../../types.dart';
import 'brood_mother.dart';
import 'frost_wyrm.dart';
import 'goldfang.dart';
import 'golem.dart';
import 'necro_lord.dart';
import 'slime_king.dart';
import 'void_eye.dart';

export 'frost_wyrm.dart' show wyrmSegmentRadius, wyrmSegments;
export 'goldfang.dart' show coinFuse, goldfangEscape;

class BossTick {
  final GameState s;
  final Enemy e;
  final Player target;
  final double d; // distance to target
  final double nx; // unit vector toward target
  final double ny;
  final double sp; // current move speed (slows applied)
  final double dt;
  final bool enraged; // below 50% HP
  const BossTick(this.s, this.e, this.target, this.d, this.nx, this.ny, this.sp, this.dt, this.enraged);
}

class _BossBehavior {
  /// Initial attack timers when the boss spawns.
  final void Function(Enemy e) init;
  final void Function(BossTick b) update;
  const _BossBehavior(this.init, this.update);
}

final Map<String, _BossBehavior> _bosses = {
  'slimeking': _BossBehavior((e) => e.t = 3, (b) => slimeKing(b.s, b.e, b.target, b.nx, b.ny, b.sp, b.dt, b.enraged)),
  'necrolord': _BossBehavior(
    (e) => e
      ..t = 2
      ..t2 = 3
      ..t3 = 1,
    (b) => necroLord(b.s, b.e, b.d, b.nx, b.ny, b.sp, b.dt, b.enraged),
  ),
  'golem': _BossBehavior(
    (e) => e
      ..t = 3
      ..t2 = 6,
    (b) => golem(b.s, b.e, b.nx, b.ny, b.sp, b.dt, b.enraged),
  ),
  'voideye': _BossBehavior(
    (e) => e
      ..t = 4
      ..t2 = 0,
    (b) => voidEye(b.s, b.e, b.d, b.nx, b.ny, b.sp, b.dt, b.enraged),
  ),
  'broodmother': _BossBehavior(
    (e) => e
      ..t = 2.5
      ..t2 = 1.5
      ..t3 = 0.9
      ..sx = 3,
    (b) => broodMother(b.s, b.e, b.nx, b.ny, b.sp, b.dt, b.enraged),
  ),
  'wyrm': _BossBehavior(
    (e) => e
      ..t = 2.5
      ..t2 = 6
      ..t3 = 2,
    (b) => wyrm(b.s, b.e, b.target, b.d, b.nx, b.ny, b.sp, b.dt, b.enraged),
  ),
  'goldfang': _BossBehavior(initGoldfang, (b) => goldfang(b.s, b.e, b.d, b.nx, b.ny, b.sp, b.dt, b.enraged)),
};

void initBoss(Enemy e) {
  e.state = 0;
  _bosses[e.type]?.init(e);
}

void updateBoss(GameState s, Enemy e, Player target, double d, double nx, double ny, double sp, double dt) {
  _bosses[e.type]?.update(BossTick(s, e, target, d, nx, ny, sp, dt, e.hp < e.maxHp * 0.5));
}
