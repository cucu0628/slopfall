// Application flow: menus, starting / continuing / pausing runs, wiring the
// session to the overlay screens, touch controls and run saving.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nightfall_sim/nightfall_sim.dart';

import 'audio/sound.dart';
import 'game/input.dart';
import 'game/session.dart';
import 'game/touch.dart';
import 'platform/window.dart';
import 'render/renderer.dart';
import 'storage/run_storage.dart';
import 'storage/settings.dart';
import 'ui/game_view.dart';
import 'ui/screens/char_select.dart';
import 'ui/screens/codex.dart';
import 'ui/screens/game_over.dart';
import 'ui/screens/level_up.dart';
import 'ui/screens/main_menu.dart';
import 'ui/screens/pause.dart';
import 'ui/theme.dart';
import 'ui/touch_controls.dart';
import 'ui/volume_control.dart';

const double _saveEvery = 5; // game seconds

enum Screen { menu, chars, codex, levelup, pause, over }

class NightfallApp extends StatelessWidget {
  final RunStorage storage;
  final Settings settings;
  final bool audio;
  const NightfallApp({super.key, required this.storage, required this.settings, this.audio = true});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Nightfall Survivors',
        debugShowCheckedModeBanner: false,
        theme: nightfallTheme(),
        home: GameShell(storage: storage, settings: settings, audio: audio),
      );
}

class GameShell extends StatefulWidget {
  final RunStorage storage;
  final Settings settings;
  final bool audio;
  const GameShell({super.key, required this.storage, required this.settings, this.audio = true});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  final Renderer _renderer = Renderer();
  final TouchState _touch = TouchState();
  late final Input _input = Input(_touch);
  late final Sound _sound = Sound(enabled: widget.audio)
    ..volume = widget.settings.volume
    ..muted = widget.settings.muted;
  final FocusNode _focus = FocusNode(debugLabel: 'game');
  late final AppLifecycleListener _lifecycle;

  late Session _session;
  Screen? _screen = Screen.menu;
  List<UpgradeOption>? _shownChoices;
  String _lastChar = characterIds[0];
  bool _realRun = false; // false while the menu backdrop demo runs
  double _lastSave = 0;
  GameState? _saved;
  String? _saveMsg;
  bool _saveMsgError = false;
  // touch button cooldowns, refreshed a few times per second
  double _abilityCd = 0, _dashCd = 0;

  RunStorage get _storage => widget.storage;

  @override
  void initState() {
    super.initState();
    _touch.enabled = isTouchPlatform;
    _renderer.touchMode = _touch.enabled;
    HardwareKeyboard.instance.addHandler(_onKey);
    _lifecycle = AppLifecycleListener(
      // closing the app, switching apps or locking the phone saves the run
      onHide: _writeSave,
      onPause: _writeSave,
      onDetach: _writeSave,
      onInactive: () {
        if (_inGame && _screen == null) _setPaused(true);
      },
    );
    _runDemo();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _lifecycle.dispose();
    _focus.dispose();
    _renderer.dispose();
    super.dispose();
  }

  bool get _inGame => _realRun && _screen != Screen.menu && _screen != Screen.chars && _screen != Screen.codex;

  void _setScreen(Screen? s) {
    setState(() {
      _screen = s;
      if (s != Screen.menu) _saveMsg = null;
      final visible = s == null;
      if (visible != _touch.visible) {
        _touch.visible = visible;
        if (!visible) _touch.reset();
      }
    });
    if (s == null) _focus.requestFocus();
  }

  void _writeSave() {
    final s = _session.state;
    if (!_realRun || s.gameOver) return;
    if (_storage.saveRun(s)) _lastSave = s.time;
  }

  void _refreshContinue() => _saved = _storage.loadRun();

  void _message(String text, {bool error = false}) => setState(() {
        _saveMsg = text;
        _saveMsgError = error;
      });

