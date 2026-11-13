// The game kept when the app is paused or quits, or another player plays: one flat
// image of the screen and the game, with a checksum, in the playing player's game-N.bin
// (players.goose). Part of the shell's namespace.
namespace shell;
import std;
import vec;
import os;

// What is kept when the app is paused, for Android may kill it then: the screen and the
// game with its variant, undo history, clocks, and whom it is against at which skill, one
// flat value (docs/architecture/README.md, "Game state is a value"). VERSION changes when
// its layout does; an image of another layout doesn't verify, and the app starts afresh.
// Version 4 keeps `unset`, the game being one nobody set up, so home's Continue stays
// hidden for it after a restart (issue 1).
let VERSION = 4;

struct Saved {
    version:   i64,
    unset:     bool,
    screen:    i64,
    variant:   u8,
    start:     rules::Position,
    pos:       rules::Position,
    last_from: u8,
    last_to:   u8,
    has_last:  bool,
    history:   board::Step[..board::MAX_HISTORY],
    clock:     clock::Clock,
    computer:  i64,
    level:     i64,
    skill:     i64,
    number:    i64,
    counted:   bool,
}

// FNV-1a over bytes, for the image's checksum: from_bytes checks an image's shape, not
// that its bytes are the ones written.
fn checksum(data: const u8[:]) -> u64 {
    var h: u64 = 0xcbf29ce484222325;
    for c in data { h = (h ^ c) * 0x100000001b3; }
    return h;
}

// What is kept of the game on the game screen and the screen showing.
fn kept_of(sh: Shell&) -> Saved {
    let b .= sh.game.b;
    return Saved { version: VERSION, unset: sh.unset, screen: if sh.screen == RESULTS || sh.screen == REPLAY { HOME } else { sh.screen }, variant: b.variant, start: b.start, pos: b.pos,
                     last_from: b.last.from, last_to: b.last.to, has_last: b.has_last, history: b.history,
                     clock:     sh.game.clock, computer: sh.game.computer, level: sh.game.level, skill: sh.game.skill,
                   number: sh.game.number, counted: sh.game.counted };
}

// The image of what is kept, then its checksum (8 bytes, little-endian), for the app to
// write. While a game played from a replay shows, the game set aside for it is kept
// (Parked), with home as the screen: the game from the replay never is.
fn save(sh: Shell&) -> u8[>..] {
    var one: Saved[>..] = [];
    if sh.trial {
        one.push(sh.parked.kept);
        one[0].screen = HOME;
    } else {
        one.push(kept_of(sh));
    }
    var image = to_bytes(one);
    let h = checksum(image);
    for i in 8 { image.push(((h >> (8 * i)) & 0xFF) as u8); }
    return image;
}

// Brings back what an image kept: the screen, and the game as it was, of whichever
// variant, with no move or selection under way. False, changing nothing, for an image
// that isn't one.
fn restore(sh: Shell&, file: const u8[:]) -> bool {
    guard file.len > 8 else { return false; }
    let image = file[..file.len - 8];
    var h: u64 = 0;
    for i in 8 { h |= (file[image.len + i] as u64) << (8 * i); }
    guard h == checksum(image) else { return false; }
    var one, ok = from_bytes<Saved[>..]>(image);
    if !ok || one.len != 1 || one[0].version != VERSION {
        guard old(image, one) else { return false; }
    }
    let s .= one[0];
    guard s.version == VERSION && s.variant < rules::VARIANT_COUNT && s.start.variant == s.variant
          && s.pos.variant == s.variant && s.screen >= HOME && s.screen <= PUZZLE && s.computer >= -1
          && s.computer <= rules::BLACK && s.level >= game::EASY && s.level <= game::HARD
          && s.clock.kind >= 0 && s.clock.kind < clock::KINDS && s.skill >= 0 && s.skill <= 100
    else { return false; }
    bring_back(sh, s);
    // A puzzle isn't kept; the puzzles to pick from come back instead.
    sh.screen = if s.screen == PUZZLE { PICKER } else { s.screen };
    apply_prefs(sh);
    return true;
}

