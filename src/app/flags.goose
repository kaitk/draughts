// The app's development flags, for trying it and for screenshots (docs/development.md,
// "Run on the Mac"): each is `--name value` but --reset-skill and --no-vsync, which take
// none. A field left at its default means the flag wasn't given, and the player's settings or the
// app's default hold. --theme, --hints, --lang, --background, --board, and --material
// override the settings for the run without changing them, unless a tap in settings writes them.
namespace flags;
import std;
import vec;

// --go play: a new game from home's setup, as its play starts one; --go here: the
// replay's play from here, a game from the move it shows.
let GO_PLAY = 99;
let GO_HERE = 98;

// The most --tap flags kept: two taps a move, room for the longest count a shot plays
// to its end from a position (Russian's 60 moves each, 120 plies, takes 240).
let MAX_TAPS = 256;
let MAX_KEYS = 16;
let KEY_ENTER = 9;          // in keys: Enter, after gui's STEP_UP..STEP_RIGHT
let KEY_TAB = 10;           // Tab, and Shift and Tab
let KEY_BACKTAB = 11;

struct Flags {
    width:      i64  = 1280, // --size WxH: the window, in points on the Mac
    height:     i64  = 800,
    full:       bool = false, // --size full: the desktop's window fills the screen
    theme:      i64  = -1,  // --theme wood|stone|birch|sunset: the board, else the season's
    background: i64  = -1,  // --background photo|plain: 0 the photograph, 1 the plain fade
    board:      i64  = -1,  // --board 3d|flat: settings::RAISED or settings::FLAT
    lookout:    i64  = -1,  // --lookout on|off: the player's lookout, 1 on, 0 off
    moves:      i64  = -1,  // --moves off|list|marks: the player's move list (settings::MOVES_*)
    sheet:      bool = false, // --sheet on: the game's moves' sheet open once the taps have played (task 078)
    languages:  bool = false, // --languages open: settings' language list open (task 080)
    tip:        i64  = -1,  // --tip N: the tip of the game's move N (from 1) shown once the taps have played
    why:        bool = false, // --tip why: the replay's card saying why a game from it doesn't count, open
    // --hints moves: the selected piece's targets (board::MOVES); mistakes only by default
    hints: i64 = -1,
    // --lang CODE: a language with a file in strings/, else the system's
    lang: i64 = -1,
    // --dp N: the layout N dp across its shorter side, not 800 (and the density floor
    // off unless --density-floor is given too)
    dp: i64 = -1,
    // --inset L,T,R,B: a phone's safe area in dp of the layout; x < 0 the window's own
    inset: float4 = float4 { -1.0, 0.0, 0.0, 0.0 },
    // --touch on|off: a desktop's window laid out as a touch screen, its controls as large
    // as a hand needs (gui::desktop_scale), or as a desktop's; on with --size WxH, --dp,
    // or --inset, which stand for a device, unless off is given. 1 on, 0 off, -1 not given
    touch: i64 = -1,
    // --mouse X,Y: the pointer held at pixel X,Y of the window, to shoot the tile it
    // lights on a desktop (gui::hover); x < 0 the mouse's own
    mouse: float2 = float2 { -1.0, -1.0 },
    // --keys up,down,left,right,enter,tab,backtab (up to MAX_KEYS): pressed one a frame from the third
    // drawn frame, to shoot the keys' focus (gui::focus_keys)
    keys: i64[..MAX_KEYS] = [],
    // --density-floor F with --display-scale S: the scale's floor (gui::scale_of), S
    // standing for the display's (the Mac's is left out: its windows are in points)
    density_floor: f32 = -1.0,
    display_scale: f32 = -1.0,
    fen:           u8[..256], // --fen POSITION: a game from there
    // --tap SQUARE (c3, d10), up to MAX_TAPS: played in order on the first frames, on the
    // game's board or the puzzle's
    taps:   u8[..3][..MAX_TAPS],
    frames: i64 = -1,       // --frames N: stop after N frames and save draughts.png
    // --screen home|game|settings|puzzles|results|replay: where the run opens (home unless
    // a position, taps, a clock, or the computer are given); replay the newest game's
    screen: i64 = -1,
    // --screen friend|computer|setup: home with the setup open (home::NEW_GAME), against
    // a friend or the computer, or as the player's file has it
    setup:  i64 = home::NO_SETUP,
    friend: i64 = -1,       // 1 for --screen friend, 0 for computer
    puzzle: i64 = -1,       // --puzzle ID: that puzzle, its taps on its board
    // --history FILE: the games the results screen and a replay read, in place of the
    // playing player's history (a history file's lines, shell/history.goose)
    history: u8[..512],
    ply:     i64 = -1,      // --ply N: a replay at its Nth move (0 the start), else at its end
    // --variant international|brazilian|russian: a new game of that draughts, and the
    // puzzles' set; with a setup open, its choice
    variant: i64 = -1,
    clock:   i64 = -1,      // --clock none|5+3|10+5: a new game with that clock
    // --computer white|black: a new game against the computer playing that side; with a
    // setup open, the child playing the other
    computer: i64 = -1,
    level:    i64 = -1,     // --level easy|medium|hard: the computer's, else the setup's last
    // --go home|settings|game|play|here|puzzles|puzzle: switches there on the second
    // frame, through its transition, once any taps have played out: game as continue
    // does, play as the setup's play (GO_PLAY), here as the replay's play from here
    // (GO_HERE, with --screen replay), puzzle from the puzzles to pick from to --puzzle ID
    // or the first
    go:   i64 = -1,
    hold: f64 = -1.0,       // --hold T: keeps a transition at T of the way, 0..1
    win:  f64 = -1.0,       // --win T: keeps a win at T seconds into its celebration
    // --wood N and --marble N: the 3D board's wood (0..3) and winter frame's marble (0 the
    // slate, 1..4); --summer N summer's 3D look (0..6, looks::SUMMERS; 4 and 5 amber
    // stone); --spring N spring's (0 the birch, 1 the elven carved stone, 2 the Baltic
    // folk carved oak, 3 the plain stone); --autumn N autumn's (0 the wood, 1..3 stone,
    // looks::AUTUMNS) and --winter N winter's (0 the slate, 1..3 wood, looks::WINTERS).
    // Each, given, picks its season's look over the player's material, for tuning; -1 not
    // given
    wood:   i64 = -1,
    marble: i64 = -1,
    summer: i64 = -1,
    autumn: i64 = -1,
    winter: i64 = -1,
    spring: i64 = -1,
    // --material auto|wood|stone|carved: the raised board's material for the run
    // (settings::MATERIAL_AUTO..), as settings' Board row sets it
    material: i64 = -1,
    // --bench N: times N of the board's frames, then quits (draw3d.goose; the flat board's
    // in draughts.goose)
    bench: i64 = 0,
    // --keep off: the UI and the 3D backdrop drawn as they come each frame, never kept as
    // layers (widgets::prepare, render3d::keep_backdrop), to measure their work alone
    keep: bool = true,
    // --rest S: the CPU time and memory footprint over S seconds at rest, printed once
    // (draughts.goose; where Instruments can't measure them, the iPhone)
    rest: i64 = 0,
    // --reset-skill: the playing player back to easy, the computer's skill at every level
    // at its start with the first steps to come, kept in their file; stars and games stay
    reset_skill: bool,
    // --no-vsync: presents without waiting for the display, to measure frames uncapped
    // (task 070): gfx's NO_VSYNC, or ngfx's in its build; both turn the Metal layer's
    // display sync off
    no_vsync: bool,
}

