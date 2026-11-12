// The games played (task 074): each move of a game judged on the worker (answered here
// at once with ai::judge, as think.goose's worker would) and listed with its mark; a
// finished game written to the player's history-N.txt, once when it ends and again over
// its own line once its last moves are judged; the rating moved by a game against the
// computer, never by a friend's; undo dropping a taken-back move's note; start again
// clearing the history and the rating. Then the file's lines on their own: a line read
// back as written, a line that holds no game dropped, the file capped at MAX_GAMES with
// the oldest going, and dates from the epoch's seconds.
//
// The friend's game, Russian from W:Wc3:Bf6: c3-d4 (sound), f6-e5?? (d4 takes it: g5
// keeps the game even), d4:f6, the one move, which takes black's last piece.
import std;
import vec;
import os;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";
import check from "../";

let NAMES = ["-", "only", "best", "good", "?!", "?", "??"];

fn folder() -> u8[>..] {
    let dir = if is_dir("build") { str("build/history-files/") } else { str("history-files/") };
    make_dir(dir);
    var names: u8[>..] = [];
    list_dir(dir, names);
    for name in split(names, '\n') { if name.len > 0 { delete_file(str(dir, name)); } }
    return dir;
}

fn start(dir: const u8[:]) -> shell::Shell {
    var sh = shell::new(rules::RUSSIAN);
    var ps = players::Players {};
    sh.prefs = players::load(ps, dir, true);
    sh.players = ps;
    sh.game = game::new(rules::RUSSIAN);
    sh.wall = 1762819200.0;     // 2025-11-11, midnight UTC
    return sh;
}

// Answers the game's open ask at once, as the worker would; true when it answered one.
fn answer(sh: shell::Shell&, e: ai::Engine&) -> bool {
    let gm .= sh.game;
    var a = game::ask_for(gm);
    guard a.id != 0 else { return false; }
    if a.kind == game::JUDGE {
        let v = ai::judge(e, a.past, a.pos, a.move);
        game::judged(gm, a.id, v.mark, v.loss);
        return true;
    }
    if a.kind == game::THINK {
        let m = ai::think_after(e, a.past, a.pos, a.skill, a.seed);
        game::answer(gm, a.id, m, 1);
        return true;
    }
    return false;
}

// Frames from `now` for `seconds`, the worker answering between them.
fn run(sh: shell::Shell&, g: gui::Gui&, e: ai::Engine&, now: f64, seconds: f64) -> f64 {
    var t = now;
    while t < now + seconds {
        drive::idle(sh, g, t);
        answer(sh, e);
        t += 0.05;
    }
    return t;
}

// Plays the move named `text` (PDN) on the game's board, as a tap would.
fn play(sh: shell::Shell&, text: const u8[:], now: f64) {
    let b .= sh.game.b;
    for i in b.moves.len {
        var t: u8[>..] = [];
        rules::format_move(t, b.variant, b.moves[i]);
        guard t == text else { continue; }
        board::play_chosen(b, i, now);
        return;
    }
    print("  no move ", text);
}

fn notes(sh: shell::Shell&) -> u8[>..] {
    var s: u8[>..] = [];
    for &n in sh.game.notes {
        rules::format_move(s, sh.game.b.variant, n.move);
        format(s, " ", NAMES[n.mark], ", ");
    }
    return s;
}

fn file(dir: const u8[:], name: const u8[:]) {
    var text: u8[>..] = [];
    if !read_file(str(dir, name), text) {
        print("  ", name, ": none");
        return;
    }
    for line in split(text, '\n') { if line.len > 0 { print("  ", name, ": ", line); } }
}

fn setup(sh: shell::Shell&, fen: const u8[:], computer: i64) {
    game::start(sh.game, rules::RUSSIAN, clock::NONE, computer, game::EASY, 8, 1);
    board::set(sh.game.b, check::position(rules::RUSSIAN, fen));
    sh.game.turn = sh.game.b.pos.side;
    sh.screen = shell::GAME;
    sh.drawn = shell::GAME;
}

