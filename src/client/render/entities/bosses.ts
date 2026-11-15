// Boss artwork, one case per boss type.

import { wyrmSegmentRadius } from '../../../sim/systems/bosses';
import type { Enemy } from '../../../sim/types';
import { Ctx, TAU, circle, eyes } from './shared';

export function drawBoss(ctx: Ctx, e: Enemy, x: number, y: number, t: number, dx: number, dy: number, col: string): void {
  const r = e.radius;
  const enraged = e.hp < e.maxHp * 0.5;
  ctx.save();
  switch (e.type) {
    case 'slimeking': {
      let lift = 0, sq = Math.sin(t * 5) * 0.06;
      if (e.state === 1) sq = 0.25 * (1 - e.t2 / 0.55);
      if (e.state === 2) {
        const prog = 1 - e.t2 / 0.9;
        lift = Math.sin(prog * Math.PI) * 140;
        sq = -0.15;
      }
      ctx.fillStyle = 'rgba(0,0,0,0.35)';
      ctx.beginPath();
      ctx.ellipse(x, y + r * 0.6, r * (1 - lift / 400), r * 0.35 * (1 - lift / 400), 0, 0, TAU);
      ctx.fill();
      const by = y - lift;
      ctx.fillStyle = enraged && e.flash <= 0 ? '#1f6fe0' : col;
      ctx.beginPath();
      ctx.ellipse(x, by, r * (1.15 + sq), r * (0.95 - sq), 0, Math.PI, TAU);
      ctx.lineTo(x + r * (1.15 + sq), by + r * 0.55);
      ctx.quadraticCurveTo(x, by + r * 0.8, x - r * (1.15 + sq), by + r * 0.55);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,0.35)';
      circle(ctx, x - r * 0.45, by - r * 0.4, r * 0.18);
      ctx.fill();
      eyes(ctx, x, by - r * 0.1, r * 1.1, dx, dy, '#08203f', r * 0.12);
      // crown
      ctx.fillStyle = '#ffd166';
      const cy = by - r * (0.95 - sq);
      ctx.beginPath();
      ctx.moveTo(x - r * 0.5, cy);
      ctx.lineTo(x - r * 0.55, cy - r * 0.5);
      ctx.lineTo(x - r * 0.25, cy - r * 0.25);
      ctx.lineTo(x, cy - r * 0.6);
      ctx.lineTo(x + r * 0.25, cy - r * 0.25);
      ctx.lineTo(x + r * 0.55, cy - r * 0.5);
      ctx.lineTo(x + r * 0.5, cy);
      ctx.closePath();
      ctx.fill();
      break;
    }
    case 'necrolord': {
      const fy = y + Math.sin(t * 2) * 4;
      ctx.fillStyle = e.flash > 0.06 ? '#fff' : '#2a1840';
      ctx.beginPath();
      ctx.moveTo(x, fy - r * 1.3);
      ctx.lineTo(x + r, fy + r);
      for (let i = 0; i <= 5; i++) ctx.lineTo(x + r - (i * 2 * r) / 5, fy + r + (i % 2 ? 8 : 0));
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = col;
      ctx.lineWidth = 2;
      ctx.stroke();
      ctx.fillStyle = '#e8e0c8';
      circle(ctx, x, fy - r * 0.45, r * 0.42);
      ctx.fill();
      ctx.fillStyle = enraged ? '#ff3060' : '#c084ff';
      circle(ctx, x - r * 0.16 + dx * 2, fy - r * 0.5, r * 0.1);
      ctx.fill();
      circle(ctx, x + r * 0.16 + dx * 2, fy - r * 0.5, r * 0.1);
      ctx.fill();
      // orbiting skulls
      for (let i = 0; i < 3; i++) {
        const a = t * 1.5 + (i * TAU) / 3;
        ctx.fillStyle = '#d8d2bd';
        circle(ctx, x + Math.cos(a) * r * 1.6, fy + Math.sin(a) * r * 1.0, 6);
        ctx.fill();
      }
      break;
    }
    case 'golem': {
      let sx = 0;
      if (e.state === 1 || e.state === 3) sx = (Math.random() - 0.5) * 5;
      if (e.state === 1) {
        ctx.strokeStyle = 'rgba(255,60,40,0.3)';
        ctx.lineWidth = r * 1.8;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x + e.tx * 520, y + e.ty * 520);
        ctx.stroke();
      }
      ctx.fillStyle = 'rgba(0,0,0,0.35)';
      ctx.beginPath();
      ctx.ellipse(x, y + r * 0.85, r, r * 0.35, 0, 0, TAU);
      ctx.fill();
      ctx.fillStyle = col;
      ctx.beginPath();
      const pts = [[-1, -0.6], [-0.6, -1.05], [0.3, -1.1], [1, -0.55], [1.1, 0.4], [0.6, 1], [-0.5, 1], [-1.1, 0.35]];
      for (const [px, py] of pts) ctx.lineTo(x + sx + px * r, y + py * r);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = enraged ? '#ff5a1f' : '#ff9f43';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(x + sx - r * 0.5, y - r * 0.6);
      ctx.lineTo(x + sx - r * 0.1, y - r * 0.1);
      ctx.lineTo(x + sx - r * 0.3, y + r * 0.5);
      ctx.moveTo(x + sx + r * 0.6, y - r * 0.3);
      ctx.lineTo(x + sx + r * 0.2, y + r * 0.2);
      ctx.stroke();
      ctx.fillStyle = enraged ? '#ff5a1f' : '#ffd166';
      circle(ctx, x + sx - r * 0.3 + dx * 4, y - r * 0.45, r * 0.11);
      ctx.fill();
      circle(ctx, x + sx + r * 0.3 + dx * 4, y - r * 0.45, r * 0.11);
      ctx.fill();
      // arms
      ctx.fillStyle = '#7d6b57';
      circle(ctx, x + sx - r * 1.25, y + r * 0.2 + Math.sin(t * 3) * 3, r * 0.35);
      ctx.fill();
      circle(ctx, x + sx + r * 1.25, y + r * 0.2 - Math.sin(t * 3) * 3, r * 0.35);
      ctx.fill();
      break;
    }
    case 'broodmother': {
      const moving = e.state === 0 || e.state === 2;
      const ang = e.state === 2 || e.state === 3 ? Math.atan2(e.ty, e.tx) : Math.atan2(dy, dx);
      const fx = Math.cos(ang), fy = Math.sin(ang);
      if (e.state === 3) {
        ctx.strokeStyle = 'rgba(255,60,90,0.3)';
        ctx.lineWidth = r * 1.4;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x + fx * 300, y + fy * 300);
        ctx.stroke();
      }
      ctx.fillStyle = 'rgba(0,0,0,0.35)';
      ctx.beginPath();
      ctx.ellipse(x, y + r * 0.6, r * 1.2, r * 0.45, 0, 0, TAU);
      ctx.fill();
      // legs
      ctx.strokeStyle = '#2a0f1e';
      ctx.lineWidth = 5;
      ctx.lineCap = 'round';
      for (let side = -1; side <= 1; side += 2) {
        for (let i = 0; i < 4; i++) {
          const la = ang + side * (0.55 + i * 0.5) + (moving ? Math.sin(t * 14 + i * 1.7 + side) * 0.18 : 0);
          const kx = x + Math.cos(la) * r * 1.15, ky = y + Math.sin(la) * r * 1.15 - r * 0.35;
          const ex = x + Math.cos(la) * r * 1.75, ey = y + Math.sin(la) * r * 1.75 + r * 0.25;
          ctx.beginPath();
          ctx.moveTo(x + Math.cos(la) * r * 0.4, y + Math.sin(la) * r * 0.4);
          ctx.lineTo(kx, ky);
          ctx.lineTo(ex, ey);
          ctx.stroke();
        }
      }
      // abdomen with hourglass
      const ax = x - fx * r * 0.75, ay = y - fy * r * 0.75;
      ctx.fillStyle = e.flash > 0.06 ? '#fff' : '#4a1830';
      ctx.beginPath();
      ctx.ellipse(ax, ay, r * 0.95, r * 0.8, ang, 0, TAU);
      ctx.fill();
      ctx.fillStyle = enraged ? '#ff3060' : '#d8344f';
      ctx.beginPath();
      ctx.moveTo(ax - fy * r * 0.25 - fx * r * 0.2, ay + fx * r * 0.25 - fy * r * 0.2);
      ctx.lineTo(ax + fy * r * 0.25 - fx * r * 0.2, ay - fx * r * 0.25 - fy * r * 0.2);
      ctx.lineTo(ax - fy * r * 0.25 + fx * r * 0.2, ay + fx * r * 0.25 + fy * r * 0.2);
      ctx.lineTo(ax + fy * r * 0.25 + fx * r * 0.2, ay - fx * r * 0.25 + fy * r * 0.2);
      ctx.closePath();
      ctx.fill();
      // head
      const hx = x + fx * r * 0.2, hy = y + fy * r * 0.2;
      ctx.fillStyle = col;
      circle(ctx, hx, hy, r * 0.6);
      ctx.fill();
      ctx.fillStyle = enraged ? '#ff2040' : '#ff6a8a';
      for (let i = 0; i < 6; i++) {
        const ea = ang + (i - 2.5) * 0.28;
        circle(ctx, hx + Math.cos(ea) * r * 0.38, hy + Math.sin(ea) * r * 0.38 - (i % 2) * 3, i % 2 ? 3 : 4.5);
        ctx.fill();
      }
      ctx.strokeStyle = '#1a0810';
      ctx.lineWidth = 4;
      for (const sd of [-1, 1]) {
        ctx.beginPath();
        ctx.moveTo(hx + fx * r * 0.5 - fy * sd * r * 0.15, hy + fy * r * 0.5 + fx * sd * r * 0.15);
        ctx.lineTo(hx + fx * r * 0.8 - fy * sd * r * 0.05, hy + fy * r * 0.8 + fx * sd * r * 0.05);
        ctx.stroke();
      }
      break;
    }
    case 'wyrm': {
      // body from the tail toward the head
      const n = e.trail.length / 2;
      for (let i = n - 1; i >= 1; i--) {
        const sx = e.trail[i * 2], sy = e.trail[i * 2 + 1];
        const sr = wyrmSegmentRadius(r, i);
        ctx.fillStyle = 'rgba(0,0,0,0.25)';
        ctx.beginPath();
        ctx.ellipse(sx, sy + sr * 0.7, sr, sr * 0.35, 0, 0, TAU);
        ctx.fill();
        ctx.fillStyle = i % 2 ? '#5fb8e8' : col;
        circle(ctx, sx, sy, sr);
        ctx.fill();
        ctx.strokeStyle = '#1d4a6a';
        ctx.lineWidth = 2;
        ctx.stroke();
        ctx.fillStyle = '#e8f8ff';
        circle(ctx, sx, sy - sr * 0.35, sr * 0.28);
        ctx.fill();
      }
      const ha = e.ang, hfx = Math.cos(ha), hfy = Math.sin(ha);
      if (e.state === 1) {
        ctx.strokeStyle = 'rgba(140,220,255,0.35)';
        ctx.lineWidth = r * 1.6;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x + hfx * 480, y + hfy * 480);
        ctx.stroke();
      }
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(ha);
      ctx.fillStyle = e.flash > 0.06 ? '#ffffff' : col;
      ctx.beginPath();
      ctx.ellipse(r * 0.15, 0, r * 1.15, r * 0.8, 0, 0, TAU);
      ctx.fill();
      ctx.strokeStyle = '#1d4a6a';
      ctx.lineWidth = 3;
      ctx.stroke();
      ctx.fillStyle = '#e8f8ff';
      for (const sd of [-1, 1]) {
        ctx.beginPath();
        ctx.moveTo(-r * 0.4, sd * r * 0.5);
        ctx.lineTo(-r * 1.25, sd * r * 1.05);
        ctx.lineTo(-r * 0.15, sd * r * 0.3);
        ctx.closePath();
        ctx.fill();
      }
      ctx.fillStyle = enraged ? '#ff4d8a' : '#1a3cff';
      for (const sd of [-1, 1]) {
        circle(ctx, r * 0.6, sd * r * 0.35, r * 0.14);
        ctx.fill();
      }
      ctx.fillStyle = 'rgba(200,240,255,0.7)';
      circle(ctx, r * 1.15, sd0(t) * r * 0.1, r * 0.12);
      ctx.fill();
      ctx.restore();
      break;
    }
    case 'voideye': {
      ctx.strokeStyle = '#5a1040';
      ctx.lineWidth = 4;
      for (let i = 0; i < 8; i++) {
        const a = (i * TAU) / 8 + Math.sin(t * 2 + i) * 0.2;
        ctx.beginPath();
        ctx.moveTo(x + Math.cos(a) * r, y + Math.sin(a) * r);
        ctx.quadraticCurveTo(
          x + Math.cos(a + 0.3) * r * 1.6, y + Math.sin(a + 0.3) * r * 1.6,
          x + Math.cos(a) * r * 2 + Math.sin(t * 3 + i) * 6, y + Math.sin(a) * r * 2,
        );
        ctx.stroke();
      }
      ctx.fillStyle = e.flash > 0.06 ? '#ffd0e4' : '#f4ecf0';
      circle(ctx, x, y, r);
      ctx.fill();
      ctx.strokeStyle = col;
      ctx.lineWidth = 3;
      ctx.stroke();
      const ix = x + dx * r * 0.35, iy = y + dy * r * 0.35;
      ctx.fillStyle = enraged ? '#ff1060' : col;
      circle(ctx, ix, iy, r * 0.5);
      ctx.fill();
      ctx.fillStyle = '#12020a';
      ctx.beginPath();
      ctx.ellipse(ix, iy, r * 0.12, r * 0.38, 0, 0, TAU);
      ctx.fill();
      break;
    }
    case 'goldfang': {
      // a hooded goblin merchant sprinting with a sack bigger than himself;
      // drawn facing +x and mirrored to his running direction
      const F = e.flash > 0.06;
      const run = t * (enraged ? 16 : 12);
      const step = Math.sin(run);
      const bob = Math.abs(step) * 4;
      const dir = Math.cos(e.ang) >= 0 ? 1 : -1;
      ctx.fillStyle = 'rgba(0,0,0,0.28)';
      ctx.beginPath();
      ctx.ellipse(x, y + r * 0.95, r * 0.9, r * 0.22, 0, 0, TAU);
      ctx.fill();
      ctx.translate(x, y - bob);
      ctx.scale(dir, 1);
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';

      // boots, alternating
      ctx.fillStyle = F ? '#fff' : '#2a1a10';
      for (const k of [-1, 1]) {
        const lift = Math.max(0, step * k) * 5;
        ctx.beginPath();
        ctx.ellipse(k * step * r * 0.22 + r * 0.05, r * 0.86 + bob - lift, r * 0.19, r * 0.1, 0, 0, TAU);
        ctx.fill();
      }

      // the sack, swinging behind him
      ctx.save();
      ctx.translate(-r * 0.72, -r * 0.28);
      ctx.rotate(-0.3 + Math.sin(run * 0.5) * 0.08);
      const sack = () => {
        ctx.beginPath();
        ctx.moveTo(-r * 0.28, -r * 0.72);
        ctx.bezierCurveTo(-r * 1.15, -r * 0.4, -r * 1.05, r * 0.78, 0, r * 0.78);
        ctx.bezierCurveTo(r * 1.05, r * 0.78, r * 1.15, -r * 0.4, r * 0.28, -r * 0.72);
        ctx.closePath();
      };
      sack();
      ctx.fillStyle = F ? '#fff' : '#94632f';
      ctx.fill();
      ctx.save();
      ctx.clip();
      ctx.fillStyle = 'rgba(40,20,0,0.25)';
      ctx.beginPath();
      ctx.ellipse(-r * 0.45, r * 0.45, r * 0.8, r * 0.55, 0.5, 0, TAU);
      ctx.fill();
      ctx.restore();
      sack(); // the shading replaced the current path
      ctx.strokeStyle = '#4e3015';
      ctx.lineWidth = 2;
      ctx.stroke();
      // patch with stitches
      ctx.fillStyle = F ? '#eee' : '#b07d42';
      ctx.fillRect(r * 0.22, r * 0.12, r * 0.34, r * 0.28);
      ctx.strokeStyle = '#4e3015';
      ctx.lineWidth = 1;
      ctx.setLineDash([2, 2]);
      ctx.strokeRect(r * 0.22, r * 0.12, r * 0.34, r * 0.28);
      ctx.setLineDash([]);
      // embroidered sign (un-mirrored so it always reads right)
      ctx.save();
      ctx.scale(dir, 1);
      ctx.fillStyle = F ? '#ddd' : '#ffc83d';
      ctx.font = `bold ${Math.round(r * 0.7)}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('$', -r * 0.2 * dir, r * 0.2);
      ctx.restore();
      // coins spilling out of the opening
      for (let i = 0; i < 5; i++) {
        const cx = -r * 0.32 + i * r * 0.16, cy = -r * 0.78 - (i % 2) * r * 0.13 - (i === 2 ? r * 0.08 : 0);
        ctx.fillStyle = '#b8860b';
        ctx.beginPath();
        ctx.ellipse(cx, cy, r * 0.16, r * 0.12, 0, 0, TAU);
        ctx.fill();
        ctx.fillStyle = F ? '#fff' : '#ffd25a';
        ctx.beginPath();
        ctx.ellipse(cx, cy - 1, r * 0.12, r * 0.08, 0, 0, TAU);
        ctx.fill();
      }
      // cinch rope
      ctx.strokeStyle = '#e2c48a';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(-r * 0.33, -r * 0.6);
      ctx.quadraticCurveTo(0, -r * 0.5, r * 0.33, -r * 0.6);
      ctx.stroke();
      // twinkle
      const tw = Math.max(0, Math.sin(t * 3 + e.id));
      if (tw > 0.2) {
        ctx.fillStyle = `rgba(255,255,255,${tw})`;
        const s = r * 0.2 * tw, sx = r * 0.1, sy = -r * 0.98;
        ctx.beginPath();
        ctx.moveTo(sx, sy - s);
        ctx.lineTo(sx + s * 0.25, sy - s * 0.25);
        ctx.lineTo(sx + s, sy);
        ctx.lineTo(sx + s * 0.25, sy + s * 0.25);
        ctx.lineTo(sx, sy + s);
        ctx.lineTo(sx - s * 0.25, sy + s * 0.25);
        ctx.lineTo(sx - s, sy);
        ctx.lineTo(sx - s * 0.25, sy - s * 0.25);
        ctx.closePath();
        ctx.fill();
      }
      ctx.restore();

      const skin = F ? '#fff' : '#7cbf4a', skinDark = F ? '#eee' : '#5f9a38';
      const robe = F ? '#fff' : '#4b2a6b', robeDark = F ? '#eee' : '#3a1f55';
      // back arm hauling the sack
      ctx.strokeStyle = robeDark;
      ctx.lineWidth = r * 0.2;
      ctx.beginPath();
      ctx.moveTo(-r * 0.15, -r * 0.1);
      ctx.lineTo(-r * 0.62, -r * 0.78);
      ctx.stroke();
      ctx.fillStyle = skinDark;
      circle(ctx, -r * 0.64, -r * 0.82, r * 0.12);
      ctx.fill();

      // robe
      ctx.beginPath();
      ctx.moveTo(-r * 0.42, -r * 0.22);
      ctx.quadraticCurveTo(0, -r * 0.34, r * 0.42, -r * 0.22);
      ctx.lineTo(r * 0.68, r * 0.76);
      ctx.quadraticCurveTo(0, r * 0.9, -r * 0.68, r * 0.76);
      ctx.closePath();
      ctx.fillStyle = robe;
      ctx.fill();
      ctx.save();
      ctx.clip();
      ctx.fillStyle = 'rgba(0,0,0,0.22)';
      ctx.fillRect(-r, -r, r * 0.85, r * 2);
      ctx.restore();
      ctx.strokeStyle = '#ffc83d';
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.moveTo(r * 0.68, r * 0.76);
      ctx.quadraticCurveTo(0, r * 0.9, -r * 0.68, r * 0.76);
      ctx.stroke();
      // belt, buckle and a fat coin purse
      ctx.fillStyle = '#2a1a10';
      ctx.fillRect(-r * 0.56, r * 0.26, r * 1.12, r * 0.13);
      ctx.fillStyle = '#ffc83d';
      ctx.fillRect(-r * 0.08, r * 0.23, r * 0.16, r * 0.19);
      ctx.fillStyle = F ? '#fff' : '#c08a3e';
      circle(ctx, r * 0.4, r * 0.5, r * 0.14);
      ctx.fill();
      // front arm, clutching a coin
      ctx.strokeStyle = robe;
      ctx.lineWidth = r * 0.2;
      ctx.beginPath();
      ctx.moveTo(r * 0.18, -r * 0.08);
      ctx.lineTo(r * 0.5 - step * r * 0.08, r * 0.18);
      ctx.stroke();
      ctx.fillStyle = skin;
      circle(ctx, r * 0.55 - step * r * 0.08, r * 0.22, r * 0.12);
      ctx.fill();
      ctx.fillStyle = '#ffc83d';
      circle(ctx, r * 0.66 - step * r * 0.08, r * 0.17, r * 0.08);
      ctx.fill();

      // head
      const hx = r * 0.08, hy = -r * 0.52;
      ctx.fillStyle = F ? '#fff' : '#3d2259';
      const flap = Math.sin(run) * r * 0.06;
      ctx.beginPath();
      ctx.moveTo(hx - r * 0.3, hy - r * 0.4);
      ctx.quadraticCurveTo(hx - r * 0.85, hy - r * 0.62 + flap, hx - r * 1.0, hy - r * 0.15 + flap);
      ctx.lineTo(hx - r * 0.4, hy + r * 0.05);
      ctx.closePath();
      ctx.fill();
      // ears
      for (const [ex, len, col] of [[-1, 0.62, skinDark], [1, 0.5, skin]] as const) {
        ctx.fillStyle = col;
        ctx.beginPath();
        ctx.moveTo(hx + ex * r * 0.25, hy - r * 0.12);
        ctx.lineTo(hx + ex * r * (0.3 + len), hy - r * 0.42 - flap);
        ctx.lineTo(hx + ex * r * 0.28, hy + r * 0.08);
        ctx.closePath();
        ctx.fill();
      }
      ctx.fillStyle = skin;
      circle(ctx, hx, hy, r * 0.36);
      ctx.fill();
      ctx.fillStyle = 'rgba(0,0,0,0.12)';
      circle(ctx, hx - r * 0.12, hy + r * 0.04, r * 0.3);
      ctx.fill();
      // hood framing the face
      ctx.fillStyle = robeDark;
      ctx.beginPath();
      ctx.moveTo(hx - r * 0.42, hy + r * 0.12);
      ctx.quadraticCurveTo(hx - r * 0.5, hy - r * 0.52, hx + r * 0.05, hy - r * 0.48);
      ctx.quadraticCurveTo(hx + r * 0.42, hy - r * 0.44, hx + r * 0.4, hy - r * 0.12);
      ctx.quadraticCurveTo(hx + r * 0.05, hy - r * 0.3, hx - r * 0.2, hy - r * 0.02);
      ctx.closePath();
      ctx.fill();
      // greedy brows and eyes looking ahead
      ctx.strokeStyle = '#1a1206';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(hx - r * 0.12, hy - r * 0.2);
      ctx.lineTo(hx + r * 0.04, hy - r * 0.13);
      ctx.moveTo(hx + r * 0.36, hy - r * 0.22);
      ctx.lineTo(hx + r * 0.2, hy - r * 0.14);
      ctx.stroke();
      ctx.fillStyle = '#fff8d0';
      circle(ctx, hx - r * 0.02, hy - r * 0.05, r * 0.08);
      ctx.fill();
      circle(ctx, hx + r * 0.26, hy - r * 0.06, r * 0.08);
      ctx.fill();
      ctx.fillStyle = '#1a1206';
      circle(ctx, hx + r * 0.01, hy - r * 0.05, r * 0.045);
      ctx.fill();
      circle(ctx, hx + r * 0.29, hy - r * 0.06, r * 0.045);
      ctx.fill();
      // hooked nose
      ctx.fillStyle = F ? '#eee' : '#8fd257';
      ctx.beginPath();
      ctx.moveTo(hx + r * 0.14, hy - r * 0.02);
      ctx.quadraticCurveTo(hx + r * 0.55, hy + r * 0.02, hx + r * 0.5, hy + r * 0.2);
      ctx.quadraticCurveTo(hx + r * 0.32, hy + r * 0.12, hx + r * 0.16, hy + r * 0.12);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = skinDark;
      ctx.lineWidth = 1.2;
      ctx.stroke();
      // monocle with its chain
      ctx.strokeStyle = '#ffc83d';
      ctx.lineWidth = 1.8;
      circle(ctx, hx + r * 0.26, hy - r * 0.06, r * 0.13);
      ctx.stroke();
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.moveTo(hx + r * 0.36, hy + r * 0.03);
      ctx.quadraticCurveTo(hx + r * 0.42, hy + r * 0.4, hx + r * 0.15, hy + r * 0.32);
      ctx.stroke();
      // wide grin with a gold tooth
      ctx.fillStyle = '#2a0f08';
      ctx.beginPath();
      ctx.moveTo(hx - r * 0.12, hy + r * 0.15);
      ctx.quadraticCurveTo(hx + r * 0.1, hy + r * 0.34, hx + r * 0.3, hy + r * 0.18);
      ctx.quadraticCurveTo(hx + r * 0.1, hy + r * 0.24, hx - r * 0.12, hy + r * 0.15);
      ctx.fill();
      ctx.fillStyle = '#ffc83d';
      ctx.fillRect(hx + r * 0.08, hy + r * 0.2, r * 0.07, r * 0.06);
      if (enraged) {
        // panicking: sweat flying off
        ctx.fillStyle = '#9ad8ff';
        for (const [sx, sy, sr, ph] of [[-0.42, -0.95, 3.2, 0], [0.5, -0.85, 2.6, 1.7]] as const) {
          ctx.beginPath();
          ctx.ellipse(hx + r * sx - Math.abs(Math.sin(run + ph)) * 4, hy + r * sy + r * 0.4, sr * 0.8, sr * 1.2, 0, 0, TAU);
          ctx.fill();
        }
      }
      break;
    }
  }
  ctx.restore();
}

/** Small breathing offset for the wyrm's frosty breath. */
export const sd0 = (t: number) => Math.sin(t * 6);
