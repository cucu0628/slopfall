// Player projectiles (bolts, arrows, axes, shells, ...).

import type { Projectile } from '../../../sim/types';
import { rgba } from '../sprites';
import { drawCoin } from './pickups';
import { Ctx, TAU, circle } from './shared';

// ---------------------------------------------------------------- player stuff
export function projectileColor(kind: string): string {
  switch (kind) {
    case 'bolt': return '#6ee7ff';
    case 'bolt2': return '#b47cff';
    case 'arrow': return '#b6ff7a';
    case 'arrow2': return '#e6ffd0';
    case 'orb': return '#c084ff';
    case 'orb2': return '#ff7ae0';
    case 'axe': return '#ffb347';
    case 'axe2': return '#ff6a3d';
    case 'axe3': return '#ff4d8a';
    case 'prism': return '#fff6d6';
    case 'shell': return '#ffb347';
    case 'bullet': return '#7dffcf';
    case 'shard': return '#9ad8ff';
    case 'shard2': return '#e0f6ff';
    case 'coin': return '#ffc83d';
    default: return '#ffffff';
  }
}

export function drawProjectile(ctx: Ctx, p: Projectile, x: number, y: number): void {
  const col = projectileColor(p.kind);
  const r = p.radius;
  switch (p.kind) {
    case 'coin':
      drawCoin(ctx, x, y, r, p.age * 2);
      break;
    case 'bolt':
    case 'bolt2':
    case 'bullet': {
      const sp = Math.hypot(p.vx, p.vy) || 1;
      ctx.strokeStyle = rgba(col, 0.5);
      ctx.lineWidth = r * 1.2;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x - (p.vx / sp) * r * 3, y - (p.vy / sp) * r * 3);
      ctx.stroke();
      ctx.fillStyle = '#ffffff';
      circle(ctx, x, y, r * 0.6);
      ctx.fill();
      break;
    }
    case 'arrow':
    case 'arrow2': {
      const sp = Math.hypot(p.vx, p.vy) || 1;
      const ux = p.vx / sp, uy = p.vy / sp;
      ctx.strokeStyle = col;
      ctx.lineWidth = p.kind === 'arrow2' ? 3 : 2;
      ctx.beginPath();
      ctx.moveTo(x - ux * 22, y - uy * 22);
      ctx.lineTo(x, y);
      ctx.stroke();
      ctx.fillStyle = col;
      ctx.beginPath();
      ctx.moveTo(x + ux * 6, y + uy * 6);
      ctx.lineTo(x - uy * 4, y + ux * 4);
      ctx.lineTo(x + uy * 4, y - ux * 4);
      ctx.closePath();
      ctx.fill();
      break;
    }
    case 'orb':
    case 'orb2': {
      ctx.fillStyle = col;
      circle(ctx, x, y, r);
      ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,0.8)';
      circle(ctx, x - r * 0.3, y - r * 0.3, r * 0.35);
      ctx.fill();
      break;
    }
    case 'prism': {
      const sp = Math.hypot(p.vx, p.vy) || 1;
      const ux = p.vx / sp, uy = p.vy / sp;
      ctx.lineCap = 'round';
      for (const [w, c] of [[r * 2.2, 'rgba(180,140,255,0.35)'], [r * 1.3, 'rgba(110,231,255,0.6)'], [r * 0.6, '#ffffff']] as const) {
        ctx.strokeStyle = c;
        ctx.lineWidth = w;
        ctx.beginPath();
        ctx.moveTo(x - ux * r * 5, y - uy * r * 5);
        ctx.lineTo(x + ux * r, y + uy * r);
        ctx.stroke();
      }
      break;
    }
    case 'shell': {
      const prog = Math.min(1, p.age / Math.max(0.01, p.maxLife));
      const lift = Math.sin(prog * Math.PI) * 60;
      ctx.fillStyle = 'rgba(0,0,0,0.3)';
      ctx.beginPath();
      ctx.ellipse(x, y, r, r * 0.4, 0, 0, TAU);
      ctx.fill();
      ctx.fillStyle = '#3a3a44';
      circle(ctx, x, y - lift, r);
      ctx.fill();
      ctx.strokeStyle = col;
      ctx.lineWidth = 2;
      ctx.stroke();
      break;
    }
    case 'axe':
    case 'axe2':
    case 'axe3': {
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(p.ang);
      ctx.fillStyle = '#6b4a2b';
      ctx.fillRect(-r * 0.15, -r, r * 0.3, r * 2);
      ctx.fillStyle = col;
      for (const s of [-1, 1]) {
        ctx.beginPath();
        ctx.moveTo(0, s * r * 0.9);
        ctx.quadraticCurveTo(r * 1.1, s * r * 0.9, r * 0.9, s * r * 0.1);
        ctx.lineTo(0, s * r * 0.35);
        ctx.closePath();
        ctx.fill();
      }
      ctx.restore();
      break;
    }
    case 'shard':
    case 'shard2': {
      const a = Math.atan2(p.vy, p.vx);
      ctx.fillStyle = col;
      ctx.beginPath();
      ctx.moveTo(x + Math.cos(a) * r * 1.8, y + Math.sin(a) * r * 1.8);
      ctx.lineTo(x + Math.cos(a + 1.6) * r * 0.6, y + Math.sin(a + 1.6) * r * 0.6);
      ctx.lineTo(x - Math.cos(a) * r * 1.2, y - Math.sin(a) * r * 1.2);
      ctx.lineTo(x + Math.cos(a - 1.6) * r * 0.6, y + Math.sin(a - 1.6) * r * 0.6);
      ctx.closePath();
      ctx.fill();
      break;
    }
    default:
      ctx.fillStyle = col;
      circle(ctx, x, y, r);
      ctx.fill();
  }
}
