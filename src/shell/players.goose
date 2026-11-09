// The players on one tablet (docs/architecture/README.md, "Players"), with no graphics:
// up to four, each a picture, an optional name, and what a child makes their own (the
// look, move hints, a new game's setup, the computer's skill and games, puzzle stars,
// the first start, and the game in progress). The language and who is playing belong to
// the device.
//
// The files, in the app's storage folder: `settings.txt` keeps the device's keys
// (`language`, `player = N`); `player-N.txt` a player's keys as settings::write writes
// them; `game-N.bin` the player's saved game (shell::save). N is the player's id, 1 to 4,
// the lowest free one for a new player; players show in the order of their ids. Each
// file is written whole and atomically; starting again or removing deletes files.
//
// In memory: the playing player's settings (the shell's prefs), and for every player
// only the id, picture, and name, for the picker, in a fixed table read at start.
namespace players;
import std;
import os;

let MAX_PLAYERS = 4;
// The pictures (badges), as the file names them, each with its own colour; one a player
// has is not offered to another. app/widgets.goose's badge() draws them, for now a
// placeholder in the badge's colour: the art is still open (task 038).
let ANIMALS = ["fox", "hare", "bear", "owl", "frog", "hedgehog"];
let NAME_CHARS = 12;
let NAME_BYTES = 36;        // 12 characters of at most 3 bytes: the faces hold none longer
let MAX_DIR = 512;

type Name = u8[..NAME_BYTES];

struct Player {
    id:      i64  = 0,
    picture: i64  = 0,
    name:    Name = [],
}

struct Players {
    list:    Player[..MAX_PLAYERS] = [],
    playing: i64                   = 0,     // the playing player's place in list
    // The storage folder, ending in a separator; "" reads and writes nothing.
    dir: u8[..MAX_DIR] = [],
    // Whether the players' games are read and written (not in a run whose flags set up a
    // game or take a screenshot).
    games: bool = false,
    // The device's keys as settings.txt last had them, so it is written only when one
    // changes.
    language: i64 = -2,
    player:   i64 = -1,
    // Whether this start found no player and no settings.txt before them: a fresh install,
    // whose child picks their badge first.
    fresh: bool = false,
}

// Whether character c may be in a name: one the faces draw, and no control character.
fn drawable(c: i64) -> bool { c >= 0x20 && (c < 0x7F || c >= 0xA0) && gui::glyph_index(c) >= 0 }

// How many characters name n has.
fn length(n: const u8[:]) -> i64 {
    var k = 0;
    var i = 0;
    while i < n.len {
        let c, next = gui::next_char(n, i);
        i = next;
        k++;
    }
    return k;
}

// Appends character c to name n as UTF-8, if it may be in a name and there is room.
fn add_char(n: Name&, c: i64) {
    guard drawable(c) && length(n) < NAME_CHARS else { return; }
    if c < 0x80 {
        n.push(c as u8);
    } else if c < 0x800 {
        n.push((0xC0 | (c >> 6)) as u8);
        n.push((0x80 | (c & 0x3F)) as u8);
    } else {
        n.push((0xE0 | (c >> 12)) as u8);
        n.push((0x80 | ((c >> 6) & 0x3F)) as u8);
        n.push((0x80 | (c & 0x3F)) as u8);
    }
}

// Takes the last character off name n.
fn erase_char(n: Name&) {
    guard n.len > 0 else { return; }
    var i = n.len - 1;
    while i > 0 && (n[i] & 0xC0) == 0x80 { i--; }
    n.resize(i);
}

// Name n as text gives it: the characters a name may hold, at most NAME_CHARS.
fn set_name(n: Name&, text: const u8[:]) {
    n.clear();
    var i = 0;
    while i < text.len {
        let c, next = gui::next_char(text, i);
        i = next;
        add_char(n, c);
    }
}

// Name n without spaces at its ends.
fn trimmed(n: Name&) {
    var t: Name = [];
    set_name(t, trim(n[..]));
    n = t;
}

// The paths, in the storage folder.
fn device_path(ps: Players&) -> u8[>..] { str(ps.dir[..], "settings.txt") }
fn player_path(ps: Players&, id: i64) -> u8[>..] { str(ps.dir[..], "player-", id, ".txt") }
fn game_path(ps: Players&, id: i64) -> u8[>..] { str(ps.dir[..], "game-", id, ".bin") }
fn files(ps: Players&) -> bool { ps.dir.len > 0 }

// The player id settings.txt names, or 0 when it names none (a file from before players,
// or none at all).
fn named_player(text: const u8[:]) -> i64 {
    var rest = text;
    var id = 0;
    while rest.len > 0 {
        let line, after, found = split_once(rest, '\n');
        rest = after;
        let k, v, ok = split_once(line, '=');
        guard ok && trim(k) == "player" else { continue; }
        let n, number = parse_int(trim(v));
        if number && n >= 1 && n <= MAX_PLAYERS { id = n; }
    }
    return id;
}

// settings.txt for the device: the language (settings' language value), and the player.
fn write_device(language: i64, player: i64, out: u8[>..]&) {
    out.append("language = ");
    out.append(if language >= 0 { strings::LANGUAGES[language] } else { "system" });
    format(out, "\nplayer = ", player, "\n");
}

fn store_device(ps: Players&, language: i64, player: i64) {
    guard files(ps) && (language != ps.language || player != ps.player) else { return; }
    var out: u8[>..] = [];
    write_device(language, player, out);
    if write_file_atomic(device_path(ps), out) {
        ps.language = language;
        ps.player = player;
    }
}

