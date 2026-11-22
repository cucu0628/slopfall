import 'dart:math' as math;

import 'js.dart';
import 'map.dart';
import 'spatial.dart';
import 'systems/abilities.dart';
import 'systems/enemies.dart';
import 'systems/hazards.dart';
import 'systems/idle.dart';
import 'systems/leveling.dart';
import 'systems/pickups.dart';
import 'systems/secret.dart';
import 'systems/waves.dart';
import 'systems/weapons/index.dart';
import 'types.dart';

class PlayerSetup {
  final String id;
  final String charId;
  const PlayerSetup(this.id, this.charId);
}

GameState createGame(int seed, List<PlayerSetup> setups, {bool pauseOnLevelUp = true, double waveDuration = 45, bool godMode = false}) {
  final s = GameState(
    cfg: SimConfig(pauseOnLevelUp: pauseOnLevelUp, waveDuration: waveDuration, godMode: godMode),
    mapSeed: hash(seed, 17, 31),
    rng: i32(seed),
    players: [for (var i = 0; i < setups.length; i++) createPlayer(setups[i].id, setups[i].charId, i * 60.0, 0)],
    secret: rollSecret(seed),
  );
  startWave(s, 1);
  return s;
}

/// Inputs may come from the network one day: never trust them.
InputCmd _sanitize(InputCmd? cmd) {
  if (cmd == null) return InputCmd();
  return InputCmd(
    mx: finiteClamp(cmd.mx, 1),
    my: finiteClamp(cmd.my, 1),
    ax: finiteClamp(cmd.ax, 5000),
    ay: finiteClamp(cmd.ay, 5000),
    ability: cmd.ability,
    dash: cmd.dash,
    choose: cmd.choose,
  );
}

bool isFrozen(GameState s) => s.cfg.pauseOnLevelUp && s.players.any((p) => !p.dead && p.choices != null);

const double _webSlow = 0.55;
const double _dashSpeed = 1050;
const double _dashTime = 0.18;

/// Universal dash: a short invulnerable burst in the movement (or facing) direction.
void _startDash(GameState s, Player p, InputCmd cmd) {
  var dx = cmd.mx, dy = cmd.my;
  if (hypot(dx, dy) < 0.1) {
    dx = p.fx;
    dy = p.fy;
  }
  final l = or1(hypot(dx, dy));
  p.dashT = _dashTime;
  p.dashX = (dx / l) * _dashSpeed;
  p.dashY = (dy / l) * _dashSpeed;
  p.invuln = math.max(p.invuln, _dashTime + 0.15);
  p.dashCd = p.dashMaxCd;
  s.events.add(DashEvent(p.id));
}

void _updatePlayer(GameState s, Player p, InputCmd cmd, double dt) {
  p.ax = cmd.ax;
  p.ay = cmd.ay;
  p.invuln = math.max(0, p.invuln - dt);
  p.hurtT = math.max(0, p.hurtT - dt);
  p.dashMaxCd = (p.charId == 'ranger' ? 1.8 : 2.6) * p.stats.cooldown;
  p.dashCd = math.max(0, p.dashCd - dt);
  p.slowT = math.max(0, p.slowT - dt);
  if (cmd.dash && p.dashCd <= 0 && p.dashT <= 0) _startDash(s, p, cmd);
  if (p.dashT > 0) {
    p.dashT -= dt;
    p.x += p.dashX * dt;
    p.y += p.dashY * dt;
  } else {
    var mx = cmd.mx, my = cmd.my;
    final l = hypot(mx, my);
    if (l > 1) {
      mx /= l;
      my /= l;
    }
    final speed = p.stats.speed * (p.slowT > 0 ? _webSlow : 1);
    p.x += mx * speed * dt;
    p.y += my * speed * dt;
    if (l > 0.1) {
      final fl = hypot(mx, my);
      p.fx = mx / fl;
      p.fy = my / fl;
    }
  }
  resolveObstacles(s.mapSeed, p, p.radius);
  updateIdle(s, p, dt);
  if (p.stats.regen > 0) p.hp = math.min(p.stats.maxHp, p.hp + p.stats.regen * dt);
  updateAbility(s, p, cmd, dt);
  updateWeapons(s, p, dt);
}

void _savePrev(List<Moving> list) {
  for (final o in list) {
    o.px = o.x;
    o.py = o.y;
  }
}

void _cleanup(GameState s) {
  s.enemies.removeWhere((x) => x.dead);
  s.projectiles.removeWhere((x) => x.dead);
  s.eprojectiles.removeWhere((x) => x.dead);
  s.zones.removeWhere((x) => x.dead);
  s.hazards.removeWhere((x) => x.dead);
  s.turrets.removeWhere((x) => x.dead);
  s.minions.removeWhere((x) => x.dead);
  s.pickups.removeWhere((x) => x.dead);
  while (s.corpses.isNotEmpty && s.time - s.corpses[0].t > 8) {
    s.corpses.removeAt(0);
  }
}

/// Advances the simulation by one fixed tick.
void step(GameState s, Map<String, InputCmd> inputs, [double dt = dt60]) {
  s.events.clear();
  if (s.gameOver) return;

  for (final p in s.players) {
    final cmd = _sanitize(inputs[p.id]);
    if (p.choices != null && cmd.choose >= 0) chooseUpgrade(s, p, cmd.choose);
    updateLeveling(s, p);
  }
  if (isFrozen(s)) return;

  _savePrev(s.players);
  _savePrev(s.enemies);
  _savePrev(s.projectiles);
  _savePrev(s.eprojectiles);
  _savePrev(s.minions);
  _savePrev(s.pickups);
  s.tick++;
  s.time += dt;
  buildGrid(s);

  for (final p in s.players) {
    if (!p.dead) _updatePlayer(s, p, _sanitize(inputs[p.id]), dt);
  }
  updateEnemies(s, dt);
  updateProjectiles(s, dt);
  updateZones(s, dt);
  updateTurrets(s, dt);
  updateMinions(s, dt);
  updateEnemyProjectiles(s, dt);
  updateHazards(s, dt);
  updatePickups(s, dt);
  updateWaves(s, dt);
  for (final p in s.players) {
    updateLeveling(s, p);
  }
  _cleanup(s);

  if (s.players.every((p) => p.dead)) s.gameOver = true;
}
