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
// With the 3D board chosen (settings::raised) every screen with a board shows it: home's
// and settings' fitted into the room they give it, the game and a puzzle round it in the
// corners layout (panel::corners_in). A transition then moves and scales the one image
// of it, drawn once through the larger end's view, from one end's bounds to the other's
// (a puzzle's tile, which has no 3D board, crossfading it in or out).
// Home's way out asks the app to stop (quit), which ends its loop. Android's back, and
// Escape on the Mac, go back a screen as its own back control does (back).
// A game against the computer plays at the skill kept for its level, which each
// finished game moves (ai::adapt). Tests run it headless. What is kept of the game is in
// saved.goose, switching and changing players in roster.goose.
namespace shell;
import std;
import vec;
import os;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import strings from "../../strings";
import ai from "../ai";
import puzzles from "../puzzles";
import .home;
import .settings;
import .picker;
import .puzzle;
import .players;
import .who;
import .saved;
import .roster;

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
    prefs:   settings::Settings = settings::Settings {},  // the playing player's, and the device's language
    players: players::Players   = players::Players {},
    who:     who::Who           = who::Who {},        // who's playing, over home's menu
    changed: bool               = false,      // prefs changed since the app last wrote them
    quit:    bool               = false,      // home's way out was tapped: the app stops
    drawn:   i64                = -1,         // the screen the last frame declared
    back:    i64                = HOME,       // where settings goes back to
    setup:   i64                = home::NOTHING, // home's column: the menu, or a setup
    staged:  bool               = false,      // home shows `next`, having declared a setup this frame
    layout:  board::Layout,                   // where the board is this frame
    // The 3D board this frame (settings::raised, on a screen showing a board), and the
    // view the app draws it through, sh.layout then the flat square it plays on
    // (view3d::square); where on screen the view's bounds (view.rect) go and how opaque:
    // the bounds and 1 at rest, moving between the ends' in a transition, which `hold`s
    // the image as drawn once. Each end's view this frame, rect.z 0 for none.
    raised: bool = false,
    // Set by the app each frame: whether the 3D board, when chosen, is ready to draw
    // (else it gets ready a step a frame, taps on it left alone), and whether an image of
    // it shows meanwhile (else a still mark in its place: gui::waiting's words).
    ready3d:   bool         = true,
    shown3d:   bool         = true,
    view:      view3d::View = view3d::View {},
    place:     float4       = float4 { 0.0, 0.0, 0.0, 0.0 },
    fade:      f32          = 1.0,
    hold:      bool         = false,
    went_view: view3d::View = view3d::View {},
    came_view: view3d::View = view3d::View {},
    // How blurred the photograph is this frame: 0 as it is (home, settings, the puzzles to
    // pick from), 1 blurred and dimmed (the game, a puzzle), between in a transition.
    blur:   f32           = 0.0,
    over:   game::Overlay = [],               // the screen's pieces over the UI this frame
    puzzle: puzzle::Play,                     // the puzzle playing, or last played
    theme:  i64 = -1,                         // the theme the picker shows, -1 its library
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
    // passing in a transition (x, y, size, corner radius; size 0 at rest), `tall` pixels
    // tall (0 as tall as wide; the 3D board's bounds are wider).
    shows: i64    = HOME,
    hole:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    tall:  f32    = 0.0,
    // Home's 3D board as a drag on it left it: the showcase's swing and tilt (rig::drive),
    // kept while home stays open, eased back to rest as home is left.
    cam: rig::Rig = rig::Rig {},
}

fn new(variant: u8) -> Shell {
    let g = game::new(variant);
    let l = panel::layout(1.0, 1.0, rules::VARIANTS[variant].size).board;
    var sh = Shell { game: g, preview: board::new(variant), next: board::new(variant), layout: l, puzzle: puzzle::new(),
                     went: l, came: l, .. };
    // One player, the fox, until the app reads the players (players::load).
    sh.players.list.push(players::Player { id: 1, .. });
    return sh;
}

