// The games played, a past game replayed, and a game played on from it (task 074, task
// 078): the shell's side of results.goose and replay.goose, which only show. Part of the
// shell's namespace.
namespace shell;
import std;
import os;

// What the results and a replay keep while the app runs. Nothing of a replay reaches the
// game, the history, or the ratings.
struct Past {
    // The playing player's games, read as the results open, and the draughts they show.
    games:   history::Game[..history::MAX_GAMES] = [],
    variant: i64                                 = rules::INTERNATIONAL,
    // A past game replayed, with its own board. Back from it, the results show as they
    // were left (`replayed`, their list's scroll kept in `at`).
    replay:   replay::Replay,
    replayed: bool = false,
    at:       f32  = 0.0,
    // The game on the game screen is one played from the replay (play_from_here), the
    // game in progress set aside in `parked` until it ends: it isn't written to the
    // history, moves no rating or skill, and isn't kept; the parked game is (save).
    trial:  bool = false,
    parked: Parked,
}

// The games played: the history read as the screen opens, the draughts it shows at first
// the setup's. Its board lies off the screen, as the puzzles' library's.
fn results_screen(sh: Shell&, g: gui::Gui&, area: float4, now: f64, fresh: bool) -> bool {
    sh.out.over.clear();
    if fresh && sh.past.replayed {
        gui::scroll_set(g, results::LIST, sh.past.at);
    } else if fresh {
        read_history(sh, sh.past.games);
        sh.past.variant = sh.prefs.variant;
    }
    sh.past.replayed = false;
    var variant = sh.past.variant;
    let ask = results::frame(g, area, sh.prefs, sh.past.games, variant);
    sh.past.variant = variant;
    sh.out.layout = board::layout_at(-2.0 * area.z, 0.0, 0.5 * area.z, g.scale, sh.out.layout.n);
    if ask == results::BACK {
        go_up(sh, HOME, now);
    }
    if ask >= 0 {
        sh.past.at = if g.scroll.id == results::LIST { g.scroll.offset } else { 0.0 };
        open_replay(sh, ask, now);
    }
    return ask != results::NOTHING;
}

// Opens the replay of game `index` of sh.past.games, its moves read again from the history
// file, on its row's tap (or the app's --screen replay). Nothing else changes.
fn open_replay(sh: Shell&, index: i64, now: f64) {
    guard index >= 0 && index < sh.past.games.len else { return; }
    var text: u8[>..] = [];
    let path = history_of(sh);
    if path.len > 0 && file_exists(path) { read_file(path, text); }
    let line, found = history::line_of(text, index);
    replay::open(sh.past.replay, sh.past.games[index], if found { line } else { text[..0] });
    sh.past.replay.b.king_look = king_look(sh);
    sh.past.replayed = true;
    go_to(sh, REPLAY, now);
}

// A past game for this frame. Returns whether anything on screen changed.
fn replay_screen(sh: Shell&, g: gui::Gui&, area: float4, now: f64, fresh: bool) -> bool {
    let r .= sh.past.replay;
    let moved = board::update(r.b, now);
    sh.out.over.clear();
    let ask = replay::frame(r, g, area, sh.out.layout, sh.out.over, now, fresh);
    if ask == replay::BACK { go_to(sh, RESULTS, now); }
    if ask == replay::PLAY { play_from_here(sh, now); }
    return moved || ask != replay::NOTHING;
}

// Play from here on the replay: a game from the position at the move shown, of the same
// draughts, against the same opponent (the computer at the game's level and skill, or a
// friend), the player on the same side and the side to move as there, with no clock (the
// history keeps none), and its moves numbered on from the replay's. The game in progress
// is set aside (park) and comes back as it was when this one is left (leave_trial).
fn play_from_here(sh: Shell&, now: f64) {
    let r .= sh.past.replay;
    guard replay::playable(r) && r.pos.len > r.ply else { return; }
    if !sh.past.trial { park(sh); }
    sh.past.trial = true;
    let x .= r.game;
    let gm .= sh.game;
    let computer = if x.level == history::FRIEND { -1 } else { 1 - x.side };
    let level = if x.level == history::FRIEND { sh.prefs.level } else { clamp(x.level, game::EASY, game::HARD) };
    game::start(gm, x.variant as u8, clock::NONE, computer, level, x.skill, sh.prefs.games);
    game::start_from(gm, r.pos[r.ply], r.ply + replay::offset(r));
    apply_prefs(sh);
    go_to(sh, GAME, now);
}

// A game from the replay left (its back, or the system's): the game in progress back as
// it was, and the replay where it was left.
fn leave_trial(sh: Shell&, now: f64) {
    guard sh.past.trial else { return; }
    unpark(sh);
    sh.past.trial = false;
    go_to(sh, REPLAY, now);
}
