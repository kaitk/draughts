// The development flags (flags.goose, docs/development.md "Run on the Mac"): those that
// set up the shell at launch (setup), and those that act while the loop runs: --tap's taps, --go's switch, --win's and --hold's moments, --bench's
// frame times, --rest's CPU and footprint, and --frames' count and screenshot. The loop
// calls in at fixed points of a frame, and with none of these flags given each call does
// nothing.
namespace dev;
import std;
import vec;
import gfx;

// Ends the next frame()'s wait at once: an event pushed now (wake.c).
extern fn draughts_wake_now();
// The process's CPU time in seconds and its memory footprint in MB (memory.c), for --rest.
extern fn draughts_cpu_seconds() -> f64;
extern fn draughts_footprint_mb() -> f64;
// Each thread's name and CPU time so far, on Apple platforms (memory.c), for --rest.
extern fn draughts_threads(out: u8[:]) -> i64;

struct Dev {
    go:     i64 = -1,           // --go's screen, -1 once switched
    tapped: i64 = 0,            // --tap's taps played so far
    // --bench N on the flat board: N whole frames, from the shell's fill to the GPU done,
    // each waited for (cpu: up to the submit); then N as the loop draws them, frame to
    // frame. In seconds; draw3d::Bench times the 3D board.
    bench2d:     draw3d::Bench = draw3d::Bench {},
    flat_bench:  bool          = false, // this frame is one of the flat board's bench
    drawn_at:    f64           = 0.0,   // when this frame's drawing began (clock())
    rest_at:     f64           = -1.0,  // --rest: when the rest began, and the CPU time then
    rest_cpu:    f64           = 0.0,
    rested:      bool          = false,
    rest_passes: i64           = 0, // frame()'s returns during --rest, and the frames drawn
    rest_draws:  i64           = 0,
}

fn new(f: flags::Flags&) -> Dev { Dev { go: f.go, .. } }

// At launch, once the shell has the player's settings (`prefs`, as read) and before the
// saved game is brought back: the game, the settings, the position, the screen, the
// setup, and the puzzle the flags give. The settings they set apply for the run and are
// written only if a tap there writes them.
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
    if f.board >= 0 { sh.prefs.board = f.board; }
    if f.lookout >= 0 { sh.prefs.lookout = f.lookout == 1; }
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
    sh.setup = f.setup;
    // A setup the flags open shows the draughts, the child's color, and the level they
    // give, with the settings file left as it is unless a tap in the setup writes it.
    if f.setup != home::NO_SETUP {
        if f.variant >= 0 { sh.prefs.variant = f.variant; }
        if f.computer >= 0 { sh.prefs.color = 1 - f.computer; }
        if f.level >= 0 { sh.prefs.level = f.level; }
    }
    // The puzzles the flags open are of their draughts' set, loaded at launch: the
    // library's switch lights those draughts, and home doesn't load the player's set back
    // on the way.
    let to_puzzles = sh.screen == shell::PICKER || sh.screen == shell::PUZZLE || f.go == shell::PICKER
                     || f.go == shell::PUZZLE || f.puzzle >= 0;
    if f.variant >= 0 && to_puzzles { sh.prefs.variant = f.variant; }
    if f.puzzle >= 0 && puzzles::find(puzzles::all, f.puzzle) >= 0 && f.go != shell::PUZZLE {
        shell::play_puzzle(sh, puzzles::find(puzzles::all, f.puzzle));
    }
}

// After the system's back, before the shell's frame. A switch the flags ask for waits for
// their taps to have played out, and for the win they lead to, if any, held at --win's
// moment (which must be past: the celebration's start is kept as a time, never before
// 0). Then --hold keeps a transition at its moment, and --win the end's.
fn before(dv: Dev&, f: flags::Flags&, sh: shell::Shell&, now: f64) {
    if dv.go >= 0 && host::frame_count() >= 2 && dv.tapped >= f.taps.len && !sh.game.b.moving
       && (f.win < 0.0 || ((sh.game.won_at >= 0.0 || sh.game.drawn_at >= 0.0) && now > f.win)) {
        if dv.go == flags::GO_PLAY {
            // As the setup's play, leaving settings.txt as it is: the count of games
            // against the computer and the choices the flags gave aren't written.
            shell::play(sh, now);
            sh.changed = false;
        }
        else if dv.go == shell::PUZZLE { shell::play_puzzle(sh, max(puzzles::find(puzzles::all, f.puzzle), 0), now); }
        else { shell::go_to(sh, dv.go, now); }
        dv.go = -1;
    }
    if f.hold >= 0.0 && sh.from >= 0 { sh.since = now - f.hold * shell::DURATION; }
    if f.win >= 0.0 && sh.game.won_at >= 0.0 { sh.game.won_at = now - f.win; }
    if f.win >= 0.0 && sh.game.drawn_at >= 0.0 { sh.game.drawn_at = now - f.win; }
}

