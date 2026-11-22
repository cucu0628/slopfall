// Goldfang the Greedy (secret boss): never attacks, keeps just out of reach
// and escapes with his treasure after goldfangEscape seconds. He drops coins
// while running; every third one is a fake that blows up when stepped near.

import '../../combat.dart';
import '../../entities.dart';
import '../../fdlibm.dart';
import '../../js.dart';
import '../../rng.dart';
import '../../types.dart';

const double goldfangEscape = 25;

/// Fuse of a fake coin once a player steps close.
const double coinFuse = 0.5;

void initGoldfang(Enemy e) {
  e.t = goldfangEscape; // escape timer
  e.t2 = 1.5; // next coin
  e.t3 = 0; // coins dropped
  e.sx = 2; // next strafe direction change
  e.sy = 1; // strafe direction
}

void goldfang(GameState s, Enemy e, double d, double nx, double ny, double sp, double dt, bool enraged) {
  e.t -= dt;
  if (e.t <= 0) {
    e.dead = true; // got away: no kill, no treasure
    s.events.add(EscapeEvent(e.x, e.y, 'Goldfang'));
    s.events.add(ExplodeEvent(e.x, e.y, 90, '#ffc83d'));
    return;
  }

  e.sx -= dt;
  if (e.sx <= 0) {
    e.sx = randRange(s, 1.8, 3.5);
    e.sy = -e.sy;
  }
  // stays close enough to be shot at, but runs from anyone who gets near
  final speed = sp * (enraged ? 1.15 : 1);
  double mx, my;
  if (d < 280) {
    mx = -nx - ny * e.sy * 0.6;
    my = -ny + nx * e.sy * 0.6;
  } else if (d > 440) {
    mx = nx;
    my = ny;
  } else {
    mx = -ny * e.sy;
    my = nx * e.sy;
  }
  final l = or1(hypot(mx, my));
  e.x += (mx / l) * speed * dt;
  e.y += (my / l) * speed * dt;
  e.ang = jsAtan2(my, mx);

  e.t2 -= dt;
  if (e.t2 <= 0) {
    e.t2 = enraged ? 0.75 : 1.1;
    e.t3++;
    if (jsMod(e.t3, 3) == 0) {
      // speed = 1 once the fuse is lit (systems/hazards.dart)
      addHazard(s, 'coin', x: e.x, y: e.y, r: 65, dmg: 14 * waveScale(s.wave.n).dmg, warn: 8, life: 0.05);
    } else {
      addPickup(s, 'coin', e.x, e.y, jsRound(3 + s.wave.n * 0.5));
    }
  }
}
