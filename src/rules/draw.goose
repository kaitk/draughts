// Draws (docs/architecture/rules.md, "Draws"): the counts each variant runs and the
// repetition of positions, as pure functions over values. A game keeps a `Draw` beside
// its position, made by draw_start and carried through each move by draw_after (from
// the move) or draw_between (from the positions alone, for a game's history); `seen`,
// how often the position has come, is the caller's: it compares the positions since the
// last man's move or capture (`quiet` plies) with same(). draw_reason then says whether
// the game is drawn and why. Every count runs at once; the first to reach its end draws.
// A *move* below is one side's move, a ply; "N moves each" is 2N plies.
//
// - Repetition, every variant: a position (pieces, kings, side to move) for the third
//   time, not necessarily in a row.
// - Only kings moved, nothing taken (`quiet`): International 25 moves each (FMJD 6.2);
//   Brazilian 15 (FMJD-64 7.2.5); Russian 15 with 4 or 5 pieces on the board and 25
//   with 6 or 7 (6.1.8.8).
// - Both sides with kings and nothing taken or crowned (`calm`): Russian 5 moves each
//   with 2 or 3 pieces, 30 with 4 or 5, 60 with 6 or 7 (6.1.8.6); Brazilian 30 and 60
//   (7.2.6).
// - A lone king against a strong side with a king (`lone`), counted from the move that
//   made the material, which itself doesn't count; a crowning inside it doesn't restart
//   it: International three pieces 16 moves each (6.3), two or one 5 each (6.4);
//   Russian and Brazilian three kings or more by the strong side's 15th move (6.1.8.3–4,
//   7.2.4); Brazilian two pieces or one by its 5th (7.2.8).
// - The main road (`road`), a lone king on the long diagonal a1–h8 against three pieces:
//   Russian of any kind, none of them on it (6.1.8.5); Brazilian with a king among them
//   (7.2.7); drawn by the strong side's 5th move. It runs from when the position first
//   arises with that material and stops for good once the king leaves the diagonal (or,
//   in Russian, a strong piece steps on it).
// A count ends only when the lone king is taken: the federations' "unless a winning
// position" exceptions need judgment and aren't built. English has repetition only.
namespace rules;
import std;

// Why a game is drawn.
let NO_DRAW = 0;
let DRAW_REPEAT = 1;        // the same position a third time
let DRAW_KINGS = 2;         // only kings moved and nothing was taken, for the count
let DRAW_LONE = 3;          // the lone king held out: the strong side didn't take it in time
let DRAW_BALANCE = 4;       // nothing taken or crowned, both sides with kings, for the count

// The lone-king counts, by the material: International's three pieces and two or
// fewer, and the strong side's 15th and 5th move.
let LONE_NONE = 0;
let LONE_THREE = 1;         // International 6.3: 32 plies
let LONE_TWO = 2;           // International 6.4: 10 plies
let LONE_KINGS = 3;         // Russian 6.1.8.3–4, Brazilian 7.2.4: the strong side's 15th move
let LONE_FEW = 4;           // Brazilian 7.2.8: the strong side's 5th move

// The main road's count.
let ROAD_WAITING = 0;       // the material is there; the position hasn't arisen
let ROAD_RUNNING = 1;
let ROAD_STOPPED = 2;       // the king left the road: nothing restarts it

// Room for the positions a game passes to the computer for repetition: those since the
// last man's move or capture, the latest PAST. The counts end every such stretch well
// before this but Russian with 8 pieces or more, where it is only an approximation.
let PAST = 100;

// What a game knows of its past for draws, beside its position.
struct Draw {
    quiet:      i64  = 0,   // plies since a man moved or anything was taken
    calm:       i64  = 0,   // plies since anything was taken or crowned
    lone:       i64  = 0,   // plies of the lone-king count
    lone_kind:  u8   = 0,   // LONE_*, LONE_NONE when none runs
    lone_side:  u8   = 0,   // the strong side
    lone_end:   i64  = 0,   // the ply of the count it draws at
    road:       i64  = 0,   // plies of the main road's count
    road_on:    bool = false, // whether its material is on the board
    road_side:  u8   = 0,   // the strong side
    road_state: u8   = 0,   // ROAD_*
    road_end:   i64  = 0,
    seen:       i64  = 1,   // the times the position has come, this one included (the caller's)
}