// The characters a face draws, for the faces baked with only those (rendering.md,
// "Fonts"): the title, the app's name in every language (home's wordmark), and the
// figures, a clock's time. False for a face that holds every glyph.
fn face_chars(face: i64, set: gui::Chars&) -> bool {
    set.clear();
    if face == gui::TITLE {
        for code, lang in strings::LANGUAGES { gui::add_chars(set, strings::text_of(lang, strings::APP_NAME)); }
        return true;
    }
    if face == gui::FIGURES {
        gui::add_chars(set, clock::CHARS);
        return true;
    }
    return false;
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
    if sh.screen == HOME {
        sh.left = sh.setup;
        rig::settle(sh.cam, now, DURATION);
    }
    sh.from = if animates(sh.screen, to) { sh.screen } else { -1 };
    sh.since = if back { now - (1.0 - p) * DURATION } else { now };
    sh.screen = to;
}

// Opens puzzle `index` of puzzles::all at `now`: from the puzzles to pick from through
// a transition, from another puzzle at once.
fn play_puzzle(sh: Shell&, index: i64, now: f64 = 0.0) {
    puzzle::open(sh.puzzle, index);
    sh.theme = puzzles::all.list[index].theme;
    go_to(sh, PUZZLE, now);
}

// Android's back, or Escape on the Mac, at `now`: what the screen's own back or home
// control does. A setup goes back to home's menu, the game, settings, and the puzzles to
// pick from where their tiles go (home, or where settings came from), a puzzle to its
// theme's page, a theme's page to the library. False, changing nothing, on home's menu,
// which has no way back: there back leaves the app as the system's does, and Escape
// closes the window. In a transition it acts on the screen come to, as a tap does.
fn back(sh: Shell&, now: f64) -> bool {
    if sh.screen == HOME && sh.who.state != who::CLOSED {
        who::back(sh.who);
    } else if sh.screen == HOME {
        guard sh.setup != home::NOTHING else { return false; }
        sh.setup = home::NOTHING;
    } else if sh.screen == SETTINGS {
        go_to(sh, sh.back, now);
    } else if sh.screen == PUZZLE {
        go_to(sh, PICKER, now);
    } else if sh.screen == PICKER && sh.theme >= 0 {
        sh.theme = -1;
    } else {
        go_to(sh, HOME, now);
        sh.setup = home::NOTHING;
    }
    return true;
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

// One frame, after gui::begin, on a screen width × height pixels, each screen laid out in
// its safe area (gui::safe, the insets in g). Returns whether anything on screen changed.
fn frame(sh: Shell&, g: gui::Gui&, width: f32, height: f32, now: f64) -> bool {
    // A switch happens in a frame that declared the old screen, so the first frame of the
    // new one is a change, however long ago the tap was.
    let fresh = sh.drawn != sh.screen;
    sh.drawn = sh.screen;
    let changed = declare(sh, g, gui::safe(g, width, height), now, fresh);
    return changed || fresh;
}

// The puzzles are the set of the player's draughts (puzzles::set_of). The draughts
// change in home's setup, in settings, or with the player; home, where every way to the
// puzzles starts, reads the other set then, and the picker starts at its library. The
// library's own switch reads it at once (load_set).
fn sync_puzzles(sh: Shell&) {
    guard sh.screen == HOME else { return; }
    load_set(sh);
}

// Reads the set of the player's draughts where another is loaded: no puzzle is open, and
// the picker is at its library.
fn load_set(sh: Shell&) {
    guard puzzles::set_of(sh.prefs.variant as u8) != puzzles::loaded else { return; }
    puzzles::load(sh.prefs.variant as u8);
    sh.puzzle = puzzle::new();
    sh.theme = -1;
}

fn declare(sh: Shell&, g: gui::Gui&, area: float4, now: f64, fresh: bool) -> bool {
    sync_puzzles(sh);
    sh.game.b.king_look = king_look(sh);
    sh.went_view = view3d::View {};
    sh.came_view = view3d::View {};
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
        still(sh, g, from, area, now, gone, sh.went);
        gui::listen(g, true);
    }
    let middle = g.quads.len;
    let changed = g.input.pressed || g.input.released;
    // The 3D board not ready yet: a press is the UI's, never the board's (game and puzzle
    // touch the board only when the UI didn't take it); the panels work as ever.
    if waiting3d(sh) && g.input.pressed { g.took = true; }
    var asked = false;
    if sh.screen == GAME { asked = game_screen(sh, g, area, now, crossing); }
    else if sh.screen == PUZZLE { asked = puzzle_screen(sh, g, area, now); }
    else if sh.screen == PICKER { asked = picker_screen(sh, g, area, now); }
    else if sh.screen == SETTINGS { asked = settings_screen(sh, g, area, now, fresh); }
    else { asked = home_screen(sh, g, area, now); }
    sh.came = sh.layout;
    sh.mix = 1.0;
    // Between home and settings the board is home's all the way: settings show their
    // preview once the board is there, and home's board as soon as they are left, so one
    // set of pieces is ever on screen.
    sh.shows = if crossing && was == SETTINGS { from } else { was };
    if crossing { blend(sh, g, first, middle, gone, e, if sh.shows == was { sh.came } else { sh.went }); }
    sh.hole = if crossing { sh.layout.board } else { float4 { 0.0, 0.0, 0.0, 0.0 } };
    sh.tall = 0.0;
    raise(sh, g, crossing, e);
    // With no image of it yet, a still mark where the 3D board goes until it shows.
    if sh.raised && waiting3d(sh) && !sh.shown3d { gui::waiting(g, sh.place, strings::get(strings::BOARD_PREPARING)); }
    sh.blur = if crossing { blurred(from) + (blurred(was) - blurred(from)) * e } else { blurred(was) };
    // A switch this frame shows what was declared, and what the app fills and draws
    // agrees with it: the start of a transition, the screen left as it stands; one turned
    // round, the same moment of it the other way.
    if sh.screen != was && sh.from >= 0 { sh.mix = if crossing { 1.0 - sh.mix } else { 0.0 }; }
    return changed || asked || ended || crossing;
}

