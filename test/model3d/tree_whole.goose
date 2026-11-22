// The old maple grown whole (tree_whole.goose, task 107's T1): the same tree from the same
// seed; its sizes real (the trunk about a metre thick, the crown about 22 m and 20 m
// across, the blades about 11 cm); every leaf on a twig, none in the crown's core; culled
// to the parts seen through the windows or casting through them, the shadow's part the
// same as the whole tree's; and the shell's shadow baked from it within 0..1.
import std;
import vec;
import math;
import model3d from "../../src/model3d";

fn metres(x: f32) -> f32 { floor(x / surfaces::METRE * 10.0 + 0.5) / 10.0 }

fn main() {
    let r = rooms::get(rooms::LIBRARY);
    let s = room_shell::LIBRARY;
    let w = rooms::whole_tree(r, s);
    let sight = rooms::whole_sight(r, s);
    let v = rooms::shell_tree_view(r, s);
    print("sight: ", sight.eyes.len, " eyes, ", sight.windows.len, " windows");

    var whole = trees::Tree { .. };
    trees::grow_whole(whole, w, v, sight, false);
    var line: u8[>..] = [];
    format(line, "whole: ", whole.segments.len, " segments, ", whole.limbs.len, " limbs (");
    for level in 5 { format(line, if level > 0 { " " } else { "" }, trees::limbs_at(whole, level)); }
    format(line, "), ", whole.cards.len, " leaves, ", whole.leaves.len, " casting, ", whole.left_out, " left out");
    print(line);

    // The sizes, in metres.
    var top: f32 = -1e9;
    var lo = float2 { 1e9, 1e9 };
    var hi = float2 { -1e9, -1e9 };
    for &sg in whole.segments {
        top = max(top, sg.b.y);
        lo = float2 { min(lo.x, sg.b.x), min(lo.y, sg.b.z) };
        hi = float2 { max(hi.x, sg.b.x), max(hi.y, sg.b.z) };
    }
    for &c in whole.cards {
        top = max(top, c.base.y);
        lo = float2 { min(lo.x, c.base.x), min(lo.y, c.base.z) };
        hi = float2 { max(hi.x, c.base.x), max(hi.y, c.base.z) };
    }
    print("tall ", metres(top - w.foot.y), " m, across ", metres(hi.x - lo.x), " m, deep ", metres(hi.y - lo.y),
          " m; the trunk ", metres(whole.segments[1].ra * 2.0), " m thick a little up, ", metres(whole.segments[0].ra * 2.0),
          " m at its foot");
    var size:  f32 = 0.0;
    var stalk: f32 = 0.0;
    var deep = 0;
    var off_twig = 0;
    var nearest: f32 = 1e9;
    for &c in whole.cards {
        size += c.size;
        stalk += length(c.base - c.foot);
        if trees::crown_depth(w, c.foot) >= w.shell { deep++; }
        nearest = min(nearest, c.base.z - w.house);
    }
    for &sg in whole.segments { nearest = min(nearest, sg.b.z - w.house); }
    let n = max(whole.cards.len, 1) as f32;
    print("a blade ", floor(size / n / surfaces::METRE * 100.0 + 0.5) as i64, " cm, its stalk ",
          floor(stalk / n / surfaces::METRE * 100.0 + 0.5) as i64, " cm; ", deep, " leaves in the core; nothing nearer the house than ",
          if nearest >= trees::WALL_GAP { "the gap" } else { "the gap: WRONG" });
    // Each leaf's face and axis at right angles, unit long.
    var bad = 0;
    for &c in whole.cards {
        if abs(dot(c.face, c.along)) > 1e-3 || abs(length(c.face) - 1.0) > 1e-3 || abs(length(c.along) - 1.0) > 1e-3 { bad++; }
    }
    if bad > 0 { print("    ", bad, " leaves with a bent frame"); }
    // The tints spread from green to orange.
    var tints: i64[5] = [0; 5];
    for &c in whole.cards { tints[min((c.tint * 2.0) as i64, 4)]++; }
    print("tints by half: ", tints[0], " ", tints[1], " ", tints[2], " ", tints[3], " ", tints[4]);

    // Grown again: the same tree.
    var again = trees::Tree { .. };
    trees::grow_whole(again, w, v, sight, false);
    var same = again.segments.len == whole.segments.len && again.cards.len == whole.cards.len;
    if same { for i in whole.cards.len { if again.cards[i].base.x != whole.cards[i].base.x { same = false; } } }
    if !same { print("    grown again, another tree"); }

    // Culled: fewer parts, the shadow's part the same.
    var culled = trees::Tree { .. };
    trees::grow_whole(culled, w, v, sight, true);
    print("culled: ", culled.segments.len, " segments, ", culled.limbs.len, " limbs, ", culled.cards.len, " leaves, ",
          culled.leaves.len, " casting");
    var same_shadow = culled.leaves.len == whole.leaves.len;
    if same_shadow {
        for i in whole.leaves.len {
            if culled.leaves[i].at.x != whole.leaves[i].at.x || culled.leaves[i].at.z != whole.leaves[i].at.z { same_shadow = false; }
        }
    }
    var on_whole = 0;
    var on_culled = 0;
    for &sg in whole.segments { if trees::segment_on_map(v, sg) { on_whole++; } }
    for &sg in culled.segments { if trees::segment_on_map(v, sg) { on_culled++; } }
    print("the shadow's leaves ", if same_shadow { "the same" } else { "differ: WRONG" }, ", its segments ",
          if on_whole == on_culled { "the same" } else { "differ: WRONG" }, " (", on_culled, ")");

    // Its shadow through the shell's windows.
    let spec = rooms::tree_spec(rooms::shell_tree(r));
    var map: u8[>..] = [];
    trees::draw_map(culled, spec, v, map);
    var pass_line: u8[>..] = [];
    format(pass_line, "its shadow: passing ", floor(trees::passing(map, -1, v) * 100.0 + 0.5) as i64, "%");
    for layer in 4 { format(pass_line, " ", floor(trees::passing(map, layer, v) * 100.0 + 0.5) as i64); }
    print(pass_line);
}
