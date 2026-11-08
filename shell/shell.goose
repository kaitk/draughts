// The app's screens, with no graphics: home, the game, settings, and the puzzles, and
// which one shows (docs/architecture/rendering.md, "Home", "Game screen";
// docs/architecture/puzzles.md, "The screen"). Each frame it declares the screen showing
// and switches when that asks: home's continue opens the game, a friend and the computer
// open a new game's setup in home's column, whose play starts the game; puzzles opens
// the puzzles to pick from, and a pick plays that puzzle, whose next plays the one after;
// settings opens from home, the game, and a puzzle, and goes back where it came from.
// It holds the settings, keeps the game's move hints and kings in step with them, and
// says when they changed, for the app to write and apply; and where the board goes this
// frame, turned when the child plays black, and how blurred the photograph behind it
// is, and the pieces the screen shows over the UI, for the app to draw. Settings show
// their own board, the preview, beside them; home's setup its own too, the game its play
// starts, at the start of the chosen draughts and turned for a child playing black
// against the computer, which play then starts as it shows.
// Home and settings, home and the game, and the puzzles to pick from and a puzzle switch
// through a transition: the board slides and grows from one's place to the other's
// (home's board sliding to settings', which shows their own once it is there; a
// puzzle's board growing out of its tile), while the screen left fades out and the one
// come to fades in, both drifting a little with the board and hidden where the board
// passes, and the photograph goes from sharp to blurred or back. A tap during it lands
// on the screen come to. The game counts no time and asks the computer for nothing
// until its transition is over.
// Home's way out asks the app to stop (quit), which ends its loop as Escape does.
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
import puzzles from "../puzzles";
import .home;
import .settings;
import .picker;
import .puzzle;

let HOME = 0;
let GAME = 1;
let SETTINGS = 2;
let PICKER = 3;             // the puzzles to pick from
let PUZZLE = 4;             // one puzzle

let DURATION = 0.25;        // seconds a transition takes
let DRIFT = 40.0;           // dp the screens' UI drifts along with the board in one

struct Shell {
    screen:  i64 = HOME,
    game:    game::Game,
    preview: board::Board,                    // the board beside settings, as they make it
    next:    board::Board,                    // the board beside home's setup: the game its play starts
    prefs:   settings::Settings = settings::Settings {},
    changed: bool               = false,      // prefs changed since the app last wrote them
    quit:    bool               = false,      // home's way out was tapped: the app stops
    drawn:   i64                = -1,         // the screen the last frame declared
    back:    i64                = HOME,       // where settings goes back to
    setup:   i64                = home::NOTHING, // home's column: the menu, or a setup
    staged:  bool               = false,      // home shows `next`, having declared a setup this frame
    layout:  board::Layout,                   // where the board is this frame
    // How blurred the photograph is this frame: 0 as it is (home, settings, the puzzles to
    // pick from), 1 blurred and dimmed (the game, a puzzle), between in a transition.
    blur:   f32           = 0.0,
    over:   game::Overlay = [],               // the screen's pieces over the UI this frame
    puzzle: puzzle::Play,                     // the puzzle playing, or last played
    tier:   i64 = 0,                          // the tier a phone's picker shows once a mark is tapped
    // A transition: the screen it leaves, or -1, and when it began; and this frame, how
    // far it has gone, eased, 0..1, and where the screen left and the one come to put the
    // board. `left` is home's column as home had it when left, a setup whose play
    // started the game.
    from:  i64 = -1,
    since: f64 = 0.0,
    mix:   f32 = 1.0,
    went:  board::Layout,
    came:  board::Layout,
    left:  i64 = home::NOTHING,
    // This frame: the screen whose board shows, and where the UI is hidden for the board
    // passing in a transition (x, y, size, corner radius; size 0 at rest).
    shows: i64    = HOME,
    hole:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
}

fn new(variant: u8) -> Shell {
    let g = game::new(variant);
    let l = panel::layout(1.0, 1.0, rules::VARIANTS[variant].size).board;
    return Shell { game: g, preview: board::new(variant), next: board::new(variant), layout: l, puzzle: puzzle::new(),
                   went: l, came: l, .. };
}

