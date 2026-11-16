// The prototypes' sound synthesis, shared by sound.html and sound-set.html (task 089):
// plain sample math into Float32Arrays at RATE, as the app would make them at startup
// for Goose's audio module (audio::create_sound), and the Freesound hits that
// tools/sound_samples.py writes to samples/samples.js. Plain script, no build step: its
// names are the pages' globals.
'use strict';

// Each is made once into a Float32Array at RATE, as the app would at startup into the
// mixer (audio::create_sound). Nothing here uses Web Audio's nodes but a buffer, a
// source, and a gain, so what is heard is what the Goose code would make.
const RATE = 48000;
function rng(seed) { let s = seed >>> 0 || 1; return () => { s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 2147483648 - 1; }; }
// A one-pole low-pass, in place: no ringing, so no edge.
function lowpass(x, hz) { const a = 1 - Math.exp(-2 * Math.PI * hz / RATE); let y = 0; for (let i = 0; i < x.length; i++) { y += a * (x[i] - y); x[i] = y; } }
function normalize(x, peak) { let m = 0; for (const v of x) m = Math.max(m, Math.abs(v)); if (m > 0) for (let i = 0; i < x.length; i++) x[i] *= peak / m; return x; }
// A knock: a piece set down, as modal synthesis makes one. The piece rings in a few
// inharmonic modes [Hz, gain, decay s], each a little detuned per take (seed); a
// 1.5 ms breath of noise is the contact; the board under it gives a short low thump
// [Hz, gain, decay s]; a 0.6 ms rise keeps the start from clicking, and a gentle
// low-pass keeps it muted. No pitch glide: that is what made a punch of it.
function knock(o, seed = 1, pitch = 1) {
  const x = new Float32Array(Math.round(0.25 * RATE)), r = rng(seed);
  const modes = o.modes.map(([hz, gain, decay]) => [hz * pitch * (1 + 0.04 * r()), gain * (1 + 0.15 * r()), decay]);
  const ph = modes.map(() => r() * Math.PI);
  let n = 0;
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE, rise = Math.min(1, t / 0.0006);
    let v = 0;
    modes.forEach(([hz, gain, decay], k) => { v += gain * Math.sin(ph[k] + 2 * Math.PI * hz * t) * Math.exp(-t / decay); });
    const [bh, bg, bd] = o.thump;
    v += bg * Math.sin(2 * Math.PI * bh * t) * Math.exp(-t / bd) * Math.min(1, t / 0.002);
    n += 0.5 * (r() - n);
    x[i] = rise * (v + o.noise * n * Math.exp(-t / 0.0015));
  }
  lowpass(x, o.lp);
  return normalize(x, 0.9);
}
// A mallet's note, soft: the fundamental, a quiet partial near 4 (as a marimba's bar),
// a slow 12 ms rise, and a long low-passed decay.
function note(f, decay = 0.55, gain = 1) {
  const x = new Float32Array(Math.round(decay * 6 * RATE));
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE, rise = Math.min(1, t / 0.012);
    x[i] = gain * rise * (Math.sin(2 * Math.PI * f * t) * Math.exp(-t / decay)
      + 0.08 * Math.sin(2 * Math.PI * f * 3.93 * t) * Math.exp(-t / (decay * 0.15))
      + 0.05 * Math.sin(2 * Math.PI * f * 2 * t) * Math.exp(-t / (decay * 0.5)));
  }
  lowpass(x, 1800);
  return x;
}
// Notes laid one after another (seconds apart) into one buffer.
function phrase(parts) {
  const len = Math.max(...parts.map(([at, b]) => Math.round(at * RATE) + b.length));
  const x = new Float32Array(len);
  for (const [at, b] of parts) { const o = Math.round(at * RATE); for (let i = 0; i < b.length; i++) x[o + i] += b[i]; }
  return x;
}
// The board's material under the piece: a cloth-covered board, bare wood, and stone.
const TIMBRES = {
  felt: { modes: [[520, 1, 0.016], [1240, 0.4, 0.009], [2100, 0.15, 0.005]], thump: [130, 0.7, 0.014], noise: 0.4, lp: 2000 },
  wood: { modes: [[680, 1, 0.032], [1630, 0.5, 0.02], [2750, 0.25, 0.011], [3900, 0.1, 0.007]], thump: [170, 0.5, 0.018], noise: 0.5, lp: 3400 },
  stone: { modes: [[1150, 1, 0.028], [2600, 0.45, 0.018], [4300, 0.2, 0.01]], thump: [200, 0.3, 0.012], noise: 0.45, lp: 4200 },
};
const HZ = { D3: 146.8, A3: 220, D4: 293.7, E4: 329.6, 'F#4': 370, G4: 392, A4: 440, B4: 493.9, D5: 587.3, E5: 659.3, 'F#5': 740,
  G5: 784, A5: 880, B5: 987.8, D6: 1174.7, E6: 1318.5, 'F#6': 1480, A6: 1760 };

