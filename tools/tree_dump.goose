// The old maple (trees::grow_whole) and the leaf atlas (leaf_atlas) dumped for review on
// the CPU, no window and no GPU (task 107's T1 and T3): the tree whole and culled as flat
// little-endian f32 records, the frame's eyes, windows and sun as text, the atlas's two
// layers at level 0, and the shell's shadow baked from the culled tree; with the counts
// and how long each step took. Build it (C at -O2) for the times:
//
//   goose build -o build/tree_dump tools/tree_dump.goose && build/tree_dump OUT_DIR
//
// One tree-NAME-whole.bin and -culled.bin a variant (rooms::WHOLE_VARIANTS), its shadow
// shadow-NAME.grey and times in times.txt; the frame's eyes and windows for the default.
// tree.bin: "segments" n, then n × (a.xyz b.xyz ra rb level); "limbs" n × (first count
// level parent); "cards" n × (foot.xyz base.xyz along.xyz face.xyz size width kind tint);
// each count an f32 too.
import std;
import os;
import vec;
import math;
import binary;
import model3d from "../src/model3d";

fn put(out: u8[>..]&, x: f32) {
    let b = binary::bits_of_f32(x);
    out.push((b & 0xFF) as u8);
    out.push(((b >> 8) & 0xFF) as u8);
    out.push(((b >> 16) & 0xFF) as u8);
    out.push(((b >> 24) & 0xFF) as u8);
}

fn put3(out: u8[>..]&, v: float3) { put(out, v.x); put(out, v.y); put(out, v.z); }

fn write_tree(path: const u8[:], t: trees::Tree&) {
    var out: u8[>..] = [];
    put(out, t.segments.len as f32);
    for &s in t.segments { put3(out, s.a); put3(out, s.b); put(out, s.ra); put(out, s.rb); put(out, s.level as f32); }
    put(out, t.limbs.len as f32);
    for &l in t.limbs { put(out, l.first as f32); put(out, l.count as f32); put(out, l.level as f32); put(out, l.parent as f32); }
    put(out, t.cards.len as f32);
    for &c in t.cards {
        put3(out, c.foot); put3(out, c.base); put3(out, c.along); put3(out, c.face);
        put(out, c.size); put(out, c.width); put(out, c.kind as f32); put(out, c.tint);
    }
    guard write_file(path, out[..]) else { abort("could not write the tree"); }
}

// A map's four layers multiplied, one byte a texel.
fn write_grey(path: const u8[:], map: u8[>..]&, v: trees::View) {
    var grey: u8[>..] = [];
    for i in v.w * v.h {
        let o = i * 4;
        grey.push(((map[o] as i64) * (map[o + 1] as i64) / 255 * (map[o + 2] as i64) / 255 * (map[o + 3] as i64) / 255) as u8);
    }
    guard write_file(path, grey[..]) else { abort("could not write the shadow"); }
}

fn line3(out: u8[>..]&, name: const u8[:], v: float3) { format(out, name, " ", v.x, " ", v.y, " ", v.z, "\n"); }

