// sin, cos and atan2 ported from fdlibm (the versions V8 uses for Math.sin,
// Math.cos and Math.atan2).
//
// dart:math calls the platform's C library, whose results differ in the last
// bit from platform to platform (and from the browser). The simulation must
// give identical results everywhere — on every Dart platform and compared to
// the original TypeScript version — so it uses these instead.
//
// Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
// Developed at SunSoft, a Sun Microsystems, Inc. business.
// Permission to use, copy, modify, and distribute this software is freely
// granted, provided that this notice is preserved.

import 'dart:math' as math;
import 'dart:typed_data';

final ByteData _bits = ByteData(8);

int _hi(double x) {
  _bits.setFloat64(0, x);
  return _bits.getInt32(0);
}

int _lo(double x) {
  _bits.setFloat64(0, x);
  return _bits.getUint32(4);
}

double _words(int hi, int lo) {
  _bits.setInt32(0, hi);
  _bits.setUint32(4, lo);
  return _bits.getFloat64(0);
}

// ---------------------------------------------------------------- kernels

const double _s1 = -1.66666666666666324348e-01;
const double _s2 = 8.33333333332248946124e-03;
const double _s3 = -1.98412698298579493134e-04;
const double _s4 = 2.75573137070700676789e-06;
const double _s5 = -2.50507602534068634195e-08;
const double _s6 = 1.58969099521155010221e-10;

double _kernelSin(double x, double y, int iy) {
  final ix = _hi(x) & 0x7fffffff;
  if (ix < 0x3e400000 && x.toInt() == 0) return x; // |x| < 2**-27
  final z = x * x;
  final v = z * x;
  final r = _s2 + z * (_s3 + z * (_s4 + z * (_s5 + z * _s6)));
  if (iy == 0) return x + v * (_s1 + z * r);
  return x - ((z * (0.5 * y - v * r) - y) - v * _s1);
}

const double _c1 = 4.16666666666666019037e-02;
const double _c2 = -1.38888888888741095749e-03;
const double _c3 = 2.48015872894767294178e-05;
const double _c4 = -2.75573143513906633035e-07;
const double _c5 = 2.08757232129817482790e-09;
const double _c6 = -1.13596475577881948265e-11;

double _kernelCos(double x, double y) {
  final ix = _hi(x) & 0x7fffffff;
  if (ix < 0x3e400000 && x.toInt() == 0) return 1; // |x| < 2**-27
  final z = x * x;
  final r = z * (_c1 + z * (_c2 + z * (_c3 + z * (_c4 + z * (_c5 + z * _c6)))));
  if (ix < 0x3fd33333) return 1 - (0.5 * z - (z * r - x * y)); // |x| < 0.3
  final qx = ix > 0x3fe90000 ? 0.28125 : _words(ix - 0x00200000, 0); // x/4
  final hz = 0.5 * z - qx;
  final a = 1 - qx;
  return a - (hz - (z * r - x * y));
}

// --------------------------------------------------------- range reduction

const List<int> _npio2hw = [
  0x3FF921FB, 0x400921FB, 0x4012D97C, 0x401921FB, 0x401F6A7A, 0x4022D97C, 0x4025FDBB, 0x402921FB, //
  0x402C463A, 0x402F6A7A, 0x4031475C, 0x4032D97C, 0x40346B9C, 0x4035FDBB, 0x40378FDB, 0x403921FB,
  0x403AB41B, 0x403C463A, 0x403DD85A, 0x403F6A7A, 0x40407E4C, 0x4041475C, 0x4042106C, 0x4042D97C,
  0x4043A28C, 0x40446B9C, 0x404534AC, 0x4045FDBB, 0x4046C6CB, 0x40478FDB, 0x404858EB, 0x404921FB,
];

const double _invpio2 = 6.36619772367581382433e-01;
const double _pio2_1 = 1.57079632673412561417e+00;
const double _pio2_1t = 6.07710050650619224932e-11;
const double _pio2_2 = 6.07710050630396597660e-11;
const double _pio2_2t = 2.02226624879595063154e-21;
const double _pio2_3 = 2.02226624871116645580e-21;
const double _pio2_3t = 8.47842766036889956997e-32;

