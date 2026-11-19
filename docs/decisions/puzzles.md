# Puzzles decisions

The decisions behind the puzzles, dated, with their reasons. How they work now:
[Architecture: Puzzles](../architecture/puzzles.md).

## The set

Each theme is a short curve of its own in three levels, easy to hardest (2026-11-09).
Learn's set was three tiers of ten before; it keeps the ids it had then, and the new
puzzles start at 31, so a child's stars stay with the puzzle that won them.

International's Captures puzzle 32 is a choice again (2026-11-19): black's men on 13 and
22 make a forward double, 27x18x9, which 3x14 takes back, beside the backward 27x38x29,
and a white man on 47 keeps black's men on the left from running through to crown (the
computer player scored the right move −219 without it). Moving its man from 39 to 34 on
2026-11-09 had taken away the other double, taken back by 21x32x41, which a child saw
turned down with no reason shown ([rivals](#rivals)), and left the right move the only
legal one. A wrong move's line now shows why it is wrong. Putting the man back on 39 was
rejected: it would bring back the very move reported then.

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
  back, that answer plays, holds, and slides back before the wrong move does.
- A wrong move shows the whole line (2026-11-19), replacing the answer alone: the
  answer and every move after it play until the board shows what the line wins, then
  hold and slide back move by move. A shot's first move is often a sacrifice that wins
  the other side a piece, and a tester who saw only that (a safe move's 34-40, met by
  50-45) couldn't tell why the move was wrong.
- The miss shows as a wrong move with an answer lands, and the line ends at once
  (2026-11-19), replacing its sliding back move by move: the ring and "try again" came
  only after the line had played forward and back, 14 s for seven plies, and the
  player had to sit through both. A tap on "try again" or the board ends it sooner.

## Checks

- No line may leave the other side a king (2026-11-19). The solver counts a king as a
  man, so a take that gives one away looked like a win; 67 library puzzles did (53
  International, 4 Russian, 10 Brazilian, with the long lines below) and were dropped,
  their ids kept unused. A king given and taken back stays, a shot's motif. Counting a
  king as three men in the solver was tried and set aside: at three plies it can't tell
  a king that lasts from one taken at once, and turned right safe moves wrong (Russian's
  64, whose g3-f4 the computer player rates best) and wrong ones right (the library's
  2833).
- Where a king is made, the computer player judges the first moves (2026-11-19), offline
  in `tools/puzzles.goose`, while the app's solver keeps counting a king as a man. A
  king worth three men in the solver, with or without two plies more past a king made,
  disagreed with the computer player both ways (Russian's 64, the library's 2833) and was
  rejected. Wherever a first move's line makes a king for either side, the computer
  player at full skill scores every first move exactly; a puzzle passes when each right
  move scores at least 50 (half a man) above each wrong one, of the pairs where either
  makes a king, or when every right move wins by force. 50 sits in the trough between
  ties (−25 to 25) and a man won (about 100). Comparing every pair was rejected: it fails
  puzzles with no king made as often, so it measures rivals, not kings. A crown puzzle
  always passes: its goal is the king, and the computer player judges by material (a
  third of them would fail, mostly where another move scores as well as crowning). 406
  library puzzles failed and were dropped (192 International, 92 Russian, 122
  Brazilian), their ids kept unused. Built-in puzzles that fail are replaced, not
  dropped, and so is one where a wrong move wins by force, which beats crowning.
- A capture puzzle rated 500 or more must give a real choice (2026-11-19, task 097): three
  legal first moves or more, or two of the solver's moves or more. A tester found the
  easy puzzles "just forced moves"; a choice of two captures one move deep is a
  beginner's puzzle, rated high only where the computer player read past the goal. 61
  library puzzles lacked one (29 International, 4 Russian, 28 Brazilian); 9 that `rate`
  now puts under 500 were rated again, the other 52 dropped, their ids kept unused.
  Counting two pieces able to capture as a choice was set aside: it kept 25 two-way
  captures from two pieces, the same choice of two.
- New library puzzles must not have the computer player prefer a wrong first move
  (2026-11-19, task 097): at full skill it may score no wrong first move 50 or more
  above a right one, crowning and right moves that win by force aside (`kings --every`,
  `PREFERS`). A puzzle whose answer the engine judges weaker teaches a weaker move. Over
  the libraries' non-crowning puzzles the gap of the right move over the best wrong one
  gathers at −25 to 25 (ties) and near −100 (a man worse), so 50, half a man, as in the
  kings check. 9 of the 25 Russian one-glance captures re-rated the same day failed and
  were dropped (Russian 2025, at −20, is a tie and stays). The rest of the libraries
  that failed it were dropped too (2026-11-19), 110 International, 43 Russian, and 41
  Brazilian still there, as a trap whose wrong move the engine prefers is the confusing
  puzzle a tester hit; spare puzzles of the same theme and level replaced all but 15
  International safe moves and a capture in Russian and Brazilian. The replacements rate
  lower, the computer's misses having made the dropped ones hard: International's 1600
  and over fell from 209 to 140 (task 097, subtask 04).
- A wrong first move's line may run eight plies at most (2026-11-19): a tester shown 13
  plies of exchanges couldn't follow them. Cutting the line on screen was set aside, as
  no place partway says what the move lost.

- A line must end quiet (2026-11-08): a puzzle that stops with a capture on the board
  shows the child more to play than it let them.
- A safe move's replies may still give men (2026-11-09), since the threat it answers
  starts with one: the sacrifice is still there to make, only no longer wins.

### Rivals

`puzzles::rivals` reports a move as good as the solution (2026-11-09), as a report rather
than a refusal, after International's second Captures puzzle refused a good move. Six
rivals that needed two more of the solver's moves were fixed by adding or moving a man,
each named in its source, keeping the line and its lesson; both sets report none since.

## Daily puzzles

Children who had solved every themed puzzle asked for more, and solved all three
draughts' sets in a day (2026-11-14). Adding puzzles by hand doesn't scale, and a count
over thousands on home would only discourage. So (2026-11-14, task 088):

- **The themed sets stay as the course**: they teach the motifs in order, are checked by
  hand, and keep the stars by id. They gate the daily puzzles and seed the puzzle rating.
- **A few puzzles a day from a large library**, picked by the local date and the player,
  so a child can't do too many at once and none pile up on a missed day. 4 a day by
  default; 3, 6, or 8 in settings (2026-11-16). They were 3, 5, and 10 from 2026-11-14:
  ten dots ran into the Puzzles label in a desktop's narrow home column, and 5 was an odd
  step. A file's 5 reads as 6 and its 10 as 8. Home's dots also shrink to keep clear of
  the label, so no count nor language overlaps it.
- **Generated, not imported.** Every position stays our own: GoDraughts' puzzles are
  proprietary, Lidraughts publishes no puzzle data license, Lichess's public-domain
  database is chess only, and the EU's database right covers a collection's substantial
  extraction. Generating on the device was rejected: a good puzzle costs search time and
  curation. The library is built offline (`tools/puzzles.goose`) and embedded, about
  150 bytes a puzzle.
- **After Lichess's generator** (`lichess-puzzler`): one clear move at each turn (ours by
  exact search), each position once, a cheap pass then a strict one, themes tagged by
  detectors over the line. With no data leaving the device, difficulty is estimated
  offline (how many skills miss the move, the line's shape, the motif's level), checked
  against kabe.ee's five puzzles for grown-ups (in `tools/`, never shipped).
- **The course is the floor**: the course's puzzles are easy next to real ones, so the
  library reaches well past its hardest, and a child's rating climbs fast at first.
- **A puzzle rating per player and draughts**, Elo's against the puzzle's difficulty,
  stars a partial score (3 = 1.0, 2 = 0.6, 1 = 0.3), the step large while it is new;
  seeded from the course's stars; moved only by a puzzle's first try. Not shown as a
  number on the puzzle screen.
- **A day's shape**: a warm-up below the rating, the middle at it, a stretch above.
- **A capture the goal names is easy** (2026-11-19): a puzzle of one move where only one
  legal move meets the goal at a glance, the one capture that crowns or takes the goal's
  N, counts none of the computer's misses in its difficulty, which puts it under 500.
  The computer misses such a move only by reading past the goal, where a child counts the
  pieces and is done; 27 library puzzles were rated 500 to 1,461 that way (25 Russian,
  most of them a king's or a crowned man's capture, 1 International, 1 Brazilian). They
  were rated again, keeping their ids, and now rate 300 to 406. Dropping them was
  rejected: they are sound, checked puzzles, and a beginner's warm-up needs easy ones.
  Rating them at a fixed number was rejected too: the rest of the estimate (the pieces,
  the moves to weigh, the motif's level) still orders them.
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
  bars and its stars; the row's mark turns to the moon once all are solved. A page of its
  own for today was rejected as not needed.
- Today opens once Learn is solved, all of it: Learn is the rules, which a daily puzzle
  may use. Gating on the other themes too was rejected as too strict (a young child would
  stall on Safe move); the pick keeps to the themes opened instead. Until then How to play
  heads the library and the locked Today ends it; once it opens, Today heads the list and
  How to play is a tile beside the title in landscape, the list's last row in portrait.
- No "one more" after the day's set: the moon ends the day.
- **Today opens in every draughts once Learn is solved in any one** (2026-11-14,
  replacing the same day's "Today opens once Learn is solved" per draughts): a player
  who knows the rules from one draughts shouldn't grind another's simple Learn puzzles
  to reach its daily ones; the daily pick keeps to the themes opened in the draughts
  shown, Captures always among them. A draughts' first puzzle rating is then the best
  the player has in any draughts, a rating there or one from its course's stars, so it
  doesn't start at the floor of a course not played; its large first steps correct it.
  Rejected: seeding from the draughts' own course alone, which puts a player who
  learned elsewhere back on the easiest puzzles.
- Today's row opens a puzzle (2026-11-14): the first unsolved, or the first once all
  are, as a replay for stars. A tap there did nothing, though the mark looks like a theme
  row's, which opens. The whole row is the tile, lit whole under the mouse; the puzzles'
  tiles inside it, declared after it, take the presses over them. A tile over the head
  alone, clear of the puzzles' tiles, was built first and lit only the row's left.
- The day's shape on the puzzle screen (2026-11-14): the warm-up and the stretch are
  named by a word under the goal's lines, in the small face and the glow ("Warm-up", "A
  bit harder"); the middle ones, at the player's level, say nothing. Where the word
  leaves a short panel (round the 3D board) too little room, the goal's icon and the
  piece beside it shrink rather than the stars. Rejected: today's dots drawn as the
  tiles' rising bars, which need a key for a child and grow too thin at 10 a day on a
  phone in portrait.

A tester found the easy daily puzzles "just forced moves" (2026-11-19, task 097):

- **Themes open by the puzzle rating too** (2026-11-19): Crowning, Shots, and King shots
  at 600, Safe move at 800, as well as by a puzzle solved in the course. A grown-up who
  solved Learn and went to Today got only Captures, most of International's under 500 a
  choice between two captures one move deep, and the picks stayed near 500 while the
  rating climbed past 900. The thresholds are guesses where the libraries' quiet puzzles
  begin. A flawless International player with Learn alone solved now gets Captures in a
  quarter of the picks from the second day, not all of them; a young beginner, who
  doesn't reach 600, sees no change. Rejected: opening every theme with Today, which
  puts shots and safe moves before a child who has met neither in the course.
- **The rating's step stays at its first while flawless** (2026-11-19): while every
  rated first try has had three stars, the step stays 96; the first miss returns it to
  the fall by count, as a game's skill moves more after early wins
  ([AI: Levels](ai.md#levels)). Simulated with the themes above, a flawless
  International player from 470 reached 1,000 on day 8 and 1,500 on day 18, 4 puzzles a
  day; now on days 4 and 7. Children are hardly touched: few have a flawless first day
  and almost none a second. A file from before keeps a rating flawless only if no puzzle
  had moved it, as which tries had three stars wasn't kept. Rejected: a flawless day
  moving the rating up to its stretch, a jump past what the player has shown; and
  starting the fall from 96 at the first miss, which keeps the step large just when the
  rating has met the player's level.
