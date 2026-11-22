// A tiny string key-value store for the save slot.
//
// On the web this is window.localStorage with the same key the TypeScript
// version used, so a run saved by the old game on the same site continues in
// the new one. Elsewhere it is shared_preferences.

export 'kv_native.dart' if (dart.library.js_interop) 'kv_web.dart';
