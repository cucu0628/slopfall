// JavaScript-compatible number helpers.
//
// The game was first written in TypeScript and saves from that version must
// keep working, so the simulation copies JS number semantics where Dart's
// differ. Integer bit tricks are written so they give the same result on the
// Dart VM (64-bit ints) and on the web (ints are JS doubles).

import 'dart:math' as math;

const int _mask32 = 0xffffffff;

/// Low 32 bits as an unsigned value (JS `x >>> 0`).
int u32(int x) => x & _mask32;

/// Low 32 bits as a signed value (JS `x | 0`).
int i32(int x) => ((x & _mask32) ^ 0x80000000) - 0x80000000;

/// JS `Math.imul`, returned as an unsigned 32-bit value.
int imul(int a, int b) {
  a &= _mask32;
  b &= _mask32;
  final ah = (a >> 16) & 0xffff, al = a & 0xffff;
  final bh = (b >> 16) & 0xffff, bl = b & 0xffff;
  // every partial product stays below 2^53, so this is exact on the web too
  return (al * bl + (((ah * bl + al * bh) & 0xffff) << 16)) & _mask32;
}

/// JS `x >>> n` for 0 <= n < 32.
int ushr(int x, int n) => (x & _mask32) >> n;

/// JS `Math.hypot(x, y)`, using the same normalised Kahan summation as V8 so
/// results match the TypeScript version bit for bit.
double hypot(double x, double y) {
  final ax = x.abs(), ay = y.abs();
  if (ax == double.infinity || ay == double.infinity) return double.infinity;
  if (ax.isNaN || ay.isNaN) return double.nan;
  final m = ax > ay ? ax : ay;
  if (m == 0) return 0;
  var sum = 0.0, comp = 0.0;
  final nx = ax / m;
  var summand = nx * nx - comp;
  var pre = sum + summand;
  comp = (pre - sum) - summand;
  sum = pre;
  final ny = ay / m;
  summand = ny * ny - comp;
  pre = sum + summand;
  sum = pre;
  return math.sqrt(sum) * m;
}

/// JS `Math.round` (halves round up, also for negative numbers).
double jsRound(double x) => (x + 0.5).floorToDouble();

/// JS `Math.round` as an int (0 for non-finite values).
int roundInt(double x) => x.isFinite ? jsRound(x).toInt() : 0;

/// JS `a % b` for doubles: the result has the sign of the dividend.
double jsMod(double a, double b) => a.remainder(b);

/// JS `d || 1` for a distance: 0 and NaN fall back to 1.
double or1(double d) => (d == 0 || d.isNaN) ? 1 : d;

/// JS `Number.isFinite(v) ? clamp(v) : 0`.
double finiteClamp(double v, double lim) => v.isFinite ? math.max(-lim, math.min(lim, v)) : 0;

/// Formats a number like JS template literals do ("14", not "14.0").
String jsNum(num v) {
  if (v is int) return '$v';
  final d = v.toDouble();
  if (d.isFinite && d == d.truncateToDouble() && d.abs() < 1e21) return '${d.toInt()}';
  return '$d';
}

/// Reads a number from decoded JSON (JS saves store every number as a double).
double jnum(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;

int jint(Object? v, [int fallback = 0]) => v is num && v.isFinite ? v.toInt() : fallback;

bool jbool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

String jstr(Object? v, [String fallback = '']) => v is String ? v : fallback;

Map<String, Object?> jmap(Object? v) => v is Map ? v.cast<String, Object?>() : <String, Object?>{};

List<Object?> jlist(Object? v) => v is List ? v : const [];

List<double> jnums(Object? v) => [for (final x in jlist(v)) jnum(x)];
