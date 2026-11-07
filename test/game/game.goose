// The game screen (game/), headless, driven through the pointer as the app drives it:
// undo takes back one move at a time, also one still animating, and brings back the
// last move's marks; restart goes back to where the game began, a FEN start too; hint
// selects the capture that takes the most and marks it whatever the move hints are,
// until another press; the toggle switches the move hints; a press that starts on the
// panel never moves a piece and one that starts on the board never presses a button; a
// win starts the celebration once the move has shown, stops asking for frames when its sparks are done, and its restart starts over; back
// asks for home.
import std;
import vec;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import game from "../../game";

fn name(v: rules::Variant&, sq: i64) -> u8[>..] {
    if sq < 0 { return str("-"); }
    var s: u8[>..] = [];
    s.push(97 + v.x_of[sq]);
    format(s, v.y_of[sq] as i64 + 1);
    return s;
}

fn marked(v: rules::Variant&, bits: u32[4]&) -> u8[>..] {
    var s: u8[>..] = [];
    for y in v.size {
        for x in v.size {
            let n = y * v.size + x;
            if (bits[n / 32] >> (n % 32)) & 1 != 0 { s.append(name(v, board::bit_at(v, x, y))); s.append(" "); }
        }
    }
    return s;
}

fn square(l: board::Layout, text: const u8[:]) -> float2 {
    let v .= rules::VARIANTS[rules::RUSSIAN];
    return board::center(l, v, board::bit_at(v, text[0] - 97, text[1] - 49));
}

// One frame with the pointer at `at`; returns what the screen asks the shell for.
fn frame(gm: game::Game&, g: gui::Gui&, l: board::Layout, at: float2, down: bool, pressed: bool,
         released: bool, now: f64) -> i64 {
    gui::begin(g, gui::Input { at: at, down: down, pressed: pressed, released: released }, l.scale, now);
    let go, changed = game::frame(gm, g, l, now);
    return go;
}

// A tap at p: down on one frame, up on the next.
fn tap(gm: game::Game&, g: gui::Gui&, l: board::Layout, p: float2, now: f64) -> i64 {
    frame(gm, g, l, p, true, true, false, now);
    return frame(gm, g, l, p, false, false, true, now + 0.02);
}

// The center of the n-th tile the last frame declared: undo, hint, restart, back, the
// hints toggle; then the celebration's back and restart.
fn tile(g: gui::Gui&, n: i64) -> float2 {
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON else { continue; }
        if k == n { return float2 { q.rect.x + 0.5 * q.rect.z, q.rect.y + 0.5 * q.rect.w }; }
        k++;
    }
    assert(false);
    return float2 { 0.0, 0.0 };
}

fn show(gm: game::Game&, what: const u8[:]) {
    let v .= rules::VARIANTS[gm.b.variant];
    var last: u8[>..] = [];
    if gm.b.has_last { last = str(name(v, gm.b.last.from), "-", name(v, gm.b.last.to)); } else { last = str("none"); }
    print(what, ": ", rules::fen(gm.b.pos), ", history ", gm.b.history.len, ", last ", last);
}

let UNDO = 0;
let HINT = 1;
let RESTART = 2;
let BACK = 3;
let TOGGLE = 4;

