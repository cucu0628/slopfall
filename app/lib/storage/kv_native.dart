import 'package:shared_preferences/shared_preferences.dart';

class KeyValueStore {
  final SharedPreferences? _prefs;
  KeyValueStore._(this._prefs);

  static Future<KeyValueStore> open() async {
    try {
      return KeyValueStore._(await SharedPreferences.getInstance());
    } catch (_) {
      return KeyValueStore._(null);
    }
  }

  String? get(String key) => _prefs?.getString(key);

  bool set(String key, String value) {
    final p = _prefs;
    if (p == null) return false;
    p.setString(key, value); // cached synchronously, written in the background
    return true;
  }

  void remove(String key) => _prefs?.remove(key);
}
