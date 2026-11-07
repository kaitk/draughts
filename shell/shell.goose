// The app's screens, with no graphics: home, the game, and settings, and which one
// shows (docs/architecture/rendering.md, "Home", "Game screen"). Each frame it declares
// the screen showing and switches when that asks: home's continue and a friend open the
// game, its settings open settings, and back returns home. It holds the settings, keeps
// the game's move hints in step with them, and says when they changed, for the app to
// write and apply; and where the board goes this frame, if anywhere, and whether the
// photograph behind it is sharp, for the app to draw. Tests run it headless.
namespace shell;
import std;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import strings from "../strings";
import .home;
import .settings;

let HOME = 0;
let GAME = 1;
let SETTINGS = 2;

struct Shell {
    screen:  i64 = HOME,
    game:    game::Game,
    prefs:   settings::Settings = settings::Settings {},
    changed: bool               = false,  // prefs changed since the app last wrote them
    drawn:   i64                = -1,     // the screen the last frame declared
    layout:  board::Layout,               // where the board is this frame
    board:   bool = true,                 // whether there is a board this frame
    sharp:   bool = true,                 // the photograph as it is (home, settings), or blurred (the game)
}

fn new(variant: u8) -> Shell {
    let g = game::new(variant);
    return Shell { game: g, layout: board::layout(1.0, 1.0, rules::VARIANTS[variant].size), .. };
}

// One frame, after gui::begin, on a screen width × height pixels. Returns whether
// anything on screen changed.
fn frame(sh: Shell&, g: gui::Gui&, width: f32, height: f32, now: f64) -> bool {
    // A switch happens in a frame that declared the old screen, so the first frame of the
    // new one is a change, however long ago the tap was.
    let fresh = sh.drawn != sh.screen;
    sh.drawn = sh.screen;
    return declare(sh, g, width, height, now) || fresh;
}

fn declare(sh: Shell&, g: gui::Gui&, width: f32, height: f32, now: f64) -> bool {
    let n = rules::VARIANTS[sh.game.b.variant].size;
    sh.board = true;
    if sh.screen == GAME {
        sh.layout = board::layout(width, height, n);
        sh.sharp = false;
        let go, changed = game::frame(sh.game, g, sh.layout, now);
        // The game's toggle changes the move-hints setting.
        if sh.game.b.hints != sh.prefs.hints {
            sh.prefs.hints = sh.game.b.hints;
            sh.changed = true;
        }
        if go == game::HOME {
            sh.screen = HOME;
            return true;
        }
        return changed;
    }
    sh.sharp = true;
    var changed = board::update(sh.game.b, now) || g.input.pressed || g.input.released;
    if sh.screen == SETTINGS {
        sh.board = false;
        sh.game.overlay.clear();
        let ask = settings::frame(sh.prefs, g, width, height, strings::current);
        if ask == settings::CHANGED {
            sh.game.b.hints = sh.prefs.hints;
            sh.changed = true;
        }
        if ask == settings::BACK { sh.screen = HOME; }
        return changed || ask != settings::NOTHING;
    }
    let pick = home::frame(sh.game, g, sh.layout, width, height);
    if pick == home::SETTINGS {
        sh.screen = SETTINGS;
        changed = true;
    }
    if pick == home::CONTINUE {
        sh.screen = GAME;
        changed = true;
    }
    if pick == home::FRIEND {
        board::set(sh.game.b, rules::start(sh.game.b.variant));
        sh.game.won_at = -1.0;
        sh.screen = GAME;
        changed = true;
    }
    return changed;
}

// What is kept when the app is paused, for Android may kill it then: the screen and the
// game with its undo history, one flat value (docs/architecture/README.md, "Game state is
// a value"). VERSION changes when its layout does; an image of another layout doesn't
// verify, and the app starts afresh.
let VERSION = 1;

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
                     last_from: b.last.from, last_to: b.last.to, has_last: b.has_last, history: b.history });
    var image = to_bytes(one);
    let h = checksum(image);
    for i in 8 { image.push(((h >> (8 * i)) & 0xFF) as u8); }
    return image;
}

// Brings back what an image kept: the screen, and the game as it was, with no move or
// selection under way. False, changing nothing, for an image that isn't one.
fn restore(sh: Shell&, file: const u8[:]) -> bool {
    guard file.len > 8 else { return false; }
    let image = file[..file.len - 8];
    var h: u64 = 0;
    for i in 8 { h |= (file[image.len + i] as u64) << (8 * i); }
    guard h == checksum(image) else { return false; }
    let one, ok = from_bytes<Saved[>..]>(image);
    guard ok && one.len == 1 else { return false; }
    let s .= one[0];
    guard s.version == VERSION && s.variant == sh.game.b.variant && s.screen >= HOME && s.screen <= SETTINGS
    else { return false; }
    let b .= sh.game.b;
    board::set(b, s.start);
    board::show(b, s.pos);
    b.history = s.history;
    b.has_last = s.has_last;
    b.last = rules::Move { from: s.last_from, to: s.last_to, .. };
    sh.game.won_at = -1.0;
    sh.screen = s.screen;
    return true;
}

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(sh: Shell&, g: gui::Gui&, now: f64) -> bool {
    return if sh.screen == GAME { game::animating(sh.game, g, now) }
           else { board::animating(sh.game.b, now) || gui::animating(g) };
}
