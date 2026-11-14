// The daily puzzles in the shell (task 088; docs/architecture/puzzles.md, "Daily
// puzzles"): a few a day from the set's library (puzzles::load_library), picked by the
// local date, which the app hands in (Shell.day), and the player, at the player's puzzle
// rating, once Learn is solved (picker::today_open). A new day, seen from home or the
// library, seeds the rating from the course's stars where it has none, picks the day's
// puzzles from the themes the player has opened, marks them had, and keeps them in the
// player's file (settings::Today); they are read from the library into a small table when
// the day, the set, or the player changes, never per frame. A daily puzzle plays on the
// puzzle screen; its first solve moves the rating, and replays the same day win stars
// only. Part of the shell's namespace.
namespace shell;
import std;
import vec;

// Today's puzzles as read from the library: the set, the day, and the player (their id)
// read, and the puzzles in the order they are played. A set of -1 has it read again.
struct Daily {
    set:    i64                                   = -1,
    day:    i64                                   = -1,
    player: i64                                   = -1,
    list:   puzzles::Puzzle[..puzzles::MAX_DAILY] = [],
}

// The playing player's id, which with the date picks their puzzles; 0 with no players
// read (a test's shell).
fn playing_id(sh: Shell&) -> i64 {
    let ps .= sh.players;
    return if ps.playing < ps.list.len { ps.list[ps.playing].id } else { 0 };
}

// The player's daily puzzles in the set shown.
fn today_of(sh: Shell&) -> settings::Today& { return sh.prefs.today[puzzles::loaded]; }

// Today's puzzles ready for home and the library to show: a new day picked where the day
// differs from the one kept, and the table read where the day, the set, or the player
// changed. Only while home or the library shows, the day known, and Today open.
fn sync_daily(sh: Shell&) {
    guard sh.screen == HOME || sh.screen == PICKER else { return; }
    let set = puzzles::loaded;
    guard sh.day >= 0 && picker::today_open(sh.prefs.stars[set]) else { return; }
    if today_of(sh).day != sh.day { new_day(sh); }
    let d .= sh.daily;
    guard d.set != set || d.day != today_of(sh).day || d.player != playing_id(sh) else { return; }
    // A record the library can't read (a library changed since) is picked again.
    if !read_daily(sh) {
        new_day(sh);
        read_daily(sh);
    }
}

// The themes today's puzzles may come from: Captures, and each theme the set has with a
// puzzle solved in the course.
fn opened_themes(stars: const u8[:]) -> u64 {
    var themes = rules::bit(puzzles::CAPTURES);
    for t in puzzles::THEMES {
        if puzzles::theme_count(puzzles::all, t) > 0 && picker::solved(stars, t) > 0 { themes |= rules::bit(t); }
    }
    return themes;
}

// Picks today's puzzles for the playing player in the set shown, and saves them: the
// rating seeded first if it has none, from all the course's stars against three a puzzle.
fn new_day(sh: Shell&) {
    let set = puzzles::loaded;
    let p .= sh.prefs;
    if p.puzzle_rating[set] == 0 {
        let won, all = picker::totals(p.stars[set]);
        p.puzzle_rating[set] = puzzles::first_puzzle_rating(won, all);
    }
    let t .= p.today[set];
    puzzles::pick(puzzles::library, sh.day, playing_id(sh), p.puzzle_rating[set], opened_themes(p.stars[set]), p.seen[set],
                  p.daily_count, t.picked);
    t.day = sh.day;
    t.stars = [0; puzzles::MAX_DAILY];
    for id in t.picked.list { p.seen[set][id / 64] |= rules::bit(id % 64); }
    sh.daily.set = -1;
    sh.changed = true;
}

// Reads today's puzzles from the library into sh.daily; false if one doesn't read.
fn read_daily(sh: Shell&) -> bool {
    let t .= today_of(sh);
    let d .= sh.daily;
    d.list.clear();
    d.set = puzzles::loaded;
    d.day = t.day;
    d.player = playing_id(sh);
    let text = sh.library_text;
    for id in t.picked.list {
        let pz .= d.list.push(default<puzzles::Puzzle>());
        guard puzzles::entry_by_id(text, puzzles::library, id, pz) else {
            d.list.clear();
            d.set = -1;
            return false;
        }
    }
    return true;
}

// The puzzle screen's dots: today's count and stars, with the place of the one playing.
fn show_day(sh: Shell&) {
    let t .= today_of(sh);
    sh.puzzle.day_n = t.picked.list.len;
    sh.puzzle.day_won = t.stars;
}

// Opens today's puzzle at place k at `now`, from the library through a transition, from
// another of today's at once.
fn play_daily(sh: Shell&, k: i64, now: f64 = 0.0) {
    guard k >= 0 && k < sh.daily.list.len else { return; }
    puzzle::open_daily(sh.puzzle, sh.daily.list[k], k);
    show_day(sh);
    sh.theme = -1;
    go_to(sh, PUZZLE, now);
}

// Library puzzle `id` on the puzzle screen, outside today's
// set, for looking the library over (the app's --library flag): its replies, stars, and
// hint as any puzzle's, no dots, and nothing kept: no place in today's record to keep
// stars in, no rating moved, next back to the library.
fn play_library(sh: Shell&, id: i64, now: f64 = 0.0) {
    // A run's flags open it before home or the library has read the library.
    if sh.library != puzzles::loaded || sh.library_text.len == 0 { load_library(sh); }
    var pz = default<puzzles::Puzzle>();
    guard puzzles::entry_by_id(sh.library_text, puzzles::library, id, pz) else { return; }
    puzzle::open_daily(sh.puzzle, pz, puzzles::MAX_DAILY);
    sh.puzzle.day_n = 0;
    sh.theme = -1;
    go_to(sh, PUZZLE, now);
}

// Today's puzzle at place k solved with `won` stars: the most kept, and its first solve
// moves the puzzle rating by the library's difficulty of it.
fn daily_solved(sh: Shell&, k: i64, won: i64) {
    let set = puzzles::loaded;
    let p .= sh.prefs;
    let t .= p.today[set];
    guard k >= 0 && k < t.picked.list.len else { return; }
    if t.stars[k] == 0 {
        let i = puzzles::place_of(puzzles::library, t.picked.list[k]);
        if i >= 0 {
            p.puzzle_rating[set] = puzzles::rated(p.puzzle_rating[set], p.puzzle_rated[set], puzzles::library.list[i].difficulty,
                                                  won);
            p.puzzle_rated[set] += 1;
        }
    }
    if won > t.stars[k] { t.stars[k] = won as u8; }
    sh.changed = true;
    show_day(sh);
}

// Next on today's puzzle at place k: the one after, or after the last the library.
fn daily_next(sh: Shell&, k: i64, now: f64) {
    if k + 1 < sh.daily.list.len { play_daily(sh, k + 1, now); }
    else {
        sh.theme = -1;
        go_to(sh, PICKER, now);
    }
}
