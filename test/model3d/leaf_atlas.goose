// The leaf atlas (leaf_atlas.goose, task 107's T3): eight maple leaves made the same each
// time; each leaf's outline covering about the same share of its cell down its mips, so a
// far leaf under alpha-to-coverage doesn't thin away; tar spots on the last two only; and
// a backlit texel deeper and more saturated than the same texel front-lit.
import std;
import vec;
import math;
import model3d from "../../src/model3d";

fn main() {
    var shape: u8[>..] = [];
    var marks: u8[>..] = [];
    leaf_atlas::make(shape, marks);
    print("atlas: ", leaf_atlas::ATLAS_W, " by ", leaf_atlas::ATLAS_H, ", ", leaf_atlas::mips_of(leaf_atlas::ATLAS_W, leaf_atlas::ATLAS_H),
          " levels, ", shape.len, " bytes a layer");
    var again_shape: u8[>..] = [];
    var again_marks: u8[>..] = [];
    leaf_atlas::make(again_shape, again_marks);
    var same = true;
    for i in shape.len { if shape[i] != again_shape[i] || marks[i] != again_marks[i] { same = false; } }
    if !same { print("    made again, another atlas"); }
    // Each leaf's share of its cell over a half, at level 0 and as its mips keep it.
    var at = 0;
    var w = leaf_atlas::ATLAS_W;
    var h = leaf_atlas::ATLAS_H;
    for level in 6 {
        let cell = leaf_atlas::CELL >> level;
        var line: u8[>..] = [];
        format(line, "level ", level, ":");
        for k in leaf_atlas::LEAVES {
            let share = leaf_atlas::share_over_half(shape, at, w, k, cell, 1.0);
            format(line, " ", floor(share * 100.0 + 0.5) as i64);
        }
        print(line);
        at += w * h * 4;
        w /= 2;
        h /= 2;
    }
    // Tar spots: which leaves have them.
    var spotted: u8[>..] = [];
    format(spotted, "tar spots on leaves");
    for k in leaf_atlas::LEAVES {
        var n = 0;
        let cx = (k % leaf_atlas::ACROSS) * leaf_atlas::CELL;
        let cy = (k / leaf_atlas::ACROSS) * leaf_atlas::CELL;
        for j in leaf_atlas::CELL {
            for i in leaf_atlas::CELL { if marks[((cy + j) * leaf_atlas::ATLAS_W + cx + i) * 4 + 1] > 127 { n++; } }
        }
        if n > 0 { format(spotted, " ", k); }
    }
    print(spotted);
    // The middle of leaf 0's middle lobe, front-lit and backlit, gold.
    let i = (leaf_atlas::FOOT.y - 0.5 * leaf_atlas::SCALE) as i64 * leaf_atlas::ATLAS_W + leaf_atlas::FOOT.x as i64 + 6;
    let s: u8[4] = [shape[i * 4], shape[i * 4 + 1], shape[i * 4 + 2], shape[i * 4 + 3]];
    let m: u8[4] = [marks[i * 4], marks[i * 4 + 1], marks[i * 4 + 2], marks[i * 4 + 3]];
    let front = leaf_atlas::texel_color(s, m, 1.0, false);
    let back = leaf_atlas::texel_color(s, m, 1.0, true);
    let sat_front = (max(front.x, front.y) - front.z) / max(front.x, front.y);
    let sat_back = (max(back.x, back.y) - back.z) / max(back.x, back.y);
    print("backlit ", if sat_back >= sat_front { "as saturated or more" } else { "less saturated: WRONG" }, ", ",
          if back.y / back.x <= front.y / front.x { "deeper" } else { "paler: WRONG" });
}
