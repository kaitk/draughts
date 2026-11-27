// The light tuner's downloaded woods (task 122): the CC0 textures from Poly Haven the user
// picked, oak_veneer_01 for the panelling, herringbone_parquet for the floor and
// sapele_veneer for the table and chairs, read at run time from build/wood-candidates/ (not
// built in, not in git) and put on the GPU for render3d::Wood's way 2, to compare with ours
// under the same finish (--woods). As tools/blender/scene.py's finished_wood takes them: the
// albedo with the roughness map in A, the stain's range the albedo's luminance at its 5th and
// 95th percentiles; the normal map's slopes scaled to our own fields' mean (RELIEF), in R and
// G, the normal's up in A.
namespace wood_pictures;
import std;
import os;
import vec;
import math;
import gfx;

// src/native/tuner_jpeg.c's.
extern fn tuner_jpeg(file: const u8[:], out: u8[:], w: i64, h: i64) -> bool;

let SIDE = 2048;
let MIPS = 12;
// By render3d's WOOD_OAK, WOOD_FLOOR, WOOD_TABLE: the folder (from tools/, where the tuner
// runs) and the side of the wood a picture covers (metres, its meta.json's).
let DIRS = ["../build/wood-candidates/oak_veneer_01", "../build/wood-candidates/herringbone_parquet",
            "../build/wood-candidates/sapele_veneer"];
let SIDES: f32[3] = [1.83, 3.4, 0.5];
// The normal maps' slopes kept, so a picture's relief is as strong as our field's beside it
// and the two differ in their wood alone: the mean slope of oak_veneer_01's 0.039, the
// parquet's 0.021, sapele's 0.042, against our panelling's 0.0087, floor's 0.0113 and table's
// 0.0167 (blender_export's maps, 2026-11-27).
let RELIEF: f32[3] = [0.23, 0.54, 0.40];
// What each picture gave, by wood: its luminance's 5th and 95th percentiles (linear), its side
// (world units), and 1 once it is on the GPU.
var pictured = [float4_0; 3];

fn read_jpeg(dir: const u8[:], name: const u8[:], out: u8[>..]&) -> bool {
    var file: u8[>..] = [];
    guard read_file(str(dir, "/", name)[..], file) else { return false; }
    out.resize(4 * SIDE * SIDE, 0);
    return tuner_jpeg(file[..], out[..], SIDE, SIDE);
}

// Wood k's picture put on the GPU (g.wood_pictures), what it gave in pictured[k]; false,
// nothing put, where its files aren't there or don't decode.
fn put<O>(o: O&, g: render3d::Gpu&, k: i64) -> bool {
    guard g.wood_pictures[2 * k].id == 0 else { return true; }
    let t0 = clock();
    let n = SIDE * SIDE;
    var diff:  u8[>..] = [];
    var rough: u8[>..] = [];
    var nor:   u8[>..] = [];
    guard read_jpeg(DIRS[k], "diff.jpg", diff) && read_jpeg(DIRS[k], "rough.jpg", rough) && read_jpeg(DIRS[k], "nor.jpg", nor) else {
        print("--woods: no picture in ", DIRS[k], " (diff, rough and nor .jpg, ", SIDE, " square): ours instead");
        return false;
    }
    var linear: f32[256] = [0.0; 256];
    for i in 256 {
        let c = i / 255.0;
        linear[i] = (if c <= 0.04045 { c / 12.92 } else { pow((c + 0.055) / 1.055, 2.4) }) as f32;
    }
    var albedo: u8[>..] = [];
    var normal: u8[>..] = [];
    albedo.resize(render3d::rgba_bytes(SIDE, SIDE, MIPS), 0);
    normal.resize(render3d::rgba_bytes(SIDE, SIDE, MIPS), 0);
    let BINS = 4096;
    var counts: i64[4096] = [0; 4096];
    for i in n {
        let r = diff[4 * i];
        let gr = diff[4 * i + 1];
        let b = diff[4 * i + 2];
        albedo[4 * i] = r;
        albedo[4 * i + 1] = gr;
        albedo[4 * i + 2] = b;
        albedo[4 * i + 3] = rough[4 * i];
        let y = 0.2126 * linear[r] + 0.7152 * linear[gr] + 0.0722 * linear[b];
        counts[min((y * BINS) as i64, BINS - 1)] += 1;
        // The map's x right and y up (OpenGL's); our slopes along the picture's x and down its rows.
        var sx = RELIEF[k] * (nor[4 * i] / 127.5 - 1.0);
        var sy = -RELIEF[k] * (nor[4 * i + 1] / 127.5 - 1.0);
        let len2 = sx * sx + sy * sy;
        if len2 > 0.9 {
            let k2 = sqrt(0.9 / len2);
            sx *= k2;
            sy *= k2;
        }
        normal[4 * i] = clamp(sx * 127.5 + 127.5 + 0.5, 0.0, 255.0) as u8;
        normal[4 * i + 1] = clamp(sy * 127.5 + 127.5 + 0.5, 0.0, 255.0) as u8;
        normal[4 * i + 2] = 102;   // the table's wear patches between used and left (TABLE_FRAG's tn.z)
        normal[4 * i + 3] = (sqrt(1.0 - sx * sx - sy * sy) * 255.0 + 0.5) as u8;
    }
    var lo:   f32 = 0.0;
    var hi:   f32 = 1.0;
    var seen: i64 = 0;
    var lo_found = false;
    for b in BINS {
        seen += counts[b];
        if !lo_found && seen >= n / 20 {
            lo = (b + 0.5) / BINS;
            lo_found = true;
        }
        if seen >= n - n / 20 {
            hi = (b + 0.5) / BINS;
            break;
        }
    }
    g.wood_pictures[2 * k] = render3d::put_rgba(o, albedo, SIDE, SIDE, MIPS, gfx::RGBA8_SRGB);
    g.wood_pictures[2 * k + 1] = render3d::put_rgba(o, normal, SIDE, SIDE, MIPS);
    pictured[k] = float4 { lo, hi, SIDES[k] * surfaces::METRE, 1.0 };
    print("--woods: ", DIRS[k], " read in ", floor((clock() - t0) * 1000.0) as i64, " ms, its luminance's 5th and 95th percentiles ",
          lo, ", ", hi);
    return true;
}
