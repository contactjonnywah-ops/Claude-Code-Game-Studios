// PROTOTYPE - NOT FOR PRODUCTION
/**
 * Synth: compact polyphonic Web Audio synthesizer. No dependencies.
 *
 *   <script src="synth.js"></script>          // classic script, works from file://
 *   const synth = new Synth();                // or new Synth(existingAudioContext)
 *   synth.play('pluck', 'C4', 0.5);           // preset, note, duration (s)
 *   const v = synth.play('pad', 'A3', null);  // held note...
 *   v.stop();                                 // ...released later
 *
 * A patch is a preset name or an object shaped like DEFAULT (missing keys fall back).
 * Add your own: synth.presets.myLead = { osc: [{ type: 'square', unison: 3, spread: 15 }] };
 */
(function (root) {
  'use strict';

  const DEFAULT = {
    osc: [{ type: 'sawtooth' }],      // each: type, octave, detune (cents), gain, unison (count), spread (cents)
    noise: 0,                          // white noise level 0..1
    fm: { ratio: 1, index: 0 },        // modulator at note*ratio Hz, depth note*index Hz
    pitch: { amount: 0, decay: 0.1 },  // start offset in semitones, glides to the note over decay s
    amp: { a: 0.005, d: 0.2, s: 0.7, r: 0.3 },
    filter: { type: 'lowpass', freq: 8000, q: 1, env: 0, a: 0.005, d: 0.3, s: 0, r: 0.3 }, // env: Hz added at peak
    lfo: { rate: 5, depth: 0, target: 'pitch' }, // target pitch|filter (depth in cents) or amp (depth 0..1)
    gain: 0.5, pan: 0, delay: 0, reverb: 0,      // delay/reverb are send levels 0..1
  };

  const PRESETS = {
    supersaw: { osc: [{ type: 'sawtooth', unison: 7, spread: 30 }], amp: { a: 0.01, s: 0.8, r: 0.4 },
      filter: { freq: 2500, env: 4000, d: 0.4, s: 0.3 }, delay: 0.15, reverb: 0.3, gain: 0.35 },
    pad: { osc: [{ type: 'sawtooth', unison: 5, spread: 20 }, { type: 'triangle', octave: -1, gain: 0.6 }],
      amp: { a: 0.8, d: 1, s: 0.8, r: 1.5 }, filter: { freq: 900, q: 2, env: 900, a: 1, d: 2, s: 0.5, r: 1.5 },
      lfo: { rate: 0.3, depth: 700, target: 'filter' }, reverb: 0.6, gain: 0.3 },
    pluck: { osc: [{ type: 'sawtooth' }, { type: 'square', detune: 7, gain: 0.5 }], amp: { d: 0.3, s: 0, r: 0.2 },
      filter: { freq: 300, q: 6, env: 5000, d: 0.15, s: 0 }, delay: 0.3, reverb: 0.2 },
    bass: { osc: [{ type: 'sawtooth', unison: 2, spread: 10 }, { type: 'sine', octave: -1 }],
      amp: { a: 0.003, d: 0.2, s: 0.8, r: 0.1 }, filter: { freq: 200, q: 8, env: 1500, d: 0.2, s: 0.1 }, gain: 0.55 },
    keys: { osc: [{ type: 'triangle' }, { type: 'sine', octave: 1, gain: 0.3 }], amp: { d: 1, s: 0.3, r: 0.5 },
      lfo: { rate: 5, depth: 0.3, target: 'amp' }, reverb: 0.25 },
    bell: { osc: [{ type: 'sine' }], fm: { ratio: 3.5, index: 4 }, amp: { a: 0.001, d: 2, s: 0, r: 2 }, reverb: 0.4, gain: 0.4 },
    kick: { osc: [{ type: 'sine' }], pitch: { amount: 24, decay: 0.08 }, amp: { a: 0.001, d: 0.3, s: 0, r: 0.1 }, gain: 0.9 },
    snare: { osc: [{ type: 'triangle', gain: 0.6 }], noise: 1, pitch: { amount: 12, decay: 0.05 },
      amp: { a: 0.001, d: 0.15, s: 0, r: 0.1 }, filter: { type: 'highpass', freq: 800 }, reverb: 0.15, gain: 0.5 },
    hat: { osc: [], noise: 1, amp: { a: 0.001, d: 0.05, s: 0, r: 0.05 }, filter: { type: 'highpass', freq: 7000 }, gain: 0.3 },
    laser: { osc: [{ type: 'square' }], pitch: { amount: 24, decay: 0.2 }, amp: { a: 0.001, d: 0.2, s: 0, r: 0.05 },
      filter: { freq: 4000 }, delay: 0.25, gain: 0.3 },
  };

  const SEMI = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };

  const merge = (p) => {
    const r = { ...DEFAULT, ...p };
    for (const k of ['fm', 'pitch', 'amp', 'filter', 'lfo']) r[k] = { ...DEFAULT[k], ...p[k] };
    return r;
  };

  // Attack to peak, then decay toward the sustain level.
  const adsr = (param, t, e, base, peak) => {
    param.setValueAtTime(base, t);
    param.linearRampToValueAtTime(peak, t + e.a);
    param.setTargetAtTime(base + (peak - base) * e.s, t + e.a, e.d / 3 + 1e-4);
  };

  class Synth {
    /**
     * @param {BaseAudioContext} [ctx] Audio context to render into; a new AudioContext by default.
     * @param {{maxVoices?: number}} [opts] maxVoices: oldest voice is cut when exceeded.
     */
    constructor(ctx, { maxVoices = 32 } = {}) {
      const c = (this.ctx = ctx || new (root.AudioContext || root.webkitAudioContext)());
      this.maxVoices = maxVoices;
      this.voices = [];
      this.presets = { ...PRESETS };

      this.out = c.createGain(); // master volume
      const limiter = c.createDynamicsCompressor(); // stops unison stacks and chords from clipping
      limiter.threshold.value = -6;
      limiter.ratio.value = 12;
      this.out.connect(limiter).connect(c.destination);

      this.delay = c.createDelay(2);
      this.delay.delayTime.value = 0.3;
      this.delayFeedback = c.createGain();
      this.delayFeedback.gain.value = 0.35;
      this.delay.connect(this.delayFeedback).connect(this.delay);
      this.delay.connect(this.out);

      this.reverb = c.createConvolver();
      this.reverb.buffer = this._impulse(2.5);
      this.reverb.connect(this.out);

      this.noiseBuf = c.createBuffer(1, c.sampleRate * 2, c.sampleRate);
      this.noiseBuf.getChannelData(0).forEach((_, i, d) => (d[i] = Math.random() * 2 - 1));
    }

    /** Master volume, 0..1+. */
    get volume() { return this.out.gain.value; }
    set volume(v) { this.out.gain.value = v; }

    /** Current audio time, for scheduling with play(..., when). */
    get now() { return this.ctx.currentTime; }

    /**
     * Note name ('C4', 'F#3', 'Eb5') or MIDI number to Hz.
     * @param {string|number} note
     * @returns {number}
     */
    static hz(note) {
      if (typeof note === 'number') return 440 * 2 ** ((note - 69) / 12);
      const m = /^([A-Ga-g])([#b]?)(-?\d+)$/.exec(note);
      if (!m) throw new Error(`Bad note: ${note}`);
      const midi = 12 * (+m[3] + 1) + SEMI[m[1].toUpperCase()] + (m[2] === '#') - (m[2] === 'b');
      return Synth.hz(midi);
    }

    /**
     * Play a note.
     * @param {string|object} patch Preset name or patch object.
     * @param {string|number} [note='C4'] Note name or MIDI number.
     * @param {number|null} [dur=0.5] Seconds until release; null holds until voice.stop().
     * @param {number} [when] AudioContext time to start (synth.now + offset); default now.
     * @param {number} [vel=1] Velocity 0..1.
     * @returns {{stop: (at?: number, release?: number) => void}} Voice handle.
     */
    play(patch, note = 'C4', dur = 0.5, when, vel = 1) {
      const c = this.ctx;
      if (c.state === 'suspended' && c.resume) c.resume().catch(() => {}); // browsers start suspended until a user gesture
      const src = typeof patch === 'string' ? this.presets[patch] : patch;
      if (!src) throw new Error(`Unknown patch: ${patch}`);
      const p = merge(src), A = p.amp, F = p.filter;
      const t = Math.max(when ?? 0, c.currentTime), f = Synth.hz(note);
      const srcs = [], carriers = [];

      const filt = c.createBiquadFilter();
      filt.type = F.type;
      filt.Q.value = F.q;
      const trem = c.createGain(), amp = c.createGain(), pan = c.createStereoPanner();
      amp.gain.value = 0;
      pan.pan.value = p.pan;
      filt.connect(trem).connect(amp).connect(pan).connect(this.out);
      for (const [dest, lvl] of [[this.delay, p.delay], [this.reverb, p.reverb]]) {
        if (!lvl) continue;
        const g = c.createGain();
        g.gain.value = lvl;
        pan.connect(g).connect(dest);
      }

      for (const o of p.osc) {
        const n = o.unison || 1, g = c.createGain();
        g.gain.value = (o.gain ?? 1) / Math.sqrt(n);
        g.connect(filt);
        const fo = f * 2 ** (o.octave || 0);
        for (let i = 0; i < n; i++) {
          const s = n > 1 ? (i / (n - 1)) * 2 - 1 : 0; // -1..1 across the unison stack
          const osc = c.createOscillator(), sp = c.createStereoPanner();
          osc.type = o.type || 'sawtooth';
          osc.detune.value = (o.detune || 0) + s * (o.spread || 0);
          if (p.pitch.amount) {
            osc.frequency.setValueAtTime(fo * 2 ** (p.pitch.amount / 12), t);
            osc.frequency.exponentialRampToValueAtTime(fo, t + p.pitch.decay);
          } else osc.frequency.value = fo;
          sp.pan.value = s * 0.8;
          osc.connect(sp).connect(g);
          carriers.push(osc);
          srcs.push([osc, n > 1 ? t + Math.random() * 0.003 : t]); // staggered starts avoid phase-locked unison
        }
      }

      if (p.fm.index) {
        const m = c.createOscillator(), mg = c.createGain();
        m.frequency.value = f * p.fm.ratio;
        mg.gain.value = f * p.fm.index;
        m.connect(mg);
        carriers.forEach((o) => mg.connect(o.frequency));
        srcs.push([m, t]);
      }

      if (p.noise) {
        const s = c.createBufferSource(), g = c.createGain();
        s.buffer = this.noiseBuf;
        s.loop = true;
        g.gain.value = p.noise;
        s.connect(g).connect(filt);
        srcs.push([s, t]);
      }

      if (p.lfo.depth) {
        const l = c.createOscillator(), lg = c.createGain();
        l.frequency.value = p.lfo.rate;
        lg.gain.value = p.lfo.depth;
        l.connect(lg);
        if (p.lfo.target === 'amp') {
          trem.gain.value = 1 - p.lfo.depth / 2;
          lg.gain.value = p.lfo.depth / 2;
          lg.connect(trem.gain);
        } else if (p.lfo.target === 'filter') lg.connect(filt.detune);
        else carriers.forEach((o) => lg.connect(o.detune));
        srcs.push([l, t]);
      }

      if (!srcs.length) throw new Error('Patch has no sound sources (osc or noise)');
      adsr(amp.gain, t, A, 0, p.gain * vel);
      adsr(filt.frequency, t, F, F.freq, F.freq + F.env);
      srcs.forEach(([s, at]) => s.start(at));

      let stopped = false;
      const voice = {
        stop: (at = c.currentTime, release = A.r) => {
          if (stopped) return;
          stopped = true;
          // shortcut: release waits for the attack peak, so notes shorter than the attack still reach it.
          const r = Math.max(at, t + A.a);
          amp.gain.setTargetAtTime(0, r, release / 3 + 1e-4);
          filt.frequency.setTargetAtTime(F.freq, r, F.r / 3 + 1e-4);
          srcs.forEach(([s]) => s.stop(r + release * 2 + 0.05));
        },
      };
      srcs[0][0].onended = () => {
        pan.disconnect();
        const i = this.voices.indexOf(voice);
        if (i >= 0) this.voices.splice(i, 1);
      };

      this.voices.push(voice);
      if (this.voices.length > this.maxVoices) this.voices.shift().stop(c.currentTime, 0.02);
      if (dur != null) voice.stop(t + dur);
      return voice;
    }

    /** Release every playing voice. */
    stopAll() { this.voices.forEach((v) => v.stop()); }

    // Decaying stereo noise: cheap algorithmic reverb impulse.
    _impulse(sec) {
      const c = this.ctx, n = (c.sampleRate * sec) | 0, b = c.createBuffer(2, n, c.sampleRate);
      for (let ch = 0; ch < 2; ch++) {
        const d = b.getChannelData(ch);
        for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n) ** 3;
      }
      return b;
    }
  }

  root.Synth = Synth;
  if (typeof module === 'object' && module.exports) module.exports = Synth;
})(globalThis);
