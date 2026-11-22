// Saving the current run so it can be continued after the app is closed.
// Storage can be full or blocked; then runs simply aren't resumable.

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:nightfall_sim/nightfall_sim.dart';

import 'kv.dart';

const String _saveKey = 'nightfall.run';

class RunStorage {
  final KeyValueStore _kv;
  RunStorage(this._kv);

  static Future<RunStorage> open() async => RunStorage(await KeyValueStore.open());

  /// The underlying store, shared with the settings.
  KeyValueStore get store => _kv;

  GameState? loadRun() {
    try {
      final raw = _kv.get(_saveKey);
      return raw == null ? null : restore(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  bool saveRun(GameState s) {
    try {
      return _kv.set(_saveKey, jsonEncode(snapshot(s, DateTime.now().millisecondsSinceEpoch)));
    } catch (_) {
      return false;
    }
  }

  void clearRun() => _kv.remove(_saveKey);

  /// The stored save as text for an export file, or null when there is no usable save.
  String? exportRun() {
    final raw = _kv.get(_saveKey);
    return raw != null && loadRun() != null ? raw : null;
  }

  /// Validates an exported save and makes it the current save slot.
  /// Returns the run, or null if the text is not a usable save.
  GameState? importRun(String text) {
    try {
      final data = jsonDecode(text);
      final s = restore(data);
      if (s == null) return null;
      _kv.set(_saveKey, text);
      return s;
    } catch (_) {
      return null;
    }
  }

  /// Asks where to save the current save file. Returns the file name, or null.
  Future<String?> exportToFile() async {
    final raw = exportRun();
    final s = loadRun();
    if (raw == null || s == null) return null;
    final name = exportName(s);
    final uri = await FilePicker.saveFile(fileName: name, bytes: Uint8List.fromList(utf8.encode(raw)), mimeType: 'application/json');
    return uri == null ? null : name;
  }

  /// Lets the user pick a save file. Returns its text, '' when unreadable, or null when cancelled.
  Future<String?> pickImportFile() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (f == null) return null;
    try {
      final bytes = await f.readAsBytes();
      if (bytes.length > 5000000) return '';
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }
}

/// File name for an exported save, e.g. "nightfall-mage-wave7.json".
String exportName(GameState s) => 'nightfall-${s.players[0].charId}-wave${s.wave.n}.json';

/// One-line summary for the Continue button, e.g. "Mage · Wave 7 · Lv 21 · 5:12".
String describeRun(GameState s) {
  final p = s.players[0];
  final m = (s.time / 60).floor(), sec = (s.time % 60).floor();
  return '${characterDefs[p.charId]!.name} · Wave ${s.wave.n} · Lv ${p.level} · $m:${sec.toString().padLeft(2, '0')}';
}