// Whether a switch between screens a and b is drawn as a transition.
fn animates(a: i64, b: i64) -> bool { pair(a, b, HOME, SETTINGS) || pair(a, b, HOME, GAME) || pair(a, b, PICKER, PUZZLE) }
fn pair(a: i64, b: i64, x: i64, y: i64) -> bool { (a == x && b == y) || (a == y && b == x) }

// How blurred a screen shows the photograph.
fn blurred(screen: i64) -> f32 { if screen == GAME || screen == PUZZLE { 1.0 } else { 0.0 } }

// How far the transition is at `now`, 0..1; 1 when there is none.
fn progress(sh: Shell&, now: f64) -> f64 {
    return if sh.from < 0 { 1.0 } else { clamp((now - sh.since) / DURATION, 0.0, 1.0) };
}

// Switches to screen `to` at `now`, through a transition where one is drawn. Going back
// to the screen a transition is leaving turns it round where it is.
fn go_to(sh: Shell&, to: i64, now: f64) {
    let p = progress(sh, now);
    let back = sh.from == to && p < 1.0;
    if sh.screen == HOME { sh.left = sh.setup; }
    sh.from = if animates(sh.screen, to) { sh.screen } else { -1 };
    sh.since = if back { now - (1.0 - p) * DURATION } else { now };
    sh.screen = to;
}

// Opens puzzle `index` of puzzles::all at `now`: from the puzzles to pick from through
// a transition, from another puzzle at once.
fn play_puzzle(sh: Shell&, index: i64, now: f64 = 0.0) {
    puzzle::open(sh.puzzle, index);
    sh.tier = 0;
    go_to(sh, PUZZLE, now);
}

// Starts a new game as home's setup stands, replacing the one there was, and goes to it.
// Against the computer it is counted, for the computer's seeds.
fn play(sh: Shell&, now: f64) {
    let p .= sh.prefs;
    let computer = if sh.setup == home::COMPUTER { 1 - p.color } else { -1 };
    game::start(sh.game, p.variant as u8, p.clock, computer, p.level, p.skill[p.level], p.games);
    if computer >= 0 {
        p.games += 1;
        sh.changed = true;
    }
    // The transition shows the setup leaving; home, come back to, shows this game rather
    // than the setup's board.
    go_to(sh, GAME, now);
    sh.setup = home::NOTHING;
    sh.staged = false;
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
    // Time away from the game screen isn't on the clock.
    if sh.screen != GAME { game::pause(sh.game); }
    // In a transition the screen left is declared first, with no pointer, then the screen
    // come to over it. The frame after it ends is drawn, at rest.
    var ended = false;
    if sh.from >= 0 && progress(sh, now) >= 1.0 {
        sh.from = -1;
        ended = true;
    }
    let was = sh.screen;
    let from = sh.from;
    let crossing = from >= 0;
    let e = board::ease(progress(sh, now)) as f32;
    var gone: game::Overlay = [];
    let first = g.quads.len;
    if crossing {
        gui::listen(g, false);
        still(sh, g, from, width, height, now, gone, sh.went);
        gui::listen(g, true);
    }
    let middle = g.quads.len;
    let changed = g.input.pressed || g.input.released;
    var asked = false;
    if sh.screen == GAME { asked = game_screen(sh, g, width, height, now, crossing); }
    else if sh.screen == PUZZLE { asked = puzzle_screen(sh, g, width, height, now); }
    else if sh.screen == PICKER { asked = picker_screen(sh, g, width, height, now); }
    else if sh.screen == SETTINGS { asked = settings_screen(sh, g, width, height, now, fresh); }
    else { asked = home_screen(sh, g, width, height, now); }
    sh.came = sh.layout;
    sh.mix = 1.0;
    // Between home and settings the board is home's all the way: settings show their
    // preview once the board is there, and home's board as soon as they are left, so one
    // set of pieces is ever on screen.
    sh.shows = if crossing && was == SETTINGS { from } else { was };
    if crossing { blend(sh, g, first, middle, gone, e, if sh.shows == was { sh.came } else { sh.went }); }
    sh.hole = if crossing { sh.layout.board } else { float4 { 0.0, 0.0, 0.0, 0.0 } };
    sh.blur = if crossing { blurred(from) + (blurred(was) - blurred(from)) * e } else { blurred(was) };
    // A switch this frame shows what was declared, and what the app fills and draws
    // agrees with it: the start of a transition, the screen left as it stands; one turned
    // round, the same moment of it the other way.
    if sh.screen != was && sh.from >= 0 { sh.mix = if crossing { 1.0 - sh.mix } else { 0.0 }; }
    return changed || asked || ended || crossing;
}