// A game's past for the computer: the counts at its position, and the positions since
// the last man's move or capture before it, oldest first.
struct Past {
    draw:   Draw,
    before: Position[..PAST],
}

// Whether two positions are the same for repetition.
fn same(a: Position&, b: Position&) -> bool {
    a.pieces[WHITE] == b.pieces[WHITE] && a.pieces[BLACK] == b.pieces[BLACK] && a.kings == b.kings && a.side == b.side
}

// The long diagonal a1–h8 of an 8×8 board, the main road; none on 10×10.
// Square (i, i) is bit 5i there (rules.goose's layout, h = 4).
fn make_road() -> u64 {
    var r: u64 = 0;
    for i in 8 { r |= bit(5 * i); }
    return r;
}

let ROAD = make_road();

// The side left with one king alone and how its opponent stands, or -1.
fn lone_side(p: Position&) -> i64 {
    for w in 2 {
        let own = p.pieces[w];
        if own != 0 && own & (own - 1) == 0 && own & p.kings != 0 && p.pieces[1 - w] != 0 { return 1 - w; }
    }
    return -1;
}

// The lone-king count p's material runs, and the strong side.
fn lone_class(p: Position&) -> u8, u8 {
    let s = lone_side(p);
    guard s >= 0 else { return LONE_NONE, 0; }
    let n = popcount(p.pieces[s]);
    let k = popcount(p.pieces[s] & p.kings);
    var kind: u8 = LONE_NONE;
    if p.variant == INTERNATIONAL {
        if k >= 1 && n == 3 { kind = LONE_THREE; }
        else if k >= 1 && n <= 2 { kind = LONE_TWO; }
    } else if p.variant == RUSSIAN {
        if k >= 3 { kind = LONE_KINGS; }
    } else if p.variant == BRAZILIAN {
        if k >= 3 { kind = LONE_KINGS; }
        else if k >= 1 && n <= 2 { kind = LONE_FEW; }
    }
    return kind, s as u8;
}

// The ply a count that began in p draws at: `moves` of the strong side's, or each
// side's when `each`.
fn count_end(p: Position&, strong: u8, moves: i64, each: bool) -> i64 {
    let first = if !each && p.side == strong { 1 } else { 0 };
    return 2 * moves - first;
}

fn lone_end(p: Position&, kind: u8, strong: u8) -> i64 {
    return match kind {
        LONE_THREE => 32,
        LONE_TWO => 10,
        LONE_KINGS => count_end(p, strong, 15, false),
        _ => count_end(p, strong, 5, false),
    };
}

// Whether p has the main road's material: a lone king against three pieces (with a king
// among them in Brazilian); and the strong side.
fn road_class(p: Position&) -> bool, u8 {
    guard p.variant == RUSSIAN || p.variant == BRAZILIAN else { return false, 0; }
    let s = lone_side(p);
    guard s >= 0 && popcount(p.pieces[s]) == 3 else { return false, 0; }
    guard p.variant == RUSSIAN || p.pieces[s] & p.kings != 0 else { return false, 0; }
    return true, s as u8;
}

// Whether the main road's position stands: the lone king on it, and in Russian none of
// the strong side's pieces.
fn on_road(p: Position&, strong: u8) -> bool {
    guard p.pieces[1 - strong] & ROAD != 0 else { return false; }
    return p.variant != RUSSIAN || p.pieces[strong] & ROAD == 0;
}

