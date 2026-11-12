// A player's games played (task 074): `history-N.txt` beside `player-N.txt`, a line a
// finished game, oldest first, at most MAX_GAMES; the oldest go when a new one comes.
// Pure text in and out, so the tests read and write it headless; the shell reads and
// writes the file (keep_game) only when a game ends and when its last moves have been
// judged, never in a frame that draws.
//
// A line is tab-separated key=value fields, so a later field can be added and an older
// app skips it:
//
//   time=1762890000  draughts=international  against=computer  level=1  skill=40
//   side=white  winner=black  rating=812>796  accuracy=87,91  marks=232345..
//   moves=32-28 19-23 ..
//
// `against=friend` has no level, skill, side, or rating. `side` is the player's,
// `winner` white, black, or draw. `marks` holds a digit a move (ai::NOT_JUDGED..BLUNDER),
// `moves` the moves in PDN, space-separated, as rules::format_move writes them. An
// accuracy of -1 is a side none of whose moves was judged.
namespace history;
import std;
import os;

let MAX_GAMES = 200;
let FRIEND = -1;            // Game.level for a game against a friend
let DRAW = -1;              // Game.winner for a draw

// One game as the results screen shows it; its moves are read only for a replay.
struct Game {
    time:     i64    = 0,       // seconds since the epoch, at its end
    variant:  i64    = 0,
    level:    i64    = FRIEND,  // the computer's level, or FRIEND
    skill:    i64    = 0,
    side:     i64    = 0,       // the player's, against the computer
    winner:   i64    = DRAW,
    before:   i64    = 0,       // the player's rating before and after (against the computer)
    after:    i64    = 0,
    accuracy: i64[2] = [-1, -1],
    // Each side's marks counted, side * ai::MARKS + mark.
    marks: i64[2 * ai::MARKS] = [0; 2 * ai::MARKS],
    plies: i64                = 0,
}

let SIDES = ["white", "black"];

// The player's result in g against the computer: 1 won, 0 drawn, -1 lost.
fn result(g: Game&) -> i64 {
    guard g.winner != DRAW else { return 0; }
    return if g.winner == g.side { 1 } else { -1 };
}

// Appends the line for g, with its notes (marks and moves), to out, no newline.
fn format_game(out: u8[>..]&, g: Game&, notes: game::Notes&) {
    format(out, "time=", g.time, "\tdraughts=", rules::VARIANT_NAMES[g.variant]);
    if g.level == FRIEND {
        out.append("\tagainst=friend");
    } else {
        format(out, "\tagainst=computer\tlevel=", g.level, "\tskill=", g.skill, "\tside=", SIDES[g.side]);
    }
    out.append("\twinner=");
    out.append(if g.winner == DRAW { "draw" } else { SIDES[g.winner] });
    if g.level != FRIEND { format(out, "\trating=", g.before, ">", g.after); }
    format(out, "\taccuracy=", g.accuracy[0], ",", g.accuracy[1]);
    if notes.len > 0 && notes[0].before.side == rules::BLACK { out.append("\tfirst=black"); }
    out.append("\tmarks=");
    for &n in notes { out.push('0' + n.mark); }
    out.append("\tmoves=");
    for &n, i in notes {
        if i > 0 { out.push(' '); }
        rules::format_move(out, g.variant as u8, n.move);
    }
}

fn side_named(v: const u8[:]) -> i64 { if v == "black" { 1 } else { 0 } }

