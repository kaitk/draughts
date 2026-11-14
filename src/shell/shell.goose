// The app's screens, with no graphics: home, the game, settings, and the puzzles, and
// which one shows (docs/architecture/rendering.md, "Home", "Game screen";
// docs/architecture/puzzles.md, "The screen"). Each frame it declares the screen showing
// and switches when that asks: home's continue opens the game, new game opens
// the setup in home's column, whose play starts the game; puzzles opens
// the puzzles to pick from, and a pick plays that puzzle, whose next plays the one after;
// settings opens from home, the game, and a puzzle, and goes back where it came from.
// It holds the settings, puts them where they act (apply_prefs), and
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
// Home's way out asks the app to stop (quit), which ends its loop; on a desktop it asks
// first (home::ask_quit), as back on home's menu does there. Android's back, and Escape or
// a gamepad's B on a desktop, go back a screen as its own back control does (back).
// A game against the computer plays at the skill kept for its level, which each
// finished game moves (ai::adapt). A replay's play from here plays a past game on from
// the move shown on the game screen, the game in progress set aside meanwhile
// (play_from_here): that game counts for nothing, and its way out goes back to the
// replay. Tests run it headless. What is kept of the game is in
// saved.goose, switching and changing players in roster.goose, the results, a replay, and
// a game from it in past.goose, how to play in lessons.goose.
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
import .history;
import .record;
import .results;
import .replay;
import .tutorial;
import .past;
import .lessons;
import .today;

let HOME = 0;
let GAME = 1;
let SETTINGS = 2;
let PICKER = 3;             // the puzzles to pick from
let PUZZLE = 4;             // one puzzle
let RESULTS = 5;            // the games played (results.goose, task 074)
let REPLAY = 6;             // a past game replayed (replay.goose, task 078)
let TUTORIAL = 7;           // how to play (tutorial.goose, task 026)
let SCREENS = 8;

// What sets the screens apart where the shell runs none of their code: whose board each
// shows (board_of; home's setup shows its own), how blurred it shows the photograph,
// where back goes, which switches to or from it are drawn as a transition, and the screen
// a game kept on it comes back on (saved.goose). Their
// code is chosen in the three functions after the table, its frame, its still frame,
// and whether it moves: a new screen is a row here and an arm in each.
struct Kind {
    board: i64,     // GAME the game's, SETTINGS the preview, PUZZLE the puzzle's, REPLAY the replay's, TUTORIAL its own
    blur:  f32,     // 0 the photograph as it is, 1 blurred and dimmed
    up:    i64,     // where back goes: a screen, NO_WAY on home's menu, RETURN where it was opened from
    with:  i64,     // the screens it switches to and from through a transition, a bit each
    kept:  i64,     // the screen a game kept while it shows comes back on
}
let NO_WAY = -1;
let RETURN = -2;            // sh.back
let KINDS: Kind[SCREENS] = [
    Kind { board: GAME, blur: 0.0, up: NO_WAY, with: (1 << GAME) | (1 << SETTINGS), kept: HOME },     // HOME
    Kind { board: GAME, blur: 1.0, up: HOME, with: 1 << HOME, kept: GAME },                           // GAME
    Kind { board: SETTINGS, blur: 0.0, up: RETURN, with: 1 << HOME, kept: SETTINGS },                 // SETTINGS
    Kind { board: PUZZLE, blur: 0.0, up: HOME, with: 1 << PUZZLE, kept: PICKER },                     // PICKER
    Kind { board: PUZZLE, blur: 1.0, up: PICKER, with: 1 << PICKER, kept: PICKER },                   // PUZZLE
    Kind { board: PUZZLE, blur: 0.0, up: HOME, with: 0, kept: HOME },                                 // RESULTS
    Kind { board: REPLAY, blur: 1.0, up: RESULTS, with: 0, kept: HOME },                              // REPLAY
    Kind { board: TUTORIAL, blur: 1.0, up: RETURN, with: 0, kept: HOME },                             // TUTORIAL
];

let DURATION = 0.25;        // seconds a transition takes
let DRIFT = 40.0;           // dp the screens' UI drifts along with the board in one

// What a frame of the shell leaves for the app, each field set every frame (frame) but
// `quit`. The app reads it and writes none of it; it lives in the shell (Shell.out) and is passed by
// reference, so its pieces aren't copied.
struct Frame {
    changed: bool = false,          // anything on screen changed
    screen:  i64  = HOME,           // the screen showing
    // The screen whose board shows: in a transition between home and settings, home's.
    shows:  i64 = HOME,
    layout: board::Layout,           // where the board is
    over:   board::Overlay = [],     // the screen's pieces over the UI
    // How blurred the photograph is: 0 as it is (home, settings, the puzzles to pick
    // from), 1 blurred and dimmed (the game, a puzzle), between in a transition.
    blur: f32 = 0.0,
    // Where the UI is hidden for the board passing in a transition (x, y, size, corner
    // radius; size 0 at rest), `tall` pixels tall (0 as tall as wide; the 3D board's
    // bounds are wider).
    hole: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    tall: f32    = 0.0,
    // The 3D board this frame (settings::raised, on a screen showing a board), and the
    // view the app draws it through, `layout` then the flat square it plays on
    // (view3d::square); where on screen the view's bounds (view.rect) go and how opaque:
    // the bounds and 1 at rest, moving between the ends' in a transition, which `hold`s
    // the image as drawn once.
    raised: bool         = false,
    view:   view3d::View = view3d::View {},
    place:  float4       = float4 { 0.0, 0.0, 0.0, 0.0 },
    fade:   f32          = 1.0,
    hold:   bool         = false,
    // A player's name typed (who's playing): the keyboard up, and brought up again each
    // time `keyboard` counts a tap on the name.
    typing:   bool = false,
    keyboard: i64  = 0,
    // The settings changed, and no transition runs: the app writes them and applies what
    // is its own (the language, the season's photograph). Once a transition is over for
    // a change made by the tap that started it: the write flushes to disk, 13 to 17 ms on
    // the tablet, too long for the frame that starts it moving.
    save: bool = false,
    quit: bool = false,             // home's way out was tapped: the app stops (stays set)
}

