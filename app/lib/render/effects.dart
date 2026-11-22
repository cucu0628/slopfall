// Client-only visual effects (particles, floating numbers, rings, banners).
// These never feed back into the simulation, so dart:math Random is fine here.

import 'dart:math' as math;

final _rnd = math.Random();
double _r() => _rnd.nextDouble();

class Particle {
  double x, y, vx, vy, life;
  final double max, size;
  final String color;
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.max, this.color, this.size);
}

class FloatText {
  double x, y, life;
  final double max, size;
  final String text, color;
  FloatText(this.x, this.y, this.text, this.color, this.life, this.max, this.size);
}

class Ring {
  final double x, y, r, maxR, max, width;
  double life;
  final String color;
  Ring(this.x, this.y, this.r, this.maxR, this.life, this.max, this.color, this.width);
}

class Ghost {
  final double x, y, r, max;
  double life;
  final String color;
  Ghost(this.x, this.y, this.r, this.color, this.life, this.max);
}

class Banner {
  final String text, sub, color;
  double life;
  final double max;
  Banner(this.text, this.sub, this.color, this.life, this.max);
}

const int _maxParticles = 1500;
const int _maxTexts = 90;

class Effects {
  final List<Particle> particles = [];
  final List<FloatText> texts = [];
  final List<Ring> rings = [];
  final List<Ghost> ghosts = [];
  final List<Banner> banners = [];
  final List<Banner> toasts = [];
  double shake = 0;
  double hurtFlash = 0;
  double time = 0;

  void burst(double x, double y, String color, num n, [double speed = 160, double size = 3, double life = 0.5]) {
    for (var i = 0; i < n; i++) {
      if (particles.length >= _maxParticles) particles.removeAt(0);
      final a = _r() * math.pi * 2;
      final v = speed * (0.3 + _r() * 0.9);
      final l = life * (0.6 + _r() * 0.6);
      particles.add(Particle(x, y, math.cos(a) * v, math.sin(a) * v, l, l, color, size * (0.6 + _r() * 0.8)));
    }
  }

  void text(double x, double y, String text, String color, [double size = 14, double life = 0.7]) {
    if (texts.length >= _maxTexts) texts.removeAt(0);
    texts.add(FloatText(x + (_r() - 0.5) * 16, y, text, color, life, life, size));
  }

  void ring(double x, double y, double maxR, String color, [double life = 0.4, double width = 4, double r = 0]) {
    rings.add(Ring(x, y, r, maxR, life, life, color, width));
  }

  void ghost(double x, double y, double r, String color) => ghosts.add(Ghost(x, y, r, color, 0.3, 0.3));

  void banner(String text, [String sub = '', String color = '#ffffff', double life = 2.6]) =>
      banners.add(Banner(text, sub, color, life, life));

  void toast(String text, [String sub = '', String color = '#ffd166', double life = 3.5]) {
    toasts.add(Banner(text, sub, color, life, life));
    if (toasts.length > 4) toasts.removeAt(0);
  }

  void addShake(double v) => shake = math.min(24, shake + v);

  void update(double dt) {
    time += dt;
    shake = math.max(0, shake - dt * 40);
    hurtFlash = math.max(0, hurtFlash - dt * 3);
    final drag = math.max(0.0, 1 - dt * 4);
    var j = 0;
    for (final p in particles) {
      p.life -= dt;
      if (p.life <= 0) continue;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= drag;
      p.vy *= drag;
      particles[j++] = p;
    }
    particles.length = j;
    texts.removeWhere((t) {
      t.life -= dt;
      t.y -= 40 * dt;
      return t.life <= 0;
    });
    rings.removeWhere((r) => (r.life -= dt) <= 0);
    ghosts.removeWhere((g) => (g.life -= dt) <= 0);
    banners.removeWhere((b) => (b.life -= dt) <= 0);
    toasts.removeWhere((b) => (b.life -= dt) <= 0);
  }
}