/// Reduces x to y0 + y1 in [-pi/4, pi/4]; returns the quadrant, or null when
/// |x| is too large for the medium-size path.
int? _remPio2(double x, List<double> y) {
  final hx = _hi(x);
  final ix = hx & 0x7fffffff;
  if (ix <= 0x3fe921fb) {
    y[0] = x;
    y[1] = 0;
    return 0;
  }
  if (ix < 0x4002d97c) {
    // |x| < 3pi/4, special case with n = +-1
    if (hx > 0) {
      var z = x - _pio2_1;
      if (ix != 0x3ff921fb) {
        y[0] = z - _pio2_1t;
        y[1] = (z - y[0]) - _pio2_1t;
      } else {
        z -= _pio2_2;
        y[0] = z - _pio2_2t;
        y[1] = (z - y[0]) - _pio2_2t;
      }
      return 1;
    } else {
      var z = x + _pio2_1;
      if (ix != 0x3ff921fb) {
        y[0] = z + _pio2_1t;
        y[1] = (z - y[0]) + _pio2_1t;
      } else {
        z += _pio2_2;
        y[0] = z + _pio2_2t;
        y[1] = (z - y[0]) + _pio2_2t;
      }
      return -1;
    }
  }
  if (ix <= 0x413921fb) {
    // |x| ~<= 2^19*(pi/2), medium size
    var t = x.abs();
    final n = (t * _invpio2 + 0.5).toInt();
    final fn = n.toDouble();
    var r = t - fn * _pio2_1;
    var w = fn * _pio2_1t; // 1st round good to 85 bit
    if (n < 32 && ix != _npio2hw[n - 1]) {
      y[0] = r - w; // quick check no cancellation
    } else {
      final j = ix >> 20;
      y[0] = r - w;
      var i = j - ((_hi(y[0]) >> 20) & 0x7ff);
      if (i > 16) {
        // 2nd iteration needed, good to 118
        t = r;
        w = fn * _pio2_2;
        r = t - w;
        w = fn * _pio2_2t - ((t - r) - w);
        y[0] = r - w;
        i = j - ((_hi(y[0]) >> 20) & 0x7ff);
        if (i > 49) {
          // 3rd iteration need, 151 bits acc
          t = r;
          w = fn * _pio2_3;
          r = t - w;
          w = fn * _pio2_3t - ((t - r) - w);
          y[0] = r - w;
        }
      }
    }
    y[1] = (r - y[0]) - w;
    if (hx < 0) {
      y[0] = -y[0];
      y[1] = -y[1];
      return -n;
    }
    return n;
  }
  return null;
}

final List<double> _y = [0, 0];

/// Math.sin as computed by V8.
double jsSin(double x) {
  final ix = _hi(x) & 0x7fffffff;
  if (ix <= 0x3fe921fb) return _kernelSin(x, 0, 0);
  if (ix >= 0x7ff00000) return x - x; // NaN / Infinity
  final n = _remPio2(x, _y);
  if (n == null) return math.sin(x); // |x| > ~823000: never reached by the game
  switch (n & 3) {
    case 0:
      return _kernelSin(_y[0], _y[1], 1);
    case 1:
      return _kernelCos(_y[0], _y[1]);
    case 2:
      return -_kernelSin(_y[0], _y[1], 1);
    default:
      return -_kernelCos(_y[0], _y[1]);
  }
}

/// Math.cos as computed by V8.
double jsCos(double x) {
  final ix = _hi(x) & 0x7fffffff;
  if (ix <= 0x3fe921fb) return _kernelCos(x, 0);
  if (ix >= 0x7ff00000) return x - x;
  final n = _remPio2(x, _y);
  if (n == null) return math.cos(x);
  switch (n & 3) {
    case 0:
      return _kernelCos(_y[0], _y[1]);
    case 1:
      return -_kernelSin(_y[0], _y[1], 1);
    case 2:
      return -_kernelCos(_y[0], _y[1]);
    default:
      return _kernelSin(_y[0], _y[1], 1);
  }
}

// -------------------------------------------------------------- arctangent

const List<double> _atanhi = [
  4.63647609000806093515e-01,
  7.85398163397448278999e-01,
  9.82793723247329054082e-01,
  1.57079632679489655800e+00,
];

const List<double> _atanlo = [
  2.26987774529616870924e-17,
  3.06161699786838301793e-17,
  1.39033110312309984516e-17,
  6.12323399573676603587e-17,
];