fn main() {
    strings::use(strings::EN);
    var g = gui::Gui {};
    gui::test_faces(g);
    var e = ai::Engine { .. };
    ai::init(e);
    e.node_limit = 20000;
    let dir = folder();
    var sh = start(dir);
    let id = sh.players.list[sh.players.playing].id;
    let name = str("history-", id, ".txt");

    // A friend's game: three moves, judged as they come.
    setup(sh, "W:Wc3:Bf6", -1);
    var now = run(sh, g, e, 1.0, 0.2);
    play(sh, "c3-d4", now);
    now = run(sh, g, e, now, 1.0);
    print("after c3-d4: ", notes(sh));
    play(sh, "f6-e5", now);
    now = run(sh, g, e, now, 1.0);
    print("after f6-e5: ", notes(sh));
    // Taken back and played again: its note goes and comes back, judged again.
    board::undo(sh.game.b);
    now = run(sh, g, e, now, 0.2);
    print("taken back: ", notes(sh));
    play(sh, "f6-e5", now);
    now = run(sh, g, e, now, 1.0);
    play(sh, "d4:f6", now);
    // The end's frame writes the game before the worker has judged its last move.
    while sh.game.notes.len < 3 || !sh.game.kept { now = run(sh, g, e, now, 0.05); }
    print("ended: ", notes(sh), " waiting for marks ", sh.kept.open, ", tally accuracy ", game::tally(sh.game.notes).accuracy[0],
          " ", game::tally(sh.game.notes).accuracy[1]);
    now = run(sh, g, e, now, 2.0);
    print("all judged: ", notes(sh), " still waiting ", sh.kept.open);
    file(dir, name);
    print("rating after a friend's game: ", sh.prefs.rating[rules::RUSSIAN], ", rated ", sh.prefs.rated[rules::RUSSIAN]);

    // Against the computer (black, at easy's skill 8, rated 587): the child's one move
    // takes its last piece.
    setup(sh, "W:Wc3:Bd4", rules::BLACK);
    now = run(sh, g, e, now + 1.0, 0.2);
    play(sh, "c3:e5", now);
    now = run(sh, g, e, now, 2.0);
    print("won against easy: rating ", sh.prefs.rating[rules::RUSSIAN], ", rated ", sh.prefs.rated[rules::RUSSIAN],
          ", international untouched ", sh.prefs.rating[rules::INTERNATIONAL]);
    file(dir, name);
    // And lost: the child's one move, h2-g3, and the computer's capture takes its last
    // piece.
    setup(sh, "W:Wh2:Bf4", rules::BLACK);
    now = run(sh, g, e, now + 1.0, 0.2);
    play(sh, "h2-g3", now);
    now = run(sh, g, e, now, 4.0);
    print("lost to easy: rating ", sh.prefs.rating[rules::RUSSIAN], ", rated ", sh.prefs.rated[rules::RUSSIAN], ", ",
          notes(sh));
    var games: history::Game[..history::MAX_GAMES] = [];
    shell::read_history(sh, games);
    for &x in games {
        let y, m, d = history::date(x.time);
        print("  read: ", y, "-", m, "-", d, " ", rules::VARIANT_NAMES[x.variant], " level ", x.level, " side ", x.side,
              " winner ", x.winner, " result ", history::result(x), " rating ", x.before, ">", x.after, " plies ",
              x.plies, " blunders ", x.marks[ai::BLUNDER], " ", x.marks[ai::MARKS + ai::BLUNDER]);
    }
    let t = history::totals(games);
    print("totals: easy won ", t.computer[(rules::RUSSIAN * 3 + 0) * 3], " lost ", t.computer[(rules::RUSSIAN * 3 + 0) * 3 + 2],
          ", friend ", t.friend[rules::RUSSIAN]);

    // Start again clears the history and the rating.
    shell::start_again(sh, sh.players.playing);
    file(dir, name);
    print("started again: rating ", sh.prefs.rating[rules::RUSSIAN], ", rated ", sh.prefs.rated[rules::RUSSIAN]);

    // The lines on their own.
    var text: u8[>..] = [];
    for i in history::MAX_GAMES + 1 {
        var line: u8[>..] = [];
        format(line, "time=", 1000 + i, "\tdraughts=russian\tagainst=friend\twinner=draw\tmarks=\tmoves=");
        let next = history::with_game(text, line, false);
        text = copy(next);
        if i == 3 { text.append("not a game\n"); }
    }
    var kept: history::Game[..history::MAX_GAMES] = [];
    history::games_of(text, kept);
    print("201 written: ", kept.len, " kept, the first from ", kept[0].time, ", the last ", kept[kept.len - 1].time);
    var line: u8[>..] = [];
    format(line, "time=5\tdraughts=russian\tagainst=friend\twinner=white\tmarks=\tmoves=");
    let replaced = history::with_game(text, line, true);
    text = copy(replaced);
    history::games_of(text, kept);
    print("the last replaced: ", kept.len, " kept, the last ", kept[kept.len - 1].time, " won by ",
          kept[kept.len - 1].winner);
    let bad, ok = history::parse_game("time=x\tdraughts=chess\twinner=draw");
    print("a line with no game: ", ok);
    for epoch in [0, 951782400, 1709164800, 1762819200, -86400] {
        let y, m, d = history::date(epoch);
        print("date of ", epoch, ": ", y, "-", m, "-", d);
    }
}
