// A draw offered (src/ai/offer.goose): in kings' endings of each draughts the computer,
// to move and searching at hard, gives its score; then whether the material is a dead
// draw, whether it accepts the child's offer on that score, and whether it would offer
// one itself. Two kings against one, or three against a lone king on the long diagonal,
// score as won and are draws: it accepts. Three kings against one off it, or a king and
// a man more, are won: it declines. Behind, it accepts. With men on the board it offers
// only on a dead draw.
import std;
import rules from "../../src/rules";
import ai from "../../src/ai";
import check from "../";

fn show(e: ai::Engine&, variant: u8, fen: const u8[:], why: const u8[:]) {
    let p = check::position(variant, fen);
    let computer = p.side as i64;
    ai::think(e, p, 90, 1);
    let score, searched = ai::search_score(e);
    let s = if searched { score } else { 0 };
    print(rules::VARIANT_NAMES[variant], " ", fen, "  ", why);
    print("  score ", s, ", dead draw ", offer::dead_draw(p), ", accepts ", offer::accepts_draw(p, computer, s), ", offers ",
          offer::offers_draw(p, computer, s));
}

fn main() {
    var e = ai::Engine { .. };
    e.node_limit = 60000;
    let R: u8 = rules::RUSSIAN;
    let I: u8 = rules::INTERNATIONAL;
    let B: u8 = rules::BRAZILIAN;
    show(e, R, "W:WKc1,Ke1:BKa7", "two kings against one: accepts");
    show(e, R, "W:WKc1,Ke1,Kg1:BKa1", "three against one on a1-h8: accepts");
    show(e, R, "W:WKc1,Ke1,Kh2:BKa7", "three against one off it: declines");
    show(e, R, "W:WKb2,c3,e3:BKa7", "a king and two men against a king: declines");
    show(e, R, "B:WKc1,Ke1,Kh2:BKa7", "behind: accepts");
    show(e, R, "W:WKc1,Ke1:BKh8,Ka7", "two kings each: accepts and offers");
    show(e, R, "W:WKc1,Ke1,Kg1:BKb8,Kd8,Kf8", "three kings each: no dead draw, offers on the score");
    show(e, R, "W:WKe1,c3:BKh8,f6", "a king and a man each: accepts, no offer");
    show(e, I, "W:WK48,K49:BK11", "two kings against one: accepts");
    show(e, I, "W:WK48,K49,K50:BK23", "three against one on 46-5: accepts");
    show(e, I, "W:WK48,K49,K50:BK24", "three against one off it: declines");
    show(e, I, "W:WK47,31,32:BK11", "a king and two men against a king: declines");
    show(e, I, "W:WK48,K49:BK11,K15", "two kings each: accepts and offers");
    show(e, B, "W:WKc1,Ke1:BKa7", "two kings against one: accepts");
    show(e, B, "W:WKc1,Ke1,Kg1:BKe5", "three against one on a1-h8: accepts");
    show(e, B, "W:WKc1,Ke1,Kh2:BKa7", "three against one off it: declines");
    show(e, B, "W:WKb2,c3,e3:BKa7", "a king and two men against a king: declines");
}