// What the app does with the 3D board before a frame (board3d): it is chosen, so the app
// gets it ready; it isn't, but settings show (it may be chosen again there) or a
// transition runs, so the app keeps it; or the app gives it back.
let WANTED = 0;
let KEPT = 1;
let DROPPED = 2;

struct Shell {
    screen:   i64 = HOME,
    game:     game::Game,
    preview:  board::Board,                   // the board beside settings, as they make it
    next:     board::Board,                   // the board beside home's setup: the game its play starts
    prefs:    settings::Settings = settings::Settings {}, // the playing player's, and the device's language
    players:  players::Players   = players::Players {},
    who:      who::Who           = who::Who {},       // who's playing, over home's menu
    quitting: bool               = false,     // a desktop's quit asks first, over home's menu (home::ask_quit)
    changed:  bool               = false,     // prefs changed since the app last wrote them (Frame.save)
    drawn:    i64                = -1,        // the screen the last frame declared
    back:     i64                = HOME,      // where settings goes back to
    setup:    i64                = home::NO_SETUP, // home's column: the menu, or a setup
    staged:   bool               = false,     // home shows `next`, having declared a setup this frame
    // The game is one nobody set up, there being none kept (read_game: a fresh install, a
    // new player), until a game is set up or a move played in it (resume). Kept with the
    // game (saved.goose).
    unset: bool = false,
    out:   Frame,                             // this frame's, for the app
    // Handed in by the app each frame (frame): whether the 3D board, when chosen, is
    // ready to draw (else it gets ready a step a frame, taps on it left alone), and
    // whether an image of it shows meanwhile (else a still mark in its place:
    // gui::waiting's words).
    ready3d: bool = true,
    shown3d: bool = true,
    // Each end's 3D view this frame, rect.z 0 for none (raise).
    went_view: view3d::View = view3d::View {},
    came_view: view3d::View = view3d::View {},
    puzzle:    puzzle::Play,                  // the puzzle playing, or last played
    // How to play (task 026), and the screen it was opened from, where its back goes:
    // home (its row, or a new player's question) or the puzzles' library.
    lesson:      tutorial::Lesson,
    lesson_from: i64 = HOME,
    theme:       i64 = -1,                    // the theme the picker shows, -1 its library
    // A transition: the screen it leaves, or -1, and when it began; and this frame, how
    // far it has gone, eased, 0..1, and where the screen left and the one come to put the
    // board. `left` is home's column as home had it when left, a setup whose play
    // started the game.
    from:  i64 = -1,
    since: f64 = 0.0,
    mix:   f32 = 1.0,
    went:  board::Layout,
    came:  board::Layout,
    left:  i64 = home::NO_SETUP,
    // Home's 3D board as a drag on it left it: the showcase's swing and tilt (rig::drive),
    // kept while home stays open, eased back to rest as home is left.
    cam: rig::Rig = rig::Rig {},
    // The setup's board turning once round when a friend's board is switched to Turns, to
    // show what it does: the 3D board eases a full turn, the flat one shows black's side
    // for the middle half of it.
    demo: rig::Ease = rig::Ease { soft: true, .. },
    // The game last written to the player's history, its marks perhaps still coming
    // (record.goose), and the time now in seconds since the epoch where a test sets it,
    // else -1 for the clock's.
    kept: Kept = Kept {},
    wall: f64  = -1.0,
    past: Past,                               // the results, a replay, and a game from it (past.goose)
    // A file the games are read from in place of the playing player's history, for
    // screenshots (the app's --history), or empty.
    history_file: u8[..512] = [],
    // The daily puzzles (today.goose, task 088): the local date, days since the epoch, as
    // the app hands it in (frame's `day`; a test sets it here), -1 while unknown; the set
    // whose library is read (puzzles::load_library), -1 none, and its text, the library's
    // built-in file (a test may index its own into puzzles::library and set it here); and
    // today's puzzles read from it.
    day:          i64         = -1,
    library:      i64         = -1,
    library_text: const u8[:] = "",
    daily:        Daily       = Daily {},
}

// The screen showing for this frame, taking the pointer and doing what it asks: `fresh`
// its first frame, `crossing` in a transition to it. Returns whether anything on screen
// changed.
fn screen_frame(sh: Shell&, g: gui::Gui&, area: float4, now: f64, fresh: bool, crossing: bool) -> bool {
    return match sh.screen {
        GAME => game_screen(sh, g, area, now, crossing),
        SETTINGS => settings_screen(sh, g, area, now, fresh),
        PICKER => picker_screen(sh, g, area, now),
        PUZZLE => puzzle_screen(sh, g, area, now),
        RESULTS => results_screen(sh, g, area, now, fresh),
        REPLAY => replay_screen(sh, g, area, now, fresh),
        TUTORIAL => tutorial_screen(sh, g, area, now),
        _ => home_screen(sh, g, area, now),
    };
}

