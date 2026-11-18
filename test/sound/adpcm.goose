// The app's IMA ADPCM decoder against tools/assets/sound_hits.py's encoder: each embedded hit's
// samples and a checksum of its decoded 16-bit values, which the tool writes as this
// test's expected output when it builds assets/sounds/hits.bin. A decoder that drifts by
// one step in one sample changes a checksum.
import std;
import sound from "../../src/sound";

// FNV-1a over the samples' 16-bit two's-complement bytes, low first, as the tool's.
fn checksum(q: const i16[:]) -> u64 {
    var h: u64 = 0xcbf29ce484222325;
    for v in q {
        let u = v as! u16;
        h = (h ^ (u & 0xFF)) * 0x100000001b3;
        h = (h ^ (u >> 8)) * 0x100000001b3;
    }
    return h;
}

fn hex(x: u64) -> u8[..16] {
    var out: u8[..16] = [];
    for k in 16 {
        let d = (x >> (60 - 4 * k)) & 15;
        out.push(if d < 10 { '0' + d as u8 } else { 'a' + (d - 10) as u8 });
    }
    return out;
}

let KEPT = ["m1", "m2", "m3", "m9", "m10", "m11", "t2", "t4", "t5", "t6"];

fn main() {
    let d = sound::data();
    let list, moves = sound::hits(d);
    for h, k in list {
        var q: i16[>..] = [];
        sound::decode(d, h, q);
        let sum = hex(checksum(q[..]));
        print(KEPT[k], ": ", q.len, " samples, ", (q.len + 1) / 2, " bytes, checksum ", sum[..]);
    }
    print(d.len, " bytes");
}
