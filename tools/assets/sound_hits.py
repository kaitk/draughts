#!/usr/bin/env python3
"""Builds the move's and the take's recorded hits into assets/sounds/hits.bin (task 089).

Cuts single hits from the full-quality recordings in design/sounds/ (local, out of git;
docs/decisions/sound.md says where they come from), keeps the ones chosen by ear (KEEP),
brings each down to 24 kHz mono with a windowed-sinc low-pass, and encodes it as IMA
ADPCM, 4 bits a sample, each hit a stream from predictor 0 and step index 0. The app
embeds the file (src/sound/hits.goose) and decodes it once into the mixer's floats.

hits.bin, all little-endian: the counts of move hits and of take hits (u16 each), then
each hit, the moves first: its samples (u32), and its codes, two a byte, the first in
the low nibble.

It also writes test/expected/sound/adpcm.out, what test/sound/adpcm.goose must print
from decoding the embedded file: each hit's samples and a checksum of its decoded 16-bit
values, so the app's decoder is checked against this encoder's own. Needs ffmpeg.

    python3 tools/assets/sound_hits.py
"""
import math, os, struct, subprocess, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
SOURCES = os.path.join(ROOT, 'design', 'sounds')
OUT = os.path.join(ROOT, 'assets', 'sounds', 'hits.bin')
EXPECTED = os.path.join(ROOT, 'test', 'expected', 'sound', 'adpcm.out')

RATE = 48000                # the recordings' rate, where the hits are cut
DOWN = 2                    # to 24 kHz
MOST = 12                   # hits cut from a recording at most
# The recordings: MattyCauldron's "Chess Pieces" (Freesound 765866, CC0) for a move, and
# JJTaynos's "Chess Pieces Move (Close)" (733927, CC0) for the taken pieces.
RECORDINGS = [(765866, 'move'), (733927, 'take')]
# The hits kept, as the comparison page numbered them (m: the move's, t: the take's, from
# 1 in the order they come in the recording), chosen by ear on 2026-11-16: the move's
# more muted hits, and the take's four that sound least like a move.
KEEP = {'move': [1, 2, 3, 9, 10, 11], 'take': [2, 4, 5, 6]}


def read(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-'],
                         check=True, capture_output=True).stdout
    return list(struct.unpack(f'<{len(raw) // 4}f', raw))


