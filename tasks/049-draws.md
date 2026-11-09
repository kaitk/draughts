# 049: Draws

Status: in-progress

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

### Decided (the user, 2026-11-09)

- Russian follows the Russian federation's 2022 rules, not the IDF text lidraughts uses.
- "15/25/30/60 moves" without "each" means each side's moves (the record's numbering).
- The "either side can win" and "a winning position" exceptions are left out: a count
  ends only when the lone king is taken.
- When the lone king leaves the main road, the 5-move count stops and nothing restarts;
  6.1.8.3 or 6.1.8.6 run from their own start.
- Brazilian keeps the FMJD-64 text; the CBD's isn't looked for further.
- The draw's screen: take a of `prototypes/draw.html` (a card with words, like the win's,
  and the countdown as a line under whose turn), chosen 2026-11-09.
- The countdown where clocks leave no room: `fit=b` of the same page, a short form between
  the clocks ("Draw in 3", "Repeat 2/3"), chosen 2026-11-09 over the line beside a halved
  undo and the dots alone.
- Three readings confirmed as built (2026-11-09): Brazilian 7.2.4 counts three or more
  kings with men beside them; the Russian main road stops for good when a strong piece
  steps on it; king against king names no side.

## Work

- The rules as pure functions over the game's history and counters (`src/rules/`), per
  variant, tested headless on each count's edge (the move before and the move of the
  draw), and against the computer player's search (it should neither walk into a draw
  it can win nor miss one it needs).
- The game screen: a draw as its own ending, calm, and the computer's skill counting it
  as 0 (`ai::adapt`, which already expects that); a draw by agreement isn't needed.
- For children: show the count running down where a draw approaches (e.g. "5 moves
  left"), so it doesn't arrive as a surprise; in strings for both languages.

## Built (2026-11-09)

- Rules: `rules/draw.goose` (rules.md, "Draws"). Brazilian 7.2.4 counts three kings or
  more with men beside them, as Russian 6.1.8.4 says outright; the FMJD-64 text names
  only kings, and lidraughts needs all kings. The main road stops for good
  when the lone king leaves it, and in Russian also when a strong piece steps on it
  (the condition no longer holds). A lone king against a lone king counts each side's
  moves in the countdown ("Draw in"), with no side named.
- The search scores draws as 0 (ai.md, "Search"); the game hands it its past.
- The game: take a's card and countdown (rendering.md). A move that draws also stops the
  clock; undo takes the draw back; a saved game's counts come back from its undo
  history, so the save format didn't change. Puzzles never draw (they don't run the
  game's draw check).
- Strings, Estonian to review: `draw.balance` "{} käiku ilma löögi ja uue tammita" (the
  English "{} moves without a capture or a new king"), and the rest as the prototype
  proposed. Reviewed with Gemini (`agents/writing.md`, 2026-11-09): the Estonian kept as
  it is; `draw.kings` in English became "{} moves by kings only", since "with only kings"
  read as only kings on the board (191 dp at the body face, two lines on the smallest
  card).
- The countdown with clocks in a portrait panel and the 3D corner panel: the short form
  (`fit=b`; rendering.md), shot headless at phone sizes (`--dp 540`, `--dp 480` with a
  10:15 clock, Estonian), the tablet's portrait and landscape 3D, and a phone's landscape
  3D. `tools/play.goose` searches with the game's past and ends in the rules' draws;
  `--tap` takes 256 taps, so a count can be played to its draw headless.
- Not built: 6.1.8.7 and the winning-position exceptions (as decided).

## Acceptance criteria

- [x] Each variant's draw rules confirmed against an official text, with the link
- [x] Repetition and each move count drawing at exactly the right move, tested
  (`test/rules/draws_*`, the search in `test/ai/draws.goose`, the game in
  `test/game/draw.goose`)
- [x] The game shows a draw and counts it; the countdown shown before it (checked
  headless on the Mac; the tablet not yet)

## Measured

The search's speed, built on the Mac (M-series), before and after it saw draws
(2026-11-09). `build/aibench`, the built-in middlegames, three runs each: hard 8.7–9.1
million nodes a second before, 8.75–8.98 after, its slowest reply 102–120 ms against
105–111; every level's move and depth the same. King endings, hard (800,000 nodes):

| Position | Before, nodes/s | After |
| --- | --- | --- |
| Russian `W:WKc1,Ke1,Kg1,e3:BKb8,Kh8,a7` | 6.70 M | 6.45 M |
| International `W:WK47,K49,30,35:BK2,K4,16` | 6.91 M | 6.60 M |
| Russian `W:WKc1,Ke1:BKd8,Kf8` | 7.55 M | 6.84 M |

`build/aimatch` (after: the rules' draws end a game and the engine sees them; before: its
own 50 plies without a capture or a man's move):

| Match | Before | After |
| --- | --- | --- |
| Russian 40 against 0, 200 games | 197–1–2, 52 plies, 0.92 s | 196–2–2, 52 plies, 0.85 s |
| International 40 against 0, 100 | 99–1–0, 94 plies, 1.99 s | 97–3–0, 94 plies, 1.90 s |
| Brazilian 60 against 40, 100 | 72–25–3, 90 plies, 5.70 s | 71–25–4, 75 plies, 4.18 s |
| Russian 90 against 60, 10 | 10–0–0, 55 plies, 15.1 s | 10–0–0, 55 plies, 14.5 s |
