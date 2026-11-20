// Settings (shell/settings.goose), headless: the file they are kept in reads back what
// was written, and a file that lacks a key or says something unknown leaves the default.
// The language is the device's (shell/players.goose), kept apart from the player's file.
// On the screen, one list that scrolls under the title row, a tap applies at
// once and marks the settings changed for the app to write: the language from the list
// its button opens in the title row; move hints (which the game's board takes), a season,
// and the kings (which the game's board draws too); the Board row's Raised plays the game
// on the 3D board in the season's own material, whose kings are stacks for auto, and its
// Wood, Stone, and Carved on the 3D board in that material, kept in the file as
// `material`; Flat keeps the material for the next raised board. Each choice restages the
// board beside them: its size, its kings, and what the move hints show on a fixed position
// (the player's draughts, chosen elsewhere), where white must
// capture with the man on d4 or the king on h6. With mistakes only, a wrong move's ring
// flashes and both capturing pieces pulse, then both stay lit and still, so nothing
// animates after. The Background row's Plain is kept in the file as `background`, and with
// plain no photograph is shown (the app then loads none) and the seasons' thumbnails are
// their fades. In landscape the board is right of the list; in portrait above it. The
// language list closes on a tap outside it and on back, which then stays on settings.
// The game's lookout, off for a new player, is kept in the file too, and the puzzles a
// day, chosen in the Game section's last row. The list's and the board's rects,
// in pixels, and a language row's height in dp print verbose (DRAUGHTS_TEST_VERBOSE); by
// default whether the list scrolls and the checks they stand for.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import model3d from "../../src/model3d";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

// The tiles in the order the screen declares them with the board flat: back and the
// language button in the title row, then the list's. The 3D board's own (NATURAL, SMOOTH,
// TABLE) have no place there: at() finds each where the screen shows it.
let BACK = 0;
let LANGUAGE = 1;
let SUMMER = 4;
let BY_DATE = 6;
let FLAT = 7;               // the Board row: flat, raised, and its materials
let RAISED = 8;
let WOOD = 9;
let STONE = 10;
let CARVED = 11;
let PHOTO = 12;             // the Background row: the photograph, or the plain fade
let PLAIN = 13;
let AUTO = 14;
let STACK = 16;
let MUTE = 17;              // the Sound section's speaker; its slider is no tile
let MISTAKES = 18;
let MOVES = 19;
let LIST_OFF = 20;          // the moves panel's row: off, the moves, marks
let LIST_MARKS = 22;
let DAILY_8 = 26;           // puzzles a day: 3, 4, 6, 8
let ABOUT = 27;             // the About row, beside the privacy note
let TILES = 28;
let ENGLISH = 28;           // the language list's rows, after the screen's tiles
let EESTI = 29;
let COPY = 28;              // About's card's Copy and close, after the screen's tiles
let CLOSE = 29;
let NATURAL = 100;          // the 3D board's: its Pieces row,
let SMOOTH = 101;
let TABLE = 102;            // and Background's third tile
let OWN_3D = 3;             // the tiles the 3D board shows that the flat one doesn't

// Where tile n is declared: on the 3D board its Pieces row comes before Background, whose
// third tile, the table, comes before the kings.
fn at(sh: shell::Shell&, n: i64) -> i64 {
    guard settings::raised(sh.prefs) else { return n; }
    if n == NATURAL { return PHOTO; }
    if n == SMOOTH { return PHOTO + 1; }
    if n == TABLE { return PLAIN + 3; }
    if n == PHOTO || n == PLAIN { return n + 2; }
    if n >= AUTO { return n + OWN_3D; }
    return n;
}

// The list's tiles: the 3D board shows OWN_3D more.
fn listed(sh: shell::Shell&) -> i64 { if settings::raised(sh.prefs) { TILES + OWN_3D } else { TILES } }

