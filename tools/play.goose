// Play the computer in the terminal, to see how it plays at a skill before the app
// has it.
//
//   goose build -o build/play tools/play.goose
//   build/play [russian|international|brazilian] [easy|medium|hard|SKILL] [white|black]
//
// Type a move as the list shows it ("c3-d4", "c3:e5:c7") or its number, "u" to take
// back your last move and the reply, "q" to quit. The board has your side at the
// bottom: w and b are men, W and B kings, * marks the computer's last move. Each
// reply's seed is its ply, so the same game replays the same way.
import std;
import os;
import rules from "../src/rules";
import ai from "../src/ai";

let MAX_PLIES = 600;

fn show(p: rules::Position, human: u8, last: rules::Move, has_last: bool) {
    let v .= rules::VARIANTS[p.variant];
    var at: i64[100];
    for i in 100 { at[i] = -1; }
    var m = v.mask;
    while m != 0 {
        let b = ctz(m);
        m &= m - 1;
        at[v.y_of[b] * v.size + v.x_of[b]] = b;
    }
    let n = v.size;
    for r in n {
        let y = if human == rules::WHITE { n - 1 - r } else { r };
        var line: u8[>..] = [];
        if y + 1 < 10 { line.push(' '); }
        format(line, y + 1);
        line.append("  ");
        for c in n {
            let x = if human == rules::WHITE { c } else { n - 1 - c };
            let b = at[y * n + x];
            var mark: u8 = ' ';
            var ch:   u8 = ' ';
            if b >= 0 {
                let bb = rules::bit(b);
                ch = '.';
                if p.pieces[rules::WHITE] & bb != 0 {
                    ch = if p.kings & bb != 0 { 'W' } else { 'w' };
                } else if p.pieces[rules::BLACK] & bb != 0 {
                    ch = if p.kings & bb != 0 { 'B' } else { 'b' };
                }
                if has_last {
                    for s in last.path { if s == b { mark = '*'; } }
                }
            }
            line.push(ch);
            line.push(mark);
        }
        print(line);
    }
    var foot: u8[>..] = [];
    foot.append("    ");
    for c in n {
        let x = if human == rules::WHITE { c } else { n - 1 - c };
        foot.push('a' + x as u8);
        foot.push(' ');
    }
    print(foot);
}

fn main() {
    let a = args();
    var variant: u8 = rules::RUSSIAN;
    var skill = ai::level_skill(ai::MEDIUM);
    var human: u8 = rules::WHITE;
    for k in 1..a.len {
        let s = a[k];
        let named, known = rules::variant_named(s);
        if known { variant = named; }
        else if s == "easy" { skill = ai::level_skill(ai::EASY); }
        else if s == "medium" { skill = ai::level_skill(ai::MEDIUM); }
        else if s == "hard" { skill = ai::level_skill(ai::HARD); }
        else if s == "white" { human = rules::WHITE; }
        else if s == "black" { human = rules::BLACK; }
        else {
            let x, ok = parse_int(s);
            guard ok else {
                write_stderr("usage: play [russian|international|brazilian] [easy|medium|hard|SKILL] [white|black]\n");
                exit(2);
            }
            skill = clamp(x, 0, 100);
        }
    }
    print("skill ", skill, "; you play ", if human == rules::WHITE { "white" } else { "black" },
          ". A move, its number, u to take back, q to quit.");

    var e = ai::Engine { .. };
    ai::init(e);
    var moves:   rules::Moves                 = [];
    var history: rules::Position[..MAX_PLIES] = [];
    var p = rules::start(variant);
    var last = rules::Move { .. };
    var has_last = false;
    var line: u8[>..] = [];
    var text: u8[>..] = [];
    loop {
        rules::generate(p, moves);
        if moves.len == 0 {
            show(p, human, last, has_last);
            print(if p.side == human { "You lose." } else { "You win." });
            break;
        }
        guard history.len < MAX_PLIES else { print("Too long; a draw."); break; }
        if p.side != human {
            let t0 = clock();
            let m = ai::think(e, p, skill, history.len as u64);
            let ms = ((clock() - t0) * 1000.0) as i64;
            text.clear();
            rules::format_move(text, variant, m);
            print("computer: ", text, "   (", ms, " ms, depth ", e.seen, ", ", e.total_nodes,
                  " nodes)");
            history.push(p);
            p = rules::play(p, m);
            last = m;
            has_last = true;
            continue;
        }
        print("");
        show(p, human, last, has_last);
        var list: u8[>..] = [];
        for m, i in moves {
            if i > 0 { list.append("   "); }
            format(list, i + 1);
            list.append(") ");
            rules::format_move(list, variant, m);
        }
        print(list);
        write_stdout("> ");
        flush_stdout();
        line.clear();
        guard read_line(line) else { break; }
        let t = trim(line);
        if t == "q" { break; }
        if t == "u" {
            // Back to your last turn: the reply and your move, or just yours.
            var back = 0;
            while history.len > 0 && (back == 0 || p.side != human) {
                p = history.pop();
                back += 1;
            }
            has_last = false;
            continue;
        }
        var chosen = -1;
        let num, is_num = parse_int(t);
        if is_num && num >= 1 && num <= moves.len { chosen = num - 1; }
        for m, i in moves {
            guard chosen < 0 else { break; }
            text.clear();
            rules::format_move(text, variant, m);
            if text == t { chosen = i; }
        }
        guard chosen >= 0 else { print("Not a legal move here."); continue; }
        history.push(p);
        p = rules::play(p, moves[chosen]);
    }
}
