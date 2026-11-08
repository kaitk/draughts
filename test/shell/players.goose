// The players' files (shell/players.goose), headless, in a folder of their own: a
// player's file reads back what was written, picture, name, and first start with the
// rest; a name keeps only characters the faces draw, up to 12. A settings.txt from
// before players migrates to player 1 (the fox, no name, the first start done) with
// game.bin as game-1.bin, and settings.txt keeps only the language and the player; the
// app killed after any step migrates again to the same files. A fresh install starts
// with one player at the defaults. Adding a player takes the lowest free id and switches
// to them at the defaults with a new game; switching writes the leaving player's game
// and settings and reads the other's; starting again clears the stars, the computer's
// skill and games, and the saved game, and keeps the rest; removing deletes the files,
// never the last player, and removing the player who is playing makes the first left
// play.
import std;
import vec;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import strings from "../../strings";
import game from "../../game";
import ai from "../../ai";
import shell from "../../shell";
import puzzles from "../../puzzles";

// A folder for the files: under build/ through TinyCC (run from the repository),
// the build's own folder otherwise.
fn folder() -> u8[>..] {
    let dir = if is_dir("build") { str("build/players-files/") } else { str("players-files/") };
    make_dir(dir);
    var names: u8[>..] = [];
    list_dir(dir, names);
    for name in split(names, '\n') { if name.len > 0 { delete_file(str(dir, name)); } }
    return dir;
}

// The folder's files and what each text file holds, its lines joined by ';'.
fn files(dir: const u8[:]) {
    var names: u8[>..] = [];
    list_dir(dir, names);
    for name in split(names, '\n') {
        guard name.len > 0 else { continue; }
        guard ends_with(name, ".txt") else {
            print("  ", name);
            continue;
        }
        var text: u8[>..] = [];
        read_file(str(dir, name), text);
        for i in text.len { if text[i] == '\n' { text[i] = ';'; } }
        print("  ", name, ": ", text);
    }
}

fn put(dir: const u8[:], name: const u8[:], text: const u8[:]) { write_file(str(dir, name), text); }

// The players as the shell has them: each id, picture, and name, the one playing marked.
fn listed(sh: shell::Shell&) -> u8[>..] {
    var s: u8[>..] = [];
    for p, i in sh.players.list {
        format(s, if i == sh.players.playing { "*" } else { "" }, p.id, " ", players::ANIMALS[p.picture]);
        if p.name.len > 0 { format(s, " ", p.name[..]); }
        s.append(if i + 1 < sh.players.list.len { ", " } else { "" });
    }
    return s;
}

// What the playing player has: the stars won, the computer's skill and games, the
// season, and the game's draughts and moves so far.
fn state(sh: shell::Shell&) -> u8[>..] {
    var won = 0;
    for x in sh.prefs.stars[rules::INTERNATIONAL] { won += x; }
    return str("stars ", won, ", skill ", sh.prefs.skill[0], " ", sh.prefs.skill[1], " ", sh.prefs.skill[2], ", games ",
               sh.prefs.games, ", season ", sh.prefs.season, ", hints ", sh.prefs.hints, ", game ",
               rules::VARIANTS[sh.game.b.variant].size, "x", rules::VARIANTS[sh.game.b.variant].size, " after ",
               sh.game.b.history.len, " moves, language ", sh.prefs.language);
}

// A fresh shell reading the players from dir, as the app does at start.
fn start(dir: const u8[:]) -> shell::Shell {
    var sh = shell::new(rules::INTERNATIONAL);
    var ps = players::Players {};
    sh.prefs = players::load(ps, dir, true);
    sh.players = ps;
    sh.game = game::new(sh.prefs.variant as u8);
    shell::read_game(sh);
    return sh;
}

// Plays a move of the game, so a game read back shows whose it is.
fn play_one(sh: shell::Shell&) {
    board::play_chosen(sh.game.b, 0, 0.0);
    board::update(sh.game.b, 100.0);
}

fn written(sh: shell::Shell&) {
    players::write(sh.players, sh.prefs);
    sh.changed = false;
}