// Wooden and wind instruments in a few lines of sample math each, all on D major's
// pentatonic scale (D E F# A B), so any of them sits with any other.
// A wooden flute: a few harmonics, a 60 ms breath in, vibrato after 150 ms, a dark
// breath of noise, an optional slur up from a lower note (glide), and a soft release.
function flute(f, dur, o = {}) {
  const { h = [1, 0.22, 0.07, 0.03], att = 0.06, breath = 0.35, vib = 0.004, from = 0, seed = 3 } = o;
  const x = new Float32Array(Math.round((dur + 0.3) * RATE)), r = rng(seed);
  let ph = 0, n = 0;
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE, a = Math.min(1, t / att) * (t < dur ? 1 : Math.exp(-(t - dur) / 0.07));
    const base = from ? from * Math.pow(f / from, Math.min(1, t / 0.12)) : f;
    ph += 2 * Math.PI * base * (1 + vib * Math.min(1, Math.max(0, (t - 0.15) / 0.2)) * Math.sin(2 * Math.PI * 5 * t)) / RATE;
    let v = 0; h.forEach((g, k) => { v += g * Math.sin((k + 1) * ph); });
    n += 0.15 * (r() - n);
    x[i] = a * (v + breath * n * (0.5 + Math.exp(-t / 0.05)));
  }
  lowpass(x, f * 5);
  return x;
}
// A plucked string (Karplus-Strong), as an Estonian kannel or a Finnish kantele: a
// soft noise burst round a delay line one period long, averaged and damped each pass.
function pluck(f, dur = 1.6, seed = 5, soft = 0.45, damp = 0.9965, lp = 2600) {
  const x = new Float32Array(Math.round(dur * RATE)), L = Math.round(RATE / f), line = new Float32Array(L), r = rng(seed);
  let y = 0; for (let k = 0; k < L; k++) { y += soft * (r() - y); line[k] = y; }
  for (let i = 0, j = 0; i < x.length; i++, j = (j + 1) % L) {
    const a = line[j], b = line[(j + 1) % L];
    line[j] = 0.5 * (a + b) * damp;
    x[i] = a * Math.min(1, i / (RATE * 0.002));
  }
  lowpass(x, lp);
  return x;
}
// Decaying partials [ratio, gain, decay s], for the struck instruments.
function struck(f, parts, rise = 0.002, lp = 3000, len = 1.4) {
  const x = new Float32Array(Math.round(len * RATE));
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE; let v = 0;
    for (const [ratio, g, d] of parts) v += g * Math.sin(2 * Math.PI * f * ratio * t) * Math.exp(-t / d);
    x[i] = v * Math.min(1, t / rise);
  }
  lowpass(x, lp);
  return x;
}
const kalimba = (f) => struck(f, [[1, 1, 0.7], [5.9, 0.18, 0.06], [2.0, 0.05, 0.2]], 0.0015, 3500);
const tongue = (f) => struck(f, [[1, 1, 0.6], [2.76, 0.16, 0.12], [4.1, 0.05, 0.05]], 0.003, 1600);   // a wooden tongue drum
const musicbox = (f) => struck(f, [[1, 1, 0.5], [3, 0.25, 0.1], [5.4, 0.1, 0.04]], 0.001, 5000, 1.0);
const block = (f) => struck(f, [[1, 1, 0.07], [2.48, 0.3, 0.03], [4.1, 0.08, 0.015]], 0.0008, 3200, 0.4); // a temple block
// Bamboo chimes stirred once: a few tubes struck at random within 0.8 s, dying away.
function bamboo(seed = 9) {
  const r = rng(seed), tubes = [HZ.D5, HZ.E5, HZ['F#5'], HZ.A5, HZ.B5, HZ.D6], parts = [];
  for (let k = 0; k < 9; k++) {
    const f = tubes[Math.floor((r() + 1) / 2 * tubes.length) % tubes.length];
    parts.push([0.05 + k * 0.07 + 0.04 * r(), struck(f * 0.5, [[1, 1, 0.12], [2.76, 0.5, 0.05], [5.4, 0.2, 0.02]], 0.001, 3000, 0.6).map((v) => v * (1 - k / 11))]);
  }
  return phrase(parts);
}
// A blackbird's two phrases: whistled sweeps, quick and quiet.
function bird() {
  const x = new Float32Array(Math.round(0.9 * RATE));
  const notes = [[0, 2000, 2600, 0.09], [0.12, 2600, 2200, 0.08], [0.32, 1900, 2900, 0.12], [0.5, 2900, 2500, 0.06], [0.58, 2500, 3100, 0.07]];
  for (const [at, f0, f1, d] of notes) {
    let ph = 0; const o = Math.round(at * RATE);
    for (let i = 0; i < d * RATE; i++) {
      const t = i / RATE, u = t / d, f = f0 + (f1 - f0) * u;
      ph += 2 * Math.PI * f / RATE;
      x[o + i] += Math.sin(ph) * Math.sin(Math.PI * u) * (1 + 0.3 * Math.sin(2 * Math.PI * 40 * t));
    }
  }
  lowpass(x, 5000);
  return x;
}
// Loudness matched: each moment's first 0.6 s to one RMS, the peak under 0.95.
function even(x) {
  const n = Math.min(x.length, Math.round(0.6 * RATE)); let e = 0, m = 0;
  for (let i = 0; i < n; i++) e += x[i] * x[i];
  for (const v of x) m = Math.max(m, Math.abs(v));
  const g = Math.min(0.3 / Math.sqrt(e / n + 1e-12), 0.95 / (m + 1e-9));
  return x.map((v) => v * g);
}
const at = (dt, list) => phrase(list.map((b, k) => [k * dt, b]));

