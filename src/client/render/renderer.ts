import type { GameState, Player } from '../../sim/types';
import type { Effects } from './effects';
import {
  drawEnemy, drawEnemyProjectile, drawHazard, drawMinion, drawPickup, drawProjectile, drawTurret, drawZone, enemyColor, eprojColor, pickupColor, projectileColor,
} from './entities';
import { drawPlayer } from './heroes';
import { drawHud } from './hud';
import { glow, rgba } from './sprites';
import { CHARACTERS } from '../../sim/content/characters';
import { WorldRenderer } from './map';
import { Minimap } from './minimap';

const VIEW_W = 1400;
const VIEW_H = 800;
const VIEW_W_PORTRAIT = 1300;

const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

export class Renderer {
  readonly ctx: CanvasRenderingContext2D;
  w = 0;
  h = 0;
  dpr = 1;
  scale = 1;
  camX = 0;
  camY = 0;
  private world = new WorldRenderer();
  readonly minimap = new Minimap();

  constructor(readonly canvas: HTMLCanvasElement) {
    this.ctx = canvas.getContext('2d', { alpha: false })!;
    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  /** Phones/tablets: lighter resolution, HUD laid out around the touch controls. */
  touchMode = false;
  /** Touch aiming: where the ability will land (world coords). */
  aimPreview: { x: number; y: number; r: number } | null = null;

  resize(): void {
    this.dpr = Math.min(this.touchMode ? 1.5 : 2, window.devicePixelRatio || 1);
    this.w = window.innerWidth;
    this.h = window.innerHeight;
    this.canvas.width = Math.floor(this.w * this.dpr);
    this.canvas.height = Math.floor(this.h * this.dpr);
    this.canvas.style.width = `${this.w}px`;
    this.canvas.style.height = `${this.h}px`;
    // portrait screens (phones) get a tall view instead of a wide one
    this.scale = this.h > this.w
      ? Math.max(this.w / VIEW_H, this.h / VIEW_W_PORTRAIT)
      : Math.max(this.w / VIEW_W, this.h / VIEW_H);
  }

  /** Screen position (CSS px) of the local player, used for aiming. */
  screenOf(wx: number, wy: number): [number, number] {
    return [(wx - this.camX) * this.scale + this.w / 2, (wy - this.camY) * this.scale + this.h / 2];
  }

  draw(s: GameState, localId: string, alpha: number, fx: Effects, hud = true): void {
    const ctx = this.ctx;
    const t = fx.time;
    const me = s.players.find((p) => p.id === localId) ?? s.players[0];
    this.camX = lerp(me.px, me.x, alpha);
    this.camY = lerp(me.py, me.y, alpha);
    const shx = (Math.random() - 0.5) * fx.shake, shy = (Math.random() - 0.5) * fx.shake;

    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    ctx.fillStyle = '#0b0d17';
    ctx.fillRect(0, 0, this.w, this.h);

    const sc = this.scale * this.dpr;
    ctx.setTransform(sc, 0, 0, sc, (this.w / 2) * this.dpr - (this.camX + shx) * sc, (this.h / 2) * this.dpr - (this.camY + shy) * sc);

    const hw = this.w / 2 / this.scale + 80, hh = this.h / 2 / this.scale + 80;
    const minX = this.camX - hw, maxX = this.camX + hw, minY = this.camY - hh, maxY = this.camY + hh;
    const vis = (x: number, y: number, m = 0) => x > minX - m && x < maxX + m && y > minY - m && y < maxY + m;

    const seed = s.mapSeed;
    this.world.drawGround(ctx, seed, minX, minY, maxX, maxY);

    // ground telegraphs
    for (const h of s.hazards) if (h.kind === 'slam' || h.kind === 'skyfall' || h.kind === 'coin') drawHazard(ctx, h, t);
    for (const z of s.zones) if (z.kind === 'meteor' || z.kind === 'rain') drawZone(ctx, z, t);

    // auras
    for (const p of s.players) {
      if (p.dead) continue;
      for (const w of p.weapons) {
        if (w.id !== 'aura') continue;
        const x = lerp(p.px, p.x, alpha), y = lerp(p.py, p.y, alpha);
        const col = w.evolved ? '#fff2b0' : '#ffe08a';
        ctx.fillStyle = rgba(col, 0.08 + Math.sin(t * 3) * 0.02);
        ctx.beginPath();
        ctx.arc(x, y, w.r, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = rgba(col, 0.35);
        ctx.lineWidth = 2;
        ctx.setLineDash([10, 8]);
        ctx.lineDashOffset = -t * 30;
        ctx.stroke();
        ctx.setLineDash([]);
      }
    }

    this.world.drawObstacles(ctx, seed, minX, minY, maxX, maxY);
    if (this.aimPreview) {
      const a = this.aimPreview;
      ctx.fillStyle = 'rgba(255,140,60,0.12)';
      ctx.beginPath();
      ctx.arc(a.x, a.y, a.r, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = 'rgba(255,190,110,0.9)';
      ctx.lineWidth = 3;
      ctx.setLineDash([12, 8]);
      ctx.lineDashOffset = -t * 40;
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.beginPath();
      ctx.moveTo(a.x - 14, a.y);
      ctx.lineTo(a.x + 14, a.y);
      ctx.moveTo(a.x, a.y - 14);
      ctx.lineTo(a.x, a.y + 14);
      ctx.stroke();
    }
    this.world.drawLights(ctx, seed, minX, minY, maxX, maxY, t);

    // dash afterimages
    for (const g of fx.ghosts) {
      ctx.globalAlpha = (g.life / g.max) * 0.45;
      ctx.fillStyle = g.color;
      ctx.beginPath();
      ctx.arc(g.x, g.y, g.r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;

    // glow under pickups and enemies
    ctx.globalCompositeOperation = 'lighter';
    this.world.drawLightGlows(ctx, seed, minX, minY, maxX, maxY, t);
    for (const pk of s.pickups) {
      const x = lerp(pk.px, pk.x, alpha), y = lerp(pk.py, pk.y, alpha);
      if (!vis(x, y)) continue;
      glow(ctx, pickupColor(pk), x, y, pk.kind === 'chest' || pk.kind === 'relic' ? 50 : pk.kind === 'xp' ? 16 : 26, 0.6);
    }
    for (const e of s.enemies) {
      if (!(e.boss || e.elite || e.type === 'exploder' || e.type === 'shaman')) continue;
      const x = lerp(e.px, e.x, alpha), y = lerp(e.py, e.y, alpha);
      if (!vis(x, y, e.radius)) continue;
      glow(ctx, e.elite ? '#ffd166' : enemyColor(e), x, y, e.radius * 2.6, e.boss ? 0.5 : 0.4);
    }
    for (const p of s.players) {
      if (p.dead) continue;
      glow(ctx, CHARACTERS[p.charId].accent, lerp(p.px, p.x, alpha), lerp(p.py, p.y, alpha), 46, 0.35);
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';

    for (const pk of s.pickups) {
      const x = lerp(pk.px, pk.x, alpha), y = lerp(pk.py, pk.y, alpha);
      if (vis(x, y)) drawPickup(ctx, pk, x, y, t);
    }
    for (const z of s.zones) if (z.kind === 'nova' || z.kind === 'nova2' || z.kind === 'nova3' || z.kind === 'bash' || z.kind === 'raise') drawZone(ctx, z, t);
    for (const tu of s.turrets) if (vis(tu.x, tu.y)) drawTurret(ctx, tu, t);

    // enemies, nearest local player provides the facing direction
    for (const e of s.enemies) {
      const x = lerp(e.px, e.x, alpha), y = lerp(e.py, e.y, alpha);
      if (!vis(x, y, e.radius * 2)) continue;
      const dx = me.x - x, dy = me.y - y, d = Math.hypot(dx, dy) || 1;
      drawEnemy(ctx, e, x, y, t + e.id * 0.1, dx / d, dy / d);
    }
    for (const m of s.minions) drawMinion(ctx, m, lerp(m.px, m.x, alpha), lerp(m.py, m.y, alpha), t);

    for (const p of s.players) {
      if (p.dead) continue;
      const x = lerp(p.px, p.x, alpha), y = lerp(p.py, p.y, alpha);
      drawPlayer(ctx, p, x, y, t);
      this.drawPlayerBar(p, x, y);
    }

    this.world.drawCanopies(ctx, seed, minX, minY, maxX, maxY, this.camX, this.camY, t);

    for (const z of s.zones) if (z.kind === 'slash' || z.kind === 'slash2' || z.kind === 'slash3' || z.kind === 'bolt') drawZone(ctx, z, t);

    for (const pr of s.projectiles) {
      const x = lerp(pr.px, pr.x, alpha), y = lerp(pr.py, pr.y, alpha);
      if (vis(x, y)) drawProjectile(ctx, pr, x, y);
    }
    for (const b of s.eprojectiles) {
      const x = lerp(b.px, b.x, alpha), y = lerp(b.py, b.y, alpha);
      if (vis(x, y)) drawEnemyProjectile(ctx, b, x, y);
    }
    for (const h of s.hazards) if (h.kind === 'ring' || h.kind === 'laser') drawHazard(ctx, h, t);

    // additive glow on top of projectiles
    ctx.globalCompositeOperation = 'lighter';
    for (const pr of s.projectiles) {
      const x = lerp(pr.px, pr.x, alpha), y = lerp(pr.py, pr.y, alpha);
      if (vis(x, y)) glow(ctx, projectileColor(pr.kind), x, y, pr.radius * 3.2, 0.55);
    }
    for (const b of s.eprojectiles) {
      const x = lerp(b.px, b.x, alpha), y = lerp(b.py, b.y, alpha);
      if (vis(x, y)) glow(ctx, eprojColor(b.kind), x, y, b.r * 3.5, 0.6);
    }
    for (const p of fx.particles) {
      ctx.globalAlpha = Math.max(0, p.life / p.max);
      ctx.fillStyle = p.color;
      ctx.fillRect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size);
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';

    for (const r of fx.rings) {
      const k = r.life / r.max;
      ctx.strokeStyle = rgba(r.color, k);
      ctx.lineWidth = r.width * k + 1;
      ctx.beginPath();
      ctx.arc(r.x, r.y, r.r + (r.maxR - r.r) * (1 - k * k), 0, Math.PI * 2);
      ctx.stroke();
    }

    ctx.textAlign = 'center';
    ctx.lineJoin = 'round';
    for (const ft of fx.texts) {
      const k = ft.life / ft.max;
      ctx.globalAlpha = Math.min(1, k * 2);
      ctx.font = `bold ${ft.size}px system-ui, sans-serif`;
      ctx.lineWidth = 3;
      ctx.strokeStyle = 'rgba(0,0,0,0.7)';
      ctx.strokeText(ft.text, ft.x, ft.y);
      ctx.fillStyle = ft.color;
      ctx.fillText(ft.text, ft.x, ft.y);
    }
    ctx.globalAlpha = 1;

    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    this.world.drawVignette(ctx, this.w, this.h);
    if (hud) drawHud(ctx, this, s, me, fx);
  }

  private drawPlayerBar(p: Player, x: number, y: number): void {
    if (p.hp >= p.stats.maxHp) return;
    const ctx = this.ctx;
    const w = 34, k = Math.max(0, p.hp / p.stats.maxHp);
    ctx.fillStyle = 'rgba(0,0,0,0.6)';
    ctx.fillRect(x - w / 2 - 1, y + p.radius + 7, w + 2, 6);
    ctx.fillStyle = k > 0.3 ? '#ff4d6d' : '#ff2020';
    ctx.fillRect(x - w / 2, y + p.radius + 8, w * k, 4);
  }
}
