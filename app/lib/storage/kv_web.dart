import 'package:web/web.dart' as web;

class KeyValueStore {
  static Future<KeyValueStore> open() async => KeyValueStore();

  String? get(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null; // storage blocked (private mode)
    }
  }

  bool set(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
      return true;
    } catch (_) {
      return false; // full or blocked
    }
  }

  void remove(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {}
  }
}