// Tile n's middle, the list scrolled first where it isn't whole in the list's view, as a
// finger would scroll it.
fn seen(sh: shell::Shell&, g: gui::Gui&, n: i64, now: f64) -> float2 {
    let k = at(sh, n);
    let r = drive::rect(g, k);
    let v = g.scroll.view;
    if k > LANGUAGE && k < listed(sh) && (r.y < v.y || r.y + r.w > v.y + v.w) {
        gui::scroll_set(g, settings::LIST, g.scroll.offset + r.y + 0.5 * r.w - (v.y + 0.5 * v.w));
        drive::frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, now);
    }
    return drive::tile(g, k);
}

// A tap on tile n, scrolled to first.
fn tap(sh: shell::Shell&, g: gui::Gui&, n: i64, now: f64) { drive::tap(sh, g, seen(sh, g, n, now), now); }

// The player's draughts, chosen in home's setup or the puzzles' library (settings has no
// row for them): the preview is staged again with their size, as a
// settings' change stages it (shell::settings_screen).
fn draughts(sh: shell::Shell&, g: gui::Gui&, v: i64, now: f64) {
    sh.prefs.variant = v;
    sh.changed = true;
    shell::apply_prefs(sh);
    settings::stage(sh.preview, sh.prefs, now, v as u8);
    drive::frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, now);
}

// The pictures the last frame declared, by look.z: the background's (-2 the theme shown's
// photograph, -3 its fade), the seasons' (0 to 3 their photographs, 4 to 7 their fades),
// by the date's (-1), and the board's (-8 the flat board's faint ground, -4 to -7 the
// theme shown's raised board and its materials).
fn thumbnails(g: gui::Gui&) -> u8[>..] {
    var out: u8[>..] = [];
    for q in g.quads {
        guard q.look.x == gui::PICTURE else { continue; }
        format(out, if out.len > 0 { " " } else { "" }, q.look.z as i64);
    }
    return out;
}

fn show(sh: shell::Shell&, what: const u8[:]) {
    var out: u8[>..] = [];
    settings::write(sh.prefs, out);
    for i in out.len { if out[i] == '\n' { out[i] = ';'; } }
    print(what, ": ", out, " language ", sh.prefs.language, ", changed ", sh.changed, ", game's board hints moves ", sh.game.b.hints == board::MOVES,
          ", kings ", sh.game.b.king_look);
    sh.changed = false;
}

// The preview at `now`: its size, what is selected and marked, which pieces have a
// must-capture ring (pulsing or still) and how its kings are drawn, and whether it is
// still animating.
fn preview(sh: shell::Shell&, now: f64) {
    let b .= sh.preview;
    board::build_frame_pieces(b, sh.out.layout, now);
    let v .= rules::VARIANTS[b.variant];
    var text: u8[>..] = [];
    format(text, "  preview ", v.size, "x", v.size, ", ", rules::fen(b.pos));
    if b.selected >= 0 { format(text, ", selected ", v.x_of[b.selected], ",", v.y_of[b.selected]); }
    var targets = 0;
    var via = 0;
    for i in 4 {
        targets += popcount(b.marks.target[i]);
        via += popcount(b.marks.via[i]);
    }
    format(text, ", targets ", targets, ", stops ", via);
    if b.flash.x >= 0.0 { format(text, ", wrong ring at ", b.flash.x, " flash ", b.flash.y); }
    var pulsing = 0;
    var still = 0;
    var king: f32 = 0.0;
    for p in b.pieces {
        if p.ring.x == 1.0 { pulsing++; }
        if p.ring.x == 2.0 { still++; }
        king = max(king, p.look.y);
    }
    format(text, ", rings pulsing ", pulsing, " still ", still, ", kings drawn ", king, ", animating ",
           board::animating(b, now));
    print(text);
}

