// Ratings on the Elo scale (task 074): the computer's at a skill, and a player's after a
// game against it. Pure integer arithmetic but for the expected score's power of ten.
namespace ai;
import std;
import math;

// The computer's rating at the skills measured, from self-play between neighbours
// (`build/aimatch international A B 200`, 2026-11-11): each gap 400 · log10 of the
// stronger side's score over the weaker's, draws halves, anchored at skill 0 = 500. The
// gaps jump where a skill first sees another ply (12, 25: params' depth) and are small
// between. The chain from 8 to 25 (849) was scaled to 775, between it and the two
// skills' own match (700). Russian's gaps came out a little smaller (8 to 25: 440 for
// 0 to 8's 72). 60 to 90 scored 6.5 of 200 (589); 100 is an estimate until measured.
let RATED_SKILLS:  i64[12] = [0, 8, 12, 16, 20, 25, 30, 40, 50, 60, 90, 100];
let SKILL_RATINGS: i64[12] = [500, 587, 940, 983, 1009, 1362, 1384, 1644, 1900, 2127, 2716, 2800];

// A new player's rating, and the least a rating falls to.
let FIRST_RATING = 800;
let LEAST_RATING = 100;
// K, how far one game moves a rating: K_NEW over a player's first NEW_GAMES rated games
// of a draughts, K after.
let K_NEW = 40;
let K = 20;
let NEW_GAMES = 20;

// The computer's rating at `skill`, between the measured skills by a straight line.
fn skill_rating(skill: i64) -> i64 {
    let s = clamp(skill, 0, 100);
    for i in 1..RATED_SKILLS.len {
        guard s <= RATED_SKILLS[i] else { continue; }
        let a = RATED_SKILLS[i - 1];
        let b = RATED_SKILLS[i];
        return SKILL_RATINGS[i - 1] + (SKILL_RATINGS[i] - SKILL_RATINGS[i - 1]) * (s - a) / (b - a);
    }
    return SKILL_RATINGS[SKILL_RATINGS.len - 1];
}

// A's expected score against B, in thousandths: 1 / (1 + 10^((b − a) / 400)).
fn expected_score(a: i64, b: i64) -> i64 {
    let x = ((b - a) as f64) / 400.0;
    return (1000.0 / (1.0 + pow(10.0, x)) + 0.5) as i64;
}

// A rating after a game against `other`, `result` 1 won, 0 drawn, -1 lost, the player
// having `games` rated games of the draughts before this one.
fn rate(rating: i64, other: i64, result: i64, games: i64) -> i64 {
    let k = if games < NEW_GAMES { K_NEW } else { K };
    let s = 500 * (clamp(result, -1, 1) + 1);
    let d = k * (s - expected_score(rating, other));
    // Rounded half away from zero, so a draw between equals moves nothing.
    let step = if d >= 0 { (d + 500) / 1000 } else { -((-d + 500) / 1000) };
    return max(rating + step, LEAST_RATING);
}
