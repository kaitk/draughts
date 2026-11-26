// The tree outside the window (trees.goose): grown from a seed, the same each time; only
// the parts that fall on the map kept (the table's cut, or the room's whole window); bare
// in winter, its map letting through more with fewer leaves; every layer's map within 0..1
// and its mips the averages of the level above.
import std;
import vec;
import math;
import model3d from "../../src/model3d";

fn show(name: const u8[:], r: rooms::Room, whole: bool = false) {
    var t = trees::Tree { .. };
    let s = rooms::tree_spec(r);
    let v = rooms::tree_view(r, whole);
    trees::grow(t, s, v);
    var map: u8[>..] = [];
    trees::draw_map(t, s, v, map);
    var line: u8[>..] = [];
    format(line, name, ": ", t.segments.len, " segments, ", t.leaves.len, " leaves, ", t.left_out, " left out; ");
    format(line, "passing ", floor(trees::passing(map, -1, v) * 100.0 + 0.5) as i64, "%");
    for layer in 4 { format(line, " ", floor(trees::passing(map, layer, v) * 100.0 + 0.5) as i64); }
    print(line);
    // Grown again from the same seed: the same tree.
    var again = trees::Tree { .. };
    trees::grow(again, s, v);
    if again.segments.len != t.segments.len || again.leaves.len != t.leaves.len { print("    grown again, another tree"); }
    // Every part kept falls on the map.
    for &lf in t.leaves {
        let m = trees::on_map(v, lf.at);
        if !trees::on_rect(v, m, lf.length) { print("    a leaf off the map"); }
    }
    // The first mip the level above averaged.
    let base = v.w * v.h * 4;
    var worst = 0;
    for y in v.h / 2 {
        for x in v.w / 2 {
            var a = 0;
            for k in 4 {
                let at = ((2 * y + k / 2) * v.w + 2 * x + k % 2) * 4;
                a += map[at];
            }
            let m: i64 = map[base + (y * v.w / 2 + x) * 4];
            worst = max(worst, abs((a + 2) / 4 - m));
        }
    }
    if worst > 0 { print("    the first mip off by ", worst); }
}

fn main() {
    print("the map: ", trees::SIDE, " texels a side, ", trees::map_bytes(trees::SIDE, trees::SIDE), " bytes with its mips");
    print("the room's: ", trees::ROOM_W, " by ", trees::ROOM_H, ", ", trees::map_bytes(trees::ROOM_W, trees::ROOM_H), " bytes");
    show("library", rooms::get(rooms::LIBRARY));
    show("hall in spring", rooms::get(rooms::HALL_SPRING));
    show("evening", rooms::get(rooms::SEA_EVENING));
    var bare = rooms::get(rooms::LIBRARY);
    bare.tree.w = 0.0;
    show("library, bare", bare);
    // The room's map over the whole window, the room's own window (agents/design.md).
    var room = rooms::get(rooms::LIBRARY);
    room.panes = float4 { 11.0, 12.7, 1.0, 0.0 };
    room.opening = float4 { 3.0, 6.0, 4.0, 0.45 };
    show("library, the whole window", room, true);
}
