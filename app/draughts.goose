// Draughts: home and the game screen, played by two on one screen or against the
// computer, which thinks on a worker thread (think.goose). It draws only when something
// changed: input, a move or a pulse animating, or a new screen size
// (docs/architecture/rendering.md, "Frames and battery"). The thread needs a build: on
// the Mac, from app/, `goose build -o ../build/draughts draughts.goose`, then
//
//   ../build/draughts                             at home
//   ../build/draughts --screen game               the game screen; --fen and --tap open it too
//   ../build/draughts --theme sunset              another board than the season's
//   ../build/draughts --frames 30 --tap c3        taps squares, then saves draughts.png
//   ../build/draughts --fen W:Wc3,Kh6:Be5         starts from a position
//   ../build/draughts --hints moves               shows the selected piece's targets
//   ../build/draughts --lang et                   another language than the system's
//   ../build/draughts --dp 540                    the layout 540 dp across its shorter side, not 800
//   ../build/draughts --inset 0,59,0,24           a phone's insets, in dp: left, top, right, bottom
//   ../build/draughts --density-floor 0.75 --display-scale 2.625   the scale's floor, as on a phone
//   ../build/draughts --variant russian           a new game of another draughts
//   ../build/draughts --clock 5+3                 with a clock
//   ../build/draughts --computer white --level hard   against the computer playing white
//   ../build/draughts --screen puzzles            the puzzles to pick from
//   ../build/draughts --puzzle 21 --tap f4 --tap e5   puzzle 21, taps on its board
//   ../build/draughts --go settings --hold 0.4 --frames 10   home going to settings, held at 40%
//   ../build/draughts --screen friend --go play --hold 0.5 --frames 10   a friend's play, halfway into the game
//   ../build/draughts --fen W:Wa1,e3:Bf4 --tap e3 --tap g5 --win 1.2 --frames 60   a win held 1.2 s in
//   scripts/android.py app/draughts.goose --run   on the tablet (docs/development.md)

import std;
import vec;
import gfx;
import os;
import rules from "../rules";
import board from "../board";
import strings from "../strings";
import gui from "../gui";
import .theme;
import .draw;
import .scene;
import .widgets;
import game from "../game";
import shell from "../shell";
import ai from "../ai";
import puzzles from "../puzzles";
import .text;
import .think;

// The system's preferred locales, "et-EE,en-US" (locale.c); returns how many bytes.
extern fn draughts_locales(out: u8[:]) -> i64;
// The app's storage folder, ending in a separator (storage.c); returns how many bytes.
extern fn draughts_storage(out: u8[:]) -> i64;
// The insets around the window's safe area in pixels (left, top, right, bottom) and the
// display's scale, into out[0..5] (display.c); 0, leaving out as it is, without a window.
extern fn draughts_display(out: f32[:]) -> i64;
// Wakes the loop in ms milliseconds, where frame() waits for events (wake.c).
extern fn draughts_wake_in(ms: i64);
// Tells Android the first frame is on screen, to lift the splash and the cover (launch.c).
extern fn draughts_first_frame();
// Closes the app on Android and takes it out of recents, as home's way out asks; on the
// Mac the window closes as the program returns (launch.c).
extern fn draughts_close();
// Android's back where the app has no way back (home's menu): the system's back, which
// puts the app in the background; nothing on the Mac (launch.c).
extern fn draughts_leave();

// --go play: a new game from home's setup, as its play starts one.
let GO_PLAY = 99;

// The theme a season setting picks: its own, or by the date.
fn theme_for(season: i64) -> i64 {
    return if season >= 0 { season } else { theme::for_month(theme::month(time())) };
}