// The game a line holds, and whether it holds one: a time, a known draughts, and a
// winner at least. Its marks are counted by side from the moves' order, white first
// unless the line says otherwise (a game set up from a position: `first=black`).
fn parse_game(line: const u8[:]) -> Game, bool {
    var g = Game {};
    var has_time = false;
    var has_variant = false;
    var has_winner = false;
    var first = 0;
    var marks: const u8[:] = line[..0];
    for field in split(line, '\t') {
        let k, v, ok = split_once(field, '=');
        guard ok else { continue; }
        let n, number = parse_int(v);
        if k == "time" && number {
            g.time = n;
            has_time = true;
        }
        if k == "draughts" {
            let variant, known = rules::variant_named(v);
            if known {
                g.variant = variant;
                has_variant = true;
            }
        }
        if k == "against" && v == "friend" { g.level = FRIEND; }
        if k == "level" && number { g.level = clamp(n, ai::EASY, ai::HARD); }
        if k == "skill" && number { g.skill = clamp(n, 0, 100); }
        if k == "side" { g.side = side_named(v); }
        if k == "first" { first = side_named(v); }
        if k == "winner" {
            g.winner = if v == "draw" { DRAW } else { side_named(v) };
            has_winner = true;
        }
        if k == "rating" {
            let a, b, pair = split_once(v, '>');
            let x, ok_a = parse_int(a);
            let y, ok_b = parse_int(b);
            if pair && ok_a && ok_b {
                g.before = x;
                g.after = y;
            }
        }
        if k == "accuracy" {
            let a, b, pair = split_once(v, ',');
            let x, ok_a = parse_int(a);
            let y, ok_b = parse_int(b);
            if pair && ok_a && ok_b {
                g.accuracy[0] = clamp(x, -1, 100);
                g.accuracy[1] = clamp(y, -1, 100);
            }
        }
        if k == "marks" { marks = v; }
    }
    for c, i in marks {
        let m = (c as i64) - '0';
        guard m >= 0 && m < ai::MARKS else { continue; }
        let s = (first + i) % 2;
        g.marks[s * ai::MARKS + m] += 1;
    }
    g.plies = marks.len;
    return g, has_time && has_variant && has_winner;
}

// The moves of a line, as text, space-separated, and its marks, a digit a move: for a
// replay.
fn moves_of(line: const u8[:]) -> const u8[:], const u8[:] {
    var moves: const u8[:] = line[..0];
    var marks: const u8[:] = line[..0];
    for field in split(line, '\t') {
        let k, v, ok = split_once(field, '=');
        guard ok else { continue; }
        if k == "moves" { moves = v; }
        if k == "marks" { marks = v; }
    }
    return moves, marks;
}

// The file's text with `line` added last, the oldest dropped past MAX_GAMES, or the last
// line replaced by it (`replace`, the same game once its moves are all judged). Lines
// that hold no game are dropped.
fn with_game(text: const u8[:], line: const u8[:], replace: bool) -> u8[>..] {
    var kept: const u8[:][>..] = [];
    for l in split(text, '\n') {
        let g, ok = parse_game(l);
        if ok { kept.push(l); }
    }
    if replace && kept.len > 0 { kept.pop(); }
    let from = max(kept.len - (MAX_GAMES - 1), 0);
    var out: u8[>..] = [];
    for i in from..kept.len {
        out.append(kept[i]);
        out.push('\n');
    }
    out.append(line);
    out.push('\n');
    return out;
}

// The games a file's text holds, oldest first, into out (cleared).
fn games_of(text: const u8[:], out: Game[..MAX_GAMES]&) {
    out.clear();
    for l in split(text, '\n') {
        let g, ok = parse_game(l);
        guard ok else { continue; }
        if out.len == MAX_GAMES {
            for i in MAX_GAMES - 1 { out[i] = out[i + 1]; }
            out.pop();
        }
        out.push(g);
    }
}

// A player's numbers over their games: against each level won, drawn, lost, and against
// a friend the games played; by draughts.
struct Totals {
    // (variant * 3 + level) * 3 + (0 won, 1 drawn, 2 lost)
    computer: i64[rules::VARIANT_COUNT * 9] = [0; rules::VARIANT_COUNT * 9],
    friend:   i64[rules::VARIANT_COUNT]     = [0; rules::VARIANT_COUNT],
}

fn totals(games: Game[..MAX_GAMES]&) -> Totals {
    var t = Totals {};
    for &g in games {
        if g.level == FRIEND {
            t.friend[g.variant] += 1;
            continue;
        }
        let r = result(g);
        let k = if r > 0 { 0 } else if r == 0 { 1 } else { 2 };
        t.computer[(g.variant * 3 + g.level) * 3 + k] += 1;
    }
    return t;
}

// The date of a time in seconds since the epoch, in UTC: year, month 1..12, day 1..31
// (Howard Hinnant's days_from_civil inverse, as app/theme.goose's month).
fn date(epoch: i64) -> i64, i64, i64 {
    let z = (if epoch >= 0 { epoch / 86400 } else { (epoch - 86399) / 86400 }) + 719468;
    let era = (if z >= 0 { z } else { z - 146096 }) / 146097;
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + (if m <= 2 { 1 } else { 0 });
    return y, m, d;
}
