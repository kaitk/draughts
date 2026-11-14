# Puzzles decisions

The decisions behind the puzzles, dated, with their reasons. How they work now:
[Architecture: Puzzles](../architecture/puzzles.md).

## The set

Each theme is a short curve of its own in three levels, easy to hardest (2026-11-09).
Learn's set was three tiers of ten before; it keeps the ids it had then, and the new
puzzles start at 31, so a child's stars stay with the puzzle that won them.

A take puzzle's goal shows as "Win 2 men" ("Win a man" for one) (2026-11-09). Rejected:
"Capture 2", which a child counting the three pieces a shot takes reads wrong, as the
goal is the balance.

## On the screen

- Learn is open, and the other themes open once half of Learn is solved (2026-11-08).
- No puzzle shows a selected piece's targets, whatever the move hints setting
  (2026-11-08): the child is to find the move ([product](../product.md)).
- Captures of many jumps are made by hand (2026-11-08), as children often make them jump
  by jump. A stop never plays the rest of the way by itself, which would solve the puzzle
  for the child. Its last square plays it when every way there takes the same pieces, and any way
  and any square passed between stops costs no star (2026-11-11, issue 1: a king's
  capture tapped through its squares lost stars).
- A wrong move shows why (2026-11-09): when the other side answers it by taking something
  back, that answer plays, holds, and slides back before the wrong move does. Until then
  every wrong move slid back 0.35 s after it landed, as one without such an answer still
  does.

## Checks

- A line must end quiet (2026-11-08): a puzzle that stops with a capture on the board
  shows the child more to play than it let them.
- A safe move's replies may still give men (2026-11-09), since the threat it answers
  starts with one: the sacrifice is still there to make, only no longer wins.

### Rivals

The 2026-11-09 report: International's second Captures puzzle refused a good move. Its
other double, taking two too, was taken back at once by a double; its man on 39 moved to
34, so the backward double is the one capture that takes most. `puzzles::rivals` was
added to report such moves, as a report rather than a refusal until each is decided.

Six rivals were then fixed (2026-11-09): International's King shots 78 and Russian's 6,
9, 13, 20, and 45 each had a rival that needed two more of the solver's moves, not one,
its line then winning more than the count or ending with a capture due, so none could be
listed cleanly. Each position had a man added or moved instead, named in its source,
which kept its line and its lesson (Russian's 6 still the double answered by a double,
its 13's single now taken back). Both sets report none since.

## Daily puzzles

Children who had solved every themed puzzle asked for more, and solved all three
draughts' sets in a day (2026-11-14). Adding puzzles by hand doesn't scale, and a count
over thousands on home would only discourage. So (2026-11-14, task 088):

- **The themed sets stay as the course**: they teach the motifs in order, are checked by
  hand, and keep the stars by id. They gate the daily puzzles and seed the puzzle rating.
- **A few puzzles a day from a large library**, picked by the local date and the player,
  so a child can't do too many at once and none pile up on a missed day. 4 a day by
  default; 3, 5, or 10 in settings.
- **Generated, not imported.** Every position stays our own, as the course's are.
  GoDraughts' puzzles are proprietary; Lidraughts publishes no puzzle export or data
  license (its 2,000+ International puzzles were built by its community); Lichess's
  public-domain database is chess only; and in the EU a collection's substantial
  extraction is covered by the database right though one position is a fact. Generating
  on the device was rejected: finding and checking a good puzzle costs search time and
  curation. The library is built offline (`tools/puzzles.goose`) and embedded, about
  150 bytes a puzzle.
- **After Lichess's generator** (`lichess-puzzler`): positions from games as a second
  source, rejecting a start already won; one clear move at each turn (ours stricter, by
  exact search); each position once; a cheap pass then a strict one; themes tagged by
  detectors over the line, so the pick keeps to the themes a child has opened. Lichess's
  difficulty comes from players' attempts (Glicko-2); with no data leaving the device,
  ours is estimated offline from the computer as judge (how many skills miss the move),
  the line's shape, and the motif's level, and checked against kabe.ee's five puzzles for
  grown-ups (kept in `tools/`, never shipped) and later the user's children's solves.
- **The course is the floor**: the course's puzzles are easy next to real ones, so the
  library reaches well past its hardest, and a child's rating climbs fast at first.
- **A puzzle rating per player and draughts**, Elo's against the puzzle's difficulty,
  stars a partial score (3 = 1.0, 2 = 0.6, 1 = 0.3), the step large while it is new;
  seeded from the course's stars; moved only by a puzzle's first try. Not shown as a
  number on the puzzle screen.
- **A day's shape**: a warm-up below the rating, the middle at it, a stretch above.
- **Traps are some, not most** (2026-11-14): puzzles where the habitual move (crowning
  at once, the bigger capture, running a man home) is there and loses teach most, as in
  chess, but a library of them would teach suspicion of every natural move. A few
  hundred per draughts, under a tenth of the library, made by kinds of their own and
  spread over the levels as their difficulty falls.
- **Library puzzles have ids for good** (2026-11-14): a player's file keeps the puzzles
  had and today's by id, so a library grows without moving them; its first puzzles took
  their lines as ids. Indexing by line was rejected once the library grew.

On the screen (2026-11-14, prototyped and chosen):

- Home's Puzzles row shows today's dots, a check once all are solved; before Today
  opens, the puzzles solved in the player's draughts, not stars.
- No streak of days anywhere: it makes a missed day a loss, which pushes a child rather
  than inviting one.
- Today's puzzles are tiles inside a Today row heading the library, each its level's
  bars and its stars; the row's mark turns to the moon and its note to "New puzzles
  tomorrow" once all are solved. A page of its own for today was rejected as not needed.
- Today opens once Learn is solved, all of it: Learn is the rules, which a daily puzzle
  may use. Gating on the other themes too was rejected as too strict (a young child would
  stall on Safe move); the pick keeps to the themes opened instead. Until then How to play
  heads the library and the locked Today ends it; once it opens, Today heads the list and
  How to play is a tile beside the title in landscape, the list's last row in portrait.
- No "one more" after the day's set: the moon ends the day.
