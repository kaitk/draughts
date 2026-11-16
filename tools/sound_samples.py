#!/usr/bin/env python3
"""Fetches candidate piece sounds from Freesound for prototypes/sound.html (task 089).

Downloads each candidate's public preview (a low-quality MP3, no login needed), cuts it
into single hits where a sound starts out of quiet, and writes them all to
prototypes/samples/samples.js (local, out of git) as 16-bit PCM in base64, so the
prototype plays them from file:// with no server. The previews are good enough to choose
by; the one chosen is then downloaded in full quality from its page (a free account),
and credited if its license asks for it. Needs ffmpeg.

    python3 tools/sound_samples.py
"""
import base64, json, math, os, struct, subprocess, sys, urllib.request

RATE = 24000
OUT = os.path.join(os.path.dirname(__file__), '..', 'prototypes', 'samples')

# (id, license, uploader, title, preview, kind): zero is CC0, by is CC BY (credit needed).
# kind: move (a piece set down), take (a piece slid or lifted off), go (go stones).
CANDIDATES = [
    (701279, 'zero', '5ro4', 'wooden crokinole disc piece placed on board', 'https://cdn.freesound.org/previews/701/701279_1629501-lq.mp3', 'move'),
    (551921, 'zero', 'Joao_Janz', 'Tiny_Soft_Lay_Down_Wood_Table_12', 'https://cdn.freesound.org/previews/551/551921_9961300-lq.mp3', 'move'),
    (546119, 'zero', 'el_boss', 'Piece Placement', 'https://cdn.freesound.org/previews/546/546119_9129912-lq.mp3', 'move'),
    (546121, 'zero', 'el_boss', 'Board Start', 'https://cdn.freesound.org/previews/546/546121_9129912-lq.mp3', 'move'),
    (560698, 'zero', 'el_boss', 'Puzzle piece placed on board', 'https://cdn.freesound.org/previews/560/560698_9129912-lq.mp3', 'move'),
    (351518, 'zero', 'mh2o', 'chess_move_on_alabaster', 'https://cdn.freesound.org/previews/351/351518_4502687-lq.mp3', 'move'),
    (646781, 'zero', 'pbimal', 'chess-piece-bounce', 'https://cdn.freesound.org/previews/646/646781_11830391-lq.mp3', 'move'),
    (817568, 'zero', 'SilverDubloons', 'scrabblePieceOnWood', 'https://cdn.freesound.org/previews/817/817568_15868577-lq.mp3', 'move'),
    (743678, 'zero', 'DasWaff', 'Soft impact', 'https://cdn.freesound.org/previews/743/743678_2617407-lq.mp3', 'move'),
    (801349, 'zero', 'Alnotreally', 'Chess piece setting 1', 'https://cdn.freesound.org/previews/801/801349_17217022-lq.mp3', 'move'),
    (467282, 'zero', 'XfiXy8', 'Chess Pieces hitting wooden board', 'https://cdn.freesound.org/previews/467/467282_9895957-lq.mp3', 'move'),
    (765866, 'zero', 'MattyCauldron', 'Chess Pieces', 'https://cdn.freesound.org/previews/765/765866_15688680-lq.mp3', 'move'),
    (733927, 'zero', 'JJTaynos', 'Chess Pieces Move (Close)', 'https://cdn.freesound.org/previews/733/733927_15803939-lq.mp3', 'move'),
    (755250, 'zero', 'IENBA', 'Chess Pieces Drop', 'https://cdn.freesound.org/previews/755/755250_9616576-lq.mp3', 'move'),
    (849792, 'zero', 'IENBA', 'Small Chess Set', 'https://cdn.freesound.org/previews/849/849792_9616576-lq.mp3', 'move'),
    (555190, 'zero', 'taure', 'Board Game Pieces', 'https://cdn.freesound.org/previews/555/555190_2940947-lq.mp3', 'move'),
    (569788, 'zero', 'taure', 'Board game taps and clatter', 'https://cdn.freesound.org/previews/569/569788_2940947-lq.mp3', 'move'),
    (629181, 'zero', 'Amatsuuu', 'Chess_foley', 'https://cdn.freesound.org/previews/629/629181_13772767-lq.mp3', 'move'),
    (629182, 'zero', 'Amatsuuu', 'Chess_foley_1', 'https://cdn.freesound.org/previews/629/629182_13772767-lq.mp3', 'move'),
    (366065, 'zero', 'simone_ds', 'chess pieces', 'https://cdn.freesound.org/previews/366/366065_6040409-lq.mp3', 'move'),
    (556387, 'zero', 'zachrau', 'Moving piece on a boardgame', 'https://cdn.freesound.org/previews/556/556387_676927-lq.mp3', 'move'),
    (371352, 'zero', 'Iamgiorgio', 'D9_pawn', 'https://cdn.freesound.org/previews/371/371352_5302340-lq.mp3', 'move'),
    (245907, 'by', 'Ediecz', 'lay_down_object_01', 'https://cdn.freesound.org/previews/245/245907_3134068-lq.mp3', 'move'),
    (245914, 'by', 'Ediecz', 'lay_down_object_02', 'https://cdn.freesound.org/previews/245/245914_3134068-lq.mp3', 'move'),
    (245915, 'by', 'Ediecz', 'lay_down_object_07', 'https://cdn.freesound.org/previews/245/245915_3134068-lq.mp3', 'move'),
    (553410, 'by', 'PeteBarry', 'FX_Board_Game_Pawn01', 'https://cdn.freesound.org/previews/553/553410_5696249-lq.mp3', 'move'),
    (271390, 'by', 'discokingmusic', 'Tiny Counter', 'https://cdn.freesound.org/previews/271/271390_984701-lq.mp3', 'move'),
    (792572, 'by', 'Imrius', 'Chess piece', 'https://cdn.freesound.org/previews/792/792572_17002999-lq.mp3', 'move'),
    (588317, 'zero', 'billhails2', 'GoStoneSounds', 'https://cdn.freesound.org/previews/588/588317_12616419-lq.mp3', 'go'),
    (840425, 'zero', 'Hongsungbock', 'baduk2', 'https://cdn.freesound.org/previews/840/840425_9442533-lq.mp3', 'go'),
    (668942, 'zero', 'MPooman', 'Play Go Sounds 2', 'https://cdn.freesound.org/previews/668/668942_14220990-lq.mp3', 'go'),
    (801350, 'zero', 'Alnotreally', 'Chess piece sliding 2', 'https://cdn.freesound.org/previews/801/801350_17217022-lq.mp3', 'take'),
    (396705, 'zero', 'ChaosEntertainment', 'dragslide1', 'https://cdn.freesound.org/previews/396/396705_7546121-lq.mp3', 'take'),
    (329100, 'zero', 'Macif', 'Domino pieces 2', 'https://cdn.freesound.org/previews/329/329100_3035766-lq.mp3', 'take'),
]
MAX_HITS = 6