// How the boards draw kings: the 3D board's auto is a stack.
fn king_look(sh: Shell&) -> i64 {
    return if settings::raised(sh.prefs) { settings::raised_king_look(sh.prefs) } else { settings::king_look(sh.prefs) };
}

// The 3D board this frame, once both ends of a transition are declared: at rest the
// screen's view; in a transition the image drawn once through the larger end's view and
// moved from the bounds at one end to the other's, `e` of the way. An end with no 3D
// board (a puzzle's tile) gives the bounds fitted into its flat square, the image fading
// in or out there. sh.layout follows the drawn view, so the scene stays the same while
// the image moves.
fn raise(sh: Shell&, g: gui::Gui&, crossing: bool, e: f32) {
    sh.raised = false;
    sh.hold = crossing;
    sh.fade = 1.0;
    let a = if crossing { sh.went_view } else { view3d::View {} };
    let b = sh.came_view;
    let has_a = a.rect.z > 0.0;
    let has_b = b.rect.z > 0.0;
    guard has_a || has_b else { return; }
    sh.raised = true;
    sh.view = if has_a && has_b { if a.k > b.k { a } else { b } } else if has_a { a } else { b };
    // At rest the screen's flat layout stays, which its camera's view may have moved away
    // from (panel::aim); in a transition the drawn view's square.
    guard crossing else {
        sh.place = sh.view.rect;
        return;
    }
    let flip = sh.layout.flip;
    sh.layout = view3d::square(sh.view, g.scale);
    sh.layout.flip = flip;
    let ra = if has_a { a.rect } else { tile_rect(sh.view.rect, sh.went.board) };
    let rb = if has_b { b.rect } else { tile_rect(sh.view.rect, sh.came.board) };
    sh.place = float4 { ra.x + (rb.x - ra.x) * e, ra.y + (rb.y - ra.y) * e, ra.z + (rb.z - ra.z) * e,
                        ra.w + (rb.w - ra.w) * e };
    let fa: f32 = if has_a { 1.0 } else { 0.0 };
    let fb: f32 = if has_b { 1.0 } else { 0.0 };
    sh.fade = fa + (fb - fa) * e;
    sh.hole = float4 { sh.place.x, sh.place.y, sh.place.z, 0.0 };
    sh.tall = sh.place.w;
}

// Bounds of r's shape fitted into the flat square sq (x, y, size), centered.
fn tile_rect(r: float4, sq: float4) -> float4 {
    guard r.z > 0.0 else { return float4 { sq.x, sq.y, sq.z, sq.z }; }
    let h = sq.z * r.w / r.z;
    return float4 { sq.x, sq.y + 0.5 * (sq.z - h), sq.z, h };
}

// The 3D board fitted into `room`, as large as it fits and in its middle, when it is
// chosen (else a view with no bounds), and l set to the flat square it plays on, keeping
// l's turn: home's board and settings' preview.
fn raise_in(sh: Shell&, room: float4, n: i64, u: f32, l: board::Layout&) -> view3d::View {
    guard settings::raised(sh.prefs) && room.z > 0.0 && room.w > 0.0 else { return view3d::View {}; }
    let v = view3d::fit(view3d::Camera {}, n, room, view3d::MIDDLE);
    let flip = l.flip;
    l = view3d::square(v, u);
    l.flip = flip;
    return v;
}

