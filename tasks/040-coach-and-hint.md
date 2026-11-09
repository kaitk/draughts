# 040: The coach and the hint

Status: todo (takes drawn, a choice pending)

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
- **The hint**: the first press lights the piece to move, the second shows where it
  goes. A few hints a game (three in the takes), shown on the tile as pips.
- Neither shows while the player must capture: the must-capture ring already says what
  to do. Neither shows in puzzles.

## The takes

`prototypes/coach.html` (`?take=a` to `c`, `&state=calm`, `held`, `king`, `hint1`,
`hint2`, `control`; `&view=sheet` for every take and state side by side). Every take
gives the coach one color of its own, a soft violet (`#c7a6ff`), and still marks: the
board's red pulses and flashes (must capture, a wrong move) and its glow (the selected
piece, move dots, the last move, the puzzles' hint ring) stay as they are. The hint keeps
the glow and the puzzles' pulsing ring for its first press.

- **a, rings.** A piece in danger wears a dashed violet ring; a crowning square, a dashed
  ring with a crown. The hint is a tile in the play panel with its pips; its second press
  puts a ghost of the piece on its square. The coach is a setting in settings, under move
  hints: On or Off.
- **b, lines.** The danger is drawn as the computer's jump: a dashed violet line from its
  piece over the player's to a small ring where it lands; a crowning, a line to a crown.
  The hint's second press is a solid arrow in the glow. The coach is a tile on the game
  screen beside the hint, lit while on; nothing in settings.
- **c, badges and one Help tile.** A piece in danger carries a small violet badge with
  "!"; a crowning square, a badge with a crown. One tile does it all, its word the next
  step: Help shows the danger (free, as often as wanted), Which piece lights the piece
  and spends a hint, Where to shows the ghost. A setting under move hints says whether
  the coach shows Always or When asked.

## Open choices

1. Which take, or which mix: rings, lines, or badges on the board; a setting, a game
   screen tile, or one Help tile.
2. The coach's window over the player's horizon: one ply past it, or two; and whether at
   hard it shows nothing at all.
3. When a held piece shows what it leaves open: while dragged over a square (as the
   takes show), or on selecting it, for every target at once.
4. Whether a hint is spent by the first press or by both, and how many a game (three in
   the takes); whether a game with hints used counts toward the skill the same.
5. The coach's default: on for a new player and fading with skill, or off until turned on.
6. A game against a friend: the hint for whoever moves, the coach for both or neither.

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
