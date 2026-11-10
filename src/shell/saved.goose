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
let VERSION = 3;

struct Saved {
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

// FNV-1a over bytes, for the image's checksum: from_bytes checks an image's shape, not
// that its bytes are the ones written.
fn checksum(data: const u8[:]) -> u64 {
    var h: u64 = 0xcbf29ce484222325;
    for c in data { h = (h ^ c) * 0x100000001b3; }
    return h;
}

// The image of what is kept, then its checksum (8 bytes, little-endian), for the app to
// write.
fn save(sh: Shell&) -> u8[>..] {
    let b .= sh.game.b;
    var one: Saved[>..] = [];
    one.push(Saved { version: VERSION, screen: sh.screen, variant: b.variant, start: b.start, pos: b.pos,
                     last_from: b.last.from, last_to: b.last.to, has_last: b.has_last, history: b.history,
                     clock:     sh.game.clock, computer: sh.game.computer, level: sh.game.level, skill: sh.game.skill,
                     number: sh.game.number, counted: sh.game.counted });
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
    let one, ok = from_bytes<Saved[>..]>(image);
    guard ok && one.len == 1 else { return false; }
    let s .= one[0];
    guard s.version == VERSION && s.variant < rules::VARIANT_COUNT && s.start.variant == s.variant
          && s.pos.variant == s.variant && s.screen >= HOME && s.screen <= PUZZLE && s.computer >= -1
          && s.computer <= rules::BLACK && s.level >= game::EASY && s.level <= game::HARD
          && s.clock.kind >= 0 && s.clock.kind < clock::KINDS && s.skill >= 0 && s.skill <= 100
    else { return false; }
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
    // A puzzle isn't kept; the puzzles to pick from come back instead.
    sh.screen = if s.screen == PUZZLE { PICKER } else { s.screen };
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
// screen too (at start); false, leaving the game as it is, with none.
fn read_game(sh: Shell&) -> bool {
    let ps .= sh.players;
    guard ps.games && ps.list.len > 0 else { return false; }
    var saved: u8[>..] = [];
    guard read_file(players::game_path(ps, ps.list[ps.playing].id), saved) else { return false; }
    return restore(sh, saved);
}