// A player's settings as their file has them; the defaults for one with no file.
fn read(ps: Players&, id: i64) -> settings::Settings {
    var text: u8[>..] = [];
    if files(ps) { read_file(player_path(ps, id), text); }
    return settings::parse(text);
}

// Writes player `id`'s file with settings s.
fn store(ps: Players&, id: i64, s: settings::Settings&) {
    guard files(ps) else { return; }
    var out: u8[>..] = [];
    settings::write(s, out);
    write_file_atomic(player_path(ps, id), out);
}

// Writes the playing player's settings s, and the device's keys if they changed: after
// a change in settings, a switch, or a new player.
fn write(ps: Players&, s: settings::Settings&) {
    guard ps.list.len > 0 else { return; }
    store(ps, ps.list[ps.playing].id, s);
    store_device(ps, s.language, ps.list[ps.playing].id);
}

// From a settings.txt without `player` (`text`, perhaps empty: a fresh install) to the
// players' files: its player keys become player-1.txt with the fox and no name, game.bin
// becomes game-1.bin, then settings.txt is rewritten with the language and player 1.
// Killed at any point, the next start migrates again from the same keys, and each step
// done again does the same. A settings.txt that was there means the app was used before
// players: player 1 has had the first start.
fn migrate(ps: Players&, text: const u8[:]) {
    var s = settings::parse(text);
    s.picture = 0;
    s.name.clear();
    s.first_start_done = text.len > 0;
    store(ps, 1, s);
    let old = str(ps.dir[..], "game.bin");
    if file_exists(old) { rename_file(old, game_path(ps, 1)); }
    ps.language = -2;
    store_device(ps, s.language, 1);
}

// Reads the players at start from storage folder `dir` ("" for none), migrating a
// settings.txt from before players first, and returns the playing player's settings
// with the device's language. `games`: whether their games are read and written. With
// no player file left (or no folder), there is one player, the fox, at the defaults.
fn load(ps: Players&, dir: const u8[:], games: bool) -> settings::Settings {
    ps.dir.clear();
    if dir.len <= MAX_DIR { ps.dir.append(dir); }
    ps.games = games && files(ps);
    ps.list.clear();
    ps.playing = 0;
    var text: u8[>..] = [];
    if files(ps) { read_file(device_path(ps), text); }
    var id = named_player(text);
    ps.fresh = false;
    if files(ps) && id == 0 {
        ps.fresh = text.len == 0;
        migrate(ps, text);
        id = 1;
    } else {
        ps.language = settings::parse(text).language;
        ps.player = id;
    }
    let language = settings::parse(text).language;
    var s = settings::Settings {};
    for k in 1..MAX_PLAYERS + 1 {
        guard files(ps) && file_exists(player_path(ps, k)) else { continue; }
        let one = read(ps, k);
        ps.list.push(Player { id: k, picture: one.picture, name: one.name });
        if k == id || ps.list.len == 1 {
            ps.playing = ps.list.len - 1;
            s = one;
        }
    }
    if ps.list.len == 0 {
        s = settings::Settings {};
        ps.list.push(Player { id: 1, .. });
        store(ps, 1, s);
    }
    s.language = language;
    store_device(ps, language, ps.list[ps.playing].id);
    return s;
}

// The lowest id no player has, or 0 with four players.
fn free_id(ps: Players&) -> i64 {
    for k in 1..MAX_PLAYERS + 1 {
        var taken = false;
        for p in ps.list { if p.id == k { taken = true; } }
        if !taken { return k; }
    }
    return 0;
}

// The first picture no player but the one at `except` (-1 for none) has.
fn free_picture(ps: Players&, except: i64) -> i64 {
    for a in ANIMALS.len { if !taken(ps, a, except) { return a; } }
    return 0;
}

// Whether a player other than the one at `except` has picture a.
fn taken(ps: Players&, a: i64, except: i64) -> bool {
    for p, i in ps.list { if p.picture == a && i != except { return true; } }
    return false;
}

// Puts a player in the list in the order of the ids; returns their place.
fn insert(ps: Players&, p: Player) -> i64 {
    var at = ps.list.len;
    for q, i in ps.list { if q.id > p.id && at == ps.list.len { at = i; } }
    ps.list.push(p);
    var i = ps.list.len - 1;
    while i > at {
        ps.list[i] = ps.list[i - 1];
        i--;
    }
    ps.list[at] = p;
    if ps.list.len > 1 && at <= ps.playing { ps.playing++; }
    return at;
}

// Deletes player `id`'s saved game.
fn delete_game(ps: Players&, id: i64) {
    guard files(ps) else { return; }
    let path = game_path(ps, id);
    if file_exists(path) { delete_file(path); }
}

// Deletes player `id`'s files: the game first, so a player killed halfway is left as
// one started again, never a game without its player.
fn delete_files(ps: Players&, id: i64) {
    guard files(ps) else { return; }
    delete_game(ps, id);
    let path = player_path(ps, id);
    if file_exists(path) { delete_file(path); }
}

// Starting again clears these of settings s: the stars, and the computer's skill and
// games; the picture, the name, the look, and the setup stay.
fn clear_progress(s: settings::Settings&) {
    let fresh = settings::Settings {};
    s.stars = fresh.stars;
    s.skill = fresh.skill;
    s.played = fresh.played;
    s.games = fresh.games;
}
