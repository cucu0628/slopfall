// Weapon behaviours. Every weapon has its own file and is registered here by
// id; the id must match its data entry in content/weapons.dart.

import '../../combat.dart';
import '../../content/weapons.dart';
import '../../types.dart';
import 'arrow.dart';
import 'aura.dart';
import 'axe.dart';
import 'bolt.dart';
import 'coins.dart';
import 'frost.dart';
import 'lightning.dart';
import 'nova.dart';
import 'orbs.dart';
import 'sword.dart';
import 'turret.dart';

export 'minions.dart' show updateMinions;
export 'projectiles.dart' show updateProjectiles;
export 'shared.dart' show chainLightning;
export 'turret.dart' show placeTurret, updateTurrets;
export 'zones.dart' show updateZones;

/// Called every tick for each weapon the player owns. `w.cd` is already ticked down.
typedef WeaponUpdate = void Function(GameState s, Player p, WeaponInst w, WStats st, double dt);

const Map<String, WeaponUpdate> _weaponUpdates = {
  'sword': fireSword,
  'bolt': fireBolt,
  'arrow': fireArrow,
  'orbs': updateOrbs,
  'axe': fireAxe,
  'lightning': fireLightning,
  'aura': updateAura,
  'nova': fireNova,
  'turret': deployTurret,
  'frost': fireFrost,
  'coins': fireCoins,
};

void updateWeapons(GameState s, Player p, double dt) {
  final rate = isRaging(p) ? 1.5 : 1;
  for (final w in p.weapons) {
    final st = weaponStats(p, w);
    w.cd -= dt * rate;
    _weaponUpdates[w.id]?.call(s, p, w, st, dt);
  }
}
