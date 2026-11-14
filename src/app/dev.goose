// The development flags that act on the shell (flags.goose, docs/development.md "Run on
// the Mac"). The loop calls in at fixed points of a frame; with none of them given, each
// call does nothing.
namespace dev;
import std;
import vec;

// Ends the next frame()'s wait at once.
extern fn draughts_wake_now();
// The process's CPU time in seconds and its memory footprint in MB, for --rest.
extern fn draughts_cpu_seconds() -> f64;
extern fn draughts_footprint_mb() -> f64;
// Each thread's name and CPU time so far, on Apple platforms, for --rest.
extern fn draughts_threads(out: u8[:]) -> i64;

struct Dev {
    go:          i64          = -1,    // --go's screen, -1 once switched
    tapped:      i64          = 0,     // --tap's taps played so far
    shown:       bool         = false, // --sheet's sheet and --tip's tip shown
    keyed:       i64          = 0,     // --keys' keys pressed so far
    bench:       bench::Bench = bench::Bench {},  // --bench's frames (bench.goose)
    rest_at:     f64          = -1.0,  // --rest: when the rest began, and the CPU time then
    rest_cpu:    f64          = 0.0,
    rested:      bool         = false,
    rest_passes: i64          = 0, // frame()'s returns during --rest, and the frames drawn
    rest_draws:  i64          = 0,
}

fn new(f: flags::Flags&) -> Dev { Dev { go: f.go, .. } }

// At launch, before the saved game is brought back: the game, settings, position,
// screen, setup, and puzzle the flags give. Their settings are written only if a tap writes them.
fn setup(f: flags::Flags&, sh: shell::Shell&, prefs: settings::Settings) {
    if f.clock >= 0 || f.computer >= 0 {
        let lv = if f.level >= 0 { f.level } else { prefs.level };
        game::start(sh.game, sh.game.b.variant, max(f.clock, 0), f.computer, lv, prefs.skill[lv], prefs.games);
    }
    if f.reset_skill {
        sh.prefs.level = game::EASY;
        sh.prefs.skill = ai::LEVEL_SKILL;
        sh.prefs.played = [0; 3];
        sh.changed = true;
    }
    if f.puzzler_rating > 0 { puzzler(sh, f.puzzler_name[..], f.puzzler_rating, f.variant); }
    if f.board >= 0 { sh.prefs.board = f.board; }
    if f.material >= 0 { sh.prefs.material = f.material; }
    sh.prefs.languages_open = f.languages;
    if f.lookout >= 0 { sh.prefs.lookout = f.lookout == 1; }
    if f.moves >= 0 { sh.prefs.moves = f.moves; }
    if f.hints >= 0 { sh.prefs.hints = f.hints; }
    if f.background >= 0 { sh.prefs.plain = f.background == 1; }
    let fen .= f.fen;
    if fen.len > 0 {
        let b .= sh.game.b;
        let p, ok = rules::parse_fen(fen, b.variant);
        guard ok else { abort(str("not a position: ", fen)); }
        board::set(b, p);
    }
    sh.screen = if f.screen >= 0 { f.screen } else if fen.len > 0 || f.taps.len > 0 || f.clock >= 0 || f.computer >= 0 { shell::GAME } else { shell::HOME };
    // A replay: the newest game of the history read (--history's, else the player's), at
    // --ply's move, opened from the results screen as its row's tap does.
    if f.history.len > 0 { sh.history_file.append(f.history[..]); }
    if sh.screen == shell::REPLAY {
        sh.screen = shell::RESULTS;
        shell::read_history(sh, sh.past.games);
        sh.past.variant = if sh.past.games.len > 0 { sh.past.games[sh.past.games.len - 1].variant } else { sh.prefs.variant };
        shell::open_replay(sh, sh.past.games.len - 1, 0.0);
        if f.ply >= 0 { replay::go(sh.past.replay, f.ply, 0.0); }
        sh.past.replay.best = f.best;
        if sh.screen != shell::REPLAY { sh.screen = shell::RESULTS; }
    }
    // How to play in the flags' draughts (else the player's), at --step's step or its end;
    // a new player's question over home.
    if sh.screen == shell::TUTORIAL {
        if f.variant >= 0 { sh.prefs.variant = f.variant; }
        shell::learn(sh, shell::HOME, 0.0);
        let v = sh.prefs.variant as u8;
        if f.step >= 1 { tutorial::open(sh.lesson, v, f.step - 1); }
        if f.step == flags::STEP_END {
            tutorial::open(sh.lesson, v, tutorial::count(v) - 1);
            sh.lesson.state = tutorial::END;
        }
    }
    if f.ask { sh.who.state = who::ASKING; }
    sh.setup = f.setup;
    // The settings file stays as it is unless a tap in the setup writes it.
    if f.setup != home::NO_SETUP {
        if f.friend >= 0 { sh.prefs.friend = f.friend == 1; }
        if f.variant >= 0 { sh.prefs.variant = f.variant; }
        if f.computer >= 0 { sh.prefs.color = 1 - f.computer; }
        if f.level >= 0 { sh.prefs.level = f.level; }
    }
    // The puzzles are of the flags' draughts, loaded at launch, so home doesn't load the
    // player's set back on the way.
    let to_puzzles = sh.screen == shell::PICKER || sh.screen == shell::PUZZLE || f.go == shell::PICKER
                     || f.go == shell::PUZZLE || f.puzzle >= 0 || f.library >= 1;
    if f.variant >= 0 && to_puzzles { sh.prefs.variant = f.variant; }
    if f.puzzle >= 0 && puzzles::find(puzzles::all, f.puzzle) >= 0 && f.go != shell::PUZZLE {
        shell::play_puzzle(sh, puzzles::find(puzzles::all, f.puzzle));
    }
    if f.library >= 1 { shell::play_library(sh, f.library - 1); }
}