// The main road's count after a position p reached with the material as before (`same`).
fn road_next(d: Draw&, p: Position&, same: bool) {
    let on, s = road_class(p);
    if !same || !on || s != d.road_side || !d.road_on {
        d.road_on = on;
        d.road_side = s;
        d.road_state = ROAD_WAITING;
        d.road = 0;
    } else if d.road_state == ROAD_RUNNING {
        if on_road(p, s) { d.road += 1; } else { d.road_state = ROAD_STOPPED; }
        return;
    }
    if d.road_on && d.road_state == ROAD_WAITING && on_road(p, s) {
        d.road_state = ROAD_RUNNING;
        d.road = 0;
        d.road_end = count_end(p, s, 5, false);
    }
}

// The counts at p as a game begins there: each from zero, those p's material runs from
// p itself.
fn draw_start(p: Position) -> Draw {
    var d = Draw {};
    let kind, s = lone_class(p);
    d.lone_kind = kind;
    d.lone_side = s;
    if kind != LONE_NONE { d.lone_end = lone_end(p, kind, s); }
    road_next(d, p, false);
    return d;
}

// The counts after a move to `after`: whether a man moved (a crowning included),
// anything was taken, a man was crowned. `seen` goes back to 1 for the caller to count.
fn draw_step(d: Draw, after: Position&, man: bool, took: bool, crowned: bool) -> Draw {
    var n = d;
    n.quiet = if man || took { 0 } else { d.quiet + 1 };
    n.calm = if took || crowned { 0 } else { d.calm + 1 };
    n.seen = 1;
    let kind, s = lone_class(after);
    if kind != d.lone_kind || s != d.lone_side {
        n.lone_kind = kind;
        n.lone_side = s;
        n.lone = 0;
        if kind != LONE_NONE { n.lone_end = lone_end(after, kind, s); }
    } else if kind != LONE_NONE {
        n.lone += 1;
    }
    // Only a capture changes the material the main road needs; a crowning keeps it.
    road_next(n, after, !took);
    return n;
}

// The counts after m, one of before's legal moves, which leads to after.
fn draw_after(d: Draw, before: Position&, m: Move&, after: Position&) -> Draw {
    return draw_step(d, after, before.kings & bit(m.from) == 0, m.captured != 0, m.crowned);
}

// The counts after a move from before to after, told from the positions alone.
fn draw_between(d: Draw, before: Position&, after: Position&) -> Draw {
    let s = before.side;
    let men = before.pieces[s] & ~before.kings;
    let kings = popcount(after.pieces[s] & after.kings) > popcount(before.pieces[s] & before.kings);
    return draw_step(d, after, men != after.pieces[s] & ~after.kings, after.pieces[1 - s] != before.pieces[1 - s], kings);
}

// The plies only kings may move with nothing taken before p's variant draws, with
// `total` pieces on the board; 0 for no such count.
fn kings_limit(variant: u8, total: i64) -> i64 {
    return match variant {
        INTERNATIONAL => 50,
        BRAZILIAN => 30,
        RUSSIAN => if total >= 4 && total <= 5 { 30 } else if total >= 6 && total <= 7 { 50 } else { 0 },
        _ => 0,
    };
}

// The plies with nothing taken or crowned before p draws, both sides having kings; 0
// for none.
fn calm_limit(p: Position&, total: i64) -> i64 {
    guard p.pieces[WHITE] & p.kings != 0 && p.pieces[BLACK] & p.kings != 0 else { return 0; }
    if p.variant == RUSSIAN && total <= 3 { return 10; }
    guard p.variant == RUSSIAN || p.variant == BRAZILIAN else { return 0; }
    return if total >= 4 && total <= 5 { 60 } else if total >= 6 && total <= 7 { 120 } else { 0 };
}

// Why p, with counts d, is drawn, or NO_DRAW. A position whose side to move has no move
// is lost, not drawn: the caller asks only once the game goes on.
fn draw_reason(d: Draw&, p: Position&) -> i64 {
    if d.seen >= 3 { return DRAW_REPEAT; }
    if d.lone_kind != LONE_NONE && d.lone >= d.lone_end { return DRAW_LONE; }
    if d.road_state == ROAD_RUNNING && d.road >= d.road_end { return DRAW_LONE; }
    guard d.quiet >= 10 || d.calm >= 10 else { return NO_DRAW; }
    let total = popcount(occupied(p));
    let kings = kings_limit(p.variant, total);
    if kings > 0 && d.quiet >= kings { return DRAW_KINGS; }
    let calm = calm_limit(p, total);
    if calm > 0 && d.calm >= calm { return DRAW_BALANCE; }
    return NO_DRAW;
}