def hits(x, take, most):
    """Single hits: where 5 ms frames rise well over the quiet, kept to those quiet before,
    faded in over 2 ms and out over at most 25 ms, each matched in loudness (the first
    80 ms to one RMS, the peak under 0.98), in the order they come."""
    F = RATE // 200
    rms = [math.sqrt(sum(v * v for v in x[i:i + F]) / F) for i in range(0, len(x) - F, F)]
    floor = sorted(rms)[len(rms) // 5] + 1e-5
    top = max(rms)
    found, i = [], 1
    gap = 40 if take else 24    # frames: 200 ms for a slide, 120 for a knock
    while i < len(rms):
        if rms[i] > max(floor * 6, top * 0.08) and rms[i] > 3 * rms[i - 1]:
            before = max(rms[max(0, i - 16):i - 1] or [0])
            quiet = before / rms[i]
            end = i + 1
            limit = i + (90 if take else 70)   # 450 or 350 ms at most
            while end < min(len(rms), limit) and not (rms[end] < max(floor * 2, rms[i] * 0.02)):
                end += 1
            found.append((quiet, i, end))
            i = end + gap // 4
        else:
            i += 1
    found.sort()
    out = []
    for quiet, s, e in found:
        if quiet > 0.35 or len(out) >= most:
            continue
        a, b = max(0, s * F - RATE // 400), min(len(x), (e + 4) * F)
        h = x[a:b]
        n = len(h)
        fi, fo = RATE // 500, min(n // 3, RATE // 40)
        h = [v * min(1, k / fi) * min(1, (n - k) / fo) for k, v in enumerate(h)]
        head = h[:RATE * 80 // 1000]
        r = math.sqrt(sum(v * v for v in head) / len(head)) + 1e-9
        g = min(0.12 / r, 0.98 / (max(abs(v) for v in h) + 1e-9))
        out.append((s, [v * g for v in h]))
    out.sort()
    return [h for _, h in out]


def down(x, k):
    """Every k-th sample after a Blackman-windowed sinc low-pass just under the new
    Nyquist (64k + 1 taps), as the comparison page made them."""
    taps = 64 * k + 1
    half = (taps - 1) // 2
    fc = 0.45 / k
    h = []
    for i in range(taps):
        n = i - half
        w = 0.42 - 0.5 * math.cos(2 * math.pi * i / (taps - 1)) + 0.08 * math.cos(4 * math.pi * i / (taps - 1))
        h.append(w * (2 * fc if n == 0 else math.sin(2 * math.pi * fc * n) / (math.pi * n)))
    total = sum(h)
    out = []
    for o in range((len(x) + k - 1) // k):
        c, v = o * k, 0.0
        for i in range(taps):
            j = c + i - half
            if 0 <= j < len(x):
                v += x[j] * h[i]
        out.append(v / total)
    return out


STEPS = [7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107,
         118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963,
         1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894,
         6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794,
         32767]
INDEX = [-1, -1, -1, -1, 2, 4, 6, 8]


def step(state, code):
    """The decoder's step, which the encoder runs too: the predictor and step index after
    `code`."""
    p, i = state
    st = STEPS[i]
    d = st >> 3
    if code & 4: d += st
    if code & 2: d += st >> 1
    if code & 1: d += st >> 2
    p = max(-32768, min(32767, p - d if code & 8 else p + d))
    i = max(0, min(88, i + INDEX[code & 7]))
    return p, i


def encode(q):
    """IMA ADPCM codes for 16-bit samples q, from predictor 0 and step index 0."""
    codes, s = [], (0, 0)
    for v in q:
        st = STEPS[s[1]]
        diff, code = v - s[0], 0
        if diff < 0:
            code, diff = 8, -diff
        if diff >= st:
            code |= 4
            diff -= st
        if diff >= st >> 1:
            code |= 2
            diff -= st >> 1
        if diff >= st >> 2:
            code |= 1
        s = step(s, code)
        codes.append(code)
    return codes


def decode(codes):
    out, s = [], (0, 0)
    for c in codes:
        s = step(s, c)
        out.append(s[0])
    return out


def checksum(q):
    """FNV-1a over the decoded samples' 16-bit two's-complement bytes, low first."""
    h = 0xcbf29ce484222325
    for v in q:
        for b in struct.pack('<h', v):
            h = ((h ^ b) * 0x100000001b3) & 0xffffffffffffffff
    return h


def main():
    kept = {}
    for sid, kind in RECORDINGS:
        path = os.path.join(SOURCES, f'{sid}.wav')
        if not os.path.exists(path):
            sys.exit(f'{path} is missing: docs/decisions/sound.md says where to download it')
        cut = hits(read(path), kind == 'take', MOST)
        print(f'{sid}: {len(cut)} hits cut', file=sys.stderr)
        kept[kind] = [cut[k - 1] for k in KEEP[kind]]
    blob = bytearray(struct.pack('<HH', len(kept['move']), len(kept['take'])))
    lines = []
    for kind in ['move', 'take']:
        for k, h in zip(KEEP[kind], kept[kind]):
            q = [max(-32768, min(32767, round(v * 32767))) for v in down(h, DOWN)]
            codes = encode(q)
            if len(codes) % 2:
                codes.append(0)
            blob += struct.pack('<I', len(q))
            blob += bytes(codes[j] | codes[j + 1] << 4 for j in range(0, len(codes), 2))
            d = decode(codes[:len(q)])
            lines.append(f'{kind[0]}{k}: {len(q)} samples, {len(codes) // 2} bytes, checksum {checksum(d):016x}')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'wb') as f:
        f.write(blob)
    os.makedirs(os.path.dirname(EXPECTED), exist_ok=True)
    with open(EXPECTED, 'w') as f:
        f.write('\n'.join(lines) + f'\n{len(blob)} bytes\n')
    print(f'{OUT}: {len(blob)} bytes', file=sys.stderr)


if __name__ == '__main__':
    main()
