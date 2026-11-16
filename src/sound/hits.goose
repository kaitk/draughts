// The recorded hits (docs/architecture/sound.md): a move's and the taken pieces', cut from
// two recordings and stored as IMA ADPCM at 24 kHz in assets/sounds/hits.bin, which
// tools/sound_hits.py writes and the app embeds. Decoded once, as sound is turned on.
//
// The file, little-endian: the counts of move hits and of take hits (u16 each), then each
// hit, the moves first: its samples (u32) and its 4-bit codes, two a byte, the first in
// the low nibble. Each hit is a stream from predictor 0 and step index 0.
namespace sound;
import std;

let MAX_HITS = 16;

fn data() -> const u8[:] { embed_file("../../assets/sounds/hits.bin") }

// Where a hit's codes start in the file, and how many samples it has.
struct Hit {
    at:      i64 = 0,
    samples: i64 = 0,
}

// The `size` bytes from `at`, little-endian.
fn word(d: const u8[:], at: i64, size: i64) -> i64 {
    var n = 0;
    for k in size {
        let b: i64 = d[at + k];
        n |= b << (8 * k);
    }
    return n;
}

// The file's hits: the moves', then the takes'; how many moves.
fn hits(d: const u8[:]) -> Hit[..MAX_HITS], i64 {
    var out: Hit[..MAX_HITS] = [];
    guard d.len >= 4 else { return out, 0; }
    let moves = word(d, 0, 2);
    let all = moves + word(d, 2, 2);
    var at = 4;
    for k in min(all, MAX_HITS) {
        guard at + 4 <= d.len else { break; }
        let n = word(d, at, 4);
        guard at + 4 + (n + 1) / 2 <= d.len else { break; }
        out.push(Hit { at: at + 4, samples: n });
        at += 4 + (n + 1) / 2;
    }
    return out, min(moves, out.len);
}

let STEPS = [7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97,
             107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876,
             963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
             5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086,
             29794, 32767];
let INDEX = [-1, -1, -1, -1, 2, 4, 6, 8];

// Hit h's 16-bit samples, appended to out.
fn decode(d: const u8[:], h: Hit, out: i16[>..]&) {
    var p = 0;
    var s = 0;
    for k in h.samples {
        let byte = d[h.at + k / 2] as i64;
        let code = (if k % 2 == 1 { byte >> 4 } else { byte }) & 15;
        let step = STEPS[s];
        var diff = step >> 3;
        if code & 4 != 0 { diff += step; }
        if code & 2 != 0 { diff += step >> 1; }
        if code & 1 != 0 { diff += step >> 2; }
        p = clamp(if code & 8 != 0 { p - diff } else { p + diff }, -32768, 32767);
        s = clamp(s + INDEX[code & 7], 0, 88);
        out.push(p as i16);
    }
}
