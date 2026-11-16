// Home's Watch replay (shell::resume, home::Resume.replay): once the last game has ended
// and is in the history, Watch replay shows in Continue's place, outlined, New game under
// it lit; its note says how the game ended, against whom. A tap opens that game's replay
// at its end, and the replay's back goes home, not to the results. A game won, lost, and
// a friend's each read their own note; a new game set up brings Continue back.
//
// The games, Russian: against the computer (black, easy) W:Wc3:Bd4, c3:e5 takes its last
// piece; then W:Wh2:Bf4, h2-g3, and the computer's capture takes white's; a friend's
// W:Wc3:Bd4, c3:e5, white winning.
import std;
import vec;
import os;
import rules from "../../src/rules";
import board from "../../src/board";
import model3d from "../../src/model3d";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";
import check from "../";

let NAMES = ["home", "the game", "settings", "the puzzles", "a puzzle", "the results", "a replay"];

fn folder() -> u8[>..] {
    let dir = if is_dir("build") { str("build/last-game-files/") } else { str("last-game-files/") };
    make_dir(dir);
    var names: u8[>..] = [];
    list_dir(dir, names);
    for name in split(names, '\n') { if name.len > 0 { delete_file(str(dir, name)); } }
    return dir;
}

// Answers the game's open ask at once, as the worker would.
fn answer(sh: shell::Shell&, e: ai::Engine&) {
    let gm .= sh.game;
    var a = game::ask_for(gm);
    guard a.id != 0 else { return; }
    if a.kind == game::JUDGE {
        let v = ai::judge(e, a.past, a.pos, a.move);
        game::judged(gm, a.id, v.mark, v.loss, v.best_move, v.has_best);
    }
    if a.kind == game::THINK { game::answer(gm, a.id, ai::think_after(e, a.past, a.pos, a.skill, a.seed), 1); }
}

fn run(sh: shell::Shell&, g: gui::Gui&, e: ai::Engine&, now: f64, seconds: f64) -> f64 {
    var t = now;
    while t < now + seconds {
        drive::idle(sh, g, t);
        answer(sh, e);
        t += 0.05;
    }
    return t;
}

fn play(sh: shell::Shell&, text: const u8[:], now: f64) {
    let b .= sh.game.b;
    for i in b.moves.len {
        var t: u8[>..] = [];
        rules::format_move(t, b.pos, b.moves[i]);
        guard t == text else { continue; }
        board::play_chosen(b, i, now);
        return;
    }
    print("  no move ", text);
}

fn setup(sh: shell::Shell&, fen: const u8[:], computer: i64) {
    game::start(sh.game, rules::RUSSIAN, clock::NONE, computer, game::EASY, 8, 1);
    board::set(sh.game.b, check::position(rules::RUSSIAN, fen));
    sh.game.turn = sh.game.b.pos.side;
    sh.screen = shell::GAME;
    sh.drawn = shell::GAME;
}

// The look of the n-th tile the last frame declared.
fn style(g: gui::Gui&, n: i64) -> u8[>..] {
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON else { continue; }
        if k == n {
            let s = q.extra.y as i64;
            return str(if s == gui::ROW_PRIMARY { "lit" } else if s == gui::ROW_OUTLINE { "outlined" } else { "plain" });
        }
        k++;
    }
    return str("none");
}

// The rect of control id as the last frame offered it to the keys' focus.
fn spot(g: gui::Gui&, id: i64) -> float4 {
    for s in g.spots { if s.id == id { return s.rect; } }
    print("  no control ", id);
    return float4 { -100.0, -100.0, 1.0, 1.0 };
}

// Home's first row as resume gives it, and the looks of its first two tiles.
fn show(sh: shell::Shell&, g: gui::Gui&, what: const u8[:]) {
    let r = shell::resume(sh);
    var note: u8[..64] = [];
    if r.replay {
        strings::fill_in_word(note, r.ended_note, strings::get(r.ended_opponent));
    }
    print(what, ": ", if r.replay { "watch replay" } else if r.on { "continue" } else { "neither" }, ", note \"", note[..],
          "\"; the first row ", style(g, 0), ", the second ", style(g, 1));
}

fn home(sh: shell::Shell&, g: gui::Gui&, now: f64) -> f64 {
    shell::go_up(sh, shell::HOME, now);
    drive::idle(sh, g, now + 0.5);
    drive::idle(sh, g, now + 1.0);
    return now + 1.0;
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    var g = gui::Gui {};
    gui::test_faces(g);
    var e = ai::Engine { .. };
    ai::init(e);
    e.node_limit = 20000;
    let dir = folder();
    var sh = shell::new(rules::RUSSIAN);
    var ps = players::Players {};
    sh.prefs = players::load(ps, dir, true);
    sh.players = ps;
    sh.wall = 1762819200.0;

    // Won against the computer.
    setup(sh, "W:Wc3:Bd4", rules::BLACK);
    var now = run(sh, g, e, 1.0, 0.2);
    play(sh, "c3:e5", now);
    now = run(sh, g, e, now, 2.0);
    now = home(sh, g, now);
    show(sh, g, "won against easy");
    drive::tap(sh, g, drive::tile(g, 0), now);
    now = run(sh, g, e, now + 0.1, 0.5);
    let r .= sh.past.replay;
    print("  a tap on it: ", NAMES[sh.screen], ", at its end ", r.ply == r.plies.len, ", won by ", r.game.winner,
          " (white ", rules::WHITE, ")");
    shell::back(sh, now);
    now = run(sh, g, e, now + 0.1, 0.5);
    print("  back: ", NAMES[sh.screen]);

    // Lost to the computer.
    setup(sh, "W:Wh2:Bf4", rules::BLACK);
    now = run(sh, g, e, now + 1.0, 0.2);
    play(sh, "h2-g3", now);
    now = run(sh, g, e, now, 4.0);
    now = home(sh, g, now);
    show(sh, g, "lost to easy");
    // The replay's own back tile goes home too.
    drive::tap(sh, g, drive::tile(g, 0), now);
    now = run(sh, g, e, now + 0.1, 0.5);
    print("  a tap on it: ", NAMES[sh.screen], ", won by ", sh.past.replay.game.winner, " (black ", rules::BLACK, ")");
    drive::tap(sh, g, drive::middle(spot(g, replay::BACK_ID)), now);
    now = run(sh, g, e, now + 0.1, 0.5);
    print("  its back tile: ", NAMES[sh.screen]);

    // A friend's game won by white.
    setup(sh, "W:Wc3:Bd4", -1);
    now = run(sh, g, e, now + 1.0, 0.2);
    play(sh, "c3:e5", now);
    now = run(sh, g, e, now, 2.0);
    now = home(sh, g, now);
    show(sh, g, "a friend's game");

    // A new game set up: Continue again.
    setup(sh, "W:Wc3:Bf6", rules::BLACK);
    now = run(sh, g, e, now + 1.0, 0.2);
    now = home(sh, g, now);
    show(sh, g, "a new game");
}
