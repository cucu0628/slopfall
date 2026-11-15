// XP gems, heals, magnets, bombs, chests and Goldfang's coins and treasure.

import type { Pickup } from '../../../sim/types';
import { Ctx, TAU, circle } from './shared';

// ---------------------------------------------------------------- pickups
export function gemColor(v: number): string {
  if (v >= 50) return '#ff5df2';
  if (v >= 10) return '#ff6b5d';
  if (v >= 3) return '#5dff8f';
  return '#5dc8ff';
}

export function pickupColor(p: Pickup): string {
  switch (p.kind) {
    case 'xp': return gemColor(p.value);
    case 'heal': return '#ff4d6d';
    case 'magnet': return '#5d9bff';
    case 'bomb': return '#ffb347';
    case 'chest': return '#ffd166';
    case 'coin':
    case 'relic': return '#ffc83d';
  }
}

export function drawPickup(ctx: Ctx, p: Pickup, x: number, y: number, t: number): void {
  const bob = Math.sin(t * 4 + p.id) * 2;
  const yy = y + bob;
  switch (p.kind) {
    case 'xp': {
      const s = p.value >= 50 ? 9 : p.value >= 10 ? 7 : p.value >= 3 ? 5.5 : 4.5;
      ctx.fillStyle = gemColor(p.value);
      ctx.beginPath();
      ctx.moveTo(x, yy - s * 1.3);
      ctx.lineTo(x + s, yy);
      ctx.lineTo(x, yy + s * 1.3);
      ctx.lineTo(x - s, yy);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,0.6)';
      ctx.beginPath();
      ctx.moveTo(x, yy - s * 1.3);
      ctx.lineTo(x + s * 0.4, yy - s * 0.2);
      ctx.lineTo(x - s * 0.3, yy);
      ctx.closePath();
      ctx.fill();
      break;
    }
    case 'heal': {
      ctx.fillStyle = '#ff4d6d';
      ctx.fillRect(x - 3.5, yy - 10, 7, 20);
      ctx.fillRect(x - 10, yy - 3.5, 20, 7);
      break;
    }
    case 'magnet': {
      ctx.strokeStyle = '#ff4d4d';
      ctx.lineWidth = 6;
      ctx.beginPath();
      ctx.arc(x, yy, 8, 0, Math.PI);
      ctx.stroke();
      ctx.strokeStyle = '#e0e6f0';
      ctx.beginPath();
      ctx.moveTo(x - 8, yy);
      ctx.lineTo(x - 8, yy - 7);
      ctx.moveTo(x + 8, yy);
      ctx.lineTo(x + 8, yy - 7);
      ctx.stroke();
      break;
    }
    case 'bomb': {
      ctx.fillStyle = '#222632';
      circle(ctx, x, yy, 10);
      ctx.fill();
      ctx.strokeStyle = '#ffb347';
      ctx.lineWidth = 2;
      ctx.stroke();
      ctx.fillStyle = '#ffd166';
      circle(ctx, x + 6, yy - 11, 2 + Math.random() * 2);
      ctx.fill();
      break;
    }
    case 'chest': {
      const s = p.big ? 1.4 : 1;
      ctx.fillStyle = '#8a5a2b';
      ctx.fillRect(x - 14 * s, yy - 8 * s, 28 * s, 18 * s);
      ctx.fillStyle = '#ffd166';
      ctx.fillRect(x - 14 * s, yy - 12 * s, 28 * s, 7 * s);
      ctx.fillRect(x - 3 * s, yy - 6 * s, 6 * s, 8 * s);
      ctx.strokeStyle = '#ffeaa0';
      ctx.lineWidth = 1.5;
      ctx.strokeRect(x - 14 * s, yy - 12 * s, 28 * s, 22 * s);
      break;
    }
    case 'coin':
      drawCoin(ctx, x, yy, 7, t + p.id);
      break;
    case 'relic': {
      // Goldfang's treasure sack, spilling light
      const pulse = 0.6 + Math.sin(t * 5) * 0.4;
      ctx.strokeStyle = `rgba(255,200,61,${0.35 + pulse * 0.3})`;
      ctx.lineWidth = 3;
      for (let i = 0; i < 8; i++) {
        const a = t * 0.8 + (i * TAU) / 8;
        ctx.beginPath();
        ctx.moveTo(x + Math.cos(a) * 22, yy + Math.sin(a) * 22);
        ctx.lineTo(x + Math.cos(a) * (30 + pulse * 6), yy + Math.sin(a) * (30 + pulse * 6));
        ctx.stroke();
      }
      ctx.fillStyle = '#8a5a2b';
      ctx.beginPath();
      ctx.moveTo(x - 6, yy - 12);
      ctx.quadraticCurveTo(x - 20, yy + 2, x - 14, yy + 14);
      ctx.lineTo(x + 14, yy + 14);
      ctx.quadraticCurveTo(x + 20, yy + 2, x + 6, yy - 12);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = '#ffc83d';
      ctx.fillRect(x - 7, yy - 14, 14, 4);
      ctx.font = 'bold 14px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('$', x, yy + 9);
      break;
    }
  }
}

/** A spinning gold coin; also used for Goldfang's fake coins and the coin weapon. */
export function drawCoin(ctx: Ctx, x: number, y: number, r: number, t: number, tint = '#ffc83d'): void {
  const sx = Math.max(0.2, Math.abs(Math.cos(t * 4)));
  ctx.fillStyle = '#b8860b';
  ctx.beginPath();
  ctx.ellipse(x, y, r * sx, r, 0, 0, TAU);
  ctx.fill();
  ctx.fillStyle = tint;
  ctx.beginPath();
  ctx.ellipse(x, y, r * sx * 0.78, r * 0.78, 0, 0, TAU);
  ctx.fill();
  ctx.fillStyle = 'rgba(255,255,255,0.55)';
  ctx.beginPath();
  ctx.ellipse(x - r * sx * 0.25, y - r * 0.3, r * sx * 0.2, r * 0.25, 0, 0, TAU);
  ctx.fill();
}