  Future<void> _exportSave() async {
    _refreshContinue();
    if (_saved == null) return _message('No saved run to export.', error: true);
    try {
      final name = await _storage.exportToFile();
      if (name != null) _message('Exported $name');
    } catch (_) {
      _message('Could not write the save file.', error: true);
    }
  }

  Future<void> _importSave() async {
    if (_storage.loadRun() != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Nf.surfaceTop,
          title: Text('Import save', style: Nf.display(size: Nf.fsXl)),
          content: Text('Importing replaces your current saved run. Continue?', style: Nf.ui()),
          actions: [
            NfButton('Cancel', size: BtnSize.sm, onPressed: () => Navigator.pop(context, false)),
            NfButton('Import', size: BtnSize.sm, kind: BtnKind.primary, onPressed: () => Navigator.pop(context, true)),
          ],
        ),
      );
      if (ok != true) return;
    }
    final text = await _storage.pickImportFile();
    if (text == null) return;
    final run = _storage.importRun(text);
    setState(_refreshContinue);
    if (run != null) {
      _message('Imported: ${describeRun(run)}');
    } else {
      _message('That file is not a valid Nightfall save (or it is from an older version).', error: true);
    }
  }

  void _runDemo() {
    _realRun = false;
    _refreshContinue();
    final charId = characterIds[math.Random().nextInt(characterIds.length)];
    _session = Session(charId, _renderer);
    unawaited(leaveGame());
  }

  void _startGame(String charId, [GameState? saved]) {
    _lastChar = charId;
    unawaited(_sound.unlock());
    _shownChoices = null;
    _realRun = true;
    _lastSave = saved?.time ?? 0;
    _touch.aimMode = charId == 'mage';
    _input.clear();
    _session = Session(charId, _renderer, input: _input, sound: _sound, onFrame: _syncUi, onGameOver: _gameOver, initial: saved);
    unawaited(enterGame());
    _setScreen(null);
  }

  void _syncUi(GameState s) {
    final me = s.players.firstWhere((p) => p.id == localId);
    if (s.time - _lastSave >= _saveEvery) _writeSave();
    if (_touch.enabled) {
      final a = me.abilityCd / math.max(0.01, me.abilityMaxCd), d = me.dashCd / math.max(0.01, me.dashMaxCd);
      if ((a - _abilityCd).abs() > 0.02 || (d - _dashCd).abs() > 0.02 || (a <= 0) != (_abilityCd <= 0) || (d <= 0) != (_dashCd <= 0)) {
        setState(() {
          _abilityCd = a;
          _dashCd = d;
        });
      }
    }
    if (!identical(me.choices, _shownChoices)) {
      _shownChoices = me.choices;
      if (me.choices != null) {
        _setScreen(Screen.levelup);
      } else if (_screen == Screen.levelup) {
        _setScreen(null);
      }
    }
  }

  void _gameOver(GameState s) {
    _storage.clearRun();
    unawaited(leaveGame());
    _setScreen(Screen.over);
  }

  void _setPaused(bool p) {
    if (!_realRun || _session.state.gameOver) return;
    if (p && _screen != null) return;
    _session.paused = p;
    if (p) {
      _writeSave();
      _input.clear();
      _setScreen(Screen.pause);
    } else if (_screen == Screen.pause) {
      _setScreen(null);
    }
  }

  void _toMenu() {
    _writeSave(); // a deliberate quit can still be continued later
    _runDemo();
    _setScreen(Screen.menu);
  }

  bool _onKey(KeyEvent e) {
    final key = e.physicalKey;
    if (e is KeyUpEvent) {
      _input.keys.remove(key);
      return false;
    }
    if (e is! KeyDownEvent) return false;
    // keys typed into a dialog are not game input
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    _input.keys.add(key);
    unawaited(_sound.unlock());
    if (key == PhysicalKeyboardKey.keyM) _toggleMute();
    if (key == PhysicalKeyboardKey.f11) unawaited(toggleFullscreen());
    if (key == PhysicalKeyboardKey.escape && _screen == Screen.chars) {
      _setScreen(Screen.menu);
      return true;
    }
    if (!_inGame) return false;
    if (key == PhysicalKeyboardKey.escape) {
      _setPaused(!_session.paused);
      return true;
    }
    if (_screen == Screen.levelup) {
      const digits = [PhysicalKeyboardKey.digit1, PhysicalKeyboardKey.digit2, PhysicalKeyboardKey.digit3, PhysicalKeyboardKey.digit4];
      final i = digits.indexOf(key);
      if (i >= 0) {
        _input.choose(i);
        return true;
      }
    }
    // in a run, keep Space / arrows from activating focused buttons
    return _screen == null;
  }

  void _toggleMute() {
    setState(_sound.toggleMute);
    widget.settings.muted = _sound.muted;
  }

  void _setVolume(double v) {
    setState(() => _sound.setVolume(v));
    widget.settings
      ..volume = _sound.volume
      ..muted = _sound.muted;
  }

  Widget _volumeControl() => VolumeControl(volume: _sound.volume, muted: _sound.muted, onChanged: _setVolume, onToggleMute: _toggleMute);

  void _onPointerDown(PointerDownEvent e) {
    unawaited(_sound.unlock());
    // hybrid devices: switch to touch controls on the first real touch
    if (e.kind == PointerDeviceKind.touch && !_touch.enabled) {
      setState(() {
        _touch.enabled = true;
        _renderer.touchMode = true;
      });
    }
  }

  /// Test hooks: the current state, a forced level-up and a forced death.
  @visibleForTesting
  GameState get debugState => _session.state;

  @visibleForTesting
  void debugLevelUp() {
    final p = _session.state.players[0];
    p.perks.add(PerkInst(id: 'haste'));
    p.weapons[0].level = maxWeaponLevel;
    p.pendingLevels++;
  }

  @visibleForTesting
  void debugKill() {
    _session.state.cfg.godMode = false;
    final p = _session.state.players[0];
    p.dmgDealt['ability'] = 1234;
    hurtPlayer(_session.state, p, 1e6);
  }

  @override
  Widget build(BuildContext context) {
    final s = _session.state;
    final me = s.players[0];
    final overlay = switch (_screen) {
      Screen.menu => MainMenu(
          continueInfo: _saved != null ? describeRun(_saved!) : null,
          saveMessage: _saveMsg,
          saveMessageError: _saveMsgError,
          touch: _touch.enabled,
          onContinue: () {
            final saved = _storage.loadRun();
            if (saved != null) {
              _startGame(saved.players[0].charId, saved);
            } else {
              setState(_refreshContinue);
            }
          },
          onNewRun: () {
            unawaited(_sound.unlock());
            _setScreen(Screen.chars);
          },
          onCodex: () => _setScreen(Screen.codex),
          onExport: _exportSave,
          onImport: _importSave,
          volume: _volumeControl(),
        ),
      Screen.chars => CharSelect(onPick: _startGame, onBack: () => _setScreen(Screen.menu)),
      Screen.codex => CodexScreen(onBack: () => _setScreen(Screen.menu)),
      Screen.levelup when me.choices != null => LevelUpScreen(choices: me.choices!, player: me, touch: _touch.enabled, onChoose: _input.choose),
      Screen.pause => PauseScreen(player: me, onResume: () => _setPaused(false), onQuit: _toMenu, volume: _volumeControl()),
      Screen.over => GameOverScreen(
          state: s,
          onRetry: () => _startGame(_lastChar),
          onChange: () {
            _runDemo();
            _setScreen(Screen.chars);
          },
          onMenu: _toMenu,
        ),
      _ => null,
    };
    return Scaffold(
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GameView(session: _session, onPointerDown: _onPointerDown),
            if (_touch.active && _realRun)
              TouchControls(
                state: _touch,
                abilityColor: characterDefs[me.charId]!.accent,
                abilityCd: _abilityCd,
                dashCd: _dashCd,
                onPause: () => _setPaused(true),
              ),
            if (overlay != null) Listener(onPointerDown: _onPointerDown, child: overlay),
          ],
        ),
      ),
    );
  }
}
