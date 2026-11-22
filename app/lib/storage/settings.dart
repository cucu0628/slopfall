// Player settings (sound volume), stored next to the save slot.

import 'kv.dart';

class Settings {
  final KeyValueStore _kv;
  Settings(this._kv);

  double get volume => double.tryParse(_kv.get('nightfall.volume') ?? '') ?? 1;
  set volume(double v) => _kv.set('nightfall.volume', v.toStringAsFixed(2));

  bool get muted => _kv.get('nightfall.muted') == '1';
  set muted(bool v) => _kv.set('nightfall.muted', v ? '1' : '0');
}
