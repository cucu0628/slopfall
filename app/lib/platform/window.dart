// Fullscreen and screen-awake helpers that differ per platform.

export 'window_native.dart' if (dart.library.js_interop) 'window_web.dart';
