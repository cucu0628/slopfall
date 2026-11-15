// Tiny DOM helpers and screen switching for the HTML overlays.

export const byId = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;

export function el(tag: string, cls = '', html = ''): HTMLElement {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (html) e.innerHTML = html;
  return e;
}

export const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);

export type ScreenId = 'menu' | 'chars' | 'codex' | 'levelup' | 'pause' | 'over';

export function show(id: ScreenId | null): void {
  for (const s of ['menu', 'chars', 'codex', 'levelup', 'pause', 'over'] as ScreenId[]) {
    byId(`screen-${s}`).classList.toggle('hidden', s !== id);
  }
}