// Where the game puts the board and its panels, turned when the computer plays white:
// round the 3D board when it is chosen (settings::raised), seen as its camera has it at
// `now` (panel::aim), else the flat board's.
fn game_layout(sh: Shell&, area: float4, u: f32, now: f64) -> panel::Layout {
    let n = rules::VARIANTS[sh.game.b.variant].size;
    var l = if settings::raised(sh.prefs) { panel::corners_in(area, n, u, panel::PITCH_PORTRAIT, true, true) }
            else { panel::layout_in(area, n, u, true, true) };
    l.board.flip = sh.game.computer == rules::WHITE;
    panel::aim(l, sh.game.cam, now);
    return l;
}

// The game for this frame, `frozen` while its transition runs. Returns whether anything
// on screen changed.
fn game_screen(sh: Shell&, g: gui::Gui&, area: float4, now: f64, frozen: bool) -> bool {
    var l = game_layout(sh, area, g.scale, now);
    sh.layout = l.board;
    // The lookout as the player's setting has it, against the computer at the game's
    // skill, against a friend at the player's on their level.
    let p .= sh.prefs;
    sh.game.look = p.lookout;
    sh.game.look_skill = if sh.game.computer >= 0 { sh.game.skill } else { p.skill[clamp(p.level, game::EASY, game::HARD)] };
    let go, changed = game::frame(sh.game, g, l, now, sh.over, frozen);
    // Its eye turned on or off: kept in the player's file.
    if sh.game.look != p.lookout {
        p.lookout = sh.game.look;
        sh.changed = true;
    }
    // Drawn through the camera as this frame left it: a button tapped, a showcase drag, or
    // the board facing the side to move shows at once.
    panel::aim(l, sh.game.cam, now);
    if l.three { sh.came_view = l.view; }
    // A game against the computer ended: the child meets a stronger or weaker one next.
    let gm .= sh.game;
    if gm.result != 0 {
        let k = clamp(gm.level, game::EASY, game::HARD);
        sh.prefs.skill[k] = ai::adapt(sh.prefs.skill[k], k, gm.result, sh.prefs.played[k]);
        sh.prefs.played[k] += 1;
        gm.result = 0;
        sh.changed = true;
    }
    // Played again or started over: a new game, at its level's skill as it is now, and
    // counted as home's play counts one. The computer is asked only after this frame, so
    // it thinks at the new skill from the first move.
    if gm.restarted {
        gm.restarted = false;
        if gm.computer >= 0 {
            gm.skill = p.skill[clamp(gm.level, game::EASY, game::HARD)];
            gm.number = p.games;
            p.games += 1;
            sh.changed = true;
        }
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

// Where a puzzle puts the board and its panels, turned when black is to move, so the side
// to move plays from the bottom: round the 3D board when it is chosen, as the game's.
fn puzzle_layout(sh: Shell&, area: float4, u: f32, now: f64) -> panel::Layout {
    let pl .= sh.puzzle;
    let n = rules::VARIANTS[pl.b.variant].size;
    // A puzzle keeps its own play panel's height in a small window for now (task 050).
    var l = if settings::raised(sh.prefs) { panel::corners_in(area, n, u, panel::PITCH_PORTRAIT, false) }
            else { panel::layout_in(area, n, u, false) };
    l.board.flip = puzzle::current(pl).start.side == rules::BLACK;
    panel::aim(l, pl.cam, now);
    return l;
}

// The puzzle for this frame. Returns whether anything on screen changed.
fn puzzle_screen(sh: Shell&, g: gui::Gui&, area: float4, now: f64) -> bool {
    let pl .= sh.puzzle;
    pl.b.king_look = king_look(sh);
    var l = puzzle_layout(sh, area, g.scale, now);
    sh.layout = l.board;
    let go, changed = puzzle::frame(pl, g, l, now, sh.over);
    panel::aim(l, pl.cam, now);
    if l.three { sh.came_view = l.view; }
    // Solved: the stars kept are the most it has won.
    if pl.fresh {
        let id = puzzle::current(pl).id;
        if pl.won > sh.prefs.stars[puzzles::loaded][id] {
            sh.prefs.stars[puzzles::loaded][id] = pl.won as u8;
            sh.changed = true;
        }
    }
    if go == puzzle::PUZZLES { go_to(sh, PICKER, now); }
    if go == puzzle::SETTINGS {
        go_to(sh, SETTINGS, now);
        sh.back = PUZZLE;
    }
    if go == puzzle::NEXT {
        // On inside the theme, and after its last back to the library.
        let i = pl.index + 1;
        if i < puzzles::all.list.len && puzzles::all.list[i].theme == sh.theme { play_puzzle(sh, i, now); }
        else {
            sh.theme = -1;
            go_to(sh, PICKER, now);
        }
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
fn picker_screen(sh: Shell&, g: gui::Gui&, area: float4, now: f64) -> bool {
    sh.over.clear();
    var spot = float4 { 0.0, 0.0, 0.0, 0.0 };
    var variant = sh.prefs.variant;
    let pick = picker::frame(g, area, sh.prefs.stars[puzzles::loaded], sh.puzzle.index, sh.theme, spot, variant);
    if pick == picker::SWITCHED {
        // The library's switch is settings' draughts: new games' too, saved as settings
        // saves it, and home's count over the set it shows. The next frame shows it.
        sh.prefs.variant = variant;
        load_set(sh);
        sh.changed = true;
    } else if pick == picker::BACK {
        go_to(sh, HOME, now);
        sh.setup = home::NOTHING;
    } else if pick >= 0 {
        play_puzzle(sh, pick, now);
    }
    // No board at rest: it lies off the screen. Coming from a puzzle, or going to one,
    // it is the puzzle's, in its tile.
    if sh.from == PUZZLE || pick >= 0 { sh.layout = in_tile(sh, spot, g.scale); }
    else { sh.layout = board::layout_at(-2.0 * area.z, 0.0, 0.5 * area.z, g.scale, sh.layout.n); }
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
fn settings_screen(sh: Shell&, g: gui::Gui&, area: float4, now: f64, fresh: bool) -> bool {
    // The preview shows the settings as they are on opening and after each change; on
    // opening, its wrong move flashes once the board has arrived.
    if fresh { settings::stage(sh.preview, sh.prefs, now + (1.0 - progress(sh, now)) * DURATION); }
    let changed = board::update(sh.preview, now);
    var room = float4 { 0.0, 0.0, 0.0, 0.0 };
    let ask = settings::frame(sh.prefs, sh.over, g, sh.layout, area, strings::current, room);
    sh.came_view = raise_in(sh, room, sh.layout.n, g.scale, sh.layout);
    if ask == settings::CHANGED {
        sh.game.b.hints = sh.prefs.hints;
        settings::stage(sh.preview, sh.prefs, now);
        sh.changed = true;
    }
    if ask == settings::BACK { go_to(sh, sh.back, now); }
    return changed || ask != settings::NOTHING;
}

// Home for this frame. Returns whether anything on screen changed.
fn home_screen(sh: Shell&, g: gui::Gui&, area: float4, now: f64) -> bool {
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
    // Who's playing, over the menu: home under it takes no pointer.
    let card = sh.who.state != who::CLOSED && sh.setup == home::NOTHING;
    if card { gui::listen(g, false); }
    var room = float4 { 0.0, 0.0, 0.0, 0.0 };
    let pick = home::frame(sh.over, g, sh.layout, rules::VARIANTS[b.variant].size, area, sh.setup, sh.prefs, room);
    sh.layout.flip = flip;
    let v = raise_in(sh, room, sh.layout.n, g.scale, sh.layout);
    if !card && turn_home(sh, g, v, room, now) { changed = true; }
    sh.came_view = home_view(sh, v, room, now);
    if card {
        // Home's pieces over its UI (the wordmark's crown, the player's picture) draw
        // after all the UI, so they would sit on the card: under it, home shows without
        // them.
        sh.over.clear();
        gui::listen(g, true);
        if who_card(sh, g, area) { changed = true; }
    }
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
        home::PLAYERS => { who::open(sh.who); },
        home::PLAY => { play(sh, now); },
        _ => {},
    }
    return changed;
}

// Home's 3D board v (raise_in, fitted into `room`) seen as the drags on it left it,
// turned and tipped by the showcase's camera (rig::camera): no larger than at rest, and
// smaller where its bounds at that angle would leave the room, in its middle.
fn home_view(sh: Shell&, v: view3d::View, room: float4, now: f64) -> view3d::View {
    let cam = rig::camera(sh.cam, view3d::PITCH, now);
    guard v.rect.z > 0.0 && (cam.yaw != 0.0 || cam.pitch != view3d::PITCH) else { return v; }
    return view3d::fit(cam, v.n, room, view3d::MIDDLE, v.k);
}

// A drag that starts on home's 3D board v, inside its outline as drawn and off the UI,
// turns and tips it as the game's showcase does (rig::drive, its range and rate); a press
// anywhere else does nothing new. Not in a transition, nor before the 3D board is ready.
// Returns whether it moved.
fn turn_home(sh: Shell&, g: gui::Gui&, v: view3d::View, room: float4, now: f64) -> bool {
    let r .= sh.cam;
    let input .= g.input;
    if input.pressed || v.rect.z <= 0.0 || sh.from >= 0 || waiting3d(sh) { r.held = false; }
    guard v.rect.z > 0.0 && sh.from < 0 && !waiting3d(sh) else { return false; }
    let on = input.pressed && !g.took && view3d::on_board(home_view(sh, v, room, now), input.at);
    guard on || r.held else { return false; }
    return rig::drive(r, input.at, input.down, on, input.released, g.scale, view3d::PITCH, now);
}

// Who's playing over home for this frame, doing what it asks: switching to a player,
// adding one, saving one's picture and name, starting one again, removing one. Returns
// whether anything on screen changed.
fn who_card(sh: Shell&, g: gui::Gui&, area: float4) -> bool {
    let ask, index = who::frame(sh.who, sh.players, g, area, gui::bleed(g, area, area));
    let w .= sh.who;
    match ask {
        who::SWITCH => { switch_player(sh, index); },
        who::CREATE => { add_player(sh, w.picture, w.name); },
        who::SAVE => { edit_player(sh, index, w.picture, w.name); },
        who::AGAIN => { start_again(sh, index); },
        who::REMOVE => { remove_player(sh, index); },
        _ => {},
    }
    return ask != who::NOTHING;
}

// Declares `screen`, the one a transition leaves, as it stands, its pieces over the UI
// put in `over`, and sets l to where it puts the board. It acts on nothing: the caller
// has taken the pointer away, and the game's clocks are paused.
fn still(sh: Shell&, g: gui::Gui&, screen: i64, area: float4, now: f64, over: game::Overlay&,
         l: board::Layout&) {
    var room = float4 { 0.0, 0.0, 0.0, 0.0 };
    if screen == SETTINGS {
        settings::frame(sh.prefs, over, g, l, area, strings::current, room);
        sh.went_view = raise_in(sh, room, l.n, g.scale, l);
    } else if screen == GAME {
        let p = game_layout(sh, area, g.scale, now);
        game::still(sh.game, g, p, now, over);
        l = p.board;
        if p.three { sh.went_view = p.view; }
    } else if screen == PUZZLE {
        let p = puzzle_layout(sh, area, g.scale, now);
        puzzle::panel_frame(sh.puzzle, g, p, now, over);
        l = p.board;
        if p.three { sh.went_view = p.view; }
    } else if screen == PICKER {
        var spot = float4 { 0.0, 0.0, 0.0, 0.0 };
        var variant = sh.prefs.variant;
        picker::frame(g, area, sh.prefs.stars[puzzles::loaded], sh.puzzle.index, sh.theme, spot, variant);
        l = in_tile(sh, spot, g.scale);
    } else {
        home::frame(over, g, l, rules::VARIANTS[board_of(sh, HOME).variant].size, area, sh.left, sh.prefs, room);
        l.flip = turned(sh, sh.left);
        sh.went_view = home_view(sh, raise_in(sh, room, l.n, g.scale, l), room, now);
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

// Whether the 3D board is chosen but not ready to draw (sh.ready3d).
fn waiting3d(sh: Shell&) -> bool { settings::raised(sh.prefs) && !sh.ready3d }

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(sh: Shell&, g: gui::Gui&, now: f64) -> bool {
    if sh.from >= 0 { return true; }
    return if sh.screen == GAME { game::animating(sh.game, g, now) }
           else if sh.screen == PUZZLE { puzzle::animating(sh.puzzle, g, now) }
           else { board::animating(shown(sh), now) || gui::animating(g) || rig::moving(sh.cam, now) };
}
