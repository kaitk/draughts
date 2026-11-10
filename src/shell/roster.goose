// The players' list as the shell changes it: who plays, a player added, edited,
// started again, or removed, each writing and reading the players' files (players.goose)
// and the saved game (saved.goose). Part of the shell's namespace.
namespace shell;
import std;
import vec;
import os;

// The player at `index` of the list plays from now on, with settings s and the device's
// language: their game, or a new one of their draughts, on home's menu; the puzzles from
// the start. The app writes and applies their settings (changed): their look and the
// device's file naming them.
fn enter(sh: Shell&, index: i64, s: settings::Settings) {
    let ps .= sh.players;
    let language = sh.prefs.language;
    ps.playing = index;
    sh.prefs = s;
    sh.prefs.picture = ps.list[index].picture;
    sh.prefs.name = ps.list[index].name;
    sh.prefs.language = language;
    sh.game = game::new(sh.prefs.variant as u8);
    let screen = sh.screen;
    read_game(sh);
    sh.screen = screen;
    sh.game.b.hints = sh.prefs.hints;
    sh.puzzle = puzzle::new();
    sh.theme = -1;
    sh.setup = home::NOTHING;
    sh.changed = true;
}

// Switches to the player at `index`: the leaving player's settings and game are written,
// the other's read; the screen shows their game and look at once.
fn switch_player(sh: Shell&, index: i64) {
    let ps .= sh.players;
    guard index >= 0 && index < ps.list.len && index != ps.playing else { return; }
    players::store(ps, ps.list[ps.playing].id, sh.prefs);
    write_game(sh);
    enter(sh, index, players::read(ps, ps.list[index].id));
}

// Adds a player with `picture` and `name` and switches to them, every setting at its
// default (the season by the date). False, changing nothing, with four players.
fn add_player(sh: Shell&, picture: i64, name: players::Name) -> bool {
    let ps .= sh.players;
    let id = players::free_id(ps);
    guard id > 0 else { return false; }
    players::store(ps, ps.list[ps.playing].id, sh.prefs);
    write_game(sh);
    players::delete_game(ps, id);
    var s = settings::Settings {};
    s.picture = picture;
    s.name = name;
    players::store(ps, id, s);
    let at = players::insert(ps, players::Player { id: id, picture: picture, name: name });
    enter(sh, at, s);
    return true;
}

// Gives the player at `index` another picture and name.
fn edit_player(sh: Shell&, index: i64, picture: i64, name: players::Name) {
    let ps .= sh.players;
    guard index >= 0 && index < ps.list.len else { return; }
    let p .= ps.list[index];
    p.picture = picture;
    p.name = name;
    if index == ps.playing {
        sh.prefs.picture = picture;
        sh.prefs.name = name;
        sh.changed = true;
        return;
    }
    var s = players::read(ps, p.id);
    s.picture = picture;
    s.name = name;
    players::store(ps, p.id, s);
}

// Starts the player at `index` again: their stars, the computer's skill and games, and
// their saved game are cleared; their picture, name, look, and setup stay.
fn start_again(sh: Shell&, index: i64) {
    let ps .= sh.players;
    guard index >= 0 && index < ps.list.len else { return; }
    let id = ps.list[index].id;
    players::delete_game(ps, id);
    if index == ps.playing {
        players::clear_progress(sh.prefs);
        sh.game = game::new(sh.prefs.variant as u8);
        sh.game.b.hints = sh.prefs.hints;
        sh.puzzle = puzzle::new();
        sh.theme = -1;
        sh.changed = true;
        return;
    }
    var s = players::read(ps, id);
    players::clear_progress(s);
    players::store(ps, id, s);
}

// Removes the player at `index` and their files. The last player can't be removed
// (false). Removing the player who is playing makes the first left the player.
fn remove_player(sh: Shell&, index: i64) -> bool {
    let ps .= sh.players;
    guard ps.list.len > 1 && index >= 0 && index < ps.list.len else { return false; }
    let playing = index == ps.playing;
    players::delete_files(ps, ps.list[index].id);
    for i in index..ps.list.len - 1 { ps.list[i] = ps.list[i + 1]; }
    ps.list.pop();
    if playing {
        enter(sh, 0, players::read(ps, ps.list[0].id));
    } else if index < ps.playing {
        ps.playing--;
    }
    return true;
}
