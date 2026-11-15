import { ABILITY_MAX_LEVEL, CHARACTERS } from '../../sim/content/characters';
import { ENEMIES } from '../../sim/content/enemies';
import { PERKS } from '../../sim/content/perks';
import { MAX_WEAPON_LEVEL, WEAPONS } from '../../sim/content/weapons';
import { IDLE_GRACE, IDLE_WARNING } from '../../sim/systems/idle';
import type { GameState, Player } from '../../sim/types';
import type { Effects } from './effects';
import type { Renderer } from './renderer';
import { rgba } from './sprites';

type Ctx = CanvasRenderingContext2D;
const FONT = 'system-ui, "Segoe UI", sans-serif';

export function fmtTime(sec: number): string {
  const m = Math.floor(sec / 60), s = Math.floor(sec % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function text(ctx: Ctx, str: string, x: number, y: number, size: number, color: string, align: CanvasTextAlign = 'left', weight = 'bold'): void {
  ctx.font = `${weight} ${size}px ${FONT}`;
  ctx.textAlign = align;
  ctx.lineWidth = Math.max(2, size / 5);
  ctx.strokeStyle = 'rgba(0,0,0,0.75)';
  ctx.strokeText(str, x, y);
  ctx.fillStyle = color;
  ctx.fillText(str, x, y);
}

function bar(ctx: Ctx, x: number, y: number, w: number, h: number, k: number, color: string, bg = 'rgba(0,0,0,0.55)'): void {
  ctx.fillStyle = bg;
  ctx.fillRect(x, y, w, h);
  ctx.fillStyle = color;
  ctx.fillRect(x, y, w * Math.max(0, Math.min(1, k)), h);
  ctx.strokeStyle = 'rgba(255,255,255,0.18)';
  ctx.lineWidth = 1;
  ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
}

export function drawHud(ctx: Ctx, r: Renderer, s: GameState, me: Player, fx: Effects): void {
  const W = r.w, H = r.h;
  ctx.textBaseline = 'alphabetic';

  // damage vignette
  const low = 1 - me.hp / me.stats.maxHp;
  const vig = Math.max(fx.hurtFlash, low > 0.65 ? (low - 0.65) * 1.5 * (0.7 + Math.sin(fx.time * 6) * 0.3) : 0);
  if (vig > 0.01) {
    const g = ctx.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.3, W / 2, H / 2, Math.max(W, H) * 0.7);
    g.addColorStop(0, 'rgba(255,0,0,0)');
    g.addColorStop(1, `rgba(255,0,30,${Math.min(0.55, vig)})`);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
  }

  // XP bar
  bar(ctx, 0, 0, W, 12, me.xp / me.xpNext, '#4fa3ff', 'rgba(10,14,30,0.85)');
  text(ctx, `LV ${me.level}`, W - 10, 30, 16, '#bfe0ff', 'right');

  // HP
  const hpW = Math.min(260, W * 0.3);
  bar(ctx, 16, 22, hpW, 16, me.hp / me.stats.maxHp, '#ff4d6d');
  text(ctx, `${Math.ceil(me.hp)} / ${Math.round(me.stats.maxHp)}`, 16 + hpW / 2, 35, 12, '#fff', 'center');
  text(ctx, `${CHARACTERS[me.charId].name}`, 16, 56, 13, CHARACTERS[me.charId].accent);

  // Wave and time
  const w = s.wave;
  text(ctx, w.bossWave ? `WAVE ${w.n} · BOSS` : `WAVE ${w.n}`, W / 2, 38, 22, w.bossWave ? '#ff5d7a' : '#ffffff', 'center');
  const secret = w.bossWave && s.enemies.some((e) => e.type === 'goldfang');
  const sub = secret ? 'Catch him before he escapes!' : w.bossWave ? 'Defeat the boss!' : `next wave in ${Math.ceil(w.timer)}s`;
  text(ctx, sub, W / 2, 56, 12, secret ? '#ffc83d' : '#aab4d4', 'center', 'normal');
  text(ctx, fmtTime(s.time), W - 10, 52, 15, '#ffffff', 'right');
  text(ctx, `☠ ${s.kills}`, W - 10, 72, 14, '#ffb3b3', 'right');
  const mm = Math.round(Math.min(160, W * 0.18));
  r.minimap.draw(ctx, s, me, W - mm - 12, 84, mm, fx.time);

  // Boss bars
  const bosses = s.enemies.filter((e) => e.boss);
  bosses.forEach((b, i) => {
    const bw = Math.min(520, W * 0.6), bx = (W - bw) / 2, by = 80 + i * 34;
    if (b.type === 'goldfang') {
      // the secret boss runs on a clock: b.t is his escape timer
      text(ctx, `${ENEMIES[b.type].name.toUpperCase()} · ESCAPES IN ${Math.ceil(Math.max(0, b.t))}s`, W / 2, by - 2, 13, '#ffe08a', 'center');
      bar(ctx, bx, by + 3, bw, 12, b.hp / b.maxHp, '#ffc83d');
      return;
    }
    text(ctx, ENEMIES[b.type].name.toUpperCase(), W / 2, by - 2, 13, '#ffd0dc', 'center');
    bar(ctx, bx, by + 3, bw, 12, b.hp / b.maxHp, b.hp < b.maxHp * 0.5 ? '#ff2e5a' : '#d63a7a');
  });

  // anti-AFK warning
  if (!me.dead && me.idleT > IDLE_GRACE - IDLE_WARNING) {
    const blink = 0.55 + Math.sin(fx.time * 10) * 0.45;
    ctx.globalAlpha = blink;
    text(ctx, me.idleT >= IDLE_GRACE ? 'METEORS INCOMING — MOVE!' : 'MOVE! Standing still draws meteors', W / 2, H * 0.22, 20, '#ff9a3d', 'center');
    ctx.globalAlpha = 1;
  }

  if (r.touchMode) {
    drawSlots(ctx, me, 16, 66, 26); // bottom of the screen belongs to the thumbs
  } else {
    drawSlots(ctx, me, 16, H - 36 * 2 - 5 - 16, 36);
    drawAbility(ctx, me, W, H);
  }
  drawIndicators(ctx, r, s, me);

  // banners
  for (const b of fx.banners) {
    const k = b.life / b.max;
    const a = Math.min(1, k * 4, (1 - k) * 8);
    ctx.globalAlpha = a;
    text(ctx, b.text, W / 2, H * 0.3, 46, b.color, 'center', '900');
    if (b.sub) text(ctx, b.sub, W / 2, H * 0.3 + 34, 18, '#e6e9f5', 'center');
    ctx.globalAlpha = 1;
  }
  fx.toasts.forEach((b, i) => {
    const k = b.life / b.max;
    ctx.globalAlpha = Math.min(1, k * 4);
    const y = H * 0.62 + i * 46;
    text(ctx, b.text, W / 2, y, 20, b.color, 'center');
    if (b.sub) text(ctx, b.sub, W / 2, y + 20, 13, '#ffffff', 'center', 'normal');
    ctx.globalAlpha = 1;
  });
}

function slot(ctx: Ctx, x: number, y: number, size: number, icon: string, color: string, level: number, max: number, evolved: boolean): void {
  ctx.fillStyle = 'rgba(12,16,30,0.8)';
  ctx.fillRect(x, y, size, size);
  ctx.strokeStyle = evolved ? '#ffd166' : rgba(color, 0.7);
  ctx.lineWidth = evolved ? 2.5 : 1.5;
  ctx.strokeRect(x + 0.5, y + 0.5, size - 1, size - 1);
  ctx.font = `bold ${size * 0.55}px ${FONT}`;
  ctx.textAlign = 'center';
  ctx.fillStyle = color;
  ctx.fillText(icon, x + size / 2, y + size * 0.62);
  ctx.font = `bold ${size * 0.3}px ${FONT}`;
  ctx.textAlign = 'right';
  ctx.fillStyle = level >= max ? '#ffd166' : '#ffffff';
  ctx.fillText(level >= max ? (evolved ? '★' : 'MAX') : String(level), x + size - 3, y + size - 3);
}

function drawSlots(ctx: Ctx, me: Player, x0: number, y1: number, size: number): void {
  const gap = 5;
  let x = x0;
  const y2 = y1 + size + gap;
  for (const w of me.weapons) {
    const d = WEAPONS[w.id];
    slot(ctx, x, y1, size, d.icon, d.color, w.level, MAX_WEAPON_LEVEL, w.evolved);
    x += size + gap;
  }
  x = x0;
  for (const k of me.perks) {
    const d = PERKS[k.id];
    slot(ctx, x, y2, size, d.icon, d.color, k.level, d.max, false);
    x += size + gap;
  }
}

function drawAbility(ctx: Ctx, me: Player, W: number, H: number): void {
  const c = CHARACTERS[me.charId];
  const R = 30, cx = W / 2, cy = H - R - 22;
  const ready = me.abilityCd <= 0;
  ctx.fillStyle = 'rgba(12,16,30,0.85)';
  ctx.beginPath();
  ctx.arc(cx, cy, R, 0, Math.PI * 2);
  ctx.fill();
  if (!ready) {
    const k = me.abilityCd / Math.max(0.01, me.abilityMaxCd);
    ctx.fillStyle = 'rgba(255,255,255,0.12)';
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, R, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (1 - k));
    ctx.closePath();
    ctx.fill();
  }
  ctx.strokeStyle = ready ? c.accent : 'rgba(255,255,255,0.25)';
  ctx.lineWidth = ready ? 3 : 2;
  ctx.beginPath();
  ctx.arc(cx, cy, R, 0, Math.PI * 2);
  ctx.stroke();
  if (ready) {
    ctx.strokeStyle = rgba(c.accent, 0.4 + Math.sin(performance.now() / 150) * 0.2);
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.arc(cx, cy, R + 4, 0, Math.PI * 2);
    ctx.stroke();
  }
  text(ctx, ready ? 'READY' : me.abilityCd.toFixed(1), cx, cy + 5, ready ? 12 : 16, ready ? c.accent : '#fff', 'center');
  text(ctx, `${c.ability.name}  [SPACE]`, cx, cy - R - 8, 12, '#dfe6ff', 'center');

  // ability level pips
  for (let i = 0; i < ABILITY_MAX_LEVEL; i++) {
    ctx.fillStyle = i < me.abilityLevel ? c.accent : 'rgba(255,255,255,0.18)';
    ctx.beginPath();
    ctx.arc(cx - ((ABILITY_MAX_LEVEL - 1) * 9) / 2 + i * 9, cy + R + 9, 3, 0, Math.PI * 2);
    ctx.fill();
  }

  // dash
  const dr = 20, dx = cx + R + 38, dy = cy + 6;
  const dReady = me.dashCd <= 0;
  ctx.fillStyle = 'rgba(12,16,30,0.85)';
  ctx.beginPath();
  ctx.arc(dx, dy, dr, 0, Math.PI * 2);
  ctx.fill();
  if (!dReady) {
    ctx.fillStyle = 'rgba(255,255,255,0.12)';
    ctx.beginPath();
    ctx.moveTo(dx, dy);
    ctx.arc(dx, dy, dr, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (1 - me.dashCd / Math.max(0.01, me.dashMaxCd)));
    ctx.closePath();
    ctx.fill();
  }
  ctx.strokeStyle = dReady ? '#9ad8ff' : 'rgba(255,255,255,0.25)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(dx, dy, dr, 0, Math.PI * 2);
  ctx.stroke();
  text(ctx, '»', dx, dy + 6, 18, dReady ? '#9ad8ff' : '#8890a8', 'center');
  text(ctx, 'SHIFT', dx, dy - dr - 6, 10, '#dfe6ff', 'center');
}