// After the shell's frame and the settings' writes: --tap's next tap, on the game's board
// when it is the child's turn or on a puzzle's when it takes one. True when it tapped,
// a change to draw. --bench then starts timing: the 3D board 2 s after the launch,
// settled (draw3d.goose), and the flat board's frames.
fn after_shell(dv: Dev&, f: flags::Flags&, sh: shell::Shell&, g: gui::Gui&, d3: draw3d::Drawer&, now: f64) -> bool {
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
    if dv.tapped < f.taps.len && sh.screen == shell::PUZZLE && puzzle::ready(sh.puzzle) {
        let v .= rules::VARIANTS[sh.puzzle.b.variant];
        let sq, ok = rules::parse_square(v, f.taps[dv.tapped]);
        if ok { puzzle::tap(sh.puzzle, l, board::center(l, v, sq), now); }
        dv.tapped++;
        dirty = true;
        // Next was declared before this tap, which may have left a piece waiting.
        g.acted = true;
    }
    if f.bench > 0 && sh.out.raised && d3.draws > 0 && now > 2.0 && d3.bench.n == 0 { d3.bench.n = f.bench; }
    if d3.bench.n > 0 { dirty = true; }
    dv.flat_bench = f.bench > 0 && !sh.out.raised && now > 2.0 && dv.bench2d.i < 2 * f.bench;
    if dv.flat_bench { dirty = true; }
    return dirty;
}

// Before the frame's drawing, from the shell's fill on.
fn drawing(dv: Dev&) { dv.drawn_at = clock(); }

// After the frame's pass ended: the flat board's bench times it, its first N frames each
// waited for, then N as the loop draws them.
fn drawn(dv: Dev&, f: flags::Flags&) {
    guard dv.flat_bench else { return; }
    let t0 = dv.drawn_at;
    let bn .= dv.bench2d;
    if bn.i < f.bench {
        bn.cpu.push(clock() - t0);
        gfx::flush();
        bn.all.push(clock() - t0);
    } else {
        // The presented frames' start, for the compositor's count of them.
        if bn.i == f.bench { print("bench2d: presenting"); }
        if bn.i > f.bench { bn.gap.push(t0 - bn.last); }
        bn.last = t0;
    }
    bn.i++;
}

// Whether the 3D board's bench waits for each frame now: its first two phases do, slower
// than the loop draws them, and aren't paced.
fn waited3d(d3: draw3d::Drawer&) -> bool { d3.bench.n > 0 && d3.bench.i < 2 * d3.bench.n }

// At the frame's end, whether drawn or not; true when the loop should end: --frames'
// count reached, or a bench done.
fn after(dv: Dev&, f: flags::Flags&, d3: draw3d::Drawer&, drew: bool, size: int2, now: f64) -> bool {
    if f.frames > 0 && host::frame_count() >= f.frames { return true; }
    // A --frames run counts frames, not seconds: none waits for an event, so the
    // computer's reply or a transition is the same number of frames as without the wait.
    if f.frames > 0 { draughts_wake_now(); }
    // --rest S: the app at rest from 12 s after the launch for S seconds, its CPU time
    // and footprint printed once (memory.c).
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
    if draw3d::bench_done(d3) { return true; }
    if f.bench > 0 && dv.bench2d.i >= 2 * f.bench {
        print("bench2d: presented");
        var line: u8[>..] = [];
        format(line, "bench2d: summary, ", size.x, "x", size.y, ", ", f.bench, " frames each: cpu ",
               draw3d::median(dv.bench2d.cpu), " ms; waited ");
        draw3d::spread(line, dv.bench2d.all);
        format(line, "; presented ");
        draw3d::rates(line, dv.bench2d.gap);
        print(line);
        return true;
    }
    return false;
}

// After the loop: --frames' screenshot, and what the 3D board's preparing and drawing
// took.
fn end(f: flags::Flags&, d3: draw3d::Drawer&) {
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