const List<double> _aT = [
  3.33333333333329318027e-01,
  -1.99999999998764832476e-01,
  1.42857142725034663711e-01,
  -1.11111104054623557880e-01,
  9.09088713343650656196e-02,
  -7.69187620504482999495e-02,
  6.66107313738753120669e-02,
  -5.83357013379057348645e-02,
  4.97687799461593236017e-02,
  -3.65315727442169155270e-02,
  1.62858201153657823623e-02,
];

double _atan(double x) {
  final hx = _hi(x);
  final ix = hx & 0x7fffffff;
  int id;
  if (ix >= 0x44100000) {
    // |x| >= 2^66
    if (x.isNaN) return x + x;
    return hx > 0 ? _atanhi[3] + _atanlo[3] : -_atanhi[3] - _atanlo[3];
  }
  if (ix < 0x3fdc0000) {
    // |x| < 0.4375
    if (ix < 0x3e400000) return x; // |x| < 2^-27
    id = -1;
  } else {
    x = x.abs();
    if (ix < 0x3ff30000) {
      // |x| < 1.1875
      if (ix < 0x3fe60000) {
        id = 0;
        x = (2.0 * x - 1.0) / (2.0 + x);
      } else {
        id = 1;
        x = (x - 1.0) / (x + 1.0);
      }
    } else {
      if (ix < 0x40038000) {
        // |x| < 2.4375
        id = 2;
        x = (x - 1.5) / (1.0 + 1.5 * x);
      } else {
        id = 3;
        x = -1.0 / x;
      }
    }
  }
  var z = x * x;
  final w = z * z;
  final s1 = z * (_aT[0] + w * (_aT[2] + w * (_aT[4] + w * (_aT[6] + w * (_aT[8] + w * _aT[10])))));
  final s2 = w * (_aT[1] + w * (_aT[3] + w * (_aT[5] + w * (_aT[7] + w * _aT[9]))));
  if (id < 0) return x - x * (s1 + s2);
  z = _atanhi[id] - ((x * (s1 + s2) - _atanlo[id]) - x);
  return hx < 0 ? -z : z;
}

const double _piO4 = 7.8539816339744827900E-01;
const double _piO2 = 1.5707963267948965580E+00;
const double _pi = 3.1415926535897931160E+00;
const double _piLo = 1.2246467991473531772E-16;

/// Math.atan2 as computed by V8.
double jsAtan2(double y, double x) {
  if (x.isNaN || y.isNaN) return x + y;
  final hx = _hi(x), lx = _lo(x);
  final hy = _hi(y), ly = _lo(y);
  final ix = hx & 0x7fffffff, iy = hy & 0x7fffffff;
  if (x == 1.0) return _atan(y);
  final m = ((hy >> 31) & 1) | ((hx >> 30) & 2); // 2*sign(x)+sign(y)

  if ((iy | ly) == 0) {
    // y = 0
    switch (m) {
      case 0:
      case 1:
        return y;
      case 2:
        return _pi;
      default:
        return -_pi;
    }
  }
  if ((ix | lx) == 0) return hy < 0 ? -_piO2 : _piO2; // x = 0

  if (ix == 0x7ff00000) {
    // x is INF
    if (iy == 0x7ff00000) {
      switch (m) {
        case 0:
          return _piO4;
        case 1:
          return -_piO4;
        case 2:
          return 3.0 * _piO4;
        default:
          return -3.0 * _piO4;
      }
    }
    switch (m) {
      case 0:
        return 0.0;
      case 1:
        return -0.0;
      case 2:
        return _pi;
      default:
        return -_pi;
    }
  }
  if (iy == 0x7ff00000) return hy < 0 ? -_piO2 : _piO2; // y is INF

  // arithmetic shift of a possibly negative int32: on the web `>>` treats
  // negative numbers as unsigned, so divide instead
  final k = ((iy - ix) / 1048576).floor();
  double z;
  var mm = m;
  if (k > 60) {
    // |y/x| > 2**60
    z = _piO2 + 0.5 * _piLo;
    mm &= 1;
  } else if (hx < 0 && k < -60) {
    z = 0.0; // 0 > |y|/x > -2**-60
  } else {
    z = _atan((y / x).abs());
  }
  switch (mm) {
    case 0:
      return z;
    case 1:
      return -z;
    case 2:
      return _pi - (z - _piLo);
    default:
      return (z - _piLo) - _pi;
  }
}
