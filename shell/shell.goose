// The app's screens, with no graphics: home, the game, and settings, and which one
// shows (docs/architecture/rendering.md, "Home", "Game screen"). Each frame it declares
// the screen showing and switches when that asks: home's continue opens the game, a
// friend and the computer open a new game's setup in home's column, whose play starts
// the game; settings opens from home and from the game and goes back where it came from.
// It holds the settings, keeps the game's move hints and kings in step with them, and
// says when they changed, for the app to write and apply; and where the board goes this
// frame, turned when the child plays black, and whether the photograph behind it is
// sharp, and the pieces the screen shows over the UI, for the app to draw. Settings show
// their own board, the preview, beside them.
// A game against the computer plays at the skill kept for its level, which each
// finished game moves (ai::adapt). Tests run it headless.
namespace shell;
import std;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import strings from "../strings";
import ai from "../ai";
import .home;
import .settings;

let HOME = 0;
let GAME = 1;
let SETTINGS = 2;

struct Shell {
    screen:  i64 = HOME,
    game:    game::Game,
    preview: board::Board,                    // the board beside settings, as they make it
    prefs:   settings::Settings = settings::Settings {},
    changed: bool               = false,      // prefs changed since the app last wrote them
    drawn:   i64                = -1,         // the screen the last frame declared
    back:    i64                = HOME,       // where settings goes back to
    setup:   i64                = home::NOTHING, // home's column: the menu, or a setup
    layout:  board::Layout,                   // where the board is this frame
    sharp:   bool          = true,            // the photograph as it is (home, settings), or blurred (the game)
    over:    game::Overlay = [],              // the screen's pieces over the UI this frame
}

fn new(variant: u8) -> Shell {
    let g = game::new(variant);
    return Shell { game: g, preview: board::new(variant), layout: board::layout(1.0, 1.0, rules::VARIANTS[variant].size),
                   .. };
}

// One frame, after gui::begin, on a screen width × height pixels. Returns whether
// anything on screen changed.
fn frame(sh: Shell&, g: gui::Gui&, width: f32, height: f32, now: f64) -> bool {
    // A switch happens in a frame that declared the old screen, so the first frame of the
    // new one is a change, however long ago the tap was.
    let fresh = sh.drawn != sh.screen;
    sh.drawn = sh.screen;
    let changed = declare(sh, g, width, height, now, fresh);
    return changed || fresh;
}

fn declare(sh: Shell&, g: gui::Gui&, width: f32, height: f32, now: f64, fresh: bool) -> bool {
    sh.game.b.king_look = settings::king_look(sh.prefs);
    let n = rules::VARIANTS[sh.game.b.variant].size;
    if sh.screen == GAME {
        sh.layout = board::layout(width, height, n);
        sh.layout.flip = sh.game.computer == rules::WHITE;
        sh.sharp = false;
        let go, changed = game::frame(sh.game, g, sh.layout, now, sh.over);
        // A game against the computer ended: the child meets a stronger or weaker one next.
        let gm .= sh.game;
        if gm.result != 0 {
            let k = clamp(gm.level, game::EASY, game::HARD);
            sh.prefs.skill[k] = ai::adapt(sh.prefs.skill[k], k, gm.result);
            gm.result = 0;
            sh.changed = true;
        }
        if go == game::HOME {
            sh.screen = HOME;
            sh.setup = home::NOTHING;
            return true;
        }
        if go == game::SETTINGS {
            sh.screen = SETTINGS;
            sh.back = GAME;
            return true;
        }
        return changed;
    }
    // Time away from the game screen isn't on the clock.
    game::pause(sh.game);
    sh.sharp = true;
    var changed = g.input.pressed || g.input.released;
    if sh.screen == SETTINGS {
        // The preview shows the settings as they are on opening and after each change.
        if fresh { settings::stage(sh.preview, sh.prefs, now); }
        changed = board::update(sh.preview, now) || changed;
        let ask = settings::frame(sh.prefs, sh.over, g, sh.layout, width, height, strings::current);
        if ask == settings::CHANGED {
            sh.game.b.hints = sh.prefs.hints;
            settings::stage(sh.preview, sh.prefs, now);
            sh.changed = true;
        }
        if ask == settings::BACK { sh.screen = sh.back; }
        return changed || ask != settings::NOTHING;
    }
    changed = board::update(sh.game.b, now) || changed;
    let pick = home::frame(sh.over, g, sh.layout, n, width, height, sh.setup, sh.prefs);
    // The board is turned for a child playing black against the computer.
    sh.layout.flip = sh.game.computer == rules::WHITE;
    if pick != home::NOTHING { changed = true; }
    match pick {
        home::SETTINGS => {
            sh.screen = SETTINGS;
            sh.back = HOME;
        },
        home::CONTINUE => { sh.screen = GAME; },
        home::FRIEND => { sh.setup = home::FRIEND; },
        home::COMPUTER => { sh.setup = home::COMPUTER; },
        home::BACK => { sh.setup = home::NOTHING; },
        home::CHANGED => { sh.changed = true; },
        home::PLAY => {
            // A new game as the setup stands; it replaces the one there was. Against the
            // computer it is counted, for the computer's seeds.
            let p .= sh.prefs;
            let computer = if sh.setup == home::COMPUTER { 1 - p.color } else { -1 };
            game::start(sh.game, p.variant as u8, p.clock, computer, p.level, p.skill[p.level], p.games);
            if computer >= 0 {
                p.games += 1;
                sh.changed = true;
            }
            sh.setup = home::NOTHING;
            sh.screen = GAME;
        },
        _ => {},
    }
    return changed;
}

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
          && s.pos.variant == s.variant && s.screen >= HOME && s.screen <= SETTINGS && s.computer >= -1
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
    sh.screen = s.screen;
    return true;
}

// The board on screen: settings show their preview, the other screens the game's.
fn shown(sh: Shell&) -> board::Board& { return if sh.screen == SETTINGS { sh.preview } else { sh.game.b }; }

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(sh: Shell&, g: gui::Gui&, now: f64) -> bool {
    return if sh.screen == GAME { game::animating(sh.game, g, now) }
           else { board::animating(shown(sh), now) || gui::animating(g) };
}
