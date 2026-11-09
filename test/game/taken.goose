// What each side has taken (task 052, game::taken), headless: the start's pieces less
// those on the board, men and kings apart, a piece taken while a king counting as a king
// from the undo history. On Russian 8 × 8: nothing at the start; an exchange of men; a
// man taking a king; a king taking a man; a man crowned, moved off its edge, then taken
// as a king; undo giving the king back; a position set up with pieces missing, which
// counts them as men taken. Then the game screen: the counts follow a move only once it
// has shown, and the pieces it shows of them on the flat board's panel under the left
// one, white's pieces (black's catch) over black's, and on a turned board the other way.
import std;
import vec;
import math;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

// Plays from-to (the first legal move between them) on b, at once; false if none.
fn play(b: board::Board&, from: const u8[:], to: const u8[:]) -> bool {
    let v .= rules::VARIANTS[b.variant];
    let f, ok_f = rules::parse_square(v, from);
    let t, ok_t = rules::parse_square(v, to);
    guard ok_f && ok_t else { return false; }
    for k in b.moves.len {
        guard b.moves[k].from as i64 == f && b.moves[k].to as i64 == t else { continue; }
        board::start_move(b, k, 0.0);
        board::update(b, 10.0);
        return true;
    }
    return false;
}

fn show(what: const u8[:], b: board::Board&) {
    let t = game::taken(b);
    print(what, ": ", rules::fen(b.pos), "; white pieces taken: ", t.men[0], " men, ", t.kings[0], " kings; black: ", t.men[1],
          " men, ", t.kings[1], " kings");
}

fn from_fen(fen: const u8[:]) -> board::Board {
    var b = board::new(rules::RUSSIAN);
    let p, ok = rules::parse_fen(fen, rules::RUSSIAN);
    assert(ok);
    board::set(b, p);
    return b;
}

fn main() {
    strings::use(strings::EN);
    var b = board::new(rules::RUSSIAN);
    show("the start", b);
    // c3-d4, f6-e5, then d4 takes e5 (to f6) and g7 takes f6 back (to e5): one man each.
    assert(play(b, "c3", "d4"));
    assert(play(b, "f6", "e5"));
    assert(play(b, "d4", "f6"));
    show("a man taken by a man", b);
    assert(play(b, "g7", "e5"));
    show("and one back", b);

    // A man takes a king: c3 over the black king on d4.
    var k = from_fen("W:Wc3:BKd4,h8");
    assert(play(k, "c3", "e5"));
    show("a king taken by a man", k);

    // A flying king takes a man: a1 over c3.
    var f = from_fen("W:WKa1:Bc3,h8");
    assert(play(f, "a1", "d4"));
    show("a man taken by a king", f);

    // A man crowned on d8, then off its edge to f6, where g7 takes it as a king; undo
    // gives the king back.
    var c = from_fen("W:Wc7,a1:Bg7,h4");
    assert(play(c, "c7", "d8"));
    assert(play(c, "h4", "g3"));
    assert(play(c, "d8", "f6"));
    show("crowned, before", c);
    assert(play(c, "g7", "e5"));
    show("crowned, then taken as a king", c);
    assert(board::undo(c));
    show("undone", c);

    // The game screen, flat at the tablet's size: the counts as the board shows them.
    drive::size = float2 { 1280.0, 800.0 };
    var g = gui::Gui {};
    g.scale = gui::scale_of(1280.0, 800.0);
    gui::test_faces(g);
    let l = panel::layout(1280.0, 800.0, 8);
    var gm = game::new(rules::RUSSIAN);
    let p, ok = rules::parse_fen("W:Wc3:BKd4,h8", rules::RUSSIAN);
    assert(ok);
    board::set(gm.b, p);
    gm.turn = gm.b.pos.side;
    drive::idle(gm, g, l, 0.0);
    print("the game, before: ", caught(gm.taken), ", ", small(g), " small pieces shown");
    drive::tap(gm, g, l, drive::at(l.board, "c3"), 1.0);
    drive::tap(gm, g, l, drive::at(l.board, "e5"), 1.1);
    print("as the capture shows: moving ", gm.b.moving, ", ", caught(gm.taken));
    drive::idle(gm, g, l, 3.0);
    print("once shown: ", caught(gm.taken), "; shown ", rows(g, l), " under the left panel ", l.taken_as == panel::TAKEN_PANEL);
    var turned = l;
    turned.board.flip = true;
    drive::idle(gm, g, turned, 4.0);
    print("on a turned board: ", rows(g, turned));
}

fn caught(t: panel::Taken) -> u8[>..] {
    return str("white pieces taken ", t.men[0], " + ", t.kings[0], " kings, black ", t.men[1], " + ", t.kings[1], " kings");
}

// The small pieces over the UI: what each side has taken.
fn small(g: gui::Gui&) -> i64 {
    var n = 0;
    for p in drive::over { if p.at.z < 0.5 * panel::TAKEN_D * g.scale + 0.5 { n++; } }
    return n;
}

// The two rows of small pieces top to bottom: each row's pieces' color (white's are
// black's catch), count, and kings, and
// whether every piece lies inside the panel l.taken.
fn rows(g: gui::Gui&, l: panel::Layout) -> u8[>..] {
    var out: u8[>..] = [];
    var y:   f32     = -1.0;
    var n = 0;
    var kings = 0;
    var side: f32 = 0.0;
    var inside = true;
    for p in drive::over {
        guard p.at.z < 0.5 * panel::TAKEN_D * g.scale + 0.5 else { continue; }
        let r = l.taken;
        if p.at.x - p.at.z < r.x || p.at.x + p.at.z > r.x + r.z || p.at.y - p.at.z < r.y || p.at.y + p.at.z > r.y + r.w {
            inside = false;
        }
        if p.at.y != y && n > 0 {
            format(out, if side == 0.0 { "white " } else { "black " }, n, " (", kings, " kings) at ", floor(y + 0.5), "; ");
            n = 0;
            kings = 0;
        }
        y = p.at.y;
        side = p.look.x;
        n++;
        if p.look.y == board::CROWN as f32 { kings++; }
    }
    if n > 0 { format(out, if side == 0.0 { "white " } else { "black " }, n, " (", kings, " kings) at ", floor(y + 0.5), "; "); }
    format(out, "inside ", inside);
    return out;
}
