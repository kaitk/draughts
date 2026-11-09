// What each level plays (ai/ai.goose). Prints each skill's settings; then, in positions
// with a shot or a single good move, every level's choice and what a deep search thinks
// of it, so a reader sees which levels see how deep (the lines, checked move by move
// with test/perft.py, are in the comments);
// then that the same skill, position, and seed always give the same move, however the
// thinking is cut into steps, while seeds vary the choice among good moves; then how
// wins and losses move the skill.
import std;
import rules from "../../src/rules";
import ai from "../../src/ai";
import check from "../";

fn move_text(variant: u8, m: rules::Move) -> u8[>..] {
    var t: u8[>..] = [];
    rules::format_move(t, variant, m);
    return t;
}

// A score as text: a forced win or loss as how many plies it takes.
fn score_text(v: i64) -> u8[>..] {
    if v > ai::WON { return str("wins in ", ai::WIN - v, " plies"); }
    if v < -ai::WON { return str("loses in ", ai::WIN + v, " plies"); }
    return str(v);
}

// Each level's move in p, with what a deep search thinks of it: its score in
// hundredths of a man, for the side to move, against the best score there.
fn shot(e: ai::Engine&, variant: u8, fen: const u8[:]) {
    let p = check::position(variant, fen);
    var chosen: rules::Move[ai::LEVELS] = [rules::Move { .. }; ai::LEVELS];
    for level in ai::LEVELS { chosen[level] = ai::think(e, p, ai::level_skill(level), 1); }
    ai::begin(e, p, 10, 14, 1000, 300000);
    while e.searching { ai::run(e, 1 << 30); }
    var best = -ai::INF;
    for i in e.root_count { best = max(best, e.score[i]); }
    print(fen, "  best ", score_text(best));
    for level in ai::LEVELS {
        let m = chosen[level];
        var score = 0;
        for i in e.root_count {
            let r = e.plies[0].moves[i];
            if r.from == m.from && r.to == m.to && r.captured == m.captured { score = e.score[i]; }
        }
        print("  level ", level, ": ", move_text(variant, m), "  ", score_text(score));
    }
}

// Each level's moves for seeds 1 to 4, and whether thinking in steps of 7 nodes gives
// the same moves as thinking at once. Hard thinks with a smaller node limit here, to
// keep the test quick; the limit is part of what gives the same move.
fn seeds(e: ai::Engine&, variant: u8, fen: const u8[:]) {
    let p = check::position(variant, fen);
    print(fen);
    e.node_limit = 20000;
    for level in ai::LEVELS {
        var text: u8[>..] = [];
        var same = true;
        for seed: u64 in 1..5 {
            let once = ai::think(e, p, ai::level_skill(level), seed);
            text.append(" ");
            text.append(move_text(variant, once));
            ai::start(e, p, ai::level_skill(level), seed);
            while !ai::step(e, 7) {}
            let sliced = ai::reply(e);
            if sliced.from != once.from || sliced.to != once.to || sliced.captured != once.captured { same = false; }
        }
        print("  level ", level, ":", text, if same { "  (the same in steps)" } else { "  (DIFFER)" });
    }
    e.node_limit = ai::NODE_LIMIT;
}

fn main() {
    for level in ai::LEVELS {
        let s = ai::level_skill(level);
        let pr = ai::params(s);
        print("level ", level, ": skill ", s, ", sees ", pr.depth, "+", pr.extra, " plies, margin ",
              pr.margin, ", temper ", pr.temper, ", gift ", pr.gift, " per 1000, overlooks a capture of 1, 2, 3, 4+ pieces ",
              pr.miss[0], ", ", pr.miss[1], ", ", pr.miss[2], ", ", pr.miss[3], " per 1000");
    }
    var e = ai::Engine { .. };
    ai::init(e);
    // A shot of three plies, which every level sees: b4-c5 b6:d4 c3:e5:g7.
    shot(e, rules::RUSSIAN, "W:Wb2,e1,b4,c3,g3:Bb6,f6,h6,f8");
    // Six plies, too deep for easy: a3-b4 c5:a3:c1 (two men for a king), e3-d4 c1:g5
    // h4:f6:h8, and white has a king and a man more than it gave.
    shot(e, rules::RUSSIAN, "W:Wb2,a3,c3,e3,g3,f4,h4:Ba5,c5,e5,b6,d6,h6,g7");
    // Only g1-f2 holds; the rest lose material some plies on.
    shot(e, rules::RUSSIAN, "W:Wc1,g1,b2,d2,h2,a3,c3,e3,g3,f4,h4:Ba5,c5,g5,b6,d6,f6,h6,e7,g7,b8,d8");
    // 28-23 19x28 22x33x24x15: one man for two.
    shot(e, rules::INTERNATIONAL, "W:W22,27,28,36,37,38,39,40,42,43,44,45,46,47,48,50:B1,2,4,6,7,8,9,10,11,12,13,16,17,19,20,29,35");
    // Nine plies: 18-23 29x18 8-12 18x7x16 17-22 27x18 24-30 35x24 20x47, four men
    // given for five and a king.
    shot(e, rules::INTERNATIONAL, "B:W27,29,31,32,33,34,35,37,41,43,44,45,46,49,50:B1,2,3,4,5,6,8,9,11,15,17,18,20,24,25");
    seeds(e, rules::RUSSIAN, "W:Wa1,c1,e1,g1,b2,d2,f2,h2,a3,c3,e3,g3:Bb6,d6,f6,h6,a7,c7,e7,g7,b8,d8,f8,h8");
    seeds(e, rules::RUSSIAN, "W:Wa1,c1,e1,g1,b2,d2,f2,a3,g3:Bd4,e5,d6,c7,e7,b8,d8,f8,h8");
    seeds(e, rules::RUSSIAN, "B:WKa1,c3,e3,g3:BKh2,b6,d6");
    seeds(e, rules::INTERNATIONAL, "W:W31-50:B1-20");
    seeds(e, rules::INTERNATIONAL, "W:W31,35,36,38,39,40,41,43,44,45,46,47,48,49:B1,2,3,4,5,6,7,10,11,12,13,14,17,22");
    seeds(e, rules::BRAZILIAN, "W:Wa1,c1,e1,g1,b2,d2,f2,h2,a3,c3,e3,g3:Bb6,d6,f6,h6,a7,c7,e7,g7,b8,d8,f8,h8");
    seeds(e, rules::BRAZILIAN, "W:Wa1,c1,e1,g1,f2,h2,a3,e3,g3,b4,f4,a5:Bh4,c5,e5,d6,f6,a7,c7,e7,g7,b8,f8,h8");
    // Wins raise the skill a step and losses lower it, within the level's band; the first
    // three games' steps are twice the rest.
    var text: u8[>..] = [];
    var s = ai::level_skill(ai::EASY);
    var played = 0;
    for r in [1, 1, 1, 1, 1, 1, 1, -1, -1, 0, -1, -1, -1, -1, -1, -1, -1] {
        s = ai::adapt(s, ai::EASY, r, played);
        played += 1;
        format(text, " ", s);
    }
    print("easy, after wins, then losses:", text);
    text.clear();
    s = ai::level_skill(ai::MEDIUM);
    played = 0;
    for r in [-1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1] {
        s = ai::adapt(s, ai::MEDIUM, r, played);
        played += 1;
        format(text, " ", s);
    }
    print("medium, after losses, then wins:", text);
}
