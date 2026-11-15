import { CHARACTERS } from '../sim/content/characters';
import { ENEMIES } from '../sim/content/enemies';
import { nearestEnemy } from '../sim/spatial';
import { DT, type GameState, type InputCmd, type SimEvent } from '../sim/types';
import { createGame, isFrozen, step } from '../sim/world';
import type { Sound } from './audio';
import type { Input } from './input';
import { AIM_DRAG } from './touch';
import { METEOR_RANGE } from '../sim/systems/abilities';
import { Effects } from './render/effects';
import type { Renderer } from './render/renderer';

export const LOCAL_ID = 'p1';

export interface SessionHooks {
  onFrame?: (s: GameState) => void;
  onGameOver?: (s: GameState) => void;
}

/**
 * Runs one game: fixed-timestep simulation, event -> effects translation and
 * rendering. In demo mode a simple bot drives the player (main menu backdrop).
 */
export class Session {
  readonly state: GameState;
  readonly fx = new Effects();
  paused = false;
  private acc = 0;
  private last = 0;
  private raf = 0;
  private overT = 0;
  private overFired = false;
  private lastDodge = -1;

  constructor(
    readonly charId: string,
    private renderer: Renderer,
    private input: Input | null,
    private sound: Sound | null,
    private hooks: SessionHooks = {},
    initial: GameState | null = null,
  ) {
    const demo = !input;
    const seed = (Math.random() * 2 ** 31) | 0;
    this.state = initial ?? createGame(seed, [{ id: LOCAL_ID, charId }], demo ? { godMode: true } : {});
  }

  start(): void {
    this.last = performance.now();
    const loop = (now: number) => {
      this.frame(now);
      this.raf = requestAnimationFrame(loop);
    };
    this.raf = requestAnimationFrame(loop);
  }

  stop(): void {
    cancelAnimationFrame(this.raf);
  }

  /** Debug helper: simulates `seconds` of bot play instantly (choices auto-picked). */
  fastForward(seconds: number): void {
    const n = Math.round(seconds / DT);
    for (let i = 0; i < n && !this.state.gameOver; i++) {
      step(this.state, { [LOCAL_ID]: this.botCommand() });
    }
  }

  private command(): InputCmd {
    const s = this.state;
    const me = s.players[0];
    if (!this.input) return this.botCommand();
    const [sx, sy] = this.renderer.screenOf(me.x, me.y);
    const cmd = this.input.sample(sx, sy, this.renderer.scale);
    if (this.input.usingTouch) {
      const cast = this.input.lastCast;
      if (cast?.dragged) {
        // aimed by dragging the ability button
        [cmd.ax, cmd.ay] = this.touchAimOffset(cast.dx, cast.dy);
      } else {
        // no mouse on touch screens: aim at the nearest enemy, else straight ahead
        const e = nearestEnemy(s, me.x, me.y, 700);
        cmd.ax = e ? e.x - me.x : me.fx * 120;
        cmd.ay = e ? e.y - me.y : me.fy * 120;
      }
    }
    return cmd;
  }

  /**
   * Ability-button drag (px) to a world offset; full drag = max meteor range,
   * kept inside the visible area so the target is always on screen.
   */
  private touchAimOffset(dx: number, dy: number): [number, number] {
    const k = METEOR_RANGE / AIM_DRAG;
    const r = this.renderer;
    const hw = (r.w / 2 / r.scale) * 0.9, hh = (r.h / 2 / r.scale) * 0.9;
    return [Math.max(-hw, Math.min(hw, dx * k)), Math.max(-hh, Math.min(hh, dy * k))];
  }

  /** Target marker while the player drags the ability button. */
  private updateAimPreview(): void {
    const t = this.input?.touch;
    const me = this.state.players[0];
    if (!t?.aiming || !t.aimDragged || me.dead) {
      this.renderer.aimPreview = null;
      return;
    }
    const [ax, ay] = this.touchAimOffset(t.aimDX, t.aimDY);
    const r = 170 * me.stats.area * (1 + 0.12 * (me.abilityLevel - 1));
    this.renderer.aimPreview = { x: me.x + ax, y: me.y + ay, r };
  }