fn main() {
    let args = args();
    guard args.len >= 2 else { abort("tree_dump OUT_DIR"); }
    let dir = args[1];
    let r = rooms::get(rooms::LIBRARY);
    let s = room_shell::LIBRARY;
    let sight = rooms::whole_sight(r, s);
    let v = rooms::shell_tree_view(r, s);
    let spec = rooms::tree_spec(rooms::shell_tree(r));
    let w = rooms::whole_tree(r, s);
    var times: u8[>..] = [];
    for name, k in rooms::WHOLE_VARIANTS {
        let wk = rooms::whole_tree(r, s, k);
        var t = trees::Tree { .. };
        var t0 = clock();
        trees::grow_whole(t, wk, v, sight, false);
        let whole_ms = (clock() - t0) * 1000.0;
        print(name, " whole: ", t.segments.len, " segments, ", t.limbs.len, " limbs (", trees::limbs_at(t, 0), " ",
              trees::limbs_at(t, 1), " ", trees::limbs_at(t, 2), " ", trees::limbs_at(t, 3), " ", trees::limbs_at(t, 4), "), ",
              t.cards.len, " leaves, ", whole_ms, " ms");
        write_tree(str(dir, "/tree-", name, "-whole.bin")[..], t);
        var c = trees::Tree { .. };
        t0 = clock();
        trees::grow_whole(c, wk, v, sight, true);
        let culled_ms = (clock() - t0) * 1000.0;
        print(name, " culled: ", c.segments.len, " segments, ", c.limbs.len, " limbs, ", c.cards.len, " leaves, ", c.leaves.len,
              " casting, ", c.left_out, " left out, ", culled_ms, " ms");
        write_tree(str(dir, "/tree-", name, "-culled.bin")[..], c);
        // Its shadow through the shell's windows, the leaves cast by the atlas's outlines.
        var map: u8[>..] = [];
        t0 = clock();
        trees::draw_map(c, spec, v, map);
        let map_ms = (clock() - t0) * 1000.0;
        print(name, " shadow: passing ", trees::passing(map, -1, v), " in ", map_ms, " ms");
        format(times, name, " ", whole_ms, " ", culled_ms, " ", map_ms, " ", trees::passing(map, -1, v), "\n");
        write_grey(str(dir, "/shadow-", name, ".grey")[..], map, v);
        if k == rooms::WHOLE_OLD_LEADER {
            // The same leaves cast as the species' palmate outline, for the comparison.
            for &lf in c.leaves { lf.kind = -1; }
            var plain: u8[>..] = [];
            t0 = clock();
            trees::draw_map(c, spec, v, plain);
            print(name, " shadow, plain outlines: passing ", trees::passing(plain, -1, v), " in ", (clock() - t0) * 1000.0, " ms");
            write_grey(str(dir, "/shadow-", name, "-plain.grey")[..], plain, v);
        }
    }
    guard write_file(str(dir, "/times.txt")[..], times[..]) else { abort("could not write the times"); }

    // Today's tree's shadow for comparison.
    var today = trees::Tree { .. };
    var today_map: u8[>..] = [];
    var t0 = clock();
    trees::grow(today, spec, v);
    trees::draw_map(today, spec, v, today_map);
    let today_ms = (clock() - t0) * 1000.0;
    print("today's tree: ", today.segments.len, " segments, ", today.leaves.len, " leaves, passing ", trees::passing(today_map, -1, v),
          " in ", today_ms, " ms");
    write_grey(str(dir, "/shadow-today.grey")[..], today_map, v);

    // The frame: where the eyes, windows, sun and tree are.
    var info: u8[>..] = [];
    format(info, "metre ", surfaces::METRE, "\n");
    format(info, "shear ", v.shear.x, " ", v.shear.y, "\n");
    format(info, "map ", v.middle.x, " ", v.middle.y, " ", v.size.x, " ", v.size.y, " ", v.w, " ", v.h, "\n");
    line3(info, "foot", w.foot);
    format(info, "house ", w.house, "\nplane ", sight.plane, "\n");
    line3(info, "crown_middle", w.foot + w.middle);
    format(info, "crown ", w.crown.x, " ", w.crown.y, " ", w.crown.z, " ", w.crown.w, "\n");
    for &o in sight.windows { format(info, "window ", o.x, " ", o.y, " ", o.z, " ", o.w, "\n"); }
    // The light tuner's table-window eye and target at its default placement (less-turned).
    line3(info, "eye", rooms::plan_to_tree(r, s, float3 { 4.037, 3.75, 1.6 }));
    line3(info, "at", rooms::plan_to_tree(r, s, float3 { 4.245, 6.737, 1.426 }));
    line3(info, "floor", rooms::plan_to_tree(r, s, float3 { 4.5, 7.0, 0.0 }));
    format(info, "today_ms ", today_ms, "\n");
    guard write_file(str(dir, "/frame.txt")[..], info[..]) else { abort("could not write the frame"); }

    // The atlas.
    var shape: u8[>..] = [];
    var marks: u8[>..] = [];
    t0 = clock();
    leaf_atlas::make(shape, marks);
    let atlas_ms = (clock() - t0) * 1000.0;
    print("atlas: ", leaf_atlas::ATLAS_W, " x ", leaf_atlas::ATLAS_H, ", two layers of ", leaf_atlas::atlas_bytes(),
          " bytes with mips, ", atlas_ms, " ms");
    let n = leaf_atlas::ATLAS_W * leaf_atlas::ATLAS_H * 4;
    guard write_file(str(dir, "/atlas-shape.rgba")[..], shape[0..n]) && write_file(str(dir, "/atlas-marks.rgba")[..], marks[0..n])
        else { abort("could not write the atlas"); }
    // Its colours, linear f32 RGB, front and backlit, at five tints.
    let tints: f32[5] = [0.2, 0.6, 1.0, 1.4, 1.8];
    for tint, ti in tints {
        for side in 2 {
            var rgb: u8[>..] = [];
            for i in leaf_atlas::ATLAS_W * leaf_atlas::ATLAS_H {
                let o = i * 4;
                let sv: u8[4] = [shape[o], shape[o + 1], shape[o + 2], shape[o + 3]];
                let mv: u8[4] = [marks[o], marks[o + 1], marks[o + 2], marks[o + 3]];
                let col = leaf_atlas::texel_color(sv, mv, tint, side == 1);
                put3(rgb, col);
            }
            guard write_file(str(dir, "/atlas-", if side == 1 { "back" } else { "front" }, "-", ti, ".f32")[..], rgb[..])
                else { abort("could not write the colours"); }
        }
    }
    // The coverage at each mip, for the check that leaves don't thin away.
    var at = 0;
    var mw = leaf_atlas::ATLAS_W;
    var mh = leaf_atlas::ATLAS_H;
    var cover: u8[>..] = [];
    for level in leaf_atlas::mips_of(mw, mh) {
        var over = 0;
        for i in mw * mh { if shape[at + i * 4 + 3] > 127 { over++; } }
        format(cover, level, " ", over as f32 / (mw * mh) as f32, "\n");
        at += mw * mh * 4;
        mw /= 2;
        mh /= 2;
    }
    guard write_file(str(dir, "/atlas-coverage.txt")[..], cover[..]) else { abort("could not write the coverage"); }
}