// Where the game puts the board and its panels, turned when the computer plays white.
fn game_layout(sh: Shell&, width: f32, height: f32) -> panel::Layout {
    var l = panel::layout(width, height, rules::VARIANTS[sh.game.b.variant].size);
    l.board.flip = sh.game.computer == rules::WHITE;
    return l;
}

// The game for this frame, `frozen` while its transition runs. Returns whether anything
// on screen changed.
fn game_screen(sh: Shell&, g: gui::Gui&, width: f32, height: f32, now: f64, frozen: bool) -> bool {
    let l = game_layout(sh, width, height);
    sh.layout = l.board;
    let go, changed = game::frame(sh.game, g, l, now, sh.over, frozen);
    // A game against the computer ended: the child meets a stronger or weaker one next.
    let gm .= sh.game;
    if gm.result != 0 {
        let k = clamp(gm.level, game::EASY, game::HARD);
        sh.prefs.skill[k] = ai::adapt(sh.prefs.skill[k], k, gm.result);
        gm.result = 0;
        sh.changed = true;
    }
    if go == game::HOME {
        go_to(sh, HOME, now);
        sh.setup = home::NOTHING;
        return true;
    }
    if go == game::SETTINGS {
        go_to(sh, SETTINGS, now);
        sh.back = GAME;
        return true;
    }
    return changed;
}

// Where a puzzle puts the board and its panels, turned when black is to move.
fn puzzle_layout(sh: Shell&, width: f32, height: f32) -> panel::Layout {
    let pl .= sh.puzzle;
    var l = panel::layout(width, height, rules::VARIANTS[pl.b.variant].size);
    l.board.flip = puzzle::current(pl).start.side == rules::BLACK;
    return l;
}

// The puzzle for this frame. Returns whether anything on screen changed.
fn puzzle_screen(sh: Shell&, g: gui::Gui&, width: f32, height: f32, now: f64) -> bool {
    let pl .= sh.puzzle;
    pl.b.king_look = settings::king_look(sh.prefs);
    let l = puzzle_layout(sh, width, height);
    sh.layout = l.board;
    let go, changed = puzzle::frame(pl, g, l, now, sh.over);
    // Solved: the stars kept are the most it has won.
    if pl.fresh {
        let id = puzzle::current(pl).id;
        if pl.won > sh.prefs.stars[id] {
            sh.prefs.stars[id] = pl.won as u8;
            sh.changed = true;
        }
    }
    if go == puzzle::PUZZLES { go_to(sh, PICKER, now); }
    if go == puzzle::SETTINGS {
        go_to(sh, SETTINGS, now);
        sh.back = PUZZLE;
    }
    if go == puzzle::NEXT {
        if pl.index + 1 < puzzles::all.list.len { play_puzzle(sh, pl.index + 1, now); } else { go_to(sh, PICKER, now); }
    }
    return changed || go != puzzle::STAY;
}

// The board of the puzzle playing, small in its tile on the puzzles to pick from, which
// it grows out of and shrinks back into in a transition.
fn in_tile(sh: Shell&, spot: float4, scale: f32) -> board::Layout {
    let pl .= sh.puzzle;
    var l = board::layout_at(spot.x, spot.y, spot.z, scale, rules::VARIANTS[pl.b.variant].size);
    l.flip = puzzle::current(pl).start.side == rules::BLACK;
    return l;
}