  private botCommand(): InputCmd {
    const s = this.state;
    const p = s.players[0];
    let rx = Math.cos(s.time / 4), ry = Math.sin(s.time / 4);
    for (const e of s.enemies) {
      const dx = p.x - e.x, dy = p.y - e.y, d2 = dx * dx + dy * dy;
      if (d2 < 160 * 160) {
        rx += (dx / d2) * 300;
        ry += (dy / d2) * 300;
      }
    }
    const e = nearestEnemy(s, p.x, p.y, 500);
    return {
      mx: rx, my: ry, ax: e ? e.x - p.x : 100, ay: e ? e.y - p.y : 0,
      ability: !!e && s.tick % 600 < 5, dash: false, choose: p.choices ? Math.floor(s.tick % 3) : -1,
    };
  }

  private frame(now: number): void {
    const real = Math.min(0.1, (now - this.last) / 1000);
    this.last = now;
    const s = this.state;

    if (!this.paused) {
      this.acc += real;
      let n = 0;
      while (this.acc >= DT && n < 5) {
        step(s, { [LOCAL_ID]: this.command() });
        this.handleEvents(s.events);
        for (const p of s.players) {
          if (p.dashT > 0 && s.tick % 2 === 0) this.fx.ghost(p.x, p.y, p.radius, CHARACTERS[p.charId].accent);
        }
        this.acc -= DT;
        n++;
      }
      if (n === 5) this.acc = 0;
      this.fx.update(real);
    }

    if (this.input) this.updateAimPreview();
    const alpha = this.paused || isFrozen(s) || s.gameOver ? 1 : this.acc / DT;
    this.renderer.draw(s, LOCAL_ID, alpha, this.fx, !!this.input);
    this.hooks.onFrame?.(s);

    if (s.gameOver && !this.overFired) {
      this.overT += real;
      if (this.overT > 1.6) {
        this.overFired = true;
        this.hooks.onGameOver?.(s);
      }
    }
  }

