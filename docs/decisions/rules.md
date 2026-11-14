# Rules decisions

The decisions behind the rules engine, dated, with their reasons. How it works now:
[Architecture: Rules](../architecture/rules.md).

## Variants

Russian draughts on 8×8 and International on 10×10 come first, as the two played in
Estonia; English checkers, rarely played there, comes last, built in the engine and
checked by perft but not offered in the app.

The variant is data (`rules::Variant`), not code per variant, so a new one is a row of
fields and Brazilian is International's rules on 8×8.

International's crowning follows FMJD's Official Rules (Annex 1), art. 3.5 and 4.15: a
man that passes over the far row during a capture and ends elsewhere stays a man.

The majority rule's piece that can take fewer than another has no move, and
`rules::can_take_from` tells it from a piece with no capture, so the board can say why
a child's tap does nothing. Checked on the board with several capturing pieces, equal and
unequal, a king and a man, and captures through a shared first stop, in International,
Brazilian, and Russian (2026-11-09, `test/board/several`).

## Representation

Bitboards with ghost bits: one bit per dark square, with an unused bit before each odd
row, so every diagonal step is a fixed shift and a step off the board lands on a ghost bit
or outside the mask. Positions are values, so undo is a stack of them.

`rules::generate` fills a buffer the caller owns (`rules::Moves`, 512 moves), so
generating allocates nothing.

A move carries no stops (2026-11-14): `rules::Move` is its ends, the pieces it takes, and
whether it crowns, 16 bytes; the stops are a `rules::Way` that only the board asks for
(`ways`, `way_of`). At 64 bytes with 34 stops inline, the computer's frames took 2 MB;
perft went from 16.7 M to 44.7 M positions a second in International, with the same
counts. `MAX_MOVES` stays 512: a search found a position with 407 moves
(`test/rules/most_moves`). Rejected: stops encoded compactly in the move (still 25
bytes), and a stops query per square for every move generated.

## Draws

A game is drawn at once when a rule's count ends; nobody claims it, since an app has no
arbiter. The federations' exceptions that need judgment ("unless either side can win",
"a winning position"), Russian 6.1.8.7 (an arbiter's call), and 6.1.10.4 (competition
clocks) aren't built.

The sources, where they differ: lidraughts follows IDF's text for Russian, and Brazilian
leaflets give other numbers. The app follows Russia's 2022 sport rules, FMJD's Annex 1
for International (read from a copy, as fmjd.org's own is gone), and FMJD's draughts-64
text for Brazilian.

The game keeps no counts of its own: it folds them over its record whenever the position
changes, so undo and a saved game bring them back with no new state.

The game's record (where it began, the positions before each move, its past for draws) is
a value of the rules', `rules::Record`, held by the board (2026-11-14), not the board
widget's own fields; undo, the draws, judging, and saving work on it. Rejected: putting it
in `game/`, which the board can't import, and keeping the draw counts as they're played,
which undo and a saved game would have to rebuild anyway.