// The puzzles to pick from for this frame. Returns whether anything on screen changed.
fn picker_screen(sh: Shell&, g: gui::Gui&, width: f32, height: f32, now: f64) -> bool {
    sh.over.clear();
    var spot = float4 { 0.0, 0.0, 0.0, 0.0 };
    let pick = picker::frame(g, width, height, sh.prefs.stars, sh.puzzle.index, sh.tier, spot);
    if pick == picker::BACK {
        go_to(sh, HOME, now);
        sh.setup = home::NOTHING;
    } else if pick >= 0 {
        play_puzzle(sh, pick, now);
    }
    // No board at rest: it lies off the screen. Coming from a puzzle, or going to one,
    // it is the puzzle's, in its tile.
    if sh.from == PUZZLE || pick >= 0 { sh.layout = in_tile(sh, spot, g.scale); }
    else { sh.layout = board::layout_at(-2.0 * width, 0.0, 0.5 * width, g.scale, sh.layout.n); }
    return pick != picker::NOTHING;
}

// A transition's frame, both screens declared, the one left's quads first..middle and
// its pieces over the UI in `gone`, at e of the way, eased: the first fades out and the
// second in, both drifting the way the board moves, and the board eases from the one's
// place to the other's, with the squares and turn of `own`, the end whose board shows.
fn blend(sh: Shell&, g: gui::Gui&, first: i64, middle: i64, gone: game::Overlay&, e: f32, own: board::Layout) {
    sh.mix = e;
    let a = sh.went;
    let b = sh.came;
    let way = float2 { b.board.x - a.board.x + 0.5 * (b.board.z - a.board.z),
                       b.board.y - a.board.y + 0.5 * (b.board.z - a.board.z) };
    let far = length(way);
    let drift = if far > 0.0 { way * (DRIFT * g.scale / far) } else { float2 { 0.0, 0.0 } };
    let out = drift * e;
    let into = drift * (e - 1.0);
    gui::fade(g, first, middle, 1.0 - e, out);
    gui::fade(g, middle, g.quads.len, e, into);
    sh.layout = board::layout_at(a.board.x + (b.board.x - a.board.x) * e, a.board.y + (b.board.y - a.board.y) * e,
                                 a.board.z + (b.board.z - a.board.z) * e, g.scale, own.n);
    sh.layout.flip = own.flip;
    // The pieces over the UI likewise, the screen left's first.
    var both: game::Overlay = [];
    for p in gone { put(both, p, 1.0 - e, out); }
    for p in sh.over { put(both, p, e, into); }
    sh.over = both;
}

// A piece over the UI at opacity a, moved by d.
fn put(over: game::Overlay&, p: board::Piece, a: f32, d: float2) {
    guard over.len < panel::OVER else { return; }
    var q = p;
    q.at.x += floor(d.x + 0.5);
    q.at.y += floor(d.y + 0.5);
    q.look.w *= a;
    over.push(q);
}

// Settings for this frame. Returns whether anything on screen changed.
fn settings_screen(sh: Shell&, g: gui::Gui&, width: f32, height: f32, now: f64, fresh: bool) -> bool {
    // The preview shows the settings as they are on opening and after each change; on
    // opening, its wrong move flashes once the board has arrived.
    if fresh { settings::stage(sh.preview, sh.prefs, now + (1.0 - progress(sh, now)) * DURATION); }
    let changed = board::update(sh.preview, now);
    let ask = settings::frame(sh.prefs, sh.over, g, sh.layout, width, height, strings::current);
    if ask == settings::CHANGED {
        sh.game.b.hints = sh.prefs.hints;
        settings::stage(sh.preview, sh.prefs, now);
        sh.changed = true;
    }
    if ask == settings::BACK { go_to(sh, sh.back, now); }
    return changed || ask != settings::NOTHING;
}

// Home for this frame. Returns whether anything on screen changed.
fn home_screen(sh: Shell&, g: gui::Gui&, width: f32, height: f32, now: f64) -> bool {
    // On the menu the board is the game as it stands; in a setup, the game its play
    // starts, set up afresh when the draughts chosen changes. The board switches at once,
    // as the column does. A tap that changes the setup shows on the next frame, the board
    // and the column together: this one shows what it declared.
    sh.staged = sh.setup != home::NOTHING;
    var changed = false;
    if sh.staged && sh.next.variant != sh.prefs.variant as u8 {
        board::reset(sh.next, sh.prefs.variant as u8);
        changed = true;
    }
    let b .= board_of(sh, HOME);
    if board::update(b, now) { changed = true; }
    let flip = turned(sh, sh.setup);
    let pick = home::frame(sh.over, g, sh.layout, rules::VARIANTS[b.variant].size, width, height, sh.setup, sh.prefs);
    sh.layout.flip = flip;
    if pick != home::NOTHING { changed = true; }
    match pick {
        home::SETTINGS => {
            go_to(sh, SETTINGS, now);
            sh.back = HOME;
        },
        home::CONTINUE => { go_to(sh, GAME, now); },
        home::PUZZLES => { go_to(sh, PICKER, now); },
        home::FRIEND => { sh.setup = home::FRIEND; },
        home::COMPUTER => { sh.setup = home::COMPUTER; },
        home::BACK => { sh.setup = home::NOTHING; },
        home::CHANGED => { sh.changed = true; },
        home::EXIT => { sh.quit = true; },
        home::PLAY => { play(sh, now); },
        _ => {},
    }
    return changed;
}