fn main() {
    // Development flags: --theme NAME, --size WxH (the window), --fen POSITION,
    // --tap SQUARE (any number, played in order on the first frames), --frames N (then
    // save draughts.png), --hints moves (show targets; mistakes only by default), --lang
    // CODE (a language with a file in strings/; the system's by default), --screen
    // home|game|settings|friend|computer (home unless a position, taps, a clock, or the
    // computer are given; the last two open home's setup; puzzles the puzzles to pick
    // from), --puzzle ID (that puzzle, its taps on its board), --variant
    // international|brazilian|russian, --clock none|5+3|10+5, --computer white|black (a
    // new game; --level easy|medium|hard, the setup's last by default; with --screen
    // friend or computer, the setup's choices instead, the child playing the other
    // color), --go home|settings|game|play|puzzles|puzzle (switches there on the second
    // frame, through its transition: game as continue does, play as the setup's play,
    // puzzle from the puzzles to pick from to --puzzle ID or the first; after any taps),
    // --hold T (keeps a transition at T of the way, 0..1, for a screenshot),
    // --win T (keeps a win at T seconds into its celebration, for a screenshot). --theme,
    // --hints, and --lang override the settings for the run without changing them.
    // --3d (alone) shows settings' Board row, hidden until the 3D board exists (task 015).
    // --dp N lays out N dp across the shorter side (and leaves the density floor off);
    // --inset L,T,R,B in dp stands for a phone's safe area; --density-floor F and
    // --display-scale S try the scale's floor (gui::scale_of), S standing for the
    // display's (the Mac's is left out: its windows are in points, not a phone's dp).
    var width = 1280;
    var height = 800;
    var kind = -1;
    var frames = -1;
    var hints = -1;
    var lang = -1;
    var screen = -1;
    var variant = -1;
    var clock_kind = -1;
    var computer = -1;
    var level = -1;
    var setup = 0;
    var puzzle_id = -1;
    var go = -1;
    var hold = -1.0;
    var win_at = -1.0;
    var show_3d = false;
    var dp_given = false;
    var floor_given = false;
    var display_given = false;
    var inset_dp = float4 { -1.0, 0.0, 0.0, 0.0 };     // x < 0: the window's own
    var fen:  u8[>..]       = [];
    var taps: u8[..3][..16] = [];
    let argv = args();
    var i = 1;
    for a in argv { if a == "--3d" { show_3d = true; } }
    while i + 1 < argv.len {
        if argv[i] == "--3d" { i += 1; continue; }   // no value: the pairs shift by one
        if argv[i] == "--theme" && theme::by_name(argv[i + 1]) >= 0 { kind = theme::by_name(argv[i + 1]); }
        if argv[i] == "--frames" {
            let n, ok = parse_int(argv[i + 1]);
            if ok { frames = n; }
        }
        if argv[i] == "--size" {
            let w, h, found = split_once(argv[i + 1], "x");
            let a, ok_a = parse_int(w);
            let c, ok_c = parse_int(h);
            if found && ok_a && ok_c { width = a; height = c; }
        }
        if argv[i] == "--dp" {
            let n, ok = parse_int(argv[i + 1]);
            if ok && n >= 200 {
                gui::short_dp = n;
                dp_given = true;
            }
        }
        if argv[i] == "--inset" {
            var rest: const u8[:] = argv[i + 1];
            var d:    f32[4]      = [0.0; 4];
            var good = true;
            for k in 4 {
                let part, after, more = split_once(rest, ',');
                let x, ok = parse_flt(part);
                good = good && ok && more == (k < 3);
                d[k] = x as f32;
                rest = after;
            }
            if good { inset_dp = float4 { max(d[0], 0.0), max(d[1], 0.0), max(d[2], 0.0), max(d[3], 0.0) }; }
        }
        if argv[i] == "--density-floor" {
            let x, ok = parse_flt(argv[i + 1]);
            if ok {
                gui::density_floor = x as f32;
                floor_given = true;
            }
        }
        if argv[i] == "--display-scale" {
            let x, ok = parse_flt(argv[i + 1]);
            if ok {
                gui::display_scale = x as f32;
                display_given = true;
            }
        }
        if argv[i] == "--fen" { fen.append(argv[i + 1]); }
        if argv[i] == "--hints" && argv[i + 1] == "moves" { hints = board::MOVES; }
        if argv[i] == "--lang" { lang = strings::pick(argv[i + 1]); }
        for name, k in settings::DRAUGHTS_NAMES { if argv[i] == "--variant" && argv[i + 1] == name { variant = settings::DRAUGHTS[k]; } }
        for name, k in settings::CLOCK_NAMES { if argv[i] == "--clock" && argv[i + 1] == name { clock_kind = k; } }
        if argv[i] == "--computer" { computer = if argv[i + 1] == "white" { rules::WHITE } else { rules::BLACK }; }
        for name, k in settings::LEVEL_NAMES { if argv[i] == "--level" && argv[i + 1] == name { level = k; } }
        if argv[i] == "--screen" {
            screen = if argv[i + 1] == "game" { shell::GAME } else if argv[i + 1] == "settings" { shell::SETTINGS } else { shell::HOME };
            if argv[i + 1] == "friend" { setup = home::FRIEND; }
            if argv[i + 1] == "computer" { setup = home::COMPUTER; }
            if argv[i + 1] == "puzzles" { screen = shell::PICKER; }
        }
        if argv[i] == "--go" {
            let to = argv[i + 1];
            go = if to == "settings" { shell::SETTINGS } else if to == "game" { shell::GAME }
                 else if to == "play" { GO_PLAY } else if to == "puzzles" { shell::PICKER }
                 else if to == "puzzle" { shell::PUZZLE } else { shell::HOME };
        }
        if argv[i] == "--hold" {
            let n, ok = parse_flt(argv[i + 1]);
            if ok { hold = clamp(n, 0.0, 1.0); }
        }
        if argv[i] == "--win" {
            let n, ok = parse_flt(argv[i + 1]);
            if ok { win_at = max(n, 0.0); }
        }
        if argv[i] == "--puzzle" {
            let n, ok = parse_int(argv[i + 1]);
            if ok { puzzle_id = n; }
        }
        if argv[i] == "--tap" && argv[i + 1].len >= 2 && argv[i + 1].len <= 3 && taps.len < 16 {
            let t .= taps.push([]);
            t.append(argv[i + 1]);
        }
        i += 2;
    }
    // --dp says how many dp the shorter side has, so the floor stays off unless asked.
    if dp_given && !floor_given { gui::density_floor = 0.0; }
    // The settings and the game, kept in the app's storage folder (shell/settings.goose,
    // shell::save).
    var folder: u8[512] = [0; 512];
    let dir = folder[..draughts_storage(folder)];
    let prefs_path = str(dir, "settings.txt");
    let save_path = str(dir, "game.bin");
    var prefs_text: u8[>..] = [];
    read_file(prefs_path, prefs_text);
    let prefs = settings::parse(prefs_text);
    if kind < 0 { kind = theme_for(prefs.season); }
    if hints < 0 { hints = prefs.hints; }
    var locales: u8[256] = [0; 256];
    let system_lang = strings::pick(locales[..draughts_locales(locales)]);
    if lang < 0 { lang = if prefs.language >= 0 { prefs.language } else { system_lang }; }
    strings::use(lang);
    puzzles::load();

    var android_root: u8[>..] = [];
    let on_android = env("ANDROID_ROOT", android_root);
    let window_flags = if on_android { gfx::WINDOW_FULLSCREEN | gfx::WINDOW_RESIZABLE } else { gfx::WINDOW_RESIZABLE };
    guard gfx::open(strings::get(strings::APP_NAME), width, height, window_flags) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    // A new game of the draughts the setup last chose, until a saved game is restored.
    var sh = shell::new((if variant >= 0 { variant } else { prefs.variant }) as u8);
    if clock_kind >= 0 || computer >= 0 {
        let lv = if level >= 0 { level } else { prefs.level };
        game::start(sh.game, sh.game.b.variant, max(clock_kind, 0), computer, lv, prefs.skill[lv], prefs.games);
    }
    sh.prefs = prefs;
    sh.prefs.show_board_row = show_3d;
    let gm .= sh.game;
    let b .= gm.b;
    b.hints = hints;
    if fen.len > 0 {
        let p, ok = rules::parse_fen(fen, b.variant);
        guard ok else { abort(str("not a position: ", fen)); }
        board::set(b, p);
    }
    sh.screen = if screen >= 0 { screen } else if fen.len > 0 || taps.len > 0 || clock_kind >= 0 || computer >= 0 { shell::GAME } else { shell::HOME };
    sh.setup = setup;
    // A setup the flags open shows the draughts, the child's color, and the level they
    // give, with the settings file left as it is unless a tap in the setup writes it.
    if setup != home::NOTHING {
        if variant >= 0 { sh.prefs.variant = variant; }
        if computer >= 0 { sh.prefs.color = 1 - computer; }
        if level >= 0 { sh.prefs.level = level; }
    }
    if puzzle_id >= 0 && puzzles::find(puzzles::all, puzzle_id) >= 0 && go != shell::PUZZLE {
        shell::play_puzzle(sh, puzzles::find(puzzles::all, puzzle_id));
        screen = shell::PUZZLE;
    }
    // The game as it was when the app was last paused (shell::restore; nothing changes
    // for a missing or damaged file). A run with flags that set up a game or take a
    // screenshot neither reads nor writes it.
    let keep = screen < 0 && go < 0 && win_at < 0.0 && fen.len == 0 && taps.len == 0 && frames < 0 && variant < 0 && clock_kind < 0 && computer < 0;
    if keep {
        var saved: u8[>..] = [];
        if read_file(save_path, saved) { shell::restore(sh, saved); }
    }
    var d = draw::new(kind);
    // Loading the photograph took 16 MB of data stack for its pixels; give the pages back
    // rather than keep them resident. The same after baking the text.
    trim_memory();
    var w = widgets::new();
    var g = gui::Gui {};
    var t = text::Text {};
    var size = int2 { 0, 0 };
    var display:   f32[5] = [0.0; 5];
    var was_scale: f32    = 0.0;
    var dirty = true;
    var tapped = 0;
    var focused = true;
    var season_in = 0;
    var wake_at = -1.0;
    var thinker = think::Thinker {};
    while gfx::frame() {
        // frame() presents what the pass before it drew, and the first pass draws.
        if gfx::frame_count() == 2 { draughts_first_frame(); }
        // Android may kill the app once it is paused; it loses focus then, and SDL lets
        // the loop run once more before blocking, so the game is written here: one small
        // write per pause, none while idle.
        if keep && focused && !gfx::focused() { write_file_atomic(save_path, shell::save(sh)); }
        // The clocks count only time the game was on screen: not the gap while Android had
        // the app paused, nor while it was in the background. On the Mac a window started
        // from a terminal never has focus, and the loop never blocks there, so focus is
        // left out and the clock runs while the window shows.
        if on_android && (!focused || !gfx::focused()) { game::pause(sh.game); }
        focused = gfx::focused();
        // A new season's photograph, colors, and blurred copies load two frames after the
        // tap: the frame after it shows the tile lit, and is on screen before the load
        // (80 to 95 ms on the tablet) holds the thread.
        if season_in > 0 {
            season_in--;
            if season_in == 0 && theme_for(sh.prefs.season) != d.kind {
                draw::reload(d, theme_for(sh.prefs.season));
                trim_memory();
                dirty = true;
            }
        }
        let now = gfx::time();
        let s = gfx::screen_size();
        if s.x != size.x || s.y != size.y {
            size = s;
            dirty = true;
        }
        // The safe area and the display's scale, read each frame (a few fields in SDL):
        // turning the screen moves the camera's cutout and the gesture bar, and a change
        // of either is a change of the screen, as a new size is. The Mac's display scale
        // is left out (gui::scale_of).
        draughts_display(display);
        if on_android && !display_given { gui::display_scale = display[4]; }
        let scale = gui::scale_of(size.x, size.y);
        let e = if inset_dp.x < 0.0 { float4 { display[0], display[1], display[2], display[3] } }
                else { float4 { floor(inset_dp.x * scale + 0.5), floor(inset_dp.y * scale + 0.5),
                                floor(inset_dp.z * scale + 0.5), floor(inset_dp.w * scale + 0.5) } };
        if scale != was_scale || e.x != g.insets.x || e.y != g.insets.y || e.z != g.insets.z || e.w != g.insets.w {
            was_scale = scale;
            g.insets = e;
            dirty = true;
        }
        if text::bake(t, g, scale) { trim_memory(); }
        w.atlas = t.texture;
        // A quick tap can press and release within one frame, which mouse_down never
        // sees; pressed and released catch it. The screens give the pointer to the UI
        // first; a press that lands on it never reaches the board.
        let input = gui::Input { at: gfx::mouse_pos(), down: gfx::mouse_down(gfx::MOUSE_LEFT),
                                 pressed: gfx::mouse_pressed(gfx::MOUSE_LEFT),
                                 released: gfx::mouse_released(gfx::MOUSE_LEFT) };
        gui::begin(g, input, scale, now);
        // A switch the flags ask for waits for their taps to have played out, and for the
        // win they lead to, if any, held at --win's moment (which must be past: the
        // celebration's start is kept as a time, never before 0).
        if go >= 0 && gfx::frame_count() >= 2 && tapped >= taps.len && !b.moving
           && (win_at < 0.0 || (sh.game.won_at >= 0.0 && now > win_at)) {
            if go == GO_PLAY {
                // As the setup's play, leaving settings.txt as it is: the count of games
                // against the computer and the choices the flags gave aren't written.
                shell::play(sh, now);
                sh.changed = false;
            }
            else if go == shell::PUZZLE { shell::play_puzzle(sh, max(puzzles::find(puzzles::all, puzzle_id), 0), now); }
            else { shell::go_to(sh, go, now); }
            go = -1;
        }
        // Android's back (SDL's "AC Back"; DraughtsActivity hands the system's back to SDL
        // as that key) and Escape go back a screen, as the screen's own back or home control
        // does. On home's menu back leaves the app as the system's back would, putting it in
        // the background; Escape there ends the loop, closing the Mac's window.
        if gfx::key_pressed("AC Back") || gfx::key_pressed("Escape") {
            if shell::back(sh, now) { dirty = true; }
            else if on_android { draughts_leave(); }
            else { break; }
        }
        if hold >= 0.0 && sh.from >= 0 { sh.since = now - hold * shell::DURATION; }
        if win_at >= 0.0 && sh.game.won_at >= 0.0 { sh.game.won_at = now - win_at; }
        if shell::frame(sh, g, size.x, size.y, now) { dirty = true; }
        // Home's way out ends the loop; the game is written below.
        if sh.quit { break; }
        // The computer's move: the worker gets what the game asks, and the game the answer.
        think::frame(thinker, sh.game);
        // A tap in settings applies at once and is written; a new season reloads the
        // photograph and its blurred copies, once the tile shows lit. A change made by the
        // tap that starts a transition (the computer's play counting a game) is written
        // once it is over: the write flushes to disk, 13 to 17 ms on the tablet, too long
        // for the frame that starts it moving.
        if sh.changed && sh.from < 0 {
            sh.changed = false;
            var out: u8[>..] = [];
            settings::write(sh.prefs, out);
            write_file_atomic(prefs_path, out);
            let next = if sh.prefs.language >= 0 { sh.prefs.language } else { system_lang };
            if next != strings::current { strings::use(next); }
            if theme_for(sh.prefs.season) != d.kind { season_in = 2; }
            dirty = true;
        }
        // Settings' thumbnails, if settings show before the first idle frame loaded them
        // (below): opened at launch.
        if sh.screen == shell::SETTINGS && w.thumbs.id == 0 {
            w.thumbs = scene::thumbs();
            trim_memory();
        }
        let l = sh.layout;
        if tapped < taps.len && !b.moving && sh.screen == shell::GAME && b.pos.side != gm.computer {
            let v .= rules::VARIANTS[b.variant];
            let sq, ok = rules::parse_square(v, taps[tapped]);
            if ok {
                let p = board::center(l, v, sq);
                board::press(b, l, p, now);
                board::release(b, l, p, now);
            }
            tapped++;
            dirty = true;
        }
        if tapped < taps.len && sh.screen == shell::PUZZLE && puzzle::ready(sh.puzzle) {
            let v .= rules::VARIANTS[sh.puzzle.b.variant];
            let sq, ok = rules::parse_square(v, taps[tapped]);
            if ok { puzzle::tap(sh.puzzle, l, board::center(l, v, sq), now); }
            tapped++;
            dirty = true;
        }
        let drew = dirty || shell::animating(sh, g, now);
        if drew {
            let shown .= shell::fill(sh, now);
            widgets::upload(w, g);
            draw::frame(d, shown, sh.over, l, sh.blur, now, size.x, size.y);
            widgets::frame(w, g, d.scene, d.colors, size.x, size.y, sh.hole);
            draw::overlay(d, now, sh.hole);
            gfx::end_pass();
            dirty = false;
        }
        // Settings' thumbnails load in the first frame that draws nothing once the launch's
        // first frame is on screen, so settings' first opening doesn't wait for them; the
        // next frame shows the screen again unchanged, then the app is idle.
        if !drew && w.thumbs.id == 0 && gfx::frame_count() >= 2 {
            w.thumbs = scene::thumbs();
            trim_memory();
        }
        // A running clock is drawn when the time it shows changes, and the computer's move
        // played when it is due; a timer wakes the loop then, rather than whenever the
        // idle wait ends (wake.c).
        var next = -1.0;
        if sh.screen == shell::GAME {
            next = clock::until_next(sh.game.clock);
            let due = game::due(sh.game, now);
            if due >= 0.0 && (next < 0.0 || due < next) { next = due; }
        }
        if next >= 0.0 && (wake_at < now || now + next < wake_at - 0.005) {
            draughts_wake_in((1000.0 * next) as i64 + 2);
            wake_at = now + next;
        }
        // A widget declared this frame before a click changed what it shows (a choice
        // lit, a toggle), so the next frame draws again; this one drew, so the next
        // doesn't wait for an event.
        if g.acted { dirty = true; }
        if frames > 0 && gfx::frame_count() >= frames { break; }
    }
    if frames > 0 { gfx::screenshot("draughts.png"); }
    if keep { write_file_atomic(save_path, shell::save(sh)); }
    if sh.quit { draughts_close(); }
}
