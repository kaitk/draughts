# 049: Draws

Status: todo

The rules have no draw (`src/game/game.goose`: "the rules have none yet"), so a game ends
only in a win: two kings can chase each other forever. Raised by the user, 2026-11-09.

Secondary sources (to be checked against the federations' own texts before building;
the counting conventions differ between them):

- **International (FMJD):** the same position a third time with the same side to move;
  25 moves with only kings moved and no capture (whether 25 each or in all, to check);
  three pieces including a king against a lone king (3 kings, 2 kings and a man, a king
  and 2 men): drawn after 16 moves each; two pieces or fewer including a king against a
  lone king (2 kings, a king and a man, king against king): drawn after 5 moves each.
- **Russian:** the third repetition; 15 moves with only kings moved and no capture; three
  kings against one king holding the main road (the long diagonal): drawn if the 15th
  move doesn't take it; other endgame counts (a 60-move limit in 6- and 7-piece endings)
  uncertain, to check in the Russian Draughts Federation's rules.
- **Brazilian:** the international rules on 8 × 8; its counts to check.

Sources read: en.wikipedia.org/wiki/International_draughts and
en.wikipedia.org/wiki/Russian_draughts, lidraughts.org's and playstrategy.org's variant
pages, the 2022 computer championship's regulations (uwccpi2022.draughtsprograms.eu).
Find the official FMJD rules for competitions (fmjd.org) and the Russian federation's.

## Work

- The rules as pure functions over the game's history and counters (`src/rules/`), per
  variant, tested headless on each count's edge (the move before and the move of the
  draw), and against the computer player's search (it should neither walk into a draw
  it can win nor miss one it needs).
- The game screen: a draw as its own ending, calm, and the computer's skill counting it
  as 0 (`ai::adapt`, which already expects that); a draw by agreement isn't needed.
- For children: show the count running down where a draw approaches (e.g. "5 moves
  left"), so it doesn't arrive as a surprise; in strings for both languages.

## Acceptance criteria

- [ ] Each variant's draw rules confirmed against an official text, with the link
- [ ] Repetition and each move count drawing at exactly the right move, tested
- [ ] The game shows a draw and counts it; the countdown shown before it