fn main() {
    strings::use(strings::EN);
    // A player's file read and written back.
    var s = settings::Settings {};
    s.picture = 3;
    players::set_name(s.name, "  Jüri-Märt  ");
    players::trimmed(s.name);
    s.first_start_done = true;
    s.season = 1;
    s.stars[rules::INTERNATIONAL][2] = 3;
    var out: u8[>..] = [];
    settings::write(s, out);
    print("a player's file:\n", out);
    var again: u8[>..] = [];
    settings::write(settings::parse(out), again);
    print("written again the same: ", again == out);
    let odd = settings::parse("picture = unicorn\nname = Aleksander the Great\nfirst_start = maybe\n");
    print("an unknown picture: ", players::ANIMALS[odd.picture], ", a long name: '", odd.name[..], "' (",
          players::length(odd.name[..]), " characters), first start done ", odd.first_start_done);
    var typed: players::Name = [];
    for c in [0x41, 0x09, 0x161, 0x7F, 0x1F600, 0x2019, 0x62] { players::add_char(typed, c); }
    players::erase_char(typed);
    players::add_char(typed, 0x63);
    print("typed A, a tab, š, DEL, an emoji, ’, b, erased one, c: '", typed[..], "'");

    // Migration from before players: settings.txt with every key and game.bin.
    let dir = folder();
    let old = "season = winter\nboard = 2d\nhints = moves\nkings = stack\nlanguage = et\ndraughts = russian\nlevel = hard\ncolor = black\nclock = 5+3\nskill_easy = 12\nskill_medium = 44\nskill_hard = 95\ngames = 7\nstars = 1:3 4:2\n";
    put(dir, "settings.txt", old);
    var before = shell::new(rules::RUSSIAN);
    play_one(before);
    write_file(str(dir, "game.bin"), shell::save(before));
    var sh = start(dir);
    print("migrated: ", listed(sh), "; ", state(sh), ", first start done ", sh.prefs.first_start_done);
    files(dir);
    // Killed after player-1.txt was written: settings.txt and game.bin as they were.
    let kept = folder();
    put(kept, "settings.txt", old);
    write_file(str(kept, "game.bin"), shell::save(before));
    put(kept, "player-1.txt", "picture = fox\nseason = autumn\n");
    sh = start(kept);
    print("killed after player-1.txt: ", listed(sh), "; ", state(sh));
    files(kept);
    // Killed after game.bin was renamed: settings.txt as it was, game-1.bin there.
    let renamed = folder();
    put(renamed, "settings.txt", old);
    write_file(str(renamed, "game-1.bin"), shell::save(before));
    sh = start(renamed);
    print("killed after the rename: ", listed(sh), "; ", state(sh));
    files(renamed);
    // A fresh install.
    let fresh = folder();
    sh = start(fresh);
    print("a fresh install: ", listed(sh), "; ", state(sh), ", first start done ", sh.prefs.first_start_done);
    files(fresh);

    // Adding, switching, starting again, removing.
    let dir2 = folder();
    put(dir2, "settings.txt", old);
    write_file(str(dir2, "game.bin"), shell::save(before));
    sh = start(dir2);
    var name: players::Name = [];
    var none: players::Name = [];
    players::set_name(name, "Mia");
    let pic = players::free_picture(sh.players, -1);
    print("the first free picture: ", players::ANIMALS[pic]);
    shell::add_player(sh, pic, name);
    written(sh);
    print("added: ", listed(sh), "; ", state(sh), ", first start done ", sh.prefs.first_start_done);
    play_one(sh);
    play_one(sh);
    sh.prefs.stars[rules::INTERNATIONAL][5] = 2;
    sh.prefs.season = 3;
    written(sh);
    shell::switch_player(sh, 0);
    written(sh);
    print("back to the fox: ", listed(sh), "; ", state(sh));
    shell::switch_player(sh, 1);
    written(sh);
    print("to Mia: ", listed(sh), "; ", state(sh));
    files(dir2);
    shell::add_player(sh, 2, none);
    written(sh);
    shell::add_player(sh, 5, none);
    written(sh);
    print("four: ", listed(sh), ", a fifth added ", shell::add_player(sh, 4, none), ", free id ",
          players::free_id(sh.players));
    // The fox started again from another player.
    shell::start_again(sh, 0);
    shell::switch_player(sh, 0);
    written(sh);
    print("the fox started again: ", listed(sh), "; ", state(sh));
    // Mia, playing, started again.
    shell::switch_player(sh, 1);
    written(sh);
    shell::start_again(sh, 1);
    written(sh);
    print("Mia started again: ", listed(sh), "; ", state(sh));
    files(dir2);
    // Removing the bear (not playing), then Mia (playing): the fox, first left, plays.
    shell::remove_player(sh, 2);
    print("the bear removed: ", listed(sh));
    shell::remove_player(sh, 1);
    written(sh);
    print("Mia removed: ", listed(sh), "; ", state(sh));
    // A new player takes the lowest free id.
    shell::add_player(sh, players::free_picture(sh.players, -1), none);
    written(sh);
    print("added again: ", listed(sh));
    shell::remove_player(sh, 0);
    written(sh);
    print("the fox removed: ", listed(sh));
    shell::remove_player(sh, 0);
    written(sh);
    print("the hare removed: ", listed(sh), ", the last removed ", shell::remove_player(sh, 0), ", still ", listed(sh));
    files(dir2);
    // Read again at start: the same players, the one playing too.
    sh = start(dir2);
    print("read again: ", listed(sh));
    // A player renamed while another plays.
    shell::add_player(sh, 1, none);
    written(sh);
    players::set_name(name, "Isa");
    shell::edit_player(sh, 1, 4, name);
    print("renamed: ", listed(sh));
    files(dir2);
}
