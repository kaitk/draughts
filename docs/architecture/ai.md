# Computer player

The computer player is `ai/` (namespace `ai`): pure Goose over [`rules`](rules.md), with
no graphics, tested headless in `test/ai/`. It is made weaker the way a person is
weaker, not the way a crippled engine is: each level sees a fixed number of plies and
never past them, and picks among the moves it sees as good, more often the better ones.
Engines weakened by noise or an occasional second-best move hang a piece no person would
and then find a long combination a move later; that is what this avoids.

## Thinking in steps

```goose
var e = ai::Engine { .. };
ai::init(e);                                  // once: the table and the frames
ai::start(e, position, skill, seed);          // a move to find
while !ai::step(e, 10000) { /* a newer ask? */ }
let m = ai::reply(e);                         // one of position's legal moves
```

`step` searches for about the given number of nodes and returns whether the reply is
ready. The search is alpha-beta unrolled into one frame per ply (`Engine.plies`), so it
stops after any node and goes on at the next call.

The search counts nodes, never time, so the same position, skill, and seed give the same
move on every machine, however the thinking is cut into steps. Tests rely on that, and a
game can be replayed.

## Thinking on a worker

The app thinks on one worker thread (`src/app/think.goose`), so the frame loop never waits
for the search:

- The game says what it wants: on the computer's turn it opens an ask, `game::Ask`, a
  flat value holding an id, the position, the skill, and the seed; `game::answer` takes
  the move for an id and ignores one for an ask no longer open. Undo move, start over,
  leaving the game, or the app pausing closes the ask; the next turn opens a new one.
- Each frame the app puts the game's ask on the typed queue for `game::Ask` when it
  changed (id 0 for none) and polls the queue for `think::Thought`, the answer.
- The worker, a `thread_fn`, builds its own `ai::Engine` and calls `ai::init` once: a
  root can't cross to a thread. It waits on its queue (`qget`, blocking, no CPU), runs
  `ai::step` 10,000 nodes at a time, about 2 ms on the tablet's big cores, and between
  steps looks for a newer ask (`qpoll`). One that comes drops the search under way, so a
  take back never waits for a stale reply. The answer carries the move, the nodes, and
  the time it took.
- The worker starts at the first ask, so a game against a friend costs no thread and
  none of the engine's 6 MB.