// Declares `screen`, the one a transition leaves, as it stands, its pieces over the UI
// put in `over`, and sets l to where it puts the board. It acts on nothing: the caller
// has taken the pointer away, and the game's clocks are paused.
fn still(sh: Shell&, g: gui::Gui&, screen: i64, area: float4, now: f64, over: board::Overlay&,
         l: board::Layout&) {
    var room = float4 { 0.0, 0.0, 0.0, 0.0 };
    match screen {
        GAME => {
            let p = game_layout(sh, area, g.scale, now);
            game::still(sh.game, g, p, now, over);
            l = p.board;
            if p.three { sh.went_view = p.view; }
        },
        SETTINGS => {
            settings::frame(sh.prefs, over, g, l, area, strings::current, room);
            sh.went_view = raise_in(sh, room, l.n, g.scale, l);
        },
        PICKER => {
            var spot = float4 { 0.0, 0.0, 0.0, 0.0 };
            var variant = sh.prefs.variant;
            picker::frame(g, area, sh.prefs.stars[puzzles::loaded], sh.puzzle.index, sh.theme, spot, variant,
                          learned(sh), tutorial::count(sh.prefs.variant as u8), today_of(sh), sh.puzzle.daily);
            l = in_tile(sh, spot, g.scale);
        },
        PUZZLE => {
            let p = puzzle_layout(sh, area, g.scale, now);
            puzzle::panel_frame(sh.puzzle, g, p, now, over);
            l = p.board;
            if p.three { sh.went_view = p.view; }
        },
        RESULTS => {
            var variant = sh.past.variant;
            results::frame(g, area, sh.prefs, sh.past.games, variant);
            l = board::layout_at(-2.0 * area.z, 0.0, 0.5 * area.z, g.scale, l.n);
        },
        _ => {
            home::frame(over, g, l, rules::VARIANTS[board_of(sh, HOME).variant].size, area, sh.left, sh.prefs, room, resume(sh));
            l.flip = turned(sh, sh.left);
            sh.went_view = home_view(sh, raise_in(sh, room, l.n, g.scale, l), room, now);
        },
    }
}

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(sh: Shell&, g: gui::Gui&, now: f64) -> bool {
    if sh.from >= 0 { return true; }
    return match sh.screen {
        GAME => game::animating(sh.game, g, now) || flat_fade(sh, now) <= 1.0,
        PUZZLE => puzzle::animating(sh.puzzle, g, now),
        TUTORIAL => tutorial::animating(sh.lesson, g, now),
        REPLAY => replay::animating(sh.past.replay, now) || gui::animating(g),
        _ => board::animating(shown(sh), now) || gui::animating(g) || rig::moving(sh.cam, now)
             || (sh.screen == HOME && rig::moving(sh.demo, now)),
    };
}

fn new(variant: u8) -> Shell {
    let g = game::new(variant);
    let l = panel::layout(1.0, 1.0, rules::VARIANTS[variant].size).board;
    var sh = Shell { game: g, preview: board::new(variant), next: board::new(variant), out: Frame { layout: l, .. },
                     puzzle: puzzle::new(), lesson: tutorial::new(), went: l, came: l, past: Past { replay: replay::new(), parked: default<Parked>(), .. }, .. };
    // One player, the fox, until the app reads the players (players::load).
    sh.players.list.push(players::Player { id: 1, .. });
    apply_prefs(sh);
    return sh;
}

