# 040: The coach and the hint

Status: todo (round 2 drawn, a choice pending)

One feature for help in a game against the computer: a coach that shows the player's
danger, and a hint that shows a move. A hint alone makes a player lazy, though lighting
the piece to move helps; the coach teaches to look, as help shouldn't do the thinking
(`docs/product.md`). Asked for 2026-11-09 after a young player tried the game, widened
the same day from a hint button into the coach and the hint together. When it is built,
`docs/product.md` loses "A game has no hint button" and says what the help is.

## What it shows

- **The coach** shows danger, never the answer. From the adaptive skill the app knows
  roughly how far the player sees (`docs/architecture/ai.md`, "Levels"), and the coach
  shows the threats just past that horizon:
  - the player's pieces in danger now: what the computer would take if it were its turn;
  - while the player holds a piece, what that move would leave open (the pieces the
    reply would take, a double jump's both);
  - a king square, only when crowning is a real threat within reach. The computer's
    deeper plan is not shown: it changes almost every move.
- The coach shows less as the skill climbs: a threat the player's depth already sees is
  left to them, and at hard's skills it shows next to nothing.
- **The hint** is the coach's next step: danger first, then which piece, then where to.
  The press that lights the piece spends a hint; a few a game (three in the takes), shown
  as pips on the control.
- Neither shows while the player must capture: the must-capture ring already says what
  to do. Neither shows in puzzles.

## The takes

### Round 2 (2026-11-09)

`prototypes/coach.html` (`?take=a` or `b`, `&mark=` for the coach's color or treatment,
`&state=calm`, `ask`, `held`, `king`, `hint1`, `hint2`, `control`; `&view=sheet` for
every take, mark, and state side by side). Both takes are one feature: one control, its
word the next step (Help shows the danger, free; Which piece lights the piece to move and
spends a hint; Where to shows its square), and one language of marks for the danger and
the hint. The coach takes no new hue: the danger is still, in the app's red, cream, or
shade, or on the pieces themselves; the hint breathes in the glow, as the puzzles' does.
A setting under move hints says whether the coach shows Always or When asked (`control`);
`ask` is the game before Help is pressed. Positions and states as in round 1, the layouts
as built: landscape, a phone's portrait, and the compact small window (task 050).

- **a, corners.** The control is a tile with the bulb, its word, and the pips: beside
  undo move in portrait (halves of the row), over it in the right column, and between
  whose turn and undo in compact. The marks are four corner brackets on a square, which
  nothing else on the board draws: the danger's still, in the coach's color; the hint's
  breathing in the glow, round the piece to move and then round its square with a move
  dot. A crowning: corners and a crown on the square. Three colors (`&mark=`): `red`, the
  wrong move's red, never pulsing (must capture never shows with the coach); `cream`,
  the light piece's cream lightened; `shade`, dark corners on a darkened square.
- **b, the pieces.** No new tile: whose turn becomes the control, a glass tile with the
  piece and the words over a line with the bulb, the next step, and the pips; undo move
  stays as built. The marks are on the pieces, so nothing new is drawn over the board: a
  piece in danger is (`&mark=`) `crack`ed, a line across its face in its own shade;
  `dim`, half gone and drained of color; or `tilt`ed toward where the jump would land,
  after one shake. A crowning is the computer's king as a ghost on its square. The hint
  rings the piece to move with the puzzles' pulsing glow ring and puts its ghost where it
  goes.

Checked with `agent-browser` at 390 × 844 (a phone's portrait), 499 × 645 (compact),
and 1280 × 800 (the tablet's landscape).

### Round 1 (2026-11-09)

`prototypes/coach-1.html` (or `coach.html?round=1`; same parameters, takes `a` to `c`).
Every take gave the coach a soft violet (`#c7a6ff`): a, dashed rings, the hint a tile,
the coach a setting; b, the computer's jump as a dashed line, the coach a tile beside the
hint; c, small "!" badges and one Help tile for danger, piece, and move.

The user on round 1 (2026-11-09): the idea is OK; not sold on the violet (yet); the coach
looks rather different from the hint and feels bolted on, most of all in portrait.

## Open choices

1. Which take, or which mix: the control beside undo (a) or in whose turn (b); corners on
   squares (a) or marks on the pieces (b).
2. The coach's mark: red, cream, or shade (a); crack, dim, or tilt (b). Seen so far:
   red reads best and says danger, but red also means a wrong move; cream is close to
   winter's and spring's pale-blue glow, so a's danger and hint corners differ mostly by
   the hint's breathing; dim's half-gone piece is near the hint's ghost; tilt reads as a
   squashed disc in 2D and would be real geometry in 3D.
3. Whether the coach shows Always or When asked by default, or by skill (on for a new
   player, fading as the skill climbs).
4. The coach's window over the player's horizon: one ply past it, or two; and whether at
   hard it shows nothing at all.
5. When a held piece shows what it leaves open: while dragged over a square (as the
   takes show), or on selecting it, for every target at once.
6. How many hints a game (three in the takes), whether Where to costs a second one, and
   whether a game with hints used counts toward the skill the same.
7. A game against a friend: the hint for whoever moves, the coach for both or neither.
8. In b, whether a child finds that whose turn is a button, as nothing else there is.

## The engine

One threat search on the worker thread (`src/app/think.goose`), as the computer's move
is: on the player's turn, and while a piece is held over a square, the game opens an ask
for the position with the other side to move. The search lists the captures and crownings
the opponent has within reach, each with its depth, and the app keeps those just past
the player's depth from skill (the free plies of the formula in `ai.md`, at the player's
level). The hint is the search's best move at a skill above the opponent's. Nothing runs
on the drawing thread, and an answer for a position no longer on the board is dropped.

## Acceptance criteria

- [ ] A take chosen and this file updated with it
- [ ] The coach's marks and the hint on the game screen in every layout, 2D and 3D, their
  strings in `strings/`
- [ ] The coach shows the threats past the player's depth and less as the skill climbs;
  tested headless on fixed positions
- [ ] The hint: first press the piece, second the move, the hints left shown
- [ ] Both searches run off the drawing thread
- [ ] `docs/product.md` and `docs/architecture/ai.md` say what is built