/** Arrows at the screen edge pointing to offscreen bosses and chests. */
function drawIndicators(ctx: Ctx, r: Renderer, s: GameState, me: Player): void {
  const targets: { x: number; y: number; color: string }[] = [];
  for (const e of s.enemies) if (e.boss) targets.push({ x: e.x, y: e.y, color: '#ff2e88' });
  for (const p of s.pickups) if (p.kind === 'chest' || p.kind === 'relic') targets.push({ x: p.x, y: p.y, color: '#ffd166' });
  for (const t of targets) {
    const [sx, sy] = r.screenOf(t.x, t.y);
    if (sx > 0 && sx < r.w && sy > 0 && sy < r.h) continue;
    const a = Math.atan2(t.y - me.y, t.x - me.x);
    const m = 40;
    const ex = Math.max(m, Math.min(r.w - m, r.w / 2 + Math.cos(a) * r.w));
    const ey = Math.max(m + 60, Math.min(r.h - m, r.h / 2 + Math.sin(a) * r.h));
    ctx.save();
    ctx.translate(ex, ey);
    ctx.rotate(a);
    ctx.fillStyle = t.color;
    ctx.beginPath();
    ctx.moveTo(16, 0);
    ctx.lineTo(-8, -10);
    ctx.lineTo(-4, 0);
    ctx.lineTo(-8, 10);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }
}
