# 007: Puzzles

Status: todo

Puzzles in a plain text file: a position, the side to move, a goal ("win material",
"crown", "capture all") and the solution lines. A move that reaches the goal by a
different line counts too. About 30 for International 10×10 first, in three tiers
(2026-11-08: the default game, and a starting point for Russian ones later).

## Puzzle screen takes (2026-11-08)

`prototypes/puzzle.html`; the user picked take c on 2026-11-08; `?take=` and `&state=play`,
`wrong`, `hint`, or `solved`. All keep the game screen's layout (puzzles, settings, and
start over on the left; the goal, three stars at stake, and one big tile on the right),
and a wrong move slides back by itself, its square flashing the red ring over a fading
ghost of the piece, with "try again" and a star going out.

- **a**: the goal as the side to move, the theme's icon, and "Capture 2"; a hint tile
  where take back is, which makes the piece to move pulse a glow ring; a miss or the hint
  costs a star; solved shows the card over the dimmed board, again or next.
- **b**: the goal drawn as the pieces to take, which dim as they go; the hint tile
  appears only after a miss and is free; the theme's ten as dots with next on the left,
  to move on at any time; solved shows the card.
- **c**: no hint tile, as in a game: after two misses the piece to move glows by itself;
  next is the big tile, dim until solved, then lit, with the stars filling in the panel
  and no card over the board.

## First, from task 020's review

- Move the game panel's layout from `board::layout` to `game` (review item 2), so the
  puzzle screen's panels are laid out where the game's are.
- A `test/drive/` package for the UI tests' shared helpers (item 5) before the puzzle
  tests add another copy.

## Acceptance criteria

- [ ] Format documented, loaded at startup, validated by the rules engine (every solution legal)
- [ ] Tier 1: find the capture; tier 2: multi-jumps and mid-capture crowning; tier 3: shots
      and "the only safe move"
- [ ] Wrong move: a gentle undo and retry. Hint: highlight the piece to move
- [ ] Sources recorded per puzzle, with licenses checked