  private handleEvents(events: SimEvent[]): void {
    const fx = this.fx, snd = this.sound, s = this.state;
    const me = s.players[0];
    for (const ev of events) {
      switch (ev.t) {
        case 'hit':
          if (Math.abs(ev.x - me.x) < 900 && Math.abs(ev.y - me.y) < 600) {
            if (ev.dot) fx.text(ev.x, ev.y, String(ev.v), '#ff9a3d', 11, 0.5);
            else fx.text(ev.x, ev.y, String(ev.v), ev.crit ? '#ffd166' : '#ffffff', ev.crit ? 18 : 13);
            if (ev.crit) fx.burst(ev.x, ev.y, '#ffd166', 3, 120, 2, 0.3);
          }
          snd?.play('hit');
          break;
        case 'kill': {
          const color = ENEMIES[ev.type]?.color ?? '#fff';
          if (ev.boss && ev.type === 'goldfang') {
            fx.burst(ev.x, ev.y, '#ffc83d', 90, 520, 6, 1.3);
            fx.ring(ev.x, ev.y, 260, '#ffc83d', 0.8, 12);
            fx.addShake(18);
            fx.banner('GOLDFANG CAUGHT!', 'He dropped his treasure. Grab it!', '#ffc83d', 3);
            snd?.play('victory');
            snd?.play('coin');
          } else if (ev.boss) {
            fx.burst(ev.x, ev.y, color, 80, 500, 7, 1.2);
            fx.burst(ev.x, ev.y, '#ffffff', 40, 300, 4, 0.8);
            fx.ring(ev.x, ev.y, 300, color, 0.8, 14);
            fx.addShake(22);
            fx.banner('BOSS DEFEATED', `${ENEMIES[ev.type].name} has fallen`, '#ffd166', 3);
            snd?.play('victory');
            snd?.play('explode');
          } else {
            fx.burst(ev.x, ev.y, color, ev.elite ? 30 : 7, ev.elite ? 260 : 150, ev.elite ? 5 : 3);
            snd?.play('kill');
          }
          break;
        }
        case 'phurt':
          if (ev.pid === LOCAL_ID) {
            fx.hurtFlash = 0.55;
            fx.addShake(5);
            fx.text(me.x, me.y - 24, `-${ev.v}`, '#ff4d4d', 16);
            snd?.play('hurt');
          }
          break;
        case 'pdeath':
          fx.burst(me.x, me.y, CHARACTERS[me.charId].accent, 60, 300, 5, 1.2);
          fx.addShake(16);
          snd?.play('death');
          break;
        case 'heal':
          if (ev.pid === LOCAL_ID) fx.text(me.x, me.y - 24, `+${ev.v}`, '#6bff8f', 15);
          break;
        case 'vigor':
          if (ev.pid !== LOCAL_ID) break;
          fx.toast(`+${ev.v} MAX HP`, 'Surviving the night hardens you', '#6bff8f');
          fx.ring(me.x, me.y, 110, '#6bff8f', 0.6, 6);
          break;
        case 'levelup':
          if (ev.pid === LOCAL_ID) {
            fx.ring(me.x, me.y, 120, '#4fa3ff', 0.5, 6);
            snd?.play('levelup');
          }
          break;
        case 'wave':
          if (!ev.boss) {
            fx.banner(`WAVE ${ev.n}`, ev.n === 1 ? 'Survive the night' : 'They grow stronger...', '#ffffff', 2.2);
            snd?.play('wave');
          }
          break;
        case 'boss':
          if (ev.id === 'goldfang') {
            fx.banner(ev.name.toUpperCase(), 'A secret merchant! Catch him before he escapes', '#ffc83d', 3.5);
            snd?.play('coin');
            break;
          }
          fx.banner(ev.name.toUpperCase(), `Wave ${s.wave.n} boss`, '#ff2e88', 3);
          fx.addShake(10);
          snd?.play('boss');
          break;
        case 'escape':
          fx.burst(ev.x, ev.y, '#ffc83d', 50, 300, 4, 0.9);
          fx.banner('HE GOT AWAY!', `${ev.name} vanished with all his gold...`, '#aab4d4', 3);
          snd?.play('coin');
          break;
        case 'unique':
          if (ev.pid !== LOCAL_ID) break;
          fx.banner('UNIQUE ITEM!', ev.name, '#ffc83d', 3.5);
          fx.toast(ev.name.toUpperCase(), ev.desc);
          fx.ring(me.x, me.y, 220, '#ffc83d', 0.8, 10);
          fx.burst(me.x, me.y, '#ffc83d', 60, 320, 5, 1);
          snd?.play('chest');
          break;
        case 'explode':
          fx.ring(ev.x, ev.y, ev.r, ev.color, 0.45, ev.r > 300 ? 20 : 8);
          if (ev.color !== '#2ee6c5') {
            fx.burst(ev.x, ev.y, ev.color, Math.min(50, 10 + ev.r / 8), ev.r * 2.5, 4, 0.5);
            snd?.play('explode');
          }
          break;
        case 'pickup':
          if (ev.pid !== LOCAL_ID) break;
          if (ev.kind === 'xp') snd?.play('gem');
          else if (ev.kind === 'coin') snd?.play('coin');
          else if (ev.kind !== 'chest' && ev.kind !== 'relic') {
            snd?.play('pickup');
            const label = ev.kind === 'heal' ? 'HEAL' : ev.kind === 'magnet' ? 'MAGNET' : 'BOMB!';
            fx.text(me.x, me.y - 34, label, '#ffffff', 16, 1);
          }
          break;
        case 'chest':
          if (ev.pid !== LOCAL_ID) break;
          snd?.play('chest');
          fx.toast('TREASURE CHEST', ev.items.join('  ·  '));
          fx.burst(me.x, me.y, '#ffd166', 40, 260, 4, 0.9);
          break;
        case 'evolve':
          if (ev.pid !== LOCAL_ID) break;
          fx.banner('EVOLUTION!', ev.name, '#ffd166', 3);
          fx.ring(me.x, me.y, 200, '#ffd166', 0.7, 10);
          snd?.play('victory');
          break;
        case 'ability':
          if (ev.pid === LOCAL_ID) {
            fx.ring(me.x, me.y, 90, CHARACTERS[me.charId].accent, 0.35, 6);
            snd?.play('ability');
          }
          break;
        case 'dash':
          if (ev.pid === LOCAL_ID) snd?.play('dash');
          break;
        case 'dodge':
          if (ev.pid === LOCAL_ID && fx.time - this.lastDodge > 0.4) {
            this.lastDodge = fx.time;
            fx.text(me.x, me.y - 30, 'DODGE!', '#9ad8ff', 17, 0.8);
            snd?.play('select');
          }
          break;
        case 'sfx':
          snd?.play(ev.name);
          break;
        case 'shake':
          fx.addShake(ev.v);
          break;
      }
    }
  }
}
