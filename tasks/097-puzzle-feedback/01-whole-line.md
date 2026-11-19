# 01: The wrong move's whole line

Status: done

A wrong move plays the answer's whole line (`puzzles::answer_next`) until the board shows
what it wins, holds, and slides back move by move. The safe goal reads "Avoid the trap"
("Väldi lõksu", proposed by Gemini, chosen 2026-11-19). The checks refuse a wrong first
move's line past eight plies and a line that leaves the other side a king.

## Numbers (2026-11-19)

- Wrong-move lines in the International library, the longest of each puzzle: 3,319 of
  3,579 at most five plies, 225 six or seven, 35 eight to thirteen (18 of them safe).
- A 13-ply line takes about 11 s and 6 s to slide back.
- Dropped by the new checks: 53 International, 4 Russian, 10 Brazilian.

## Acceptance criteria

- [x] The whole line plays and slides back (`test/shell/puzzle_answer`)
- [x] The checks refuse long lines and kings given away; the libraries pass them
