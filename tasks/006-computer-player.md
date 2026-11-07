# 006: Computer player

Status: todo

Alpha-beta search with a fixed transposition table allocated once. Three levels made
weaker by shallower depth and deliberate, plausible mistakes, never by obvious blunders.
It runs off the main thread or in small slices, so the UI never stalls.

## Acceptance criteria

- [ ] Levels easy, medium, hard; an older child beats easy, and hard beats a casual adult
- [ ] Hard replies in under 1 s on the tablet
- [ ] Works for both variants from task 002

## Notes (2026-11-07)

- The engine is `rules/`: `rules::generate` fills a fixed `rules::Moves` buffer and
  `rules::play` returns a new position, so a search keeps one buffer per ply and no
  undo. Perft runs at 12 to 16 million positions a second natively on an M-series Mac
  (`docs/architecture/rules.md`); the tablet's speed is not measured yet.
- An idle `gfx::frame()` waits up to 1 s for an event (`docs/architecture/rendering.md`,
  "Frames and battery"), so a reply from a worker thread is seen within that second
  unless the board animates while the computer thinks. Animate something while it does.

## Playing like a person (2026-11-07)

Engines weakened by a shallower search, noise, or an occasional second-best move play
"like a computer": they hang a piece no person would, then find a long combination a
move later. For kids the computer should be weaker the way a person is weaker. Prior
art, nearly all chess and Go (nothing found for draughts):

- Maia (McIlroy-Young et al., KDD 2020): a network trained to predict the move a human
  of a given rating plays; it matches human moves over half the time at each level,
  1100 to 1900. Maia-2 (Tang et al., 2024, arXiv 2409.20553): one model with skill as
  an input, so strength changes smoothly.
- Allie, "Human-aligned Chess with a Bit of Search" (2024, arXiv 2410.03893): learns
  from human game logs, including thinking time, and searches only where a human would
  think hard.
- Without learning (not checked against the papers): Regan and Haworth's intrinsic
  ratings (about 2011) model the chance a player of a given strength picks each move
  from how much worse it is than the best; Guid and Bratko measure a position's
  difficulty by the depth at which the best move becomes clear; piKL (Jacob et al.,
  2022) mixes a human-imitation policy with search.
- A Maia-style network for 10×10 might later be trained on Lidraughts games, if its
  database can be exported; not for the MVP.

What to build here, without learning:

1. Mistakes a person makes: miss a good move or a threat only when its point shows deep
   in the search; never one whose refutation is two plies away. The level sets how far
   the computer "sees". Forced captures already rule out the commonest silly blunder.
2. Consistent strength: choose among good moves with chances that fall off with how much
   worse each is (Regan's model), one skill setting for the whole game, so no genius
   moves among random blunders.
3. No long combinations on easy: it never searches past the depth it plays at.
4. Adapt to the child: move the skill a little after each win or loss, so each child
   meets an opponent they beat about half the time.
5. Leave chances to learn: on the easiest level, now and then prefer a move that leaves
   the child a capture or a combination to find.