def decode(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-'],
                         check=True, capture_output=True).stdout
    return list(struct.unpack(f'<{len(raw) // 4}f', raw))


def hits(x, take):
    """Single hits: where 5 ms frames rise well over the quiet, kept to those quiet before."""
    F = RATE // 200
    rms = [math.sqrt(sum(v * v for v in x[i:i + F]) / F) for i in range(0, len(x) - F, F)]
    if not rms:
        return []
    floor = sorted(rms)[len(rms) // 5] + 1e-5
    top = max(rms)
    found, i = [], 1
    gap = 40 if take else 24   # frames: 200 ms for a slide, 120 for a knock
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
        if quiet > 0.35 or len(out) >= MAX_HITS:
            continue
        a, b = max(0, s * F - RATE // 400), min(len(x), (e + 4) * F)
        h = x[a:b]
        n = len(h)
        fi, fo = RATE // 500, min(n // 3, RATE // 40)
        h = [v * min(1, k / fi) * min(1, (n - k) / fo) for k, v in enumerate(h)]
        # Matched loudness: the first 80 ms's RMS to one level, the peak kept under 0.98.
        head = h[:RATE * 80 // 1000]
        r = math.sqrt(sum(v * v for v in head) / len(head)) + 1e-9
        g = min(0.12 / r, 0.98 / (max(abs(v) for v in h) + 1e-9))
        out.append((s, [v * g for v in h]))
    out.sort()
    return [h for _, h in out]


def pcm(h):
    return base64.b64encode(struct.pack(f'<{len(h)}h', *(int(max(-1, min(1, v)) * 32767) for v in h))).decode()


def main():
    os.makedirs(os.path.join(OUT, 'previews'), exist_ok=True)
    data = []
    for sid, lic, user, title, url, kind in CANDIDATES:
        path = os.path.join(OUT, 'previews', f'{sid}.mp3')
        if not os.path.exists(path):
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with open(path, 'wb') as f:
                f.write(urllib.request.urlopen(req, timeout=60).read())
        x = decode(path)
        hs = hits(x, kind == 'take')
        if not hs and len(x) < 3 * RATE:
            # A short file of one sound: the whole of it, from where it starts.
            top = max(abs(v) for v in x)
            s = next(i for i, v in enumerate(x) if abs(v) > top * 0.05)
            hs = hits([0.0] * (RATE // 10) + x[s:s + RATE * (9 if kind == 'take' else 6) // 10], kind == 'take')
        print(f'{sid:>7} {lic:4} {len(hs)} hits  {title}', file=sys.stderr)
        if hs:
            data.append({'id': sid, 'lic': lic, 'user': user, 'title': title, 'kind': kind,
                         'page': f'https://freesound.org/people/{user}/sounds/{sid}/', 'hits': [pcm(h) for h in hs]})
    with open(os.path.join(OUT, 'samples.js'), 'w') as f:
        f.write(f'// Made by tools/sound_samples.py from Freesound previews; local, out of git.\nwindow.SAMPLES = {{ rate: {RATE}, list: ')
        json.dump(data, f)
        f.write(' };\n')


if __name__ == '__main__':
    main()
