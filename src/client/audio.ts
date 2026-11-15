// Tiny procedural sound effects with WebAudio. No audio files needed.

const MIN_GAP: Record<string, number> = { coin: 0.06, hit: 0.035, kill: 0.04, gem: 0.03, swing: 0.06, bolt: 0.06, arrow: 0.05, zap: 0.08, frost: 0.1, hurt: 0.15 };

export class Sound {
  private ctx: AudioContext | null = null;
  private master: GainNode | null = null;
  private noiseBuf: AudioBuffer | null = null;
  private last: Record<string, number> = {};
  private gemPitch = 0;
  muted = false;

  unlock(): void {
    if (!this.ctx) {
      this.ctx = new AudioContext();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.22;
      this.master.connect(this.ctx.destination);
      const len = this.ctx.sampleRate * 0.5;
      this.noiseBuf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
      const d = this.noiseBuf.getChannelData(0);
      for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    }
    if (this.ctx.state === 'suspended') void this.ctx.resume();
  }

  toggleMute(): void {
    this.muted = !this.muted;
    if (this.master) this.master.gain.value = this.muted ? 0 : 0.22;
  }

  private tone(freq: number, dur: number, type: OscillatorType, vol: number, slideTo = 0, delay = 0): void {
    const c = this.ctx!, t = c.currentTime + delay;
    const o = c.createOscillator(), g = c.createGain();
    o.type = type;
    o.frequency.setValueAtTime(freq, t);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(g).connect(this.master!);
    o.start(t);
    o.stop(t + dur + 0.02);
  }

  private noise(dur: number, vol: number, freq: number, type: BiquadFilterType = 'lowpass', delay = 0): void {
    const c = this.ctx!, t = c.currentTime + delay;
    const src = c.createBufferSource();
    src.buffer = this.noiseBuf;
    const f = c.createBiquadFilter();
    f.type = type;
    f.frequency.value = freq;
    const g = c.createGain();
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    src.connect(f).connect(g).connect(this.master!);
    src.start(t);
    src.stop(t + dur + 0.02);
  }

  play(name: string): void {
    if (!this.ctx || this.muted) return;
    const now = this.ctx.currentTime;
    if (now - (this.last[name] ?? -1) < (MIN_GAP[name] ?? 0.02)) return;
    this.last[name] = now;
    switch (name) {
      case 'hit': this.noise(0.05, 0.15, 2500, 'bandpass'); break;
      case 'kill': this.tone(260 + Math.random() * 80, 0.08, 'triangle', 0.12, 90); break;
      case 'gem':
        this.gemPitch = now - (this.last.gemChain ?? 0) < 0.3 ? Math.min(this.gemPitch + 1, 12) : 0;
        this.last.gemChain = now;
        this.tone(880 * Math.pow(2, this.gemPitch / 24), 0.06, 'sine', 0.08);
        break;
      case 'swing': this.noise(0.12, 0.18, 1800, 'highpass'); break;
      case 'bolt': this.tone(500, 0.12, 'sine', 0.1, 1100); break;
      case 'arrow': this.tone(900, 0.05, 'square', 0.04, 500); break;
      case 'zap': this.noise(0.15, 0.2, 4000, 'highpass'); this.tone(1400, 0.1, 'sawtooth', 0.04, 300); break;
      case 'nova': this.noise(0.4, 0.25, 600); this.tone(160, 0.35, 'sawtooth', 0.08, 60); break;
      case 'frost': this.tone(1600, 0.2, 'triangle', 0.06, 2400); break;
      case 'deploy': this.tone(400, 0.06, 'square', 0.06); this.tone(700, 0.08, 'square', 0.06, 0, 0.07); break;
      case 'hurt': this.tone(140, 0.2, 'square', 0.18, 60); this.noise(0.1, 0.2, 800); break;
      case 'death': this.tone(300, 1.2, 'sawtooth', 0.2, 40); break;
      case 'levelup': [523, 659, 784, 1047].forEach((f, i) => this.tone(f, 0.18, 'triangle', 0.12, 0, i * 0.07)); break;
      case 'select': this.tone(660, 0.08, 'triangle', 0.1, 990); break;
      case 'chest': [392, 523, 659, 784, 1047, 1319].forEach((f, i) => this.tone(f, 0.25, 'triangle', 0.1, 0, i * 0.06)); break;
      case 'pickup': this.tone(700, 0.12, 'triangle', 0.12, 1400); break;
      case 'coin': this.tone(1568, 0.07, 'square', 0.04); this.tone(2093, 0.12, 'square', 0.04, 0, 0.06); break;
      case 'explode': this.noise(0.5, 0.35, 400); this.tone(90, 0.4, 'sine', 0.25, 30); break;
      case 'warn': this.tone(880, 0.12, 'square', 0.08); this.tone(660, 0.16, 'square', 0.08, 0, 0.14); break;
      case 'dash': this.noise(0.18, 0.18, 2200, 'bandpass'); this.tone(500, 0.15, 'sine', 0.05, 220); break;
      case 'ability': this.noise(0.25, 0.2, 1200, 'bandpass'); this.tone(300, 0.25, 'sine', 0.12, 900); break;
      case 'wave': this.tone(440, 0.15, 'triangle', 0.1); this.tone(660, 0.25, 'triangle', 0.1, 0, 0.12); break;
      case 'boss': this.tone(70, 1.4, 'sawtooth', 0.22, 50); this.tone(105, 1.4, 'sawtooth', 0.12, 70); break;
      case 'victory': [523, 659, 784, 1047, 784, 1047].forEach((f, i) => this.tone(f, 0.22, 'square', 0.06, 0, i * 0.1)); break;
    }
  }
}