// --puzzler: the player named `name` playing, made if there is none, their Learn solved
// and a puzzle of each other theme, their puzzle rating `rating`, and today's record
// cleared, all written at once; the run's own screens may still show them as read.
fn puzzler(sh: shell::Shell&, name: const u8[:], rating: i64, variant: i64) {
    let ps .= sh.players;
    var n: players::Name = [];
    players::set_name(n, name);
    var at = -1;
    for p, i in ps.list { if p.name == n { at = i; } }
    if at < 0 { guard shell::add_player(sh, players::free_picture(ps, -1), n) else { return; } }
    else { shell::switch_player(sh, at); }
    // The run's --variant, if given, is the player's draughts from now on.
    if variant >= 0 { sh.prefs.variant = variant; }
    let set = puzzles::set_of(sh.prefs.variant as u8);
    var course = puzzles::Set { list: [] };
    var err: u8[>..] = [];
    guard puzzles::parse(puzzles::file(set), course, err) else { return; }
    // Learn solved opens Today, and a puzzle solved in each other theme opens it to the
    // day's pick (shell::opened_themes), so every theme's puzzles come.
    var seen_theme: bool[puzzles::THEMES] = [false; puzzles::THEMES];
    for pz in course.list {
        guard pz.theme == puzzles::LEARN || !seen_theme[pz.theme] else { continue; }
        seen_theme[pz.theme] = true;
        sh.prefs.stars[set][pz.id] = 3;
    }
    sh.prefs.puzzle_rating[set] = rating;
    sh.prefs.puzzle_rated[set] = 30;
    sh.prefs.today[set] = settings::Today {};
    // Their file, and the device's: they are the one playing at the next start.
    players::write(ps, sh.prefs);
    sh.daily.set = -1;
    sh.changed = true;
}

// Before the shell's frame: --go's switch, once the taps have played out and any win they
// lead to has reached --win's moment; then --hold keeps a transition at its moment, and
// --win the end's.
fn before(dv: Dev&, f: flags::Flags&, sh: shell::Shell&, now: f64) {
    if dv.go >= 0 && host::frame_count() >= 2 && dv.tapped >= f.taps.len && !sh.game.b.moving
       && (f.win < 0.0 || ((sh.game.won_at >= 0.0 || sh.game.drawn_at >= 0.0) && now > f.win)) {
        if dv.go == flags::GO_PLAY {
            // As the setup's play, leaving settings.txt as it is.
            shell::play(sh, now);
            sh.changed = false;
        }
        else if dv.go == flags::GO_HERE { shell::play_from_here(sh, now); }
        else if dv.go == shell::PUZZLE { shell::play_puzzle(sh, max(puzzles::find(puzzles::all, f.puzzle), 0), now); }
        else { shell::go_to(sh, dv.go, now); }
        dv.go = -1;
    }
    if f.hold >= 0.0 && sh.from >= 0 { sh.since = now - f.hold * shell::DURATION; }
    if f.win >= 0.0 && sh.game.won_at >= 0.0 { sh.game.won_at = now - f.win; }
    if f.win >= 0.0 && sh.game.drawn_at >= 0.0 { sh.game.drawn_at = now - f.win; }
}

