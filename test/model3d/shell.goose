// The library's shell (room_shell::LIBRARY): every opening fits its wall with its band,
// architrave or bookcase's ledge, none overlaps another on its wall, each stops under the cornice, the walls
// close the room's rectangle, and the table stands 1.2 m from the window wall opposite the
// middle window.
import std;
import vec;
import math;
import model3d from "../../src/model3d";

fn main() {
    let s = room_shell::LIBRARY;
    for w, i in s.walls {
        let next = s.walls[(i + 1) % 4];
        let closed = length(next.a - w.b) < 1e-4;
        print("wall ", i, ": ", room_shell::length_of(w), " m long, ", w.thick, " m thick",
              if closed { "" } else { ", NOT meeting the next" });
    }
    let cornice = s.ceiling - room_shell::CORNICE_DROP;
    for k in s.count {
        let o = s.openings[k];
        let w = s.walls[o.wall];
        let half = room_shell::reach(o);
        var line: u8[>..] = [];
        format(line, if o.kind == room_shell::WINDOW { "window" } else if o.kind == room_shell::DOOR { "door" } else { "bookcase" }, " on wall ", o.wall, " at ", o.mid,
               ": ", o.width, " m wide, its top ", floor(room_shell::surround_top(o) * 100.0 + 0.5) / 100.0, " m");
        if o.mid - half < 0.0 || o.mid + half > room_shell::length_of(w) { line.append(", NOT within its wall"); }
        if room_shell::surround_top(o) > cornice { line.append(", NOT under the cornice"); }
        for j in s.count {
            let p = s.openings[j];
            guard j != k && p.wall == o.wall else { continue; }
            if abs(p.mid - o.mid) < half + room_shell::reach(p) { line.append(", OVERLAPPING another"); }
        }
        if o.rise > 0.0 {
            format(line, "; arch radius ", floor(room_shell::arch_radius(o) * 100.0 + 0.5) / 100.0, ", crown ",
                   floor(room_shell::head_at(o, 0.0) * 100.0 + 0.5) / 100.0);
        }
        print(line);
    }
    let ww = s.walls[room_shell::WINDOW_WALL];
    let from_wall = dot(s.table - ww.a, room_shell::inward(ww));
    print("the table ", floor(from_wall * 100.0 + 0.5) / 100.0, " m from the window wall, ",
          floor(abs(s.table.x - s.openings[1].mid) * 100.0 + 0.5) / 100.0, " m off the middle window's middle");
    let t = room_shell::room_of(s, s.table);
    let c = room_shell::room_of(s, float2 { 0.0, 7.0 });
    print("in the room's frame the table at ", t.x, ",", t.y, ", the stove's end of the window wall at ", c.x, ",", c.y);
}