// A sample from prototypes/samples/samples.js (tools/sound_samples.py): &move=ID.K and
// &take=ID.K put hit K of Freesound sound ID in place of the knock or the take.
const SAMPLES = window.SAMPLES || null;
function sampleHit(ref) {
  if (!SAMPLES || !ref) return null;
  const [id, k] = ref.split('.').map(Number), src = SAMPLES.list.find((x) => x.id === id);
  if (!src || !src.hits[k]) return null;
  const bytes = Uint8Array.from(atob(src.hits[k]), (c) => c.charCodeAt(0)), pcm = new Int16Array(bytes.buffer);
  return { x: Float32Array.from(pcm, (v) => v / 32768), rate: SAMPLES.rate };
}
// A ref of ID.K is that hit; a bare ID is every hit of that recording, one picked at
// random each time it plays.
function sampleHits(ref) {
  if (!SAMPLES || !ref) return [];
  if (ref.includes('.')) { const h = sampleHit(ref); return h ? [h] : []; }
  const src = SAMPLES.list.find((x) => String(x.id) === ref);
  return src ? src.hits.map((_, k) => sampleHit(`${ref}.${k}`)) : [];
}

// ---- A small calm orchestra, for the moments (sound-set.html) ---------------------
// In the spirit of an old fantasy strategy game's score (harp, lute, soft horns,
// celesta, strings), never its tunes: every phrase here is our own, on D's pentatonic.
const harp = (f, dur = 2.4, seed = 101) => pluck(f, dur, seed, 0.75, 0.998, 3200);
const lute = (f, dur = 1.4, seed = 111) => pluck(f, dur, seed, 0.95, 0.994, 3800);
const pizz = (f, seed = 121) => pluck(f, 0.7, seed, 0.6, 0.985, 2400);
const celesta = (f) => struck(f, [[1, 1, 0.9], [4, 0.12, 0.12], [2, 0.05, 0.3]], 0.001, 6000, 1.6);
const bell = (f) => struck(f, [[1, 1, 1.4], [2.76, 0.3, 0.5], [5.4, 0.12, 0.2], [8.9, 0.04, 0.1]], 0.002, 4500, 2.4);
// A soft horn: harmonics falling as 1/k, brighter as the breath grows (a low-pass that
// opens over the attack), a slow 90 ms rise, a little vibrato, and a soft release.
function horn(f, dur, o = {}) {
  const { att = 0.09, vib = 0.003 } = o;
  const x = new Float32Array(Math.round((dur + 0.35) * RATE));
  let ph = 0, y = 0;
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE, a = Math.min(1, t / att) * (t < dur ? 1 : Math.exp(-(t - dur) / 0.1));
    ph += 2 * Math.PI * f * (1 + vib * Math.sin(2 * Math.PI * 4.5 * t) * Math.min(1, t / 0.3)) / RATE;
    let v = 0; for (let k = 1; k <= 8; k++) v += Math.sin(k * ph) / k;
    const open = f * (1.5 + 2.5 * Math.min(1, t / (att * 2)));
    y += (1 - Math.exp(-2 * Math.PI * open / RATE)) * (v - y);
    x[i] = a * y;
  }
  return x;
}
// Strings held: three detuned sawtooth voices a note, low-passed, swelling in and out.
function pad(fs, dur, att = 0.35) {
  const x = new Float32Array(Math.round((dur + 0.6) * RATE)), ph = fs.flatMap(() => [0, 0.3, 0.6]);
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE, a = Math.min(1, t / att) * (t < dur ? 1 : Math.exp(-(t - dur) / 0.25));
    let v = 0;
    fs.forEach((f, n) => [0.997, 1, 1.003].forEach((d, k) => {
      const j = n * 3 + k; ph[j] = (ph[j] + f * d / RATE) % 1; v += 2 * ph[j] - 1;
    }));
    x[i] = a * v;
  }
  lowpass(x, 1400); lowpass(x, 1800);
  return x;
}
// Notes over one another: [seconds, buffer, gain].
function mix(parts) { return phrase(parts.map(([t, b, g = 1]) => [t, g === 1 ? b : b.map((v) => v * g)])); }