fn main() {
    var out: u8[>..] = [];
    settings::write(settings::Settings {}, out);
    print("defaults:\n", out);
    let s = settings::parse("season = winter\nhints = moves\nkings = stack\nlanguage = et\nboard = 3d\nmaterial = carved\ndraughts = brazilian\nopponent = friend\nturn = on\nlevel = easy\ncolor = black\nclock = 10+5\n");
    out.clear();
    settings::write(s, out);
    print("read back:\n", out, "and the language, the device's: ", s.language);
    var twice: u8[>..] = [];
    settings::write(settings::parse(out), twice);
    print("written again the same: ", twice == out);
    let again = settings::parse("kings = crown\n");
    print("kings crown reads back: ", again.kings == board::CROWN, ", draws ", settings::king_look(again),
          "; auto draws ", settings::king_look(settings::Settings {}));
    let odd = settings::parse("season = monsoon\nhints\nkings = tower\nlanguage = xx\n  board =  2d  \ndraughts = english\nopponent = robot\nlevel = 4\ncolor = red\nclock = 3+2\n");
    out.clear();
    settings::write(odd, out);
    print("unknown values and a line without one:\n", out);

    // The tablet's landscape at 900 dp across its shorter side, as before the list
    // scrolled; the list scrolls to each tile tapped (seen).
    gui::short_dp = 900.0;
    var g = gui::Gui {};
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    strings::use(strings::EN);
    var sh = shell::new(rules::RUSSIAN);
    sh.screen = shell::SETTINGS;
    drive::frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, 0.0);
    print("tiles ", drive::tiles(g), " of ", listed(sh), ", the kings' tiles' pieces ", sh.out.ui_pieces.len, ": ",
          sh.out.ui_pieces[0].look.y, " and ", sh.out.ui_pieces[1].look.y);
    if drive::verbose { print("the list: ", g.scroll.view, " scrolls ", g.scroll.max, " px"); }
    else { print("the list: ", if g.scroll.max > 0.0 { "scrolls" } else { "still" }); }
    // The board is right of the list: every tile and the glass end left of it.
    var right: f32 = 0.0;
    for q in g.quads { right = max(right, q.rect.x + q.rect.z); }
    if drive::verbose {
        print("landscape: board at ", sh.out.layout.board, ", the list ends at ", right, ", clear ",
              right < sh.out.layout.board.x);
    } else {
        print("landscape: the board right of the list, clear ", right < sh.out.layout.board.x);
    }
    print("opened, defaults:");
    preview(sh, 0.0);
    preview(sh, 1.0);
    drive::frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, 2.0);
    print("after the flash:");
    preview(sh, 2.0);
    drive::frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, 3.0);
    print("after the pulse:");
    preview(sh, 3.0);

    tap(sh, g, SUMMER, 4.0);
    show(sh, "summer");
    tap(sh, g, RAISED, 4.1);
    show(sh, "3D");
    tap(sh, g, MOVES, 4.3);
    show(sh, "all moves");
    preview(sh, 4.4);
    draughts(sh, g, rules::RUSSIAN, 4.5);
    show(sh, "Russian");
    preview(sh, 4.6);
    tap(sh, g, STACK, 4.7);
    show(sh, "stack");
    preview(sh, 4.8);
    tap(sh, g, MISTAKES, 4.9);
    show(sh, "mistakes only");
    preview(sh, 5.0);
    // The moves panel's row: off, then marks again; the game follows (apply_prefs).
    tap(sh, g, LIST_OFF, 5.1);
    print("moves panel off: moves ", sh.prefs.moves, ", the game's ", sh.game.moves_shown, ", to write ", sh.changed);
    tap(sh, g, LIST_MARKS, 5.2);
    print("marks: moves ", sh.prefs.moves, ", the game's ", sh.game.moves_shown);
    // Puzzles a day: 10, then 4 again.
    tap(sh, g, DAILY_8, 5.3);
    print("8 a day: ", sh.prefs.daily_count, ", to write ", sh.changed);
    tap(sh, g, DAILY_8 - 2, 5.4);
    print("4 a day: ", sh.prefs.daily_count);
    // A file from before the counts were 3, 4, 6, and 8 (2026-11-16): the nearest, up on a tie.
    print("a file's 5 a day reads ", settings::parse("daily_count = 5\n").daily_count, ", 10 reads ",
          settings::parse("daily_count = 10\n").daily_count, ", 1 reads ", settings::parse("daily_count = 1\n").daily_count);
    sh.changed = false;
    draughts(sh, g, rules::BRAZILIAN, 9.0);
    show(sh, "Brazilian");
    tap(sh, g, AUTO, 9.1);
    show(sh, "auto");
    draughts(sh, g, rules::INTERNATIONAL, 9.2);
    show(sh, "International");

    // The material: Wood, Stone, and Carved raise the board in it, Raised in the
    // season's own; Flat keeps it, and the chosen tile is lit.
    tap(sh, g, WOOD, 9.21);
    show(sh, "wood");
    tap(sh, g, STONE, 9.22);
    show(sh, "stone");
    tap(sh, g, FLAT, 9.23);
    show(sh, "flat");
    tap(sh, g, CARVED, 9.24);
    show(sh, "carved");
    var lit: u8[>..] = [];
    for i in 5 {
        let r = drive::rect(g, FLAT + i);
        for q in g.quads {
            if q.look.x == gui::BUTTON && q.rect.x == r.x && q.rect.y == r.y && q.extra.y == gui::CHOSEN {
                format(lit, " ", FLAT + i);
            }
        }
    }
    print("the Board row's lit tile:", lit);
    tap(sh, g, RAISED, 9.25);
    show(sh, "raised, the season's own");

    // The language: its button opens a list over the screen, its rows after the
    // screen's tiles; a tap on a language switches and closes it.
    tap(sh, g, LANGUAGE, 9.3);
    if drive::verbose {
        print("the language list open ", sh.prefs.languages_open, ", tiles ", drive::tiles(g), ", changed ", sh.changed,
              ", each row ", drive::rect(g, at(sh, ENGLISH)).w / g.scale, " dp tall");
    } else {
        print("the language list open ", sh.prefs.languages_open, ", tiles ", drive::tiles(g), ", changed ", sh.changed,
              ", each row 88 dp tall at least: ", drive::ok(drive::rect(g, at(sh, ENGLISH)).w >= gui::TAP * g.scale - 0.5));
    }
    sh.changed = false;
    tap(sh, g, EESTI, 9.31);
    show(sh, "Eesti");
    strings::use(strings::ET);  // as the app does once the change is written
    print("closed: ", !sh.prefs.languages_open, ", tiles ", drive::tiles(g));
    tap(sh, g, BY_DATE, 9.4);
    show(sh, "by the date");
    // A tap outside the list closes it and does nothing else; back closes it too and
    // stays on settings.
    tap(sh, g, LANGUAGE, 9.41);
    drive::tap(sh, g, float2 { 2.0, 2.0 }, 9.42);
    print("a tap outside: open ", sh.prefs.languages_open, ", on settings ", sh.screen == shell::SETTINGS,
          ", language ", sh.prefs.language);
    tap(sh, g, LANGUAGE, 9.43);
    print("back: went back ", !shell::back(sh, 9.44) || sh.screen != shell::SETTINGS, ", open ", sh.prefs.languages_open);
    drive::idle(sh, g, 9.45);
    tap(sh, g, LANGUAGE, 9.46);
    tap(sh, g, ENGLISH, 9.5);
    show(sh, "English");
    strings::use(strings::EN);

    // About: its row opens a card over the screen, which takes no tap; Copy asks the app
    // to copy its text, and a tap outside the card or back closes it. Its tiles are small
    // but their taps a tap at least. The app fills what it shows as it opens.
    sh.about.filled = true;
    sh.about.version.append("1.2.3");
    sh.about.aa.append("4× MSAA");
    tap(sh, g, ABOUT, 9.51);
    let about_row = drive::rect(g, at(sh, ABOUT));
    print("About: open ", sh.prefs.about_open, ", asks the app to fill it ", sh.out.about, ", tiles ", drive::tiles(g),
          ", the row ", drive::ok(about_row.w < gui::TAP * g.scale), " smaller than a tap");
    drive::tap(sh, g, drive::tile(g, at(sh, PLAIN)), 9.52);
    print("a tap on Plain under the card: plain ", sh.prefs.plain, ", open ", sh.prefs.about_open);
    drive::tap(sh, g, drive::tile(g, at(sh, COPY)), 9.53);
    print("Copy: copied ", sh.about.copied, ", open ", sh.prefs.about_open);
    var copied: u8[..2048] = [];
    settings::about_text(sh.prefs, sh.about, copied);
    let first, unused_rest, unused_more = split_once(copied[..], '\n');
    print("its text's first line: ", first);
    drive::tap(sh, g, drive::tile(g, at(sh, CLOSE)), 9.54);
    print("close: open ", sh.prefs.about_open, ", tiles ", drive::tiles(g));
    tap(sh, g, ABOUT, 9.55);
    drive::tap(sh, g, float2 { 2.0, 2.0 }, 9.56);
    print("a tap outside: open ", sh.prefs.about_open, ", on settings ", sh.screen == shell::SETTINGS);
    tap(sh, g, ABOUT, 9.57);
    print("back: went back ", !shell::back(sh, 9.58) || sh.screen != shell::SETTINGS, ", open ", sh.prefs.about_open);
    drive::idle(sh, g, 9.59);

    // Plain keeps the season (by the date here) and its board, shows no photograph, and
    // is kept in the file; the seasons' thumbnails show their fades.
    print("the row: ", strings::get(settings::ROW_NAMES[settings::BACKGROUND_ROW]), ", photo shown ",
          settings::photo_shown(sh.prefs), ", pictures ", thumbnails(g));
    tap(sh, g, PLAIN, 9.6);
    show(sh, "plain");
    drive::frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, 9.65);
    var plain: u8[>..] = [];
    settings::write(sh.prefs, plain);
    let back = settings::parse(plain);
    print("plain: photo shown ", settings::photo_shown(sh.prefs), ", read back plain ", back.plain, " season ",
          back.season, ", pictures ", thumbnails(g));
    tap(sh, g, PHOTO, 9.7);
    show(sh, "photo");
    print("photo: photo shown ", settings::photo_shown(sh.prefs));
    strings::use(strings::ET);
    print("in Estonian: ", strings::get(settings::ROW_NAMES[settings::BACKGROUND_ROW]), ", ",
          strings::get(settings::ROW_NAMES[settings::THEME_ROW]));
    strings::use(strings::EN);

    // Portrait: the board in a band on top, the list under it.
    drive::size = float2 { 800.0, 1280.0 };
    drive::frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, 10.0);
    let first = drive::rect(g, at(sh, PHOTO));
    let clear = sh.out.layout.board.y + sh.out.layout.board.z < g.scroll.view.y && g.scroll.view.y < first.y;
    if drive::verbose {
        print("portrait: board at ", sh.out.layout.board, ", the list from ", g.scroll.view.y, ", clear ", clear,
              ", tiles ", drive::tiles(g));
    } else {
        print("portrait: the board above the list, clear ", clear, ", tiles ", drive::tiles(g));
    }
    tap(sh, g, STACK, 10.1);
    show(sh, "portrait stack");
    drive::tap(sh, g, drive::tile(g, BACK), 10.2);
    print("back: ", sh.screen == shell::HOME);

    // A file's `board = 3d` and `material = stone` play on the 3D board in stone, the
    // Board row lighting Stone, and the keys are kept when another choice is written.
    drive::size = float2 { 1280.0, 800.0 };
    var raised = shell::new(rules::RUSSIAN);
    raised.screen = shell::SETTINGS;
    raised.prefs = settings::parse("board = 3d\nmaterial = stone\n");
    drive::frame(raised, g, float2 { -1.0, -1.0 }, false, false, false, 0.0);
    print("a file's board = 3d, material = stone: raised ", settings::raised(raised.prefs), ", material ",
          raised.prefs.material, ", tiles ", drive::tiles(g), " of ", listed(raised));
    tap(raised, g, STACK, 1.0);
    var kept: u8[>..] = [];
    settings::write(raised.prefs, kept);
    print("kings stack taps: ", raised.prefs.kings == board::STACK, "; board and material kept in the file: ",
          settings::parse(kept).board == settings::RAISED, " ", settings::parse(kept).material == settings::MATERIAL_STONE);
    print("an unknown material is auto: ", settings::parse("material = gold\n").material == settings::MATERIAL_AUTO);
    // The lookout's eye (game screen): off for a new player, kept as `lookout`.
    var on: u8[>..] = [];
    var lookout = settings::Settings {};
    lookout.lookout = true;
    settings::write(lookout, on);
    print("the lookout: off by default ", !settings::Settings {}.lookout, ", on read back ", settings::parse(on).lookout,
          ", off read back ", !settings::parse("lookout = off\n").lookout);
    volume(raised, g);
}

