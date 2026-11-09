# 049: Draws

Status: todo

The rules have no draw (`src/game/game.goose`: "the rules have none yet"), so a game ends
only in a win: two kings can chase each other forever. Raised by the user, 2026-11-09.

## Rules, confirmed

Checked 2026-11-09. A *move* is one side's move (one ply); "N moves each" is 2N plies.
Every rule below ends the game at once, with no claim: the federations let a player or
the arbiter claim, and an app has nobody to claim. All counts run side by side; the first
to reach its end draws. A win on the drawing move (the last enemy piece taken, or the
opponent left without a move) is a win, not a draw.

**Repetition, all variants.** Drawn when a position (the same pieces, kings, and side to
move) occurs for the third time, not necessarily in a row. Only positions since the last
man's move or capture can repeat, so the history to compare restarts there.

### International (FMJD, Annex 1, Official FMJD rules for international draughts)

The text: fmjd.org's own copy (fmjd.org/downloads/FMJD_Annexes_2024.pdf) is gone (404,
2026-11-09); read from the copy of Annex 1 at studfile.net/preview/9635026/page:3/. The
Russian sport rules' 100-square section (below, art. 7.5.2) say the same.

- **6.1, repetition:** as above.
- **6.2, kings only:** drawn after 25 moves each (50 plies) in which only kings moved and
  nothing was captured. A man's move (a promotion included) or any capture restarts it.
- **6.3, three against a lone king:** three kings, two kings and a man, or a king and two
  men against one king: drawn when each side has played 16 more moves (32 plies) counted
  from the move that made the material, which itself doesn't count. A promotion inside
  the class (2 kings and a man becoming 3 kings) doesn't restart it.
- **6.4, two or fewer against a lone king:** two kings, a king and a man, or a king
  against one king: drawn after 5 moves each (10 plies) from the move that made the
  material. Once running it doesn't restart (a promotion keeps it going).
- The strong side needs a king for 6.3 and 6.4: two men against a king has no count until
  a man is crowned, and that move starts it.

### Russian (Правила вида спорта «шашки», Минспорт приказ № 201, 17.03.2022)

The Russian federation's competition rules are the state's sport rules, which it drafts:
pravo.ppt.ru/pravila/264594. "Ход" is one side's move (6.1.4.1). The "большая дорога"
is the long diagonal a1–h8 (6.1.2).

- **5.4.13.1–2, repetition:** as above; 5.4.13.2 says outright the repetitions needn't
  follow each other.
- **6.1.8.3–6.1.8.4, three kings against a lone king:** three or more kings (with or
  without further men; 6.1.8.3 names three kings holding the main road, 6.1.8.4 three
  kings and more pieces) against one king: drawn if the strong side's 15th move, counted
  from the move that made the material, doesn't take the king. That is ply 29 or 30
  after it, by who moves first.
- **6.1.8.5, the main road:** three pieces of any kind (three kings, two kings and a man,
  a king and two men, or three men), none on the main road, against a lone king on the
  main road: drawn if the strong side's 5th move doesn't take the king, "unless a
  position arises in which either side can win".
- **6.1.8.6, balance unchanged:** both sides have kings and nothing was taken or crowned
  for: 5 moves in 2- and 3-piece endings, 30 in 4- and 5-piece, 60 in 6- and 7-piece
  (each, 10/60/120 plies). A capture or a crowning restarts it; the count of pieces is
  both sides' together.
- **6.1.8.8, kings only:** only kings moved and nothing was taken for 15 moves in 4- and
  5-piece endings, 25 moves in 6- and 7-piece endings. No such rule with 8 or more
  pieces.
- 6.1.8.7 (an "obviously drawn" position, 5 moves counted aloud, the arbiter judges)
  needs judgment and isn't built; 6.1.10.4 (rapid and blitz without increment: the
  6.1.8.5 and 2–3-piece 6.1.8.6 positions are drawn without playing on) is for clocks in
  competition. 6.1.8.2 cites 5.4.12 for the general draws, a slip for 5.4.13.

