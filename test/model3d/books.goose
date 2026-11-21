// The library's books on their shelves (model3d::books, room_shell::shelves): each shelf of
// the two bookcases by the hall door filled as a library's is, about 85 to 92% of its width
// (a pile lying flat counts its length), no book taller than its shelf's clear height or
// deeper than the shelf, none overlapping the next upright one, sets in their volumes'
// order; how many books, leaning, lying flat, and the triangles they make.
import std;
import vec;
import math;
import model3d from "../../src/model3d";

fn main() {
    let s = room_shell::LIBRARY;
    var uses: books::Uses = [0; books::MAX_SETS];
    var total = 0;
    var leaning = 0;
    var flat = 0;
    for k in s.count {
        let o = s.openings[k];
        guard o.kind == room_shell::BOOKCASE else { continue; }
        let shs = room_shell::shelves(o, room_shell::door_mid(s, o.wall));
        print("the bookcase at ", o.mid, ":");
        for sh, i in shs {
            let row = books::fill(sh, uses);
            var used:     f32     = 0.0;
            var line:     u8[>..] = [];
            var last_end: f32     = -1.0;
            var last_set = -1;
            var last_vol = 0;
            var wrong: u8[>..] = [];
            var lean = 0;
            var lying = 0;
            for p in row {
                let c = books::CELL[p.cell];
                let h = c.height / 1000.0;
                let t = c.thick / 1000.0;
                if h > sh.clear - 0.01 && !p.flat { wrong.append(" too tall"); }
                if books::depth_of(c) > sh.depth { wrong.append(" too deep"); }
                if p.flat {
                    lying++;
                    continue;
                }
                if p.lean != 0.0 { lean++; }
                if p.s < last_end - 1e-4 && p.lean == 0.0 { wrong.append(" overlapping"); }
                if c.set == last_set && c.vol != last_vol + 1 && c.vol != 1 { wrong.append(" out of order"); }
                last_end = p.s + t;
                last_set = c.set;
                last_vol = c.vol;
                used += t;
            }
            let width = sh.s1 - sh.s0;
            var pile: f32 = 0.0;
            for p in row { if p.flat { pile = max(pile, books::CELL[p.cell].height / 1000.0); } }
            format(line, "  shelf ", i, ": ", row.len, " books, ", floor(100.0 * (used + pile) / width + 0.5), "% full");
            if lean > 0 { format(line, ", ", lean, " leaning"); }
            if lying > 0 { format(line, ", ", lying, " lying flat"); }
            line.append(wrong);
            print(line);
            total += row.len;
            leaning += lean;
            flat += lying;
        }
    }
    print(total, " books, ", leaning, " leaning, ", flat, " lying flat");
    var verts:   mesh::Vertex[>..] = [];
    var indices: u32[>..]          = [];
    var glass:   mesh::Vertex[>..] = [];
    var gi:      u32[>..]          = [];
    room_shell::build(verts, indices, glass, gi, s);
    let with = indices.len / 3;
    verts.clear();
    indices.clear();
    room_shell::build(verts, indices, glass, gi, s, false);
    print("the shell's triangles: ", with, ", without the books ", indices.len / 3);
}
