// The app's development flags, for trying it and for screenshots (docs/development.md,
// "Run on the Mac"): each is `--name value` but --reset-skill, which takes none. A field
// left at its default means the flag wasn't given, and the player's settings or the
// app's default hold. --theme, --hints, --lang, --background, and --board override the
// settings for the run without changing them, unless a tap in settings writes them.
namespace flags;
import std;
import vec;

// --go play: a new game from home's setup, as its play starts one.
let GO_PLAY = 99;

// The most --tap flags kept: two taps a move, room for the longest count a shot plays
// to its end from a position (Russian's 60 moves each, 120 plies, takes 240).
let MAX_TAPS = 256;

struct Flags {
    width:      i64 = 1280, // --size WxH: the window, in points on the Mac
    height:     i64 = 800,
    theme:      i64 = -1,   // --theme wood|stone|birch|sunset: the board, else the season's
    background: i64 = -1,   // --background photo|plain: 0 the photograph, 1 the plain fade
    board:      i64 = -1,   // --board 3d|flat: settings::RAISED or settings::FLAT
    hints:      i64 = -1,   // --hints moves: the selected piece's targets (board::MOVES);
    // mistakes only by default
    lang: i64 = -1,         // --lang CODE: a language with a file in strings/, else the
    // system's
    // --dp N: the layout N dp across its shorter side, not 800 (and the density floor
    // off unless --density-floor is given too)
    dp: i64 = -1,
    // --inset L,T,R,B: a phone's safe area in dp of the layout; x < 0 the window's own
    inset: float4 = float4 { -1.0, 0.0, 0.0, 0.0 },
    // --corner W,H: a window's control in the top left corner (iPadOS's), W x H dp of the
    // layout from the screen's corner; the platform's own by default (none on the Mac)
    corner: float2 = float2 { -1.0, 0.0 },
    // --density-floor F with --display-scale S: the scale's floor (gui::scale_of), S
    // standing for the display's (the Mac's is left out: its windows are in points)
    density_floor: f32 = -1.0,
    display_scale: f32 = -1.0,
    fen:           u8[..256], // --fen POSITION: a game from there
    // --tap SQUARE (c3, d10), up to MAX_TAPS: played in order on the first frames, on the
    // game's board or the puzzle's
    taps:   u8[..3][..MAX_TAPS],
    frames: i64 = -1,       // --frames N: stop after N frames and save draughts.png
    // --screen home|game|settings|puzzles: where the run opens (home unless a position,
    // taps, a clock, or the computer are given)
    screen: i64 = -1,
    // --screen friend|computer: home with that setup open (home::FRIEND, COMPUTER)
    setup:  i64 = 0,
    puzzle: i64 = -1,       // --puzzle ID: that puzzle, its taps on its board
    // --variant international|brazilian|russian: a new game of that draughts, and the
    // puzzles' set; with a setup open, its choice
    variant: i64 = -1,
    clock:   i64 = -1,      // --clock none|5+3|10+5: a new game with that clock
    // --computer white|black: a new game against the computer playing that side; with a
    // setup open, the child playing the other
    computer: i64 = -1,
    level:    i64 = -1,     // --level easy|medium|hard: the computer's, else the setup's last
    // --go home|settings|game|play|puzzles|puzzle: switches there on the second frame,
    // through its transition, once any taps have played out: game as continue does, play
    // as the setup's play (GO_PLAY), puzzle from the puzzles to pick from to --puzzle ID
    // or the first
    go:   i64 = -1,
    hold: f64 = -1.0,       // --hold T: keeps a transition at T of the way, 0..1
    win:  f64 = -1.0,       // --win T: keeps a win at T seconds into its celebration
    // --wood N and --marble N: the 3D board's wood (0..3) and winter frame's marble (0 the
    // slate, 1..4); --summer N summer's 3D look (0..5, looks::SUMMERS; 4 and 5 amber
    // stone); --spring N spring's (0 the birch, 1 the elven carved stone, 2 the Baltic
    // folk carved oak)
    wood:   i64 = -1,
    marble: i64 = -1,
    summer: i64 = 0,
    spring: i64 = -1,
    bench:  i64 = 0,        // --bench N: times N of the 3D board's frames, then quits
    // (draw3d.goose)
    // --reset-skill: the playing player back to easy, the computer's skill at every level
    // at its start with the first steps to come, kept in their file; stars and games stay
    reset_skill: bool,
}

// The flags in a program's arguments; one it doesn't know, or a value it can't read, is
// left out.
fn parse(argv: u8[:][>..]) -> Flags {
    var f = Flags { .. };
    var i = 1;
    while i < argv.len {
        let a = argv[i];
        if a == "--reset-skill" {
            f.reset_skill = true;
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
            if found && ok_x && ok_y { f.width = x; f.height = y; }
        }
        if a == "--theme" && theme::by_name(v) >= 0 { f.theme = theme::by_name(v); }
        if a == "--background" && v == "photo" { f.background = 0; }
        if a == "--background" && v == "plain" { f.background = 1; }
        if a == "--board" && v == "3d" { f.board = settings::RAISED; }
        if a == "--board" && v == "flat" { f.board = settings::FLAT; }
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
        if a == "--corner" {
            let w, h, found = split_once(v, ",");
            let x, ok_x = parse_flt(w);
            let y, ok_y = parse_flt(h);
            if found && ok_x && ok_y { f.corner = float2 { max(x as f32, 0.0), max(y as f32, 0.0) }; }
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
                       else if v == "puzzles" { shell::PICKER } else { shell::HOME };
            if v == "friend" { f.setup = home::FRIEND; }
            if v == "computer" { f.setup = home::COMPUTER; }
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
                   else if v == "play" { GO_PLAY } else if v == "puzzles" { shell::PICKER }
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
        if a == "--wood" || a == "--marble" || a == "--summer" || a == "--spring" {
            let n, ok = parse_int(v);
            if ok && a == "--wood" { f.wood = n; }
            if ok && a == "--marble" { f.marble = n; }
            if ok && a == "--summer" { f.summer = clamp(n, 0, looks::SUMMERS - 1); }
            if ok && a == "--spring" { f.spring = n; }
        }
        if a == "--bench" {
            let n, ok = parse_int(v);
            if ok { f.bench = clamp(n, 1, 1000); }
        }
    }
    return f;
}