Threads stay in `app/`: `game/`, `shell/`, and the tests run headless through TinyCC,
which can't start a thread, and tests answer an ask with `ai::think` at once. The app is
therefore built on the Mac too ([development](../development.md#run-on-the-mac)).

A worker was chosen over slices of the search on the drawing thread (2026-11-08): hard
takes up to 0.2 s on the tablet's big cores and 0.65 s on its little ones, which sliced
into frames is 20 to 60 frames of 10 ms each, and the slices make the frames uneven.
On a worker the frame loop draws as it would without the computer.

## In the game

- **A person's pause.** The computer's move begins 0.8 s after its turn begins (the
  child's move has landed) on easy, 0.6 s on medium, and 0.45 s on hard, or when the
  search ends if that is later; then it plays through the board's move animation. Easy
  answers in under a millisecond, and a reply at once feels like a machine. Medium and
  hard pause less, as they take time of their own on the tablet.
- **Against the clock** it takes as long as a player of its level would
  (`src/game/pace.goose`): a share of what it could spend each move and keep its clock (the
  time left over 30 moves, plus the increment), 0.2 of it on easy, 0.3 on medium, 0.45
  on hard, for a quiet choice among three close moves. Its search's root scores say how
  close (`ai::close`: the moves within 0.15 of a man of the best, as far as its margin
  scores them exactly): one move standing out takes a third of that, five or more close
  ones five thirds; a single move only the pause. Medium and hard see a choice among
  captures at once and take half. Easy, like a weak player who has to look, takes 3.5
  times as long whenever a piece can be taken around its move (`pace::tense`): it must
  capture, the other side could capture were it its turn, or could once its move is
  played. That is two move generations into stack buffers, once a move, and catches the
  positions where a child's move most often goes wrong; the close moves already measure
  how hard the choice is. The first moves of a game come quickly, as a player knows them:
  the time grows over the first 12 plies. It never takes more than 12, 8, or 15 s by
  level, nor more than a tenth of its clock, so with the increment it can't lose on time.
  Easy's cap sits above medium's: a sharp position on a long clock is where easy looks
  longest. The time only decides when the move is played: the search still stops at its
  own depth, so its strength is the same. White's first move is untimed, so the computer
  playing white makes it after the pause.

  Easy was made much slower on 2026-11-09 (the user: easy should play much slower,
  especially in positions where something can be taken); it had spent 0.15, capped at
  4 s, and taken half on a choice among captures. Its planned seconds past the opening
  with its clock full (5+3 and 10+5) and on 10+5 with 2 minutes left, from
  `test/game/pace.goose`, its own search giving the close moves:

  | Position | Before: 5+3, 10+5, 10+5 at 2 min | After |
  | --- | --- | --- |
  | Quiet (10×10 start, 9 close) | 3.25, 4.00, 2.25 | 4.33, 8.33, 3.00 |
  | A man threatened, 3 close | 1.95, 3.75, 1.35 | 9.10, 12.00, 6.30 |
  | A choice of 2 captures | 0.97, 1.88, 0.80 | 6.07, 11.67, 4.20 |
  | Quiet, one move standing out | 0.80, 1.25, 0.80 | 0.87, 1.67, 0.80 |
  | Tense, one move standing out | 0.80, 1.25, 0.80 | 3.03, 5.83, 2.10 |

  Over whole games of easy against itself (the test's 2 games a clock) a move took
  2.22 s on 5+3 and 2.83 s on 10+5 on average; now 3.38 s and 5.86 s, at most 12, its
  clock never under 244 s and 507 s (3.54 s and 5.79 s once task 053's overlooks changed
  the test's games). The test's ranges for easy's mean are 2.5–5 s and
  4–8 s; medium's and hard's are unchanged.
- **While it thinks**, its piece on the panel pulses once: the glow ring fades from full
  to a third and back over 1.2 s, on its clock's piece when there are clocks, even before
  they start, then stays full. That keeps frames coming while the answer is on its way,
  so it is seen the next frame; an idle frame waits up to a second for an event
  ([rendering](rendering.md#frames-and-battery)). A longer think against the clock shows
  on its clock, which counts each second, and the app sets a timer for when the move is
  due rather than draw every frame for many seconds. Once its move has landed nothing
  animates and the app draws nothing. The child can't move the computer's pieces; home,
  settings, start over, and take back still work.
- **Undo move** takes back the child's last move and the computer's reply, so it is the
  child's turn again; while the computer thinks, it drops the search and takes back the
  child's move. Before the child's first move it does nothing.
- **Clocks**: the computer's clock runs while it thinks and pauses, from the start of the
  child's move as for any player, and its move adds the increment, as any move does.
- **The seed** of a move is the game's number times 1000 plus the ply: replies vary from
  one game to the next, and the same game replays the same. The number counts the games
  begun against the computer, kept per player in `player-N.txt` (`games`).
- **Skill**: each player's file keeps one skill per level (`skill_easy`, `skill_medium`,
  `skill_hard`, from the level's starting skill) and how many games ended on each
  (`played_easy`, ...), and a game plays at its level's skill as it began, kept with the
  saved game. A game that ends moves its level's skill with `ai::adapt`: up when the
  child won, down when the computer did, by the clock too. It counts once, when it first
  ends; taken back and ended again, it doesn't count again. A game started over or
  replaced before it ends doesn't count. A draw counts as 0 and leaves the skill. Play again on the end's card and start over during a game begin a new game
  at the level's skill as it is then, adapted by the game just ended, and count it for
  the seeds as home's play does (2026-11-09: they had replayed at the old skill).
- **The default level** for a new player, and for settings read fresh, is easy (the
  user's call, 2026-11-09, after a young player found easy hard); a player's saved
  level stays.

## Search

- **Negamax alpha-beta**, fail-soft, with iterative deepening. Moves are tried in the
  order: the table's move, captures by how many pieces and kings they take, two killer
  moves per ply, then by a history table; at the root, by the last iteration's scores.
- **Depth.** A node searches `d` more plies of free moves and at most `h` more plies in
  all. At `d = 0` the search goes on only while the side to move must capture: captures
  are compulsory, so there is no standing pat on a capture. A forced move (the only legal
  one) costs no depth, as a person sees it at once. At `h = 0` the search stops wherever
  it is. `h` is how far a level sees.
- **Transposition table**: 2^18 entries of 16 bytes (4 MB), made once by `ai::init` and
  cleared at the start of each search, so a reply never depends on earlier searches.
  Zobrist keys are updated per move. An entry answers a node only when it was searched
  with the same `d` and `h`; an entry from another depth would make the result depend on
  what was searched first. The table then changes how many nodes a search takes, never
  a score (`test/ai/search.goose`). In draughts a transposition is nearly always
  reached at the same ply, so the exact match costs little. Against 2 MB, the 4 MB
  table makes hard's searches a fifth faster on the Mac and a ply deeper in International
  middlegames; 8 MB was slower than 4, clearing it costing more than it saved.
- **Root scores.** Every root move within the level's margin of the best gets an exact
  score: each is searched with alpha at the best so far less the margin. The rest have
  only an upper bound and are never played.
- **Node limit**: no new node is entered after 800,000 nodes once an iteration has
  finished; the iteration under way is dropped. It bounds hard's reply to about a fifth
  of a second on the tablet's big cores and 0.65 s on its little ones, and more nodes
  still made hard stronger on 10×10. Easy and medium finish their depth in a few thousand
  nodes.
- **Draws** score 0 (rules.md, "Draws"). Each frame carries the draw counts
  (`rules::draw_after` per move), and a node whose counts have ended is a draw unless its
  side to move has no move, which is a loss as in the game. A position met earlier on
  the way from the root is a draw, as the side that came back can come back again; one
  met at the root or in the game before it is a draw when that makes three times. The
  game hands the search its counts and its positions since the last man's move or
  capture (`rules::Past`, `ai::start_after`), whose keys the search compares only that
  far back. So the side behind steers into a draw and the side ahead clear of it
  (`test/ai/draws.goose`). A table entry may carry a draw from another way to the
  position; draughts engines accept that. The checks cost nothing measurable in
  middlegames and about 5–10% of the nodes a second in king endings.
- **Evaluation**, in hundredths of a man, for the side to move: a man 100, a king 300
  (150 in English, whose kings don't fly); a man gains as it advances, most near the far
  row; a man on its own back row 3 to 4, for keeping kings out; a man on a central square 3.
  The weights follow from the variant's fields: the king's from flying, the rows' from the
  board's size, so Brazilian has International's king on Russian's 8×8 rows.
  All of it is integer arithmetic on the bitboards.

Nothing allocates per node: the frames, their move buffers (`rules::Moves`, 512 moves),
and the table are made once, about 6 MB in all.

## Levels

Skill runs from 0 to 100; easy starts at 0 (the user's call, 2026-11-09; it started at
10 until then), medium at 40 (the user's call, 2026-11-08), hard at 90. Easy's start
and its overlooks are to be tuned once the child has played them more. One skill holds
for a whole game. It sets:

| | Formula | Easy (0) | Medium (40) | Hard (90) |
| --- | --- | --- | --- | --- |
| Plies of free moves it sees | `1 + s / 12 + max(s − 60, 0) / 6` | 1 | 4 | 13 |
| Plies of forced captures past them | `2 + s / 8` | 2 | 7 | 13 |
| Temper: how much worse makes a move e times less likely | `2 + 60 (100 − s)² / 10000` | 62 | 23 | 2 |
| Margin: never a move this much worse than the best it sees | `min(60, 3 × temper)` | 60 | 60 | 6 |
| Chances left for the child, per thousand moves | `5 × max(25 − s, 0)` | 125 | 0 | 0 |
| Overlooks a capture of 1; 2; 3; 4+ pieces, per thousand, tense, next to the moved piece | `MISS × (max(SURE − s, 0) / SURE)²`, MISS 25; 300; 300; 450, SURE 15; 25; 65; 65 | 25; 300; 300; 450 | 0; 0; 44; 66 | 0 |

How each part plays like a person:

1. **It misses only what shows deep, or what a person overlooks.** A level never
   searches past what it sees, so it misses a shot or a threat only when the point lies
   beyond. From skill 15 on it sees its own move and every one-piece capture it allows,
   so it never hangs a piece to the reply that just takes one; from 25 every two-piece
   capture, from 65 every capture (`test/ai/blunders.goose`). Easy plays a sacrifice
   that fails only further on, as a child does.
2. **It sometimes overlooks a capture, as a person errs** (the table's last row). After
   each of its moves it may not see one of the child's captures: each capture is seen
   or not by its own chance, drawn from a hash of the move's seed and both moves
   (`ai::overlooked`), so the search meets the same answer each time and every machine
   agrees. The chance grows with how many pieces the capture takes (MISS) and with how
   far it starts from the piece just moved (times 1, 1.25, 1.5, and 2 for a step, 2, 3,
   and 4 or more squares away; a capture of the moved piece by one jump starts a step
   away), and is a tenth as large in a quiet position: one where neither side could
   capture before its move (`ai::notice`, the root's half of `pace::tense`). It fades
   with skill, each size by the square of the way left to its own sure skill: easy
   misses a one-piece capture now and then until 15 and a two-piece one until 25;
   medium only captures of three pieces or more, now and then (44 per thousand at 40,
   next to the moved piece); from 65 on, hard included, nothing. Where it sees none of
   the child's captures it takes the position as quiet. It still chooses as always among
   what it does see, so an overlooking move is a sensible move but for the capture, and
   it hangs a piece only where its best-looking move does. Its own captures stay
   compulsory, as the rules make them (`test/ai/overlook.goose`).

   Why (the user, 2026-11-09): easy and medium should err where a person does, more
   where captures are around (a long multi-capture, a capture away from the piece just
   moved) and less in a quiet position, where an obvious blunder looks like a machine.
   In chess every strength errs more in complex positions (Guid and Bratko, 2006 and
   2011; Regan and Haworth's model, which the choosing uses, shows the same), and
   tactics are among the strongest signals of a human blunder (Maia, McIlroy-Young et
   al., 2020). Until then easy overlooked with a flat chance a move, fading to none by
   15: at 0, 60 per thousand moves where its piece lands and 90 for a capture its move
   opens (a young player had found that easy never missed a capture nor hung a piece,
   so every mistake was punished, 2026-11-09); medium never did. Most of those hangs
   came in quiet positions. Now they come where captures are around, and easy hangs
   about as many pieces as before, so its strength stays (the numbers below).

   Easy a touch weaker still (the user, 2026-11-09): a two-piece capture is overlooked
   at 0 as often as a three-piece one, 300 per thousand where it was 160, fading to none
   by 25 as before, so medium and hard are unchanged. It is a mistake of a tense
   position, a double capture missed, and of the easy-only knobs it weakens easy most
   for the fewest quiet hangs ([easy a touch weaker](#easy-a-touch-weaker-2026-11-09)).

3. **Consistent strength.** It chooses among the moves within the margin with chances
   that fall off as e^(−δ / temper), δ being how much worse each is than the best it sees:
   Regan and Haworth's model of how players of a given strength choose. So there are no
   genius moves among random blunders. The margin, under 0.6 of a man, keeps positional
   terms from passing off a move that loses one. The chances use integer weights, so
   every machine agrees.
4. **No long combinations on easy**: it sees four plies in all. Depth rises evenly with
   skill, so 15 points more wins about three games in four against itself, and the
   small steps of adapting are felt.
5. **It adapts.** `ai::adapt` moves the skill 4 up after the child wins and 4 down after
   the child loses, within the level's band (easy 0 to 30, medium 25 to 60, hard 70 to
   100: `LEVEL_FLOOR`, `LEVEL_TOP`), so a child meets an opponent they beat about half
   the time ([in the game](#in-the-game)). Over a player's first three games on a level
   the steps are 8, so the skill finds the child sooner (the user's call, 2026-11-09);
   the file counts the games that ended on each level. Easy starts at its floor and
   only climbs from there. A file from before that count keeps its skills; one still at
   its level's old start (easy at 10) has had no game that moved it, and starts afresh at
   the new start with its first steps to come, while one moved from it has had them.
6. **It leaves chances to learn.** Below skill 25, now and then (the chances row),
   it looks among moves that cost it at most 1.2 men for one that leaves the child a
   combination: no capture to make, but a quiet move that wins at least 0.8 of a man on
   the position as it stands, which few of the child's other moves do. Captures are
   compulsory, so leaving a capture would only hang a piece, not leave something to find.

Played against itself, each level beats the one below it nearly every game, in each
variant. Self-play of 2026-11-09, 400 games a pair in each of Russian, International,
and Brazilian (`build/aimatch ... --overlooks`), wins, draws, losses for the first:

| Pair | Russian | International | Brazilian |
| --- | --- | --- | --- |
| Easy at 0 against skill 10 without overlooks | 91, 76, 233 | 53, 69, 278 | 89, 82, 229 |
| Easy at 0 against skill 0 without overlooks | 122, 70, 208 | 77, 82, 241 | 112, 78, 210 |
| Skill 15 against easy at 0 | 322, 44, 34 | 350, 24, 26 | 327, 33, 40 |
| Medium (40) against easy at 0 | 388, 8, 4 | 397, 1, 2 | 385, 11, 4 |
| Medium (40) against easy at its top (30) | 255, 84, 61 | 301, 57, 42 | 255, 93, 52 |

A simple child model, skill 0 overlooking three times as often (`--overlooks 300`),
loses to skill 0 without overlooks in 64 to 71% of games and to 15 in 87 to 91%. Easy's
top and medium's start are closer than the levels' starts: medium wins about 64 to 75%
there and loses 10 to 15%.

### Mistakes by tension: before and after (task 053, 2026-11-09)

`build/aimatch VARIANT A B 400 --hangs` counts, for each side, the moves that hang a
piece: after them the other side's captures win a man or more (a minimax over material,
the move and then captures only, four plies), when another move loses less that way,
unless the side's own search shows the material coming back (a sacrifice it sees).
Quiet and tense as above: tense when the side to move must capture or the other side
could capture were it its turn. Hanging moves per 100 games, quiet then tense, each
skill against the one in brackets (each side plays about 35 moves a game in Russian and
Brazilian, 60 in International, one in seven to nine of them tense):

| Skill | Russian, before → after | International | Brazilian |
| --- | --- | --- | --- |
| 0 (against 10) | 36, 12 → 6, 32 | 72, 22 → 10, 79 | 34, 15 → 6, 33 |
| 10 (against 25) | 12, 4 → 3, 16 | 20, 8 → 8, 78 | 11, 5 → 3, 31 |
| 15 (against 0) | 0, 0 → 2, 7 | 0, 0 → 3, 24 | 0, 0 → 0, 7 |
| 25 (against 40) | 0, 0 → 1, 5 | 0, 0 → 3, 31 | 0, 0 → 1, 6 |
| 40 (against 55) | 0, 0 → 0, 1 | 0, 0 → 1, 11 | 0, 0 → 0, 4 |
| 55 (against 40) | 0, 0 → 0, 0 | 0, 0 → 0, 1 | 0, 0 → 0, 0 |

Wins, draws, losses for the first, before → after; adapting's steps rely on 15 skill
points winning about three games in four:

| Pair | Russian | International | Brazilian |
| --- | --- | --- | --- |
| 10 against 0 | 217, 63, 120 → 198, 73, 129 | 221, 67, 112 → 192, 100, 108 | 222, 73, 105 → 198, 75, 127 |
| 15 against 0 | 339, 38, 23 → 320, 45, 35 | 376, 20, 4 → 335, 34, 31 | 336, 47, 17 → 328, 35, 37 |
| 25 against 10 | 367, 27, 6 → 363, 23, 14 | 396, 3, 1 → 386, 12, 2 | 362, 29, 9 → 360, 22, 18 |
| 40 against 25 | 267, 82, 51 → 272, 78, 50 | 274, 93, 33 → 299, 61, 40 | 248, 108, 44 → 252, 105, 43 |
| 55 against 40 | 248, 98, 54 → 252, 92, 56 | 290, 84, 26 → 300, 75, 25 | 255, 97, 48 → 257, 95, 48 |
| Easy at 0 against 10 without overlooks | 108, 62, 230 → 100, 76, 224 | 88, 67, 245 → 69, 89, 242 | 99, 78, 223 → 95, 82, 223 |
| Easy at 0 against 0 without overlooks | 113, 74, 213 → 133, 76, 191 | 98, 87, 215 → 92, 89, 219 | 104, 75, 221 → 117, 91, 192 |

Easy at 0 scores about as before against the fixed yardsticks (skill 0 and 10 without
overlooks, which the change doesn't touch): a little better in Russian and Brazilian, a
little worse in International, where long captures are common. Fifteen points still win
80 to 97% of games at the bottom of the scale and 63 to 75% from 25 to 40, as before.
International's 10 to 25 now hang more in tense positions than the other variants'
(its majority rule makes multi-captures the only replies more often); their win rates
moved little.

### Easy a touch weaker (2026-11-09)

The user asked for easy a touch weaker still after task 053, about 3 to 5 points less
for easy at 0 against skill 10 without overlooks, mistakes still where the position is
tense. Easy at 0's score (a win 1, a draw a half) against that yardstick, over 2000
games a variant, for each easy-only knob tried:

| Change at skill 0 | Russian | International | Brazilian | Hangs per 100 games, quiet (Russian) |
| --- | --- | --- | --- | --- |
| None (task 053) | 0.339 | 0.283 | 0.347 | 6 |
| One-piece overlook 25 → 75 | 0.329 | 0.273 | 0.332 | 10 |
| Two-piece overlook 160 → 240 | 0.326 | 0.266 | 0.335 | 7 |
| Two-piece overlook 160 → 300 (chosen) | 0.310 | 0.249 | 0.318 | 9 |
| Chances left 125 → 200 a thousand | 0.344 | 0.286 | 0.336 | 6 |
| Temper 62 → 102 | 0.358 | 0.295 | 0.346 | 6 |

The two-piece overlook takes the most from easy for the fewest hangs in quiet
positions; one-piece captures are mostly of the piece just moved, which shows in quiet
positions too. The chances left change nothing measurable, as skill 10 doesn't look for the
combinations left, and the hotter temper makes easy no weaker, as within the margin it
already chooses nearly evenly. One value fits every variant, International's drop within the range
too, so it gets no adjustment of its own.

Before → after, 400 games a pair (the score's noise at 400 games is about 2 points
either way: the 2000 games above are the surer measure of easy's drop):

| | Russian | International | Brazilian |
| --- | --- | --- | --- |
| Easy at 0 against 10 without overlooks | 100, 76, 224 → 91, 76, 233 | 69, 89, 242 → 53, 69, 278 | 95, 82, 223 → 89, 82, 229 |
| Its score | 0.345 → 0.323 | 0.284 → 0.219 | 0.340 → 0.325 |
| 15 against 0 | 320, 45, 35 → 322, 44, 34 | 335, 34, 31 → 350, 24, 26 | 328, 35, 37 → 327, 33, 40 |
| 25 against 10 | 363, 23, 14 → 368, 20, 12 | 386, 12, 2 → 388, 9, 3 | 360, 22, 18 → 362, 23, 15 |
| Hangs at 0 (against 10), quiet, tense | 6, 32 → 9, 41 | 11, 71 → 14, 90 | 8, 30 → 10, 36 |
| Hangs at 10 (against 25), quiet, tense | 3, 16 → 4, 21 | 8, 78 → 9, 89 | 3, 31 → 5, 39 |

Fifteen points still win 80 to 97% of games at the bottom of the scale; medium and hard
play as before.