// The moves the count that drew p was of, each side's (DRAW_KINGS, DRAW_BALANCE), for
// saying why.
fn draw_moves(p: Position&, reason: i64) -> i64 {
    let total = popcount(occupied(p));
    return if reason == DRAW_KINGS { kings_limit(p.variant, total) / 2 } else { calm_limit(p, total) / 2 };
}

// What the countdown before a draw shows.
let COUNT_NONE = 0;
let COUNT_DRAW = 1;         // a draw in `moves` moves, whoever makes them
let COUNT_WIN = 2;          // `side` must take the lone king within `moves` of its moves
let COUNT_TWICE = 3;        // the position has come twice: a third time draws

struct Countdown { kind: i64 = COUNT_NONE, moves: i64 = 0, side: i64 = -1 }

// How near its end a count shows, in moves: a child sees the last five coming.
let SOON = 5;

// The count nearest its end at p, if within SOON moves: the moves left, the drawing one
// included. A count of each side's moves draws at ply `end`, so (end - plies + 1) / 2
// moves are left; a count of the strong side's leaves (end - plies + 1) / 2 of its moves
// when it is to move and (end - plies) / 2 when not, and none at all once only the lone
// king's last move is left: that is a draw in 1. A lone king against a lone king counts
// each side's. On a tie the strong side's count shows, so the words don't change from
// one ply to the next. Failing a count, the position come twice.
fn countdown(d: Draw&, p: Position&) -> Countdown {
    var c = Countdown {};
    if d.lone_kind != LONE_NONE { strong(c, p, d.lone_end - d.lone, d.lone_side); }
    if d.road_state == ROAD_RUNNING { strong(c, p, d.road_end - d.road, d.road_side); }
    let total = popcount(occupied(p));
    let kings = kings_limit(p.variant, total);
    if kings > 0 { closer(c, COUNT_DRAW, (kings - d.quiet + 1) / 2, -1); }
    let calm = calm_limit(p, total);
    if calm > 0 { closer(c, COUNT_DRAW, (calm - d.calm + 1) / 2, -1); }
    if c.kind == COUNT_NONE && d.seen == 2 { c.kind = COUNT_TWICE; }
    return c;
}

fn strong(c: Countdown&, p: Position&, left: i64, side: u8) {
    let mine = if p.side == side { 1 } else { 0 };
    let moves = (left + mine) / 2;
    if popcount(p.pieces[side]) == 1 || moves == 0 {
        closer(c, COUNT_DRAW, (left + 1) / 2, -1);
    } else {
        closer(c, COUNT_WIN, moves, side);
    }
}

fn closer(c: Countdown&, kind: i64, moves: i64, side: i64) {
    guard moves >= 1 && moves <= SOON && (c.kind == COUNT_NONE || moves < c.moves) else { return; }
    c.kind = kind;
    c.moves = moves;
    c.side = side;
}

// The counts and the times the last position has come, for a game that went through
// `line`, oldest first, each the position after a legal move from the one before.
fn draw_of(line: Position[:]) -> Draw {
    var d = draw_start(line[0]);
    for i in 1..line.len { d = draw_between(d, line[i - 1], line[i]); }
    d.seen = repeats(line, line.len - 1, d.quiet);
    return d;
}

// The times line[at] has come within the `quiet` plies before it, itself included.
fn repeats(line: Position[:], at: i64, quiet: i64) -> i64 {
    var seen: i64 = 1;
    var back = 2;
    while back <= quiet && back <= at {
        if same(line[at - back], line[at]) { seen += 1; }
        back += 2;
    }
    return seen;
}
