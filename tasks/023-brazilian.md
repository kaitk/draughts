# 023: Brazilian draughts

Status: todo

Brazilian draughts is International's rules on an 8×8 board: men capture backward, kings
fly, the capture that takes the most is compulsory, and a man is crowned only where its
move ends (FMJD art. 3.5 and 4.15). Lidraughts counts as many Brazilian players as
Russian (task 019). Settings and a new game's setup offer it (rendering.md "Home",
"Settings"); the first start keeps two cards, International and Russian.

## Work

- `rules/`: a `BRAZILIAN` variant as data, International's rules at 8×8 with white
  first; `rules.md`'s table gets its column.
- `test/perft.py` learns it independently; check published Brazilian perft counts, and
  sweep random games with `compare`.
- `ai/`: the evaluation's weights for it, and `test/ai/` positions.
- The tutorial for it is International's steps on the 8×8 board.

## Acceptance criteria

- [ ] Perft counts match published Brazilian counts and `test/perft.py` over random games
- [ ] The rules tests cover majority capture and crowning only at the end on 8×8
- [ ] Settings and the setup start a Brazilian game
