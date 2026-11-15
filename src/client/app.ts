// Application flow: menus, starting / continuing / pausing runs, wiring the
// session to the HTML overlays, touch controls and run saving.

import { CHARACTER_IDS, CHARACTERS } from '../sim/content/characters';
import type { GameState, UpgradeOption } from '../sim/types';
import { Sound } from './audio';
import { Input } from './input';
import { Renderer } from './render/renderer';
import { clearRun, describeRun, exportName, exportRun, importRun, loadRun, saveRun } from './runStorage';
import { LOCAL_ID, Session } from './session';
import { TouchControls } from './touch';
import { buildCharSelect } from './ui/charSelect';
import { buildCodex, codexKey } from './ui/codex';
import { byId, show, type ScreenId } from './ui/dom';
import { buildGameOver } from './ui/gameOver';
import { buildLevelUp } from './ui/levelUp';
import { buildPause } from './ui/pause';

const SAVE_EVERY = 5; // game seconds

export function startApp(): void {
  const canvas = byId<HTMLCanvasElement>('game');
  const renderer = new Renderer(canvas);
  const input = new Input(canvas);
  const sound = new Sound();
  const touch = new TouchControls(
    () => setPaused(true),
    () => {
      renderer.touchMode = true;
      renderer.resize();
    },
  );
  input.touch = touch;
  renderer.touchMode = touch.enabled;
  renderer.resize();

  let session: Session | null = null;
  let screen: ScreenId | null = 'menu';
  let shownChoices: UpgradeOption[] | null = null;
  let lastChar = CHARACTER_IDS[0];
  let isRealRun = false; // false while the menu backdrop demo runs
  let lastSave = 0;

  function setScreen(id: ScreenId | null): void {
    screen = id;
    show(id);
    if (id !== 'menu') byId('save-msg').classList.add('hidden');
    touch.setVisible(id === null);
  }

  function writeSave(): void {
    const s = session?.state;
    if (!s || !isRealRun || s.gameOver) return;
    if (saveRun(s)) lastSave = s.time;
  }

  /** Shows the Continue and Export buttons when a resumable run exists. */
  function refreshContinue(): void {
    const saved = loadRun();
    byId('btn-continue').classList.toggle('hidden', !saved);
    byId('btn-export').classList.toggle('hidden', !saved);
    if (saved) byId('continue-info').textContent = describeRun(saved);
  }

  function saveMessage(text: string, error = false): void {
    const m = byId('save-msg');
    m.textContent = text;
    m.classList.toggle('error', error);
    m.classList.remove('hidden');
  }

  function exportSave(): void {
    const raw = exportRun();
    const saved = raw ? loadRun() : null;
    if (!raw || !saved) {
      refreshContinue();
      return saveMessage('No saved run to export.', true);
    }
    const url = URL.createObjectURL(new Blob([raw], { type: 'application/json' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = exportName(saved);
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    saveMessage(`Exported ${a.download}`);
  }

  async function importSave(file: File): Promise<void> {
    if (loadRun() && !confirm('Importing replaces your current saved run. Continue?')) return;
    const text = file.size < 5_000_000 ? await file.text().catch(() => '') : '';
    const run = importRun(text);
    refreshContinue();
    if (run) saveMessage(`Imported: ${describeRun(run)}`);
    else saveMessage('That file is not a valid Nightfall save (or it is from an older version).', true);
  }

  function runDemo(): void {
    session?.stop();
    isRealRun = false;
    refreshContinue();
    const charId = CHARACTER_IDS[Math.floor(Math.random() * CHARACTER_IDS.length)];
    session = new Session(charId, renderer, null, null);
    session.start();
  }

  function startGame(charId: string, saved: GameState | null = null): void {
    lastChar = charId;
    sound.unlock();
    session?.stop();
    shownChoices = null;
    isRealRun = true;
    lastSave = saved?.time ?? 0;
    touch.aimMode = charId === 'mage';
    if (touch.enabled && !document.fullscreenElement) {
      // more screen space on phones; ignored where unsupported (e.g. iOS Safari)
      document.documentElement.requestFullscreen?.().catch(() => {});
    }
    setScreen(null);
    session = new Session(charId, renderer, input, sound, { onFrame: syncUi, onGameOver: gameOver }, saved);
    session.start();
  }

  function syncUi(s: GameState): void {
    const me = s.players.find((p) => p.id === LOCAL_ID)!;
    if (s.time - lastSave >= SAVE_EVERY) writeSave();
    if (touch.enabled) {
      touch.setCooldowns(
        me.abilityCd / Math.max(0.01, me.abilityMaxCd),
        me.dashCd / Math.max(0.01, me.dashMaxCd),
        CHARACTERS[me.charId].accent,
      );
    }
    if (me.choices !== shownChoices) {
      shownChoices = me.choices;
      if (me.choices) {
        buildLevelUp(me.choices, me, (i) => input.choose(i));
        setScreen('levelup');
      } else if (screen === 'levelup') {
        setScreen(null);
      }
    }
  }

  function gameOver(s: GameState): void {
    clearRun();
    buildGameOver(s, s.players[0]);
    setScreen('over');
  }

  function setPaused(p: boolean): void {
    if (!session || session.state.gameOver) return;
    if (p && screen !== null) return;
    session.paused = p;
    if (p) {
      writeSave();
      buildPause(session.state.players[0]);
      setScreen('pause');
    } else if (screen === 'pause') {
      setScreen(null);
    }
  }

  function toMenu(): void {
    writeSave(); // a deliberate quit can still be continued later
    setScreen('menu');
    runDemo();
  }

  const inGame = () => session !== null && screen !== 'menu' && screen !== 'chars' && screen !== 'codex';

  buildCharSelect(startGame);
  byId('btn-play').addEventListener('click', () => {
    sound.unlock();
    setScreen('chars');
  });
  byId('btn-continue').addEventListener('click', () => {
    const saved = loadRun();
    if (saved) startGame(saved.players[0].charId, saved);
    else refreshContinue();
  });
  byId('btn-back').addEventListener('click', () => setScreen('menu'));
  byId('btn-codex').addEventListener('click', () => {
    buildCodex();
    setScreen('codex');
    byId('screen-codex').scrollTop = 0;
  });
  byId('btn-codex-back').addEventListener('click', () => setScreen('menu'));
  byId('btn-export').addEventListener('click', exportSave);
  const fileInput = byId<HTMLInputElement>('import-file');
  byId('btn-import').addEventListener('click', () => fileInput.click());
  fileInput.addEventListener('change', () => {
    const f = fileInput.files?.[0];
    fileInput.value = ''; // picking the same file again still fires change
    if (f) void importSave(f);
  });
  byId('btn-resume').addEventListener('click', () => setPaused(false));
  byId('btn-quit').addEventListener('click', toMenu);
  byId('btn-retry').addEventListener('click', () => startGame(lastChar));
  byId('btn-change').addEventListener('click', () => {
    runDemo();
    setScreen('chars');
  });
  byId('btn-menu').addEventListener('click', toMenu);

  window.addEventListener('keydown', (e) => {
    if (e.code === 'KeyM') sound.toggleMute();
    if (e.code === 'Escape' && (screen === 'codex' || screen === 'chars')) setScreen('menu');
    if (screen === 'codex' && codexKey(e.code)) e.preventDefault();
    if (!inGame()) return;
    if (e.code === 'Escape') setPaused(!session!.paused);
    if (screen === 'levelup' && /^Digit[1-4]$/.test(e.code)) input.choose(Number(e.code.slice(5)) - 1);
  });
  // closing the tab, switching apps or locking the phone saves the run
  window.addEventListener('pagehide', writeSave);
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') writeSave();
  });
  window.addEventListener('blur', () => {
    if (inGame() && screen === null) setPaused(true);
  });

  runDemo();

  // Dev-only handle for debugging from the browser console.
  if (import.meta.env.DEV) (window as unknown as { __session: () => Session | null }).__session = () => session;
}