// Puts the player's settings where they act: the game's move hints and lookout, the
// kings on the game's board and the puzzle's, and the skill whose plain threats the
// lookout leaves to the player (against the computer the game's, against a friend the
// player's on their level). Called whenever the settings change, the shell's own
// changes and another player's settings read, and whenever a game starts or the puzzle
// is new; the app calls it once the flags have set the settings at launch.
fn apply_prefs(sh: Shell&) {
    let p .= sh.prefs;
    let gm .= sh.game;
    gm.b.hints = p.hints;
    gm.b.king_look = king_look(sh);
    sh.puzzle.b.king_look = king_look(sh);
    sh.lesson.b.king_look = king_look(sh);
    gm.look = p.lookout;
    gm.moves_shown = p.moves;
    gm.turns = p.turns;
    gm.look_skill = if gm.computer >= 0 { gm.skill } else { p.skill[clamp(p.level, game::EASY, game::HARD)] };
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
fn animates(a: i64, b: i64) -> bool { (KINDS[a].with >> b) & 1 != 0 }

// How blurred a screen shows the photograph.
fn blurred(screen: i64) -> f32 { KINDS[screen].blur }

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

// Goes back up to screen `to` at `now`: home, come back to, shows its menu.
fn go_up(sh: Shell&, to: i64, now: f64) {
    go_to(sh, to, now);
    if to == HOME { sh.setup = home::NO_SETUP; }
}

// Opens settings at `now` from screen `from`, where their back goes.
fn open_settings(sh: Shell&, from: i64, now: f64) {
    go_to(sh, SETTINGS, now);
    sh.back = from;
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
// theme's page, a theme's page to the library. On home's menu, which has no way back, a
// desktop asks whether to quit (home::ask_quit), and back again cancels that; elsewhere
// it is false, changing nothing: there back leaves the app as the system's does. In a
// transition it acts on the screen come to, as a tap does.
fn back(sh: Shell&, now: f64) -> bool {
    // The game's moves' sheet, or a mark's tip, closes first (task 078); so does settings'
    // language list.
    if sh.screen == GAME && game::close_sheet(sh.game) { return true; }
    if sh.screen == SETTINGS && sh.prefs.languages_open {
        sh.prefs.languages_open = false;
        return true;
    }
    // A game from the replay goes back to it.
    if sh.screen == GAME && sh.past.trial {
        leave_trial(sh, now);
        return true;
    }
    // How to play goes back where it was opened from, its end's card too.
    if sh.screen == TUTORIAL {
        go_up(sh, sh.lesson_from, now);
        return true;
    }
    if sh.screen == HOME && sh.who.state != who::CLOSED {
        who::back(sh.who);
    } else if sh.screen == HOME && sh.quitting {
        sh.quitting = false;
    } else if sh.screen == HOME {
        guard sh.setup != home::NO_SETUP else {
            guard home::asks_quit() else { return false; }
            sh.quitting = true;
            return true;
        }
        sh.setup = home::NO_SETUP;
    } else if sh.screen == PICKER && sh.theme >= 0 {
        sh.theme = -1;
    } else {
        let up = KINDS[sh.screen].up;
        if up == RETURN { go_to(sh, sh.back, now); } else { go_up(sh, up, now); }
    }
    return true;
}

// Back with the keys on the game's or a puzzle's board (board::keys): a piece chosen there
// is put down, as a desktop's Escape lets go of what it holds, rather than the screen
// left (back). False, changing nothing, with none chosen or one partway through a capture.
fn put_down(sh: Shell&, g: gui::Gui&) -> bool {
    guard (sh.screen == GAME || sh.screen == PUZZLE || sh.screen == TUTORIAL) && g.focus == panel::BOARD_ID else { return false; }
    return board::put_down(shown(sh));
}

// Starts a new game as home's setup stands, replacing the one there was, and goes to it.
// Against the computer it is counted, for the computer's seeds.
fn play(sh: Shell&, now: f64) {
    let p .= sh.prefs;
    let computer = if p.friend { -1 } else { 1 - p.color };
    game::start(sh.game, p.variant as u8, p.clock, computer, p.level, p.skill[p.level], p.games);
    if computer >= 0 {
        p.games += 1;
        sh.changed = true;
    }
    apply_prefs(sh);
    // The transition shows the setup leaving; home, come back to, shows this game rather
    // than the setup's board.
    go_to(sh, GAME, now);
    sh.setup = home::NO_SETUP;
    sh.staged = false;
    sh.unset = false;
}

// What home's continue goes back to: the game and whose it is; none while the game is
// one nobody set up (`unset`) with no move played (issue 1).
fn resume(sh: Shell&) -> home::Resume {
    let gm .= sh.game;
    let on = !sh.unset || gm.b.history.len > 0 || gm.computer >= 0;
    // A new player, asked whether they know how to play (`first_start_done`), who hasn't
    // learned their draughts, nor said they know how, nor begun a game against the
    // computer: How to play in continue's place (task 026).
    let p .= sh.prefs;
    let learn = !on && p.first_start_done && !p.knows && p.games == 0 && learned(sh) < tutorial::count(p.variant as u8);
    return home::Resume { on: on, note: home::resume_note(gm.computer, gm.level), learn: learn };
}

// One frame, after gui::begin, on a screen width × height pixels, each screen laid out in
// its safe area (gui::safe, the insets in g). The app hands in what only it knows: whether
// the 3D board, when chosen, is ready to draw, and whether an image of it shows
// (Shell.ready3d), and the local date (Shell.day; -1 leaves it as it is). Returns what the
// frame leaves for the app (Frame).
fn frame(sh: Shell&, g: gui::Gui&, width: f32, height: f32, now: f64, ready3d: bool = true,
         shown3d: bool = true, day: i64 = -1) -> Frame& {
    sh.ready3d = ready3d;
    sh.shown3d = shown3d;
    if day >= 0 { sh.day = day; }
    // A switch happens in a frame that declared the old screen, so the first frame of the
    // new one is a change, however long ago the tap was.
    let fresh = sh.drawn != sh.screen;
    sh.drawn = sh.screen;
    let changed = declare(sh, g, gui::safe(g, width, height), now, fresh);
    keep_marks(sh);
    let out .= sh.out;
    out.changed = changed || fresh;
    out.screen = sh.screen;
    out.typing = sh.who.typing && sh.screen == HOME;
    out.keyboard = sh.who.keyboard;
    out.save = sh.changed && sh.from < 0;
    return sh.out;
}

// The app has written the settings Frame.save asked it to.
fn wrote(sh: Shell&) { sh.changed = false; }

// What the app does with the 3D board before this frame: WANTED, KEPT, or DROPPED.
fn board3d(sh: Shell&) -> i64 {
    return if settings::raised(sh.prefs) { WANTED } else if sh.screen == SETTINGS || sh.from >= 0 { KEPT } else { DROPPED };
}

// How many squares a side the board the last frame laid out has (before the first, the
// player's draughts'): the 3D board the app gets ready.
fn board_n(sh: Shell&) -> i64 { if sh.out.layout.n > 0 { sh.out.layout.n } else { rules::VARIANTS[sh.prefs.variant].size } }

// The game's clocks count nothing until the frame after the next (game::pause): the app
// lost focus or was paused.
fn pause(sh: Shell&) { game::pause(sh.game); }

// Seconds from `now` until the app should wake to draw though nothing else wakes it, or
// -1 for none: on the game screen, a running clock's next change of what it shows, the
// computer's move once due, or a look soon for the hint's answer, which no frame of its
// own waits for (`poll` seconds).
fn wake_in(sh: Shell&, now: f64, poll: f64) -> f64 {
    guard sh.screen == GAME else { return -1.0; }
    var next = clock::until_next(sh.game.clock);
    let due = game::due(sh.game, now);
    if due >= 0.0 && (next < 0.0 || due < next) { next = due; }
    if game::awaiting(sh.game) && (next < 0.0 || next > poll) { next = poll; }
    return next;
}

// The players and the playing player's settings as the app read them at launch, before
// the development flags change any.
fn launch(sh: Shell&, prefs: settings::Settings, ps: players::Players&) {
    sh.prefs = prefs;
    sh.players = ps;
}

// After the flags: the settings put where they act, the playing player's game brought
// back with the screen it was on, and on a fresh install's first run (`first`) the sheet
// of its one player, to pick a badge.
fn open(sh: Shell&, first: bool) {
    apply_prefs(sh);
    read_game(sh);
    if first && sh.players.fresh { who::first_run(sh.who, sh.players); }
}

// The puzzles are the set of the player's draughts (puzzles::set_of), and its library of
// daily puzzles beside it (task 088). The draughts change in home's setup, in settings,
// or with the player; home, where every way to the puzzles starts, reads the other set
// then, and the picker starts at its library. The library's own switch reads it at once
// (load_set). Then today's puzzles (sync_daily).
fn sync_puzzles(sh: Shell&) {
    if sh.screen == HOME { load_set(sh); }
    if (sh.screen == HOME || sh.screen == PICKER) && sh.library != puzzles::loaded { load_library(sh); }
    sync_daily(sh);
}

// Reads the set of the player's draughts where another is loaded: no puzzle is open, and
// the picker is at its library.
fn load_set(sh: Shell&) {
    guard puzzles::set_of(sh.prefs.variant as u8) != puzzles::loaded else { return; }
    puzzles::load(sh.prefs.variant as u8);
    load_library(sh);
    sh.puzzle = puzzle::new();
    sh.theme = -1;
    apply_prefs(sh);
}

// Reads the library of daily puzzles of the set loaded, today's to be read again from it.
fn load_library(sh: Shell&) {
    puzzles::load_library(puzzles::loaded);
    sh.library = puzzles::loaded;
    sh.library_text = puzzles::library_file(puzzles::loaded);
    sh.daily.set = -1;
}

fn declare(sh: Shell&, g: gui::Gui&, area: float4, now: f64, fresh: bool) -> bool {
    sync_puzzles(sh);
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
    var gone: board::Overlay = [];
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
    let asked = screen_frame(sh, g, area, now, fresh, crossing);
    sh.came = sh.out.layout;
    sh.mix = 1.0;
    // Between home and settings the board is home's all the way: settings show their
    // preview once the board is there, and home's board as soon as they are left, so one
    // set of pieces is ever on screen.
    sh.out.shows = if crossing && was == SETTINGS { from } else { was };
    if crossing { blend(sh, g, first, middle, gone, e, if sh.out.shows == was { sh.came } else { sh.went }); }
    sh.out.hole = if crossing { sh.out.layout.board } else { float4 { 0.0, 0.0, 0.0, 0.0 } };
    sh.out.tall = 0.0;
    raise(sh, g, crossing, e);
    // With no image of it yet, a still mark where the 3D board goes until it shows.
    if sh.out.raised && waiting3d(sh) && !sh.shown3d { gui::waiting(g, sh.out.place, strings::get(strings::BOARD_PREPARING)); }
    sh.out.blur = if crossing { blurred(from) + (blurred(was) - blurred(from)) * e } else { blurred(was) };
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
// in or out there. sh.out.layout follows the drawn view, so the scene stays the same while
// the image moves.
fn raise(sh: Shell&, g: gui::Gui&, crossing: bool, e: f32) {
    sh.out.raised = false;
    sh.out.hold = crossing;
    sh.out.fade = 1.0;
    let a = if crossing { sh.went_view } else { view3d::View {} };
    let b = sh.came_view;
    let has_a = a.rect.z > 0.0;
    let has_b = b.rect.z > 0.0;
    guard has_a || has_b else { return; }
    sh.out.raised = true;
    sh.out.view = if has_a && has_b { if a.k > b.k { a } else { b } } else if has_a { a } else { b };
    // At rest the screen's flat layout stays, which its camera's view may have moved away
    // from (panel::aim); in a transition the drawn view's square.
    guard crossing else {
        sh.out.place = sh.out.view.rect;
        return;
    }
    let flip = sh.out.layout.flip;
    sh.out.layout = view3d::square(sh.out.view, g.scale);
    sh.out.layout.flip = flip;
    let ra = if has_a { a.rect } else { tile_rect(sh.out.view.rect, sh.went.board) };
    let rb = if has_b { b.rect } else { tile_rect(sh.out.view.rect, sh.came.board) };
    sh.out.place = float4 { ra.x + (rb.x - ra.x) * e, ra.y + (rb.y - ra.y) * e, ra.z + (rb.z - ra.z) * e,
                        ra.w + (rb.w - ra.w) * e };
    let fa: f32 = if has_a { 1.0 } else { 0.0 };
    let fb: f32 = if has_b { 1.0 } else { 0.0 };
    sh.out.fade = fa + (fb - fa) * e;
    sh.out.hole = float4 { sh.out.place.x, sh.out.place.y, sh.out.place.z, 0.0 };
    sh.out.tall = sh.out.place.w;
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
    var l = if settings::raised(sh.prefs) {
        panel::corners_in(area, n, u, panel::PITCH_PORTRAIT, true, true, sh.prefs.moves != settings::MOVES_HIDDEN)
    }
            else { panel::layout_in(area, n, u, true, true, sh.prefs.moves != settings::MOVES_HIDDEN) };
    l.board.flip = sh.game.computer == rules::WHITE || (!l.three && flat_turned(sh) != (flat_fade(sh, now) < 0.0));
    panel::aim(l, sh.game.cam, now);
    return l;
}

// The game for this frame, `frozen` while its transition runs. Returns whether anything
// on screen changed.
fn game_screen(sh: Shell&, g: gui::Gui&, area: float4, now: f64, frozen: bool) -> bool {
    var l = game_layout(sh, area, g.scale, now);
    sh.out.layout = l.board;
    let p .= sh.prefs;
    let ev, changed = game::frame(sh.game, g, l, now, sh.out.over, frozen);
    // Its eye turned on or off: kept in the player's file.
    if ev.looked {
        p.lookout = sh.game.look;
        sh.changed = true;
    }
    aimed(sh, l, sh.game.cam, now);
    // A game from the replay counts for nothing: its end and start over change nothing
    // kept, and its way out goes back to the replay.
    if sh.past.trial {
        if ev.go == game::HOME {
            leave_trial(sh, now);
            return true;
        }
        if ev.go == game::SETTINGS {
            open_settings(sh, GAME, now);
            return true;
        }
        return changed;
    }
    // A game against the computer ended: won or lost, the child meets a stronger or weaker
    // one next; drawn, the same, a game played on its level all the same.
    let gm .= sh.game;
    if ev.over { keep_game(sh, ev.winner); }
    if ev.ended {
        let k = clamp(gm.level, game::EASY, game::HARD);
        sh.prefs.skill[k] = ai::adapt(sh.prefs.skill[k], k, ev.result, sh.prefs.played[k]);
        sh.prefs.played[k] += 1;
        sh.changed = true;
    }
    // Played again or started over: a new game, at its level's skill as it is now, and
    // counted as home's play counts one. The app asks the computer for a move only after
    // shell::frame (think::frame comes after it in the app's loop), so the computer
    // thinks at the new skill from the first move.
    if ev.restarted {
        if gm.computer >= 0 {
            gm.skill = p.skill[clamp(gm.level, game::EASY, game::HARD)];
            gm.number = p.games;
            p.games += 1;
            sh.changed = true;
        }
    }
    if ev.ended || ev.restarted { apply_prefs(sh); }
    if ev.go == game::HOME {
        go_up(sh, HOME, now);
        return true;
    }
    if ev.go == game::SETTINGS {
        open_settings(sh, GAME, now);
        return true;
    }
    return changed;
}

// Where a puzzle puts the board and its panels, turned when black is to move, so the side
// to move plays from the bottom: round the 3D board when it is chosen, as the game's.
fn puzzle_layout(sh: Shell&, area: float4, u: f32, now: f64) -> panel::Layout {
    let pl .= sh.puzzle;
    return side_layout(sh, area, u, pl.b.variant, puzzle::current(pl).start.side == rules::BLACK, pl.cam, now);
}

// The puzzle's layout, which how to play shares, for a board of `variant`, turned with
// `flip`, seen through camera `cam` at `now`: round the 3D board when it is chosen, else
// the flat board with its panels beside it. It keeps its own play panel's height in a
// small window for now (task 050).
fn side_layout(sh: Shell&, area: float4, u: f32, variant: u8, flip: bool, cam: rig::Rig&, now: f64) -> panel::Layout {
    let n = rules::VARIANTS[variant].size;
    var l = if settings::raised(sh.prefs) { panel::corners_in(area, n, u, panel::PITCH_PORTRAIT, false) }
            else { panel::puzzle_in(area, n, u) };
    l.board.flip = flip;
    panel::aim(l, cam, now);
    return l;
}

// After a screen round a board has taken its frame: the board drawn through camera `cam`
// as the frame left it (a button tapped, a showcase drag, the board facing the side to
// move shows at once), and the 3D board's view, where it is one, for the transition.
fn aimed(sh: Shell&, l: panel::Layout&, cam: rig::Rig&, now: f64) {
    panel::aim(l, cam, now);
    if l.three { sh.came_view = l.view; }
}

// The puzzle for this frame. Returns whether anything on screen changed.
fn puzzle_screen(sh: Shell&, g: gui::Gui&, area: float4, now: f64) -> bool {
    let pl .= sh.puzzle;
    var l = puzzle_layout(sh, area, g.scale, now);
    sh.out.layout = l.board;
    let ev, changed = puzzle::frame(pl, g, l, now, sh.out.over);
    aimed(sh, l, pl.cam, now);
    // Solved: the stars kept are the most it has won; one of today's moves the rating
    // the first time.
    if ev.solved && pl.daily >= 0 { daily_solved(sh, pl.daily, pl.won); }
    if ev.solved && pl.daily < 0 {
        let id = puzzle::current(pl).id;
        if pl.won > sh.prefs.stars[puzzles::loaded][id] {
            sh.prefs.stars[puzzles::loaded][id] = pl.won as u8;
            sh.changed = true;
        }
    }
    if ev.go == puzzle::PUZZLES {
        if pl.daily >= 0 { sh.theme = -1; }
        go_to(sh, PICKER, now);
    }
    if ev.go == puzzle::SETTINGS {
        open_settings(sh, PUZZLE, now);
    }
    if ev.go == puzzle::NEXT && pl.daily >= 0 {
        // On through today's, and after the last back to the library.
        daily_next(sh, pl.daily, now);
    } else if ev.go == puzzle::NEXT {
        // On inside the theme, and after its last back to the library.
        let i = pl.index + 1;
        if i < puzzles::all.list.len && puzzles::all.list[i].theme == sh.theme { play_puzzle(sh, i, now); }
        else {
            sh.theme = -1;
            go_to(sh, PICKER, now);
        }
    }
    return changed || ev.go != puzzle::STAY;
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
    sh.out.over.clear();
    var spot = float4 { 0.0, 0.0, 0.0, 0.0 };
    var variant = sh.prefs.variant;
    let pick = picker::frame(g, area, sh.prefs.stars[puzzles::loaded], sh.puzzle.index, sh.theme, spot, variant,
                             learned(sh), tutorial::count(sh.prefs.variant as u8), today_of(sh), sh.puzzle.daily);
    let daily = pick <= picker::TODAY && pick > picker::TODAY - puzzles::MAX_DAILY;
    if pick == picker::LEARN { learn(sh, PICKER, now); }
    if pick == picker::SWITCHED {
        // The library's switch is settings' draughts: new games' too, saved as settings
        // saves it, and home's count over the set it shows. The next frame shows it.
        sh.prefs.variant = variant;
        load_set(sh);
        sh.changed = true;
    } else if pick == picker::BACK {
        go_up(sh, HOME, now);
    } else if pick >= 0 {
        play_puzzle(sh, pick, now);
    } else if daily {
        play_daily(sh, picker::TODAY - pick, now);
    }
    // No board at rest: it lies off the screen. Coming from a puzzle, or going to one,
    // it is the puzzle's, in its tile.
    if sh.from == PUZZLE || pick >= 0 || daily { sh.out.layout = in_tile(sh, spot, g.scale); }
    else { sh.out.layout = board::layout_at(-2.0 * area.z, 0.0, 0.5 * area.z, g.scale, sh.out.layout.n); }
    return pick != picker::NOTHING;
}

// A transition's frame, both screens declared, the one left's quads first..middle and
// its pieces over the UI in `gone`, at e of the way, eased: the first fades out and the
// second in, both drifting the way the board moves, and the board eases from the one's
// place to the other's, with the squares and turn of `own`, the end whose board shows.
fn blend(sh: Shell&, g: gui::Gui&, first: i64, middle: i64, gone: board::Overlay&, e: f32, own: board::Layout) {
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
    sh.out.layout = board::layout_at(a.board.x + (b.board.x - a.board.x) * e, a.board.y + (b.board.y - a.board.y) * e,
                                 a.board.z + (b.board.z - a.board.z) * e, g.scale, own.n);
    sh.out.layout.flip = own.flip;
    // The pieces over the UI likewise, the screen left's first.
    var both: board::Overlay = [];
    for p in gone { put(both, p, 1.0 - e, out); }
    for p in sh.out.over { put(both, p, e, into); }
    sh.out.over = both;
}

// A piece over the UI at opacity a, moved by d.
fn put(over: board::Overlay&, p: board::Piece, a: f32, d: float2) {
    guard over.len < board::OVER else { return; }
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
    let ask = settings::frame(sh.prefs, sh.out.over, g, sh.out.layout, area, strings::current, room);
    sh.came_view = raise_in(sh, room, sh.out.layout.n, g.scale, sh.out.layout);
    if ask == settings::CHANGED {
        apply_prefs(sh);
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
    sh.staged = sh.setup != home::NO_SETUP;
    var changed = false;
    if sh.staged && sh.next.variant != sh.prefs.variant as u8 {
        board::reset(sh.next, sh.prefs.variant as u8);
        changed = true;
    }
    let b .= board_of(sh, HOME);
    if board::update(b, now) { changed = true; }
    let flip = turned(sh, sh.setup);
    // Who's playing, or the quit's question, over the menu: home under it takes no pointer.
    let card = sh.who.state != who::CLOSED && sh.setup == home::NO_SETUP;
    let asking = sh.quitting && !card;
    if card || asking { gui::listen(g, false); }
    var room = float4 { 0.0, 0.0, 0.0, 0.0 };
    let still = !sh.prefs.turns;
    let pick = home::frame(sh.out.over, g, sh.out.layout, rules::VARIANTS[b.variant].size, area, sh.setup, sh.prefs, room,
                           resume(sh));
    sh.out.layout.flip = flip;
    let v = raise_in(sh, room, sh.out.layout.n, g.scale, sh.out.layout);
    if !card && !asking && turn_home(sh, g, v, room, now) { changed = true; }
    sh.came_view = home_view(sh, v, room, now);
    // A friend's board switched to turning, the setup's board turns once round to show it
    // (Shell.demo, twice the game's turn): the 3D board a full turn, the flat one showing
    // black's side for the middle half.
    if pick == home::CHANGED && still && sh.prefs.turns {
        rig::put(sh.demo, 0.0);
        rig::go(sh.demo, 360.0, now, 2.0 * rig::TURN);
    }
    if sh.setup != home::NO_SETUP && rig::moving(sh.demo, now) {
        let spin = rig::value(sh.demo, now);
        if sh.came_view.rect.z > 0.0 { sh.came_view = view3d::turned(sh.came_view, view3d::Camera { turn: spin, .. }); }
        else { sh.out.layout.flip = spin > 90.0 && spin < 270.0; }
    }
    if card {
        // Home's pieces over its UI (the wordmark's crown, the player's picture) draw
        // after all the UI, so they would sit on the card: under it, home shows without
        // them.
        sh.out.over.clear();
        gui::listen(g, true);
        if who_card(sh, g, area, now) { changed = true; }
    }
    if asking {
        sh.out.over.clear();
        gui::listen(g, true);
        let ask = home::ask_quit(g, area, gui::bleed(g, area, area));
        if ask == home::EXIT { sh.out.quit = true; }
        if ask == home::BACK { sh.quitting = false; }
        if ask != home::NOTHING { changed = true; }
    }
    if pick != home::NOTHING { changed = true; }
    match pick {
        home::SETTINGS => {
            open_settings(sh, HOME, now);
        },
        home::CONTINUE => { go_to(sh, GAME, now); },
        home::PUZZLES => { go_to(sh, PICKER, now); },
        home::NEW_GAME => { sh.setup = home::NEW_GAME; },
        home::BACK => { sh.setup = home::NO_SETUP; },
        home::CHANGED => {
            sh.changed = true;
            apply_prefs(sh);
        },
        home::EXIT => {
            if home::asks_quit() { sh.quitting = true; } else { sh.out.quit = true; }
        },
        home::PLAYERS => { who::open(sh.who); },
        home::RESULTS => { go_to(sh, RESULTS, now); },
        home::LEARN => { learn(sh, HOME, now); },
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
fn who_card(sh: Shell&, g: gui::Gui&, area: float4, now: f64) -> bool {
    let ask, index = who::frame(sh.who, sh.players, g, area, gui::bleed(g, area, area));
    let w .= sh.who;
    match ask {
        who::SWITCH => { switch_player(sh, index); },
        who::CREATE => { add_player(sh, w.picture, w.name); },
        who::SAVE => { edit_player(sh, index, w.picture, w.name); },
        _ => {},
    }
    // A new player, or a fresh install's first, is being asked whether they know how to
    // play: asked, whatever they answer (home's How to play row, resume).
    if w.state == who::ASKING && !sh.prefs.first_start_done {
        sh.prefs.first_start_done = true;
        sh.changed = true;
    }
    match ask {
        who::AGAIN => { start_again(sh, index); },
        who::REMOVE => { remove_player(sh, index); },
        who::LEARN => { learn(sh, HOME, now); },
        who::KNOWN => {
            sh.prefs.knows = true;
            sh.changed = true;
        },
        _ => {},
    }
    return ask != who::NOTHING;
}

// Whether home's board is turned with its column showing `setup`, for a child playing
// black against the computer: in the game as it stands on the menu, and in the setup
// when the computer and black are chosen.
fn turned(sh: Shell&, setup: i64) -> bool {
    return if setup == home::NEW_GAME { !sh.prefs.friend && sh.prefs.color == rules::BLACK }
           else { sh.game.computer == rules::WHITE || (!settings::raised(sh.prefs) && flat_turned(sh)) };
}

// Whether a friend's game on the flat board shows black at the bottom, the board turned
// to the side to move (settings' `turns`; game.goose's rig::face).
fn flat_turned(sh: Shell&) -> bool { sh.game.computer < 0 && sh.game.turns && rig::faces_far(sh.game.cam) }

// The flat board's turn in a friend's game is a fade (2026-11-12; at once it was too
// quick to follow): the pieces fade out over FLAT_FADE seconds still on the side they
// were, then in on the turned board. Returns their opacity while it runs, negative while
// they fade out (the board not yet turned), or 2 when no fade runs. The squares look the
// same turned, so only the pieces change.
let FLAT_FADE = 0.15;
fn flat_fade(sh: Shell&, now: f64) -> f32 {
    let t .= sh.game.cam.turn;
    guard !settings::raised(sh.prefs) && sh.game.computer < 0 && t.length > 0.0 else { return 2.0; }
    let e = now - t.start;
    guard e >= 0.0 && e < 2.0 * FLAT_FADE else { return 2.0; }
    if e < FLAT_FADE { return -(1.0 - e / FLAT_FADE) as f32; }
    return ((e - FLAT_FADE) / FLAT_FADE) as f32;
}

// The board a screen shows (KINDS): settings their preview, a puzzle its own (and the
// puzzles to pick from, which show it only in a transition with it), a replay its own,
// home's setup the game its play starts, the other screens the game's.
fn board_of(sh: Shell&, screen: i64) -> board::Board& {
    let kind = which(screen);
    return if screen == HOME && sh.staged { sh.next } else if kind == SETTINGS { sh.preview }
           else if kind == PUZZLE { sh.puzzle.b } else if kind == REPLAY { sh.past.replay.b }
           else if kind == TUTORIAL { sh.lesson.b } else { sh.game.b };
}
fn which(screen: i64) -> i64 { KINDS[screen].board }

// The board on screen at rest.
fn shown(sh: Shell&) -> board::Board& { board_of(sh, sh.screen) }

// Fills the board this frame shows (sh.out.shows) for the frame at `now`, where sh.out.layout
// puts it, and returns it for the app to draw; the game's with its win (game::cheer),
// which fades with the game screen in a transition.
fn fill(sh: Shell&, now: f64) -> board::Board& {
    let b .= board_of(sh, sh.out.shows);
    board::fill(b, sh.out.layout, now);
    let k = if which(sh.out.shows) == GAME { abs(flat_fade(sh, now)) } else { 2.0 };
    if k < 1.0 { for &p in b.pieces { p.look.w *= k; } }
    let share = if sh.screen == GAME { sh.mix } else if sh.from == GAME { 1.0 - sh.mix } else { 0.0 };
    if share > 0.0 && which(sh.out.shows) == GAME { game::cheer(sh.game, sh.out.layout, now, share); }
    return b;
}

// Whether the 3D board is chosen but not ready to draw (sh.ready3d).
fn waiting3d(sh: Shell&) -> bool { settings::raised(sh.prefs) && !sh.ready3d }