// The flags in a program's arguments; one it doesn't know, or a value it can't read, is
// left out.
fn parse(argv: u8[:][>..]) -> Flags {
    var f = Flags { .. };
    var sized = false;      // --size WxH given, standing for a device's screen
    var i = 1;
    while i < argv.len {
        let a = argv[i];
        if a == "--reset-skill" {
            f.reset_skill = true;
            i += 1;
            continue;
        }
        if a == "--no-vsync" {
            f.no_vsync = true;
            i += 1;
            continue;
        }
        guard i + 1 < argv.len else { break; }
        let v = argv[i + 1];
        i += 2;
        if a == "--size" {
            let w, h, found = split_once(v, "x");
            let x, ok_x = parse_int(w);
            let y, ok_y = parse_int(h);
            if found && ok_x && ok_y { f.width = x; f.height = y; sized = true; }
            if v == "full" { f.full = true; }
        }
        if a == "--theme" && theme::by_name(v) >= 0 { f.theme = theme::by_name(v); }
        if a == "--background" && v == "photo" { f.background = 0; }
        if a == "--background" && v == "plain" { f.background = 1; }
        if a == "--board" && v == "3d" { f.board = settings::RAISED; }
        if a == "--board" && v == "flat" { f.board = settings::FLAT; }
        if a == "--material" { for name, k in settings::MATERIAL_NAMES { if v == name { f.material = k; } } }
        if a == "--lookout" && v == "on" { f.lookout = 1; }
        if a == "--lookout" && v == "off" { f.lookout = 0; }
        if a == "--moves" && v == "off" { f.moves = settings::MOVES_HIDDEN; }
        if a == "--sheet" && v == "on" { f.sheet = true; }
        if a == "--languages" && v == "open" { f.languages = true; }
        if a == "--tip" {
            let n, ok = parse_int(v);
            if ok && n >= 1 { f.tip = n - 1; }
        }
        if a == "--tip" && v == "why" { f.why = true; }
        if a == "--moves" && v == "list" { f.moves = settings::MOVES_LIST; }
        if a == "--moves" && v == "marks" { f.moves = settings::MOVES_MARKS; }
        if a == "--keep" && v == "off" { f.keep = false; }
        if a == "--hints" && v == "moves" { f.hints = board::MOVES; }
        if a == "--lang" { f.lang = strings::pick(v); }
        if a == "--dp" {
            let n, ok = parse_int(v);
            if ok && n >= 200 { f.dp = n; }
        }
        if a == "--inset" {
            var rest: const u8[:] = v;
            var d:    f32[4]      = [0.0; 4];
            var good = true;
            for k in 4 {
                let part, after, more = split_once(rest, ',');
                let x, ok = parse_flt(part);
                good = good && ok && more == (k < 3);
                d[k] = x as f32;
                rest = after;
            }
            if good { f.inset = float4 { max(d[0], 0.0), max(d[1], 0.0), max(d[2], 0.0), max(d[3], 0.0) }; }
        }
        if a == "--touch" && v == "on" { f.touch = 1; }
        if a == "--touch" && v == "off" { f.touch = 0; }
        if a == "--mouse" {
            let xs, ys, found = split_once(v, ",");
            let x, ok_x = parse_flt(xs);
            let y, ok_y = parse_flt(ys);
            if found && ok_x && ok_y && x >= 0.0 && y >= 0.0 { f.mouse = float2 { x as f32, y as f32 }; }
        }
        if a == "--keys" {
            var rest: const u8[:] = v;
            while rest.len > 0 && f.keys.len < MAX_KEYS {
                let part, after, more = split_once(rest, ",");
                let k = if part == "up" { gui::STEP_UP } else if part == "down" { gui::STEP_DOWN } else if part == "left" { gui::STEP_LEFT }
                        else if part == "right" { gui::STEP_RIGHT } else if part == "enter" { KEY_ENTER }
                        else if part == "tab" { KEY_TAB } else if part == "backtab" { KEY_BACKTAB } else { gui::STEP_NONE };
                if k != gui::STEP_NONE { f.keys.push(k); }
                rest = if more { after } else { "" };
            }
        }
        if a == "--density-floor" {
            let x, ok = parse_flt(v);
            if ok { f.density_floor = x as f32; }
        }
        if a == "--display-scale" {
            let x, ok = parse_flt(v);
            if ok { f.display_scale = x as f32; }
        }
        if a == "--fen" && v.len <= 256 {
            f.fen.clear();
            f.fen.append(v);
        }
        if a == "--tap" && v.len >= 2 && v.len <= 3 && f.taps.len < MAX_TAPS {
            let t .= f.taps.push([]);
            t.append(v);
        }
        if a == "--frames" {
            let n, ok = parse_int(v);
            if ok { f.frames = n; }
        }
        if a == "--screen" {
            f.screen = if v == "game" { shell::GAME } else if v == "settings" { shell::SETTINGS }
                       else if v == "puzzles" { shell::PICKER } else if v == "results" { shell::RESULTS }
                       else if v == "replay" { shell::REPLAY } else { shell::HOME };
            if v == "friend" || v == "computer" || v == "setup" { f.setup = home::NEW_GAME; }
            if v == "friend" { f.friend = 1; }
            if v == "computer" { f.friend = 0; }
        }
        if a == "--history" && v.len < 512 {
            f.history.clear();
            f.history.append(v);
        }
        if a == "--ply" {
            let n, ok = parse_int(v);
            if ok { f.ply = n; }
        }
        if a == "--puzzle" {
            let n, ok = parse_int(v);
            if ok { f.puzzle = n; }
        }
        if a == "--variant" {
            let named, known = rules::variant_named(v);
            for d in settings::DRAUGHTS { if known && named == d { f.variant = d; } }
        }
        if a == "--clock" { for name, k in settings::CLOCK_NAMES { if v == name { f.clock = k; } } }
        if a == "--computer" { f.computer = if v == "white" { rules::WHITE } else { rules::BLACK }; }
        if a == "--level" { for name, k in settings::LEVEL_NAMES { if v == name { f.level = k; } } }
        if a == "--go" {
            f.go = if v == "settings" { shell::SETTINGS } else if v == "game" { shell::GAME }
                   else if v == "play" { GO_PLAY } else if v == "here" { GO_HERE } else if v == "puzzles" { shell::PICKER }
                   else if v == "puzzle" { shell::PUZZLE } else { shell::HOME };
        }
        if a == "--hold" {
            let n, ok = parse_flt(v);
            if ok { f.hold = clamp(n, 0.0, 1.0); }
        }
        if a == "--win" {
            let n, ok = parse_flt(v);
            if ok { f.win = max(n, 0.0); }
        }
        if a == "--wood" || a == "--marble" || a == "--summer" || a == "--spring" || a == "--autumn"
           || a == "--winter" {
            let n, ok = parse_int(v);
            if ok && a == "--wood" { f.wood = n; }
            if ok && a == "--marble" { f.marble = n; }
            if ok && a == "--summer" { f.summer = clamp(n, 0, looks::SUMMERS - 1); }
            if ok && a == "--spring" { f.spring = n; }
            if ok && a == "--autumn" { f.autumn = clamp(n, 0, looks::AUTUMNS - 1); }
            if ok && a == "--winter" { f.winter = clamp(n, 0, looks::WINTERS - 1); }
        }
        if a == "--rest" {
            let n, ok = parse_int(v);
            if ok { f.rest = clamp(n, 1, 600); }
        }
        if a == "--bench" {
            let n, ok = parse_int(v);
            if ok { f.bench = clamp(n, 1, 1000); }
        }
    }
    if f.touch < 0 && (sized || f.dp > 0 || f.inset.x >= 0.0) { f.touch = 1; }
    return f;
}