fn main() {
    let v .= rules::VARIANTS[rules::RUSSIAN];
    let l = board::layout(1280.0, 800.0, 8);
    var g = gui::Gui {};
    var gm = game::new(rules::RUSSIAN);
    let away = float2 { 0.0, 0.0 };
    frame(gm, g, l, away, false, false, false, 0.0);
    print("quads ", g.quads.len, ", over the UI ", gm.overlay.len, " (black ", gm.overlay[0].look.x, ")");

    // Two moves, then undo each; undo at the start does nothing.
    tap(gm, g, l, square(l, "c3"), 0.0);
    tap(gm, g, l, square(l, "d4"), 0.1);
    frame(gm, g, l, away, false, false, false, 1.0);
    print("turn after c3-d4: black ", gm.overlay[0].look.x);
    tap(gm, g, l, square(l, "f6"), 1.0);
    tap(gm, g, l, square(l, "e5"), 1.1);
    frame(gm, g, l, away, false, false, false, 2.0);
    show(gm, "two moves");
    tap(gm, g, l, tile(g, UNDO), 2.0);
    show(gm, "undo");
    tap(gm, g, l, tile(g, UNDO), 2.1);
    show(gm, "undo");
    tap(gm, g, l, tile(g, UNDO), 2.2);
    show(gm, "undo at the start");
    tap(gm, g, l, tile(g, HINT), 2.3);
    print("hint with no capture due: selected ", name(v, gm.b.selected), ", hint ", gm.b.hint);

    // Undo while the move is still animating.
    tap(gm, g, l, square(l, "e3"), 3.0);
    tap(gm, g, l, square(l, "f4"), 3.1);
    print("moving ", gm.b.moving);
    tap(gm, g, l, tile(g, UNDO), 3.15);
    print("undo while moving: moving ", gm.b.moving);
    show(gm, "  then");

    // From a FEN start white must take: c3 two pieces, by way of e5 to g7, or h2 one.
    let p, ok = rules::parse_fen("W:Wc3,h2,a1:Bd4,f6,g3,h8", rules::RUSSIAN);
    assert(ok);
    board::set(gm.b, p);
    frame(gm, g, l, away, false, false, false, 4.0);
    tap(gm, g, l, tile(g, HINT), 4.0);
    board::fill(gm.b, l, 4.1);
    print("hint: selected ", name(v, gm.b.selected), ", targets ", marked(v, gm.b.marks.target),
          ", via ", marked(v, gm.b.marks.via), "with hints on mistakes ", gm.b.hints == board::MISTAKES);
    tap(gm, g, l, square(l, "h2"), 4.2);
    board::fill(gm.b, l, 4.3);
    print("press elsewhere: selected ", name(v, gm.b.selected), ", targets ", marked(v, gm.b.marks.target));
    tap(gm, g, l, tile(g, HINT), 4.4);
    tap(gm, g, l, square(l, "g7"), 4.5);
    frame(gm, g, l, away, false, false, false, 5.5);
    show(gm, "the hinted capture played");
    tap(gm, g, l, tile(g, RESTART), 5.6);
    show(gm, "restart");

    // The toggle.
    tap(gm, g, l, tile(g, TOGGLE), 6.0);
    print("toggle: moves ", gm.b.hints == board::MOVES);
    tap(gm, g, l, tile(g, TOGGLE), 6.1);
    print("toggle again: moves ", gm.b.hints == board::MOVES);

    // A press on undo slid onto the board and released on a target moves nothing; a
    // press on a piece released on undo undoes nothing.
    board::set(gm.b, rules::start(rules::RUSSIAN));
    tap(gm, g, l, square(l, "c3"), 7.0);
    let undo_at = tile(g, UNDO);
    frame(gm, g, l, undo_at, true, true, false, 7.1);
    frame(gm, g, l, square(l, "d4"), true, false, false, 7.2);
    frame(gm, g, l, square(l, "d4"), false, false, true, 7.3);
    print("press on undo, released on d4: moving ", gm.b.moving, ", selected ", name(v, gm.b.selected));
    tap(gm, g, l, square(l, "d4"), 7.4);
    frame(gm, g, l, away, false, false, false, 8.0);
    frame(gm, g, l, square(l, "f6"), true, true, false, 8.0);
    frame(gm, g, l, undo_at, true, false, false, 8.1);
    frame(gm, g, l, undo_at, false, false, true, 8.2);
    show(gm, "press on f6, released on undo");

    // A win: c3 takes d4 and black has nothing left.
    let w, ok_w = rules::parse_fen("W:Wc3,a1:Bd4", rules::RUSSIAN);
    assert(ok_w);
    board::set(gm.b, w);
    tap(gm, g, l, square(l, "c3"), 10.0);
    tap(gm, g, l, square(l, "e5"), 10.1);
    frame(gm, g, l, away, false, false, false, 10.2);
    print("while the capture shows: celebrating ", gm.won_at >= 0.0);
    frame(gm, g, l, away, false, false, false, 11.0);
    print("after: celebrating since ", gm.won_at, ", winner black ", gm.overlay[0].look.x,
          ", pieces over the UI ", gm.overlay.len, ", the winner crowned ", gm.overlay[1].look.y);
    var sparks = 0;
    for q in g.quads { if q.look.x == gui::SPARK { sparks++; } }
    print("sparks at 0.0 s ", sparks, ", animating ", game::animating(gm, g, 11.0));
    frame(gm, g, l, away, false, false, false, 13.0);
    sparks = 0;
    for q in g.quads { if q.look.x == gui::SPARK { sparks++; } }
    print("sparks at 2.0 s ", sparks, ", animating at 8 s ", game::animating(gm, g, 19.0));
    print("back on the card asks for home: ", tap(gm, g, l, tile(g, 5), 19.1) == game::HOME);
    tap(gm, g, l, tile(g, 6), 19.2);
    show(gm, "restart on the card");
    print("celebrating ", gm.won_at >= 0.0);
    frame(gm, g, l, away, false, false, false, 19.3);
    print("back on the panel asks for home: ", tap(gm, g, l, tile(g, BACK), 19.3) == game::HOME);
}