// Declares `screen`, the one a transition leaves, as it stands, its pieces over the UI
// put in `over`, and sets l to where it puts the board. It acts on nothing: the caller
// has taken the pointer away, and the game's clocks are paused.
fn still(sh: Shell&, g: gui::Gui&, screen: i64, width: f32, height: f32, now: f64, over: game::Overlay&,
         l: board::Layout&) {
    if screen == SETTINGS {
        settings::frame(sh.prefs, over, g, l, width, height, strings::current);
    } else if screen == GAME {
        let p = game_layout(sh, width, height);
        game::still(sh.game, g, p, now, over);
        l = p.board;
    } else if screen == PUZZLE {
        let p = puzzle_layout(sh, width, height);
        puzzle::panel_frame(sh.puzzle, g, p, now);
        l = p.board;
    } else if screen == PICKER {
        var spot = float4 { 0.0, 0.0, 0.0, 0.0 };
        picker::frame(g, width, height, sh.prefs.stars, sh.puzzle.index, sh.tier, spot);
        l = in_tile(sh, spot, g.scale);
    } else {
        home::frame(over, g, l, rules::VARIANTS[board_of(sh, HOME).variant].size, width, height, sh.left, sh.prefs);
        l.flip = turned(sh, sh.left);
    }
}

// Whether home's board is turned with its column showing `setup`, for a child playing
// black against the computer: in the game as it stands on the menu, and in the
// computer's setup when black is chosen.
fn turned(sh: Shell&, setup: i64) -> bool {
    return if setup == home::COMPUTER { sh.prefs.color == rules::BLACK }
           else if setup == home::FRIEND { false }
           else { sh.game.computer == rules::WHITE };
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

// The board a screen shows: settings their preview, a puzzle its own (and the puzzles to
// pick from, which show it only in a transition with it), home's setup the game its play
// starts, the other screens the game's.
fn board_of(sh: Shell&, screen: i64) -> board::Board& {
    return if screen == SETTINGS { sh.preview } else if screen == PUZZLE || screen == PICKER { sh.puzzle.b }
           else if screen == HOME && sh.staged { sh.next } else { sh.game.b };
}
fn which(screen: i64) -> i64 {
    if screen == SETTINGS { SETTINGS } else if screen == PUZZLE || screen == PICKER { PUZZLE } else { GAME }
}

// The board on screen at rest.
fn shown(sh: Shell&) -> board::Board& { board_of(sh, sh.screen) }

// Fills the board this frame shows (sh.shows) for the frame at `now`, where sh.layout
// puts it, and returns it for the app to draw; the game's with its win (game::cheer),
// which fades with the game screen in a transition.
fn fill(sh: Shell&, now: f64) -> board::Board& {
    let b .= board_of(sh, sh.shows);
    board::fill(b, sh.layout, now);
    let share = if sh.screen == GAME { sh.mix } else if sh.from == GAME { 1.0 - sh.mix } else { 0.0 };
    if share > 0.0 && which(sh.shows) == GAME { game::cheer(sh.game, sh.layout, now, share); }
    return b;
}

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(sh: Shell&, g: gui::Gui&, now: f64) -> bool {
    if sh.from >= 0 { return true; }
    return if sh.screen == GAME { game::animating(sh.game, g, now) }
           else if sh.screen == PUZZLE { puzzle::animating(sh.puzzle, g, now) }
           else { board::animating(shown(sh), now) || gui::animating(g) };
}
