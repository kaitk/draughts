// A finished game kept in the playing player's history, and their rating moved by it
// (task 074; history.goose, ai/rating.goose). Part of the shell's namespace.
//
// The game is written once it ends, with its moves' marks as far as they are judged,
// and written again over its own line once the worker has judged the rest, if the game
// is still the one that ended (not started over, nothing taken back). Both happen on an
// event, never in a frame that only draws.
namespace shell;
import std;
import os;

// What the shell keeps of the game last written to the history, to write it again once
// its marks are in.
struct Kept {
    open:  bool          = false,   // its marks still coming
    plies: i64           = 0,       // the notes it was written with
    game:  history::Game = history::Game {},
}

// The time now, in seconds since the epoch: the shell's `wall` where a test set it.
fn wall_time(sh: Shell&) -> i64 { if sh.wall >= 0.0 { sh.wall as i64 } else { time() as i64 } }

// The game on the game screen ended (Event.over, `winner` a side or -1): its rating
// moved against the computer, and the game written to the player's history.
fn keep_game(sh: Shell&, winner: i64) {
    let gm .= sh.game;
    var g = history::Game { time: wall_time(sh), variant: gm.b.variant, winner: winner, .. };
    if gm.computer >= 0 {
        let p .= sh.prefs;
        let v = gm.b.variant as i64;
        g.level = clamp(gm.level, game::EASY, game::HARD);
        g.skill = gm.skill;
        g.side = 1 - gm.computer;
        g.before = p.rating[v];
        g.after = ai::rate(p.rating[v], ai::skill_rating(gm.skill), history::result(g), p.rated[v]);
        p.rating[v] = g.after;
        p.rated[v] += 1;
        sh.changed = true;
    }
    sh.kept = Kept { open: true, plies: gm.notes.len, game: g };
    write_kept(sh, false);
}

// Each frame: the kept game written again once its marks are all in, or let go when the
// game is no longer the one that ended.
fn keep_marks(sh: Shell&) {
    let k .= sh.kept;
    // A game from the replay is on the game screen: the kept game is set aside till it ends.
    guard k.open && !sh.past.trial else { return; }
    let gm .= sh.game;
    guard gm.kept && gm.notes.len == k.plies else {
        k.open = false;
        return;
    }
    guard game::all_judged(gm) else { return; }
    k.open = false;
    write_kept(sh, true);
}

// Writes the kept game to the player's history, as a new line or over the last.
fn write_kept(sh: Shell&, replace: bool) {
    let gm .= sh.game;
    let t = game::tally(gm.notes);
    let g .= sh.kept.game;
    g.accuracy = t.accuracy;
    g.marks = t.marks;
    g.plies = gm.notes.len;
    let ps .= sh.players;
    guard ps.games && ps.list.len > 0 else { return; }
    let path = players::history_path(ps, ps.list[ps.playing].id);
    var text: u8[>..] = [];
    if file_exists(path) { read_file(path, text); }
    var line: u8[>..] = [];
    history::format_game(line, g, gm.notes);
    write_file_atomic(path, history::with_game(text, line, replace));
}

// The file the results screen and a replay read the games from: the playing player's
// history, or the app's --history for screenshots; empty with no files.
fn history_of(sh: Shell&) -> u8[>..] {
    guard sh.history_file.len == 0 else { return str(sh.history_file[..]); }
    let ps .= sh.players;
    guard players::files(ps) && ps.list.len > 0 else { return str(""); }
    return players::history_path(ps, ps.list[ps.playing].id);
}

// The playing player's games, oldest first, into out: for the results screen, on opening it.
fn read_history(sh: Shell&, out: history::Game[..history::MAX_GAMES]&) {
    out.clear();
    let path = history_of(sh);
    guard path.len > 0 else { return; }
    var text: u8[>..] = [];
    guard file_exists(path) && read_file(path, text) else { return; }
    history::games_of(text, out);
}
