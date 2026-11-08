// The badges' animals baked from their SVG files (badges/badges.goose), headless: each
// file read (how many straight pieces its outline became) and its distance field drawn
// coarsely, a character every fourth texel ('#' inside, '+' within a texel and a half of
// the edge inside, '.' just outside, ' ' beyond), so a file that stops parsing or bakes
// to nothing shows here. Then the path syntax a tracer or an editor writes, each shape a
// square of half the viewBox: relative and absolute moves, H and V, curves through C, S,
// Q, and T, arcs (with flags run together), a group's transform, and a hole (even-odd),
// with the share of texels inside, which a wrong reading moves.
import std;
import vec;
import badges from "../../badges";

fn inside_share(out: u8[:]) -> f32 {
    var n = 0;
    for v in out { if v < 128 { n++; } }
    return n as f32 / out.len;
}

fn draw(out: u8[:]) {
    var y = 2;
    while y < badges::CELL {
        var row: u8[>..] = [];
        var x = 2;
        while x < badges::CELL {
            let v = out[y * badges::CELL + x];
            row.push(if v < 112 { '#' } else if v < 128 { '+' } else if v < 144 { '.' } else { ' ' });
            x += 4;
        }
        print("    |", row, "|");
        y += 4;
    }
}

fn check(what: const u8[:], svg: const u8[:]) {
    var sh = badges::Shape {};
    var out: u8[>..] = [];
    for n in badges::CELL * badges::CELL { out.push(0); }
    guard badges::read(svg, sh) else {
        print(what, ": not read");
        return;
    }
    badges::bake(sh, out);
    let share = floor(inside_share(out) * 1000.0 + 0.5) / 10.0;
    print(what, ": ", sh.segs.len, " pieces, ", share, "% inside");
}

fn main() {
    for name, k in badges::NAMES {
        var sh = badges::Shape {};
        guard badges::read(badges::svg(k), sh) else {
            print(name, ": not read");
            continue;
        }
        var out: u8[>..] = [];
        for n in badges::CELL * badges::CELL { out.push(0); }
        badges::bake(sh, out);
        let share = floor(inside_share(out) * 1000.0 + 0.5) / 10.0;
        print(name, ": ", sh.segs.len, " pieces, ", share, "% inside, full ", sh.full);
        draw(out);
    }
    // A square of half the viewBox: 25% inside.
    check("lines", "<svg viewBox=\"0 0 40 40\"><path d=\"M10 10L30 10L30 30L10 30Z\"/></svg>");
    check("relative, H and V", "<svg viewBox='0 0 40 40'><path d='m10,10h20v20H10z'/></svg>");
    check("a group's transform", "<svg viewBox=\"0 0 40 40\"><g transform=\"translate(0,40) scale(1,-1)\"><path d=\"M10 10h20v20h-20z\"/></g></svg>");
    check("a matrix and a comment", "<svg viewBox=\"0 0 40 40\"><!-- d=\"M0 0h40v40z\" --><path transform=\"matrix(2 0 0 2 0 0)\" d=\"M5 5h10v10h-10z\"/></svg>");
    // A circle of radius 10 in a 40 box: pi / 16, 19.6%.
    check("arcs", "<svg viewBox=\"0 0 40 40\"><path d=\"M10 20a10 10 0 1 0 20 0a10 10 0 1 0-20 0z\"/></svg>");
    check("arc flags run together", "<svg viewBox=\"0 0 40 40\"><path d=\"M10 20a10 10 0 10 20 0a10 10 0 10-20 0z\"/></svg>");
    // Curves along the square's sides, straight where S and T reflect the control point
    // before them: still 25%.
    check("C and S", "<svg viewBox=\"0 0 40 40\"><path d=\"M10 10C15 10 30 10 30 10S30 30 30 30L10 30Z\"/></svg>");
    check("Q and T", "<svg viewBox=\"0 0 40 40\"><path d=\"M10 10Q30 10 30 10T30 30L10 30Z\"/></svg>");
    // The square with a square hole of a quarter of its side: 25% less 1/16 of it.
    check("a hole, even-odd", "<svg viewBox=\"0 0 40 40\"><path d=\"M10 10h20v20h-20zM17.5 17.5h5v5h-5z\"/></svg>");
    // Two paths, filled together.
    check("two paths", "<svg viewBox=\"0 0 40 40\"><path d=\"M10 10h20v10h-20z\"/><path d=\"M10 20h20v10h-20z\"/></svg>");
    // A wide viewBox: its longer side spans the cell, the square centred.
    check("a wide viewBox", "<svg viewBox=\"0 0 80 40\"><path d=\"M20 0h40v40h-40z\"/></svg>");
    check("no viewBox", "<svg><path d=\"M10 10h20v20h-20z\"/></svg>");
    check("bad data", "<svg viewBox=\"0 0 40 40\"><path d=\"M10 10 X\"/></svg>");
}