### Brazilian (FMJD Section 64 / IDF, Official rules of the game in draughts-64)

FMJD's 64-square section publishes one rule text for draughts-64, with Brazilian
differing only in captures (art. 4.16): fmjd64.org/rules-of-the-game/. A move is one
piece's move (3.2). The Brazilian confederation's (CBD) own text wasn't found online.

- **7.2.3, repetition:** as above.
- **7.2.4, three kings against a lone king:** three or more kings against one king: drawn
  if the strong side's 15th move, counted from the move that made the material, doesn't
  take the king.
- **7.2.5, kings only:** 15 moves (each) with only kings moved and no capture, at any
  material.
- **7.2.6, balance unchanged:** both sides have kings and nothing taken or crowned for 30
  moves in 4- and 5-piece endings, 60 in 6- and 7-piece.
- **7.2.7, the long diagonal:** three kings, two kings and a man, or a king and two men
  against a lone king on the long diagonal: drawn if the strong side's 5th move doesn't
  "achieve a winning position".
- **7.2.8:** two kings, a king and a man, or a king against a lone king: the same, 5th
  move.

### How the sources differ

- **lidraughts** (github.com/RoepStoep/lidraughts, `modules/draughts/src/main/variant/`):
  International as above, in plies (50, 32, 10). Russian and Brazilian both use the
  IDF text: three kings against one 30 plies (all kings only); the main-road count
  needs a king among the three and the lone king alone on the diagonal, and draws after
  10 plies; 4–5 pieces 60 plies and 6–7 pieces 120, with the 15-move kings-only count
  (30 plies) only at 8 or more pieces, so a 4- to 7-piece ending gets no kings-only count.
  Repetition there is claimed by a player (or automatic by preference, always for bots);
  the counts end the game automatically.
- **IDF/FMJD-64 against the Russian 2022 rules:** the kings-only count is 15 at any
  material (IDF) against 15 at 4–5 and 25 at 6–7 pieces only (Russian); the Russian
  rules add 5 moves at 2–3 pieces with kings on both sides, three kings plus men, and
  three men in the main-road case, and test "takes the king" where IDF says "a winning
  position".
- **Brazilian secondary sources** (tournament regulations, rule leaflets): 20 king moves
  and 20 or 10 moves for three kings against one, unlike the FMJD-64 text; lidraughts and
  playstrategy follow the FMJD-64 text, as Wikipedia's Brazilian article cites it.

### Open questions

- Russian: follow the 2022 Russian rules (proposed) or the IDF text lidraughts uses?
  They differ in the kings-only count and the cases above.
- "15/25/30/60 moves" where the text doesn't say "each": read as each side's (the
  record's numbering, as lidraughts does); only FMJD 6.3–6.4 say "each" outright.
- Russian 6.1.8.5's exception ("unless either side can win") and IDF 7.2.7–7.2.8's "a
  winning position" need an oracle; proposed: test only whether the king is taken.
- Russian 6.1.8.5 when the lone king leaves the main road: the count stops, and 6.1.8.3
  (15 moves) applies to three kings; proposed to restart nothing and let 6.1.8.3 or
  6.1.8.6 run from their own start.
- Brazilian: whether to find the CBD's text (Portuguese) or keep FMJD-64.

## Work

- The rules as pure functions over the game's history and counters (`src/rules/`), per
  variant, tested headless on each count's edge (the move before and the move of the
  draw), and against the computer player's search (it should neither walk into a draw
  it can win nor miss one it needs).
- The game screen: a draw as its own ending, calm, and the computer's skill counting it
  as 0 (`ai::adapt`, which already expects that); a draw by agreement isn't needed.
- For children: show the count running down where a draw approaches (e.g. "5 moves
  left"), so it doesn't arrive as a surprise; in strings for both languages.

## Acceptance criteria

- [ ] Each variant's draw rules confirmed against an official text, with the link
- [ ] Repetition and each move count drawing at exactly the right move, tested
- [ ] The game shows a draw and counts it; the countdown shown before it
