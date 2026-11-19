# 04: Refill the libraries

Status: todo

Dropped puzzles leave their ids unused, so the libraries have holes: by 2026-11-19, 245
International (156 shots, 49 king shots, 27 safe moves, 9 crownings, 4 captures), 96
Russian (81 shots, 11 captures, and 4 earlier), and 132 Brazilian (119 shots, 3
captures, and 10 earlier). The kings check (02) dropped 406 of them; a new puzzle must
pass it too (`build/puzzles kings`). Generate new
puzzles of the same themes, levels, and difficulty bands (`docs/development.md`, "Daily
puzzles"), under the checks as they then stand, so each band keeps its count.

## Built-in puzzles to replace

The kings check refuses these, or a wrong move in them wins by force, which beats
crowning (2026-11-19). The engine's scores of the right move and the wrong one at fault:

- International 92 (safe move, level 3): 22-18 −59; 39-34 −97, a gap of 38.
- Russian 18 (captures, level 2, take 3): f6:d4:f2:h4 +403; f4:h2 +452.
- Brazilian 64 (safe move, level 1): f6-e5 −110; g3-h2 −128, a gap of 18.
- Russian 30 and Brazilian 30 (crowning, level 3, crown in 3, the same position):
  c3-b4 −91; g3-f4 a forced win (+29985), g3-h4 too.

## Acceptance criteria

- [ ] Each library's count per theme and level back to what it was before 097, or more
- [ ] New puzzles take new ids; the dropped ones stay unused
- [ ] The five built-in puzzles above replaced, each passing the kings check
