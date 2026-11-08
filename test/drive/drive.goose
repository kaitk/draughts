// What the UI tests (test/board/, test/game/, test/shell/) share: squares by name, the
// tiles a frame declared, and the pointer driving a screen frame by frame as the app
// drives it. A test declares test/drive/ as a package, `import drive from "../drive";`,
// beside the packages it imports.
namespace drive;
import std;
import vec;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import game from "../../game";
import shell from "../../shell";

// The pieces the game screen puts over the UI, which the shell holds in the app.
var over: game::Overlay;
// The screen the shell's frames lay out on, in pixels; its short side sets the scale.
var size = float2 { 1280.0, 800.0 };

// A square's name ("c3"), or "-" for none.
fn name(v: rules::Variant&, sq: i64) -> u8[>..] {
    if sq < 0 { return str("-"); }
    var s: u8[>..] = [];
    s.push(97 + v.x_of[sq]);
    format(s, v.y_of[sq] as i64 + 1);
    return s;
}

// The square a name gives, as its rules bit.
fn square(v: rules::Variant&, text: const u8[:]) -> i64 {
    let rank, ok = parse_int(text[1..]);
    assert(ok);
    return rules::bit_at(v, text[0] - 97, rank - 1);
}

// The center of a named square on the board l places; every board of a size numbers its
// squares alike.
fn at(l: board::Layout, text: const u8[:]) -> float2 {
    let v .= rules::VARIANTS[if l.n == 10 { rules::INTERNATIONAL } else { rules::RUSSIAN }];
    return board::center(l, v, square(v, text));
}

// The squares a mark set holds, by name.
fn marked(v: rules::Variant&, bits: u32[4]&) -> u8[>..] {
    var s: u8[>..] = [];
    for y in v.size {
        for x in v.size {
            let n = y * v.size + x;
            if (bits[n / 32] >> (n % 32)) & 1 != 0 { s.append(name(v, rules::bit_at(v, x, y))); s.append(" "); }
        }
    }
    return s;
}

fn middle(r: float4) -> float2 { float2 { r.x + 0.5 * r.z, r.y + 0.5 * r.w } }

// The n-th tile or row the last frame declared, and how many it declared.
fn rect(g: gui::Gui&, n: i64) -> float4 {
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON else { continue; }
        if k == n { return q.rect; }
        k++;
    }
    assert(false);
    return float4 { 0.0, 0.0, 0.0, 0.0 };
}
fn tile(g: gui::Gui&, n: i64) -> float2 { middle(rect(g, n)) }
fn tiles(g: gui::Gui&) -> i64 {
    var k = 0;
    for q in g.quads { if q.look.x == gui::BUTTON { k++; } }
    return k;
}

// The center of the n-th tile leaving out the clocks, which are tiles too: on the game
// screen home, settings, start over, take back; then the celebration's back and restart.
fn control(g: gui::Gui&, n: i64) -> float2 {
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON && q.extra.y < gui::CLOCK_RUN else { continue; }
        if k == n { return middle(q.rect); }
        k++;
    }
    assert(false);
    return float2 { 0.0, 0.0 };
}

// One frame of the game screen with the pointer at `at`; returns what it asks the shell
// for.
fn frame(gm: game::Game&, g: gui::Gui&, l: panel::Layout, at: float2, down: bool, pressed: bool, released: bool,
         now: f64) -> i64 {
    gui::begin(g, gui::Input { at: at, down: down, pressed: pressed, released: released }, l.board.scale, now);
    let go, changed = game::frame(gm, g, l, now, over);
    return go;
}

// One frame of the shell on a screen of `size`; returns whether anything changed.
fn frame(sh: shell::Shell&, g: gui::Gui&, at: float2, down: bool, pressed: bool, released: bool, now: f64) -> bool {
    gui::begin(g, gui::Input { at: at, down: down, pressed: pressed, released: released }, min(size.x, size.y) / 800.0,
               now);
    return shell::frame(sh, g, size.x, size.y, now);
}

let AWAY = float2 { -1.0, -1.0 };

fn idle(gm: game::Game&, g: gui::Gui&, l: panel::Layout, now: f64) -> i64 {
    return frame(gm, g, l, AWAY, false, false, false, now);
}
fn idle(sh: shell::Shell&, g: gui::Gui&, now: f64) -> bool { frame(sh, g, AWAY, false, false, false, now) }

// A tap at p: down on one frame, up on the next; returns what the second asks for.
fn tap(gm: game::Game&, g: gui::Gui&, l: panel::Layout, p: float2, now: f64) -> i64 {
    frame(gm, g, l, p, true, true, false, now);
    return frame(gm, g, l, p, false, false, true, now + 0.02);
}

// A tap at p, then a frame with the pointer away, as a finger lifts.
fn tap(sh: shell::Shell&, g: gui::Gui&, p: float2, now: f64) {
    frame(sh, g, p, true, true, false, now);
    frame(sh, g, p, false, false, true, now + 0.02);
    idle(sh, g, now + 0.04);
}