// The Sound section's volume (decided 2026-11-16): off by default on a phone or a tablet,
// half on a desktop (settings::default_volume, which the app sets at launch). The speaker
// at zero brings the sound back at half; then it mutes and unmutes, keeping the level. The
// slider sets the level as it is dragged, which is drawn but neither written nor heard,
// and on release the level is written and a move heard at it. The level is the device's:
// settings.txt keeps `volume` once it was changed, and `sound = off` while muted.
fn volume(sh: shell::Shell&, g: gui::Gui&) {
    print("the volume:");
    sh.screen = shell::SETTINGS;
    drive::size = float2 { 1280.0, 800.0 };
    drive::frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, 20.0);
    print("  by default ", settings::volume_of(sh.prefs), ", muted ", sh.prefs.muted);
    var t = 20.1;
    for k in 3 {
        let at = seen(sh, g, MUTE, t);
        drive::frame(sh, g, at, true, true, false, t);
        drive::frame(sh, g, at, false, false, true, t + 0.02);
        print("  the speaker: volume ", sh.prefs.volume, ", muted ", sh.prefs.muted, ", heard ", sh.out.sound_events.len,
              ", to write ", sh.changed);
        sh.changed = false;
        t += 0.1;
    }
    // The slider is the strip right of the speaker, as tall.
    let m = drive::rect(g, at(sh, MUTE));
    let right = g.scroll.view.x + g.scroll.view.z;
    let y = m.y + 0.5 * m.w;
    let from = float2 { m.x + m.z + 40.0, y };
    let scrolled = g.scroll.offset;
    drive::frame(sh, g, from, true, true, false, t);
    let quarter = sh.prefs.volume;
    var heard = sh.out.sound_events.len;
    drive::frame(sh, g, float2 { from.x + 0.5 * (right - from.x), y + 30.0 }, true, false, false, t + 0.1);
    heard += sh.out.sound_events.len;
    print("  pressed at the slider's left: volume ", quarter, " under 10 ", quarter < 10, "; dragged on, down and a little",
          " off it: volume over 40 ", sh.prefs.volume > 40, ", not scrolled ", g.scroll.offset == scrolled, ", heard ", heard,
          ", to write ", sh.changed);
    drive::frame(sh, g, float2 { right - 60.0, y }, false, false, true, t + 0.2);
    print("  let go further on: volume over 70 ", sh.prefs.volume > 70, ", heard ", sh.out.sound_events.len, ", to write ",
          sh.changed);
    var device: u8[>..] = [];
    players::write_device(sh.prefs.language, 64, true, true, 1, device);
    let back = settings::parse(device);
    print("  settings.txt at 64, muted: ", device.len > 0, ", read back ", back.volume, " ", back.muted, "; a file without",
          " them: ", settings::parse("language = en\n").volume == settings::VOLUME_DEFAULT,
          " ", !settings::parse("language = en\n").muted);
    print("  fullscreen read back ", back.full, "; a file without it windowed ", !settings::parse("language = en\n").full);
    settings::default_volume = 50;
    var fresh = settings::Settings {};
    print("  a desktop's default: ", settings::volume_of(fresh));
    settings::default_volume = 0;
}