// After the shell's frame: --tap's next tap, true when it tapped; then --bench's start.
fn after_shell(dv: Dev&, f: flags::Flags&, sh: shell::Shell&, g: gui::Gui&, r: render::Renderer&, now: f64) -> bool {
    let d3 .= r.d3;
    var dirty = false;
    let l = sh.out.layout;
    let b .= sh.game.b;
    if dv.tapped < f.taps.len && !b.moving && sh.screen == shell::GAME && b.pos.side != sh.game.computer {
        let v .= rules::VARIANTS[b.variant];
        let sq, ok = rules::parse_square(v, f.taps[dv.tapped]);
        if ok {
            let p = board::center(l, v, sq);
            board::press(b, l, p, now);
            board::release(b, l, p, now);
        }
        dv.tapped++;
        dirty = true;
    }
    // --sheet and --tip once the taps have played and the moves are judged.
    if !dv.shown && (f.sheet || f.tip >= 0) && dv.tapped >= f.taps.len && !b.moving && sh.screen == shell::GAME
       && game::all_judged(sh.game) {
        sh.game.sheet = f.sheet;
        sh.game.tip = f.tip;
        dv.shown = true;
        dirty = true;
    }
    if dv.tapped < f.taps.len && sh.screen == shell::PUZZLE && puzzle::ready(sh.puzzle) {
        let v .= rules::VARIANTS[sh.puzzle.b.variant];
        let sq, ok = rules::parse_square(v, f.taps[dv.tapped]);
        if ok { puzzle::tap(sh.puzzle, l, board::center(l, v, sq), now); }
        dv.tapped++;
        dirty = true;
        // Next was declared before this tap, which may have left a piece waiting.
        g.acted = true;
    }
    if dv.tapped < f.taps.len && sh.screen == shell::TUTORIAL && tutorial::ready(sh.lesson) {
        let v .= rules::VARIANTS[sh.lesson.b.variant];
        let sq, ok = rules::parse_square(v, f.taps[dv.tapped]);
        if ok { tutorial::tap(sh.lesson, l, board::center(l, v, sq), now); }
        dv.tapped++;
        dirty = true;
        g.acted = true;
    }
    if bench::start(dv.bench, f, sh.out.raised, d3.draws, now) { dirty = true; }
    return dirty;
}

// The pointer, held where --mouse puts it, and --keys' next key from the third drawn frame on.
fn pointer(dv: Dev&, f: flags::Flags&, input: gui::Input) -> gui::Input {
    var i = input;
    if f.mouse.x >= 0.0 { i.at = f.mouse; }
    if dv.keyed < f.keys.len && host::frame_count() >= 3 {
        let k = f.keys[dv.keyed];
        if k == flags::KEY_ENTER { i.confirm = true; }
        else if k == flags::KEY_TAB { i.tab = 1; } else if k == flags::KEY_BACKTAB { i.tab = -1; } else { i.step = k; }
        dv.keyed++;
    }
    return i;
}

// Whether the 3D bench waits for each frame now, so the display's pacing leaves it out.
fn waited3d(dv: Dev&) -> bool { bench::waited3d(dv.bench) }

// At the frame's end; true when the loop should end: --frames' count reached, or a bench done.
fn after(dv: Dev&, f: flags::Flags&, r: render::Renderer&, drew: bool, size: int2, now: f64) -> bool {
    if f.frames > 0 && host::frame_count() >= f.frames { return true; }
    // --frames counts frames, so nothing waits for an event.
    if f.frames > 0 { draughts_wake_now(); }
    // --rest S: the app at rest from 12 s after the launch for S seconds, CPU time and footprint printed once.
    if f.rest > 0 && dv.rest_at < 0.0 && now > 12.0 {
        dv.rest_at = now;
        dv.rest_cpu = draughts_cpu_seconds();
        var names: u8[2048] = [0; 2048];
        let k = draughts_threads(names[..]);
        if k > 0 { print("rest: threads' CPU at the start: ", names[..k]); }
    }
    if f.rest > 0 && dv.rest_at >= 0.0 && !dv.rested {
        dv.rest_passes++;
        if drew { dv.rest_draws++; }
    }
    if f.rest > 0 && dv.rest_at >= 0.0 && now >= dv.rest_at + f.rest && !dv.rested {
        dv.rested = true;
        let cpu = draughts_cpu_seconds() - dv.rest_cpu;
        print("rest: ", now - dv.rest_at, " s: process CPU ", cpu, " s (", 100.0 * cpu / (now - dv.rest_at),
              "%), footprint ", draughts_footprint_mb(), " MB; the loop ran ", dv.rest_passes, " times and drew ",
              dv.rest_draws, " frames");
        var names: u8[2048] = [0; 2048];
        let k = draughts_threads(names[..]);
        if k > 0 { print("rest: threads' CPU since the launch: ", names[..k]); }
    }
    return bench::done(dv.bench, f, r, size);
}

// After the loop: --frames' screenshot, and what the 3D board's preparing and drawing took.
fn end(f: flags::Flags&, r: render::Renderer&) {
    let d3 .= r.d3;
    if f.frames > 0 { host::screenshot("draughts.png"); }
    if f.frames > 0 && d3.prep_ms.len > 0 {
        var line: u8[>..] = [];
        for ms in d3.prep_ms { format(line, " ", floor(ms * 100.0 + 0.5) / 100.0); }
        print("3D board prepared in ", d3.prep_ms.len, " steps, each waited, ms:", line);
    }
    if f.frames > 0 && d3.frames > 0 {
        print("3D board: ", d3.frames, " frames showed it, ", d3.draws, " drew it, ", d3.shadows,
              " its shadow map, ", d3.pulses, " only its pulsing marks");
    }
}
