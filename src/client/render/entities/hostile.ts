// Enemy projectiles and boss hazards (slams, shockwaves, lasers, meteors).

import type { EnemyProjectile, Hazard } from '../../../sim/types';
import { drawCoin } from './pickups';
import { Ctx, TAU, circle } from './shared';

// ---------------------------------------------------------------- hostile
export function eprojColor(kind: string): string {
  switch (kind) {
    case 'arrow': return '#ffe9b0';
    case 'skull': return '#b26bff';
    case 'web': return '#e8e8f0';
    case 'ice': return '#9ad8ff';
    default: return '#ff2e88';
  }
}

export function drawEnemyProjectile(ctx: Ctx, b: EnemyProjectile, x: number, y: number): void {
  if (b.kind === 'web') {
    ctx.strokeStyle = 'rgba(235,235,245,0.9)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    for (let i = 0; i < 6; i++) {
      const a = (i * TAU) / 6;
      ctx.moveTo(x, y);
      ctx.lineTo(x + Math.cos(a) * b.r * 1.3, y + Math.sin(a) * b.r * 1.3);
    }
    ctx.stroke();
    circle(ctx, x, y, b.r * 0.55);
    ctx.stroke();
    circle(ctx, x, y, b.r);
    ctx.stroke();
    return;
  }
  if (b.kind === 'ice') {
    const a = Math.atan2(b.vy, b.vx);
    ctx.fillStyle = '#c8f0ff';
    ctx.beginPath();
    ctx.moveTo(x + Math.cos(a) * b.r * 2, y + Math.sin(a) * b.r * 2);
    ctx.lineTo(x + Math.cos(a + 1.7) * b.r * 0.7, y + Math.sin(a + 1.7) * b.r * 0.7);
    ctx.lineTo(x - Math.cos(a) * b.r * 1.2, y - Math.sin(a) * b.r * 1.2);
    ctx.lineTo(x + Math.cos(a - 1.7) * b.r * 0.7, y + Math.sin(a - 1.7) * b.r * 0.7);
    ctx.closePath();
    ctx.fill();
    return;
  }
  if (b.kind === 'arrow') {
    const sp = Math.hypot(b.vx, b.vy) || 1;
    ctx.strokeStyle = '#ffe9b0';
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x - (b.vx / sp) * 16, y - (b.vy / sp) * 16);
    ctx.stroke();
    ctx.fillStyle = '#ff6a6a';
    circle(ctx, x, y, 3);
    ctx.fill();
    return;
  }
  ctx.fillStyle = eprojColor(b.kind);
  circle(ctx, x, y, b.r);
  ctx.fill();
  ctx.fillStyle = '#ffffff';
  circle(ctx, x, y, b.r * 0.45);
  ctx.fill();
}

export function drawHazard(ctx: Ctx, h: Hazard, t: number): void {
  switch (h.kind) {
    case 'skyfall': {
      if (h.warn <= 0) break;
      const p = 1 - h.warn / (h.maxWarn || 1);
      ctx.fillStyle = 'rgba(255,110,30,0.14)';
      circle(ctx, h.x, h.y, h.r);
      ctx.fill();
      ctx.strokeStyle = `rgba(255,140,40,${0.6 + Math.sin(t * 24) * 0.3})`;
      ctx.lineWidth = 3;
      ctx.stroke();
      ctx.fillStyle = 'rgba(255,110,30,0.28)';
      circle(ctx, h.x, h.y, h.r * p);
      ctx.fill();
      // the falling rock
      const my = h.y - (1 - p) * 650, mx = h.x + (1 - p) * 220;
      ctx.strokeStyle = 'rgba(255,170,80,0.55)';
      ctx.lineWidth = 14;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(mx, my);
      ctx.lineTo(mx + 55, my - 150);
      ctx.stroke();
      ctx.fillStyle = '#5a4030';
      circle(ctx, mx, my, 15);
      ctx.fill();
      ctx.strokeStyle = '#ffb347';
      ctx.lineWidth = 3;
      ctx.stroke();
      break;
    }
    case 'slam': {
      if (h.warn > 0) {
        const p = 1 - h.warn / (h.maxWarn || 1);
        ctx.fillStyle = 'rgba(255,40,40,0.12)';
        circle(ctx, h.x, h.y, h.r);
        ctx.fill();
        ctx.strokeStyle = `rgba(255,60,60,${0.5 + Math.sin(t * 20) * 0.3})`;
        ctx.lineWidth = 3;
        ctx.stroke();
        ctx.fillStyle = 'rgba(255,40,40,0.25)';
        circle(ctx, h.x, h.y, h.r * p);
        ctx.fill();
      }
      break;
    }
    case 'coin': {
      // a fake coin looks exactly like a real one until a player steps close
      const yy = h.y + Math.sin(t * 4 + h.id) * 2;
      if (h.speed === 0) {
        drawCoin(ctx, h.x, yy, 7, t + h.id);
        break;
      }
      const p = 1 - h.warn / (h.maxWarn || 1);
      ctx.fillStyle = 'rgba(255,60,40,0.14)';
      circle(ctx, h.x, h.y, h.r);
      ctx.fill();
      ctx.strokeStyle = `rgba(255,80,60,${0.5 + Math.sin(t * 30) * 0.4})`;
      ctx.lineWidth = 3;
      ctx.stroke();
      ctx.fillStyle = 'rgba(255,60,40,0.28)';
      circle(ctx, h.x, h.y, h.r * p);
      ctx.fill();
      drawCoin(ctx, h.x, yy, 7 + p * 4, t * 3, Math.sin(t * 40) > 0 ? '#ff4d4d' : '#ffc83d');
      break;
    }
    case 'ring': {
      if (h.warn > 0) return;
      ctx.strokeStyle = 'rgba(255,90,60,0.85)';
      ctx.lineWidth = h.w * 2;
      circle(ctx, h.x, h.y, h.r);
      ctx.stroke();
      ctx.strokeStyle = 'rgba(255,220,180,0.9)';
      ctx.lineWidth = 3;
      ctx.stroke();
      break;
    }
    case 'laser': {
      const x2 = h.x + Math.cos(h.ang) * h.len, y2 = h.y + Math.sin(h.ang) * h.len;
      ctx.lineCap = 'round';
      if (h.warn > 0) {
        ctx.strokeStyle = `rgba(255,46,136,${0.25 + Math.sin(t * 25) * 0.15})`;
        ctx.lineWidth = h.w;
        ctx.setLineDash([16, 12]);
        ctx.beginPath();
        ctx.moveTo(h.x, h.y);
        ctx.lineTo(x2, y2);
        ctx.stroke();
        ctx.setLineDash([]);
      } else {
        for (const [w, c] of [[h.w * 2.2, 'rgba(255,46,136,0.25)'], [h.w, 'rgba(255,90,170,0.85)'], [h.w * 0.35, '#ffffff']] as const) {
          ctx.strokeStyle = c;
          ctx.lineWidth = w;
          ctx.beginPath();
          ctx.moveTo(h.x, h.y);
          ctx.lineTo(x2, y2);
          ctx.stroke();
        }
      }
      break;
    }
  }
}
