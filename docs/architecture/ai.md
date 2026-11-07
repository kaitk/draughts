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

The app thinks on one worker thread (`app/think.goose`), so the frame loop never waits
for the search:

- The game says what it wants: on the computer's turn it opens an ask, `game::Ask`, a
  flat value holding an id, the position, the skill, and the seed; `game::answer` takes
  the move for an id and ignores one for an ask no longer open. Take back, start over,
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
- **While it thinks**, its piece on the panel pulses: the glow ring fades from full to a
  third and back every 1.2 s, on its clock's piece when there are clocks, even before
  they start. That keeps frames coming, so the answer is seen the next frame; an idle
  frame waits up to a second for an event ([rendering](rendering.md#frames-and-battery)).
  Once its move has landed nothing animates and the app draws nothing. The child can't
  move the computer's pieces; home, settings, start over, and take back still work.
- **Take back** takes back the child's last move and the computer's reply, so it is the
  child's turn again; while the computer thinks, it drops the search and takes back the
  child's move. Before the child's first move it does nothing.
- **Clocks**: the computer's clock runs while it thinks and pauses, and its move adds the
  increment, as any move does.
- **The seed** of a move is the game's number times 1000 plus the ply: replies vary from
  one game to the next, and the same game replays the same. The number counts the games
  begun against the computer, kept in `settings.txt` (`games`).
- **Skill**: `settings.txt` keeps one skill per level (`skill_easy`, `skill_medium`,
  `skill_hard`, from the level's starting skill), and a game plays at its level's skill
  as it began, kept with the saved game. A game that ends moves its level's skill with
  `ai::adapt`: up when the child won, down when the computer did, by the clock too. It
  counts once, when it first ends; taken back and ended again, it doesn't count again. A
  game started over or replaced before it ends doesn't count. The rules have no draw
  yet; a draw would leave the skill.

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
- **Evaluation**, in hundredths of a man, for the side to move: a man 100, a king 300
  (150 in English, whose kings don't fly); a man gains as it advances, most near the far
  row; a man on its own back row 3 to 4, for keeping kings out; a man on a central square 3.
  The weights follow from the variant's fields: the king's from flying, the rows' from the
  board's size, so Brazilian has International's king on Russian's 8×8 rows.
  All of it is integer arithmetic on the bitboards.

Nothing allocates per node: the frames, their move buffers (`rules::Moves`, 512 moves),
and the table are made once, about 6 MB in all.

## Levels

Skill runs from 0 to 100; easy starts at 10, medium at 45, hard at 90. One skill holds for
a whole game. It sets:

| | Formula | Easy (10) | Medium (45) | Hard (90) |
| --- | --- | --- | --- | --- |
| Plies of free moves it sees | `1 + s / 12 + max(s − 60, 0) / 6` | 1 | 4 | 13 |
| Plies of forced captures past them | `2 + s / 8` | 3 | 7 | 13 |
| Temper: how much worse makes a move e times less likely | `2 + 60 (100 − s)² / 10000` | 50 | 20 | 2 |
| Margin: never a move this much worse than the best it sees | `min(60, 3 × temper)` | 60 | 60 | 6 |
| Chances left for the child, per thousand moves | `5 × max(25 − s, 0)` | 75 | 0 | 0 |

How each part plays like a person:

1. **It misses only what shows deep.** A level never searches past what it sees, so it
   misses a shot or a threat only when the point lies beyond. Every level sees its own
   move and every capture it allows, so none hangs a piece to the reply that just takes
   it (`test/ai/blunders.goose`). Easy plays a sacrifice that fails only further on, as
   a child does.
2. **Consistent strength.** It chooses among the moves within the margin with chances
   that fall off as e^(−δ / temper), δ being how much worse each is than the best it sees:
   Regan and Haworth's model of how players of a given strength choose. So there are no
   genius moves among random blunders. The margin, under 0.6 of a man, keeps positional
   terms from passing off a move that loses one. The chances use integer weights, so
   every machine agrees.
3. **No long combinations on easy**: it sees four plies in all. Depth rises evenly with
   skill, so 15 points more wins about three games in four against itself, and the
   small steps of adapting are felt.
4. **It adapts.** `ai::adapt` moves the skill 4 up after the child wins and 4 down after
   the child loses, within 20 of the level's start, so a child meets an opponent they
   beat about half the time ([in the game](#in-the-game)).
5. **It leaves chances to learn.** Below skill 25, now and then (the table's last row),
   it looks among moves that cost it at most 1.2 men for one that leaves the child a
   combination: no capture to make, but a quiet move that wins at least 0.8 of a man on
   the position as it stands, which few of the child's other moves do. Captures are
   compulsory, so leaving a capture would only hang a piece, not leave something to find.

Played against itself, each level beats the one below it nearly every game, in each
variant.