// The game as s keeps it, in place of the game on the game screen.
fn bring_back(sh: Shell&, s: Saved&) {
    // The game as started, then its board and clocks as they were.
    let gm .= sh.game;
    game::start(gm, s.variant, s.clock.kind, s.computer, s.level, s.skill, s.number);
    let b .= gm.b;
    board::set(b, s.start);
    board::show(b, s.pos);
    b.history = s.history;
    b.has_last = s.has_last;
    b.last = rules::Move { from: s.last_from, to: s.last_to, .. };
    gm.clock = s.clock;
    gm.counted = s.counted;
    gm.turn = b.pos.side;
    sh.unset = s.unset;
    // A game kept after its end was put in the player's history then (Event.over).
    gm.kept = game::ended(gm);
}

// The game in progress set aside while a game played from a replay shows (play_from_here):
// what is kept of it, and what that leaves out and the game would lose, its hints left
// and its moves' marks (notes.goose), so it comes back as it was.
struct Parked {
    kept:       Saved,
    hints:      i64[2]      = [0, 0],
    notes:      game::Notes = [],
    notes_from: i64         = 0,
}

// Sets the game in progress aside, for the game screen to play another.
fn park(sh: Shell&) {
    let p .= sh.parked;
    p.kept = kept_of(sh);
    p.hints = sh.game.hints;
    p.notes = sh.game.notes;
    p.notes_from = sh.game.notes_from;
}

// Brings the game set aside back to the game screen, as it was.
fn unpark(sh: Shell&) {
    let p .= sh.parked;
    bring_back(sh, p.kept);
    let gm .= sh.game;
    gm.hints = p.hints;
    gm.notes = p.notes;
    gm.notes_from = p.notes_from;
    gm.notes_len = -1;
    apply_prefs(sh);
}

// Version 3's layout, before `unset`, read as version 4 with the game set up, which
// every game kept then was or is played (temporary: drop it once the release after
// 2026-11-12 has been out a while).
struct Saved3 {
    version:   i64,
    screen:    i64,
    variant:   u8,
    start:     rules::Position,
    pos:       rules::Position,
    last_from: u8,
    last_to:   u8,
    has_last:  bool,
    history:   board::Step[..board::MAX_HISTORY],
    clock:     clock::Clock,
    computer:  i64,
    level:     i64,
    skill:     i64,
    number:    i64,
    counted:   bool,
}

fn old(image: const u8[:], out: Saved[>..]&) -> bool {
    let three, ok = from_bytes<Saved3[>..]>(image);
    guard ok && three.len == 1 && three[0].version == 3 else { return false; }
    let t .= three[0];
    out = [];
    out.push(Saved { version: VERSION, unset: false, screen: t.screen, variant: t.variant, start: t.start, pos: t.pos,
                     last_from: t.last_from, last_to: t.last_to, has_last: t.has_last, history: t.history,
                     clock: t.clock, computer: t.computer, level: t.level, skill: t.skill, number: t.number,
                     counted: t.counted });
    return true;
}

// Writes the playing player's game to their file (game-N.bin), where games are kept: as
// the app is paused or quits, and before another player plays.
fn write_game(sh: Shell&) {
    let ps .= sh.players;
    guard ps.games && ps.list.len > 0 else { return; }
    write_file_atomic(players::game_path(ps, ps.list[ps.playing].id), save(sh));
}

// Brings back the playing player's game from their file, where games are kept, the
// screen too (at start); false, leaving the game as it is, with none, which is then one
// nobody set up (`unset`).
fn read_game(sh: Shell&) -> bool {
    let ps .= sh.players;
    guard ps.games && ps.list.len > 0 else { return false; }
    var saved: u8[>..] = [];
    sh.unset = !read_file(players::game_path(ps, ps.list[ps.playing].id), saved) || !restore(sh, saved);
    return !sh.unset;
}
