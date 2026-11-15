import { biomeAt, CHUNK, getChunk } from '../../sim/map';
import type { GameState, Player } from '../../sim/types';
import { MINIMAP_RGB } from './map';

type Ctx = CanvasRenderingContext2D;

const RANGE = 1500; // world units from the player to the minimap edge
const SAMPLE = 48; // world units per terrain sample
const MARGIN = 400; // terrain is rendered a bit larger so it can scroll before a refresh

const RGB = Object.fromEntries(
  Object.entries(MINIMAP_RGB).map(([k, h]) => {
    const n = parseInt(h.slice(1), 16);
    return [k, [(n >> 16) & 255, (n >> 8) & 255, n & 255]];
  }),
) as Record<string, number[]>;

/** Top-right minimap: terrain, obstacles, enemies, bosses, pickups and players. */
export class Minimap {
  private terrain = document.createElement('canvas');
  private tx = NaN;
  private ty = NaN;
  private seed = -1;

  private refreshTerrain(seed: number, cx: number, cy: number): void {
    const half = RANGE + MARGIN;
    const n = Math.ceil((half * 2) / SAMPLE);
    this.terrain.width = this.terrain.height = n;
    const g = this.terrain.getContext('2d')!;
    const img = g.createImageData(n, n);
    for (let j = 0; j < n; j++) {
      for (let i = 0; i < n; i++) {
        const rgb = RGB[biomeAt(seed, cx - half + (i + 0.5) * SAMPLE, cy - half + (j + 0.5) * SAMPLE)];
        const o = (j * n + i) * 4;
        img.data[o] = rgb[0];
        img.data[o + 1] = rgb[1];
        img.data[o + 2] = rgb[2];
        img.data[o + 3] = 255;
      }
    }
    g.putImageData(img, 0, 0);
    this.tx = cx;
    this.ty = cy;
    this.seed = seed;
  }

  draw(ctx: Ctx, s: GameState, me: Player, x: number, y: number, size: number, t: number): void {
    const seed = s.mapSeed;
    if (seed !== this.seed || Math.abs(me.x - this.tx) > MARGIN * 0.7 || Math.abs(me.y - this.ty) > MARGIN * 0.7) {
      this.refreshTerrain(seed, me.x, me.y);
    }
    const k = size / (RANGE * 2); // world -> minimap pixels
    const cx = x + size / 2, cy = y + size / 2;
    const map = (wx: number, wy: number): [number, number] => [cx + (wx - me.x) * k, cy + (wy - me.y) * k];

    ctx.save();
    ctx.beginPath();
    ctx.roundRect(x, y, size, size, 10);
    ctx.clip();

    // terrain
    const half = RANGE + MARGIN;
    ctx.imageSmoothingEnabled = true;
    ctx.globalAlpha = 0.9;
    const [tx0, ty0] = map(this.tx - half, this.ty - half);
    ctx.drawImage(this.terrain, tx0, ty0, half * 2 * k, half * 2 * k);
    ctx.globalAlpha = 1;

    // obstacles
    ctx.fillStyle = 'rgba(150,155,175,0.55)';
    const c0x = Math.floor((me.x - RANGE) / CHUNK), c1x = Math.floor((me.x + RANGE) / CHUNK);
    const c0y = Math.floor((me.y - RANGE) / CHUNK), c1y = Math.floor((me.y + RANGE) / CHUNK);
    for (let gx = c0x; gx <= c1x; gx++) {
      for (let gy = c0y; gy <= c1y; gy++) {
        for (const o of getChunk(seed, gx, gy).obstacles) {
          const [ox, oy] = map(o.x, o.y);
          const r = Math.max(1, o.r * k);
          ctx.fillRect(ox - r, oy - r, r * 2, r * 2);
        }
      }
    }

    // view rectangle hint
    ctx.strokeStyle = 'rgba(255,255,255,0.12)';
    ctx.lineWidth = 1;
    ctx.strokeRect(cx - 700 * k, cy - 400 * k, 1400 * k, 800 * k);

    // pickups that matter
    for (const p of s.pickups) {
      if (p.kind === 'xp' || p.kind === 'coin') continue;
      const [px, py] = map(p.x, p.y);
      ctx.fillStyle = p.kind === 'chest' || p.kind === 'relic' ? '#ffd166' : p.kind === 'heal' ? '#ff4d6d' : p.kind === 'magnet' ? '#5d9bff' : '#ffb347';
      const r = p.kind === 'chest' || p.kind === 'relic' ? 3.5 : 2.5;
      ctx.fillRect(px - r, py - r, r * 2, r * 2);
    }

    // enemies
    for (const e of s.enemies) {
      if (e.boss) continue;
      const [ex, ey] = map(e.x, e.y);
      if (e.elite) {
        ctx.fillStyle = '#ffd166';
        ctx.fillRect(ex - 2.5, ey - 2.5, 5, 5);
      } else {
        ctx.fillStyle = 'rgba(255,80,90,0.85)';
        ctx.fillRect(ex - 1, ey - 1, 2, 2);
      }
    }
    for (const e of s.enemies) {
      if (!e.boss) continue;
      let [ex, ey] = map(e.x, e.y);
      ex = Math.max(x + 6, Math.min(x + size - 6, ex));
      ey = Math.max(y + 6, Math.min(y + size - 6, ey));
      ctx.fillStyle = '#ff2e88';
      ctx.beginPath();
      ctx.arc(ex, ey, 5 + Math.sin(t * 6) * 1, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#fff';
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    // players (local one is an arrow in the centre)
    for (const p of s.players) {
      if (p.dead || p === me) continue;
      const [px, py] = map(p.x, p.y);
      ctx.fillStyle = '#7ae7ff';
      ctx.beginPath();
      ctx.arc(px, py, 3.5, 0, Math.PI * 2);
      ctx.fill();
    }
    const a = Math.atan2(me.fy, me.fx);
    ctx.translate(cx, cy);
    ctx.rotate(a);
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.moveTo(7, 0);
    ctx.lineTo(-5, -4.5);
    ctx.lineTo(-2.5, 0);
    ctx.lineTo(-5, 4.5);
    ctx.closePath();
    ctx.fill();
    ctx.restore();

    ctx.strokeStyle = 'rgba(130,150,255,0.35)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.roundRect(x + 0.5, y + 0.5, size - 1, size - 1, 10);
    ctx.stroke();
  }
}
