# Product

## Purpose

A draughts app for all ages, from 4: play, puzzles, and later lessons. Simple enough for
a young child's first game, with puzzles and a hard level for grown-ups. It runs first on
an Android Galaxy tablet, then on the Play Store for free. Chess may follow on the same
base.

## Principles

- Minimal first: ship the smallest thing children use, and grow from how they use it.
- Usable without reading: icons first, big touch targets.
- Help that doesn't do the thinking. Showing every legal move makes a child lazy: they
  tap the glowing dot instead of looking at the board. So move hints are a setting, in
  settings, which the game reaches in one tap: **moves** shows the selected piece's targets
  (for learning the basics), **mistakes** shows nothing until a move is wrong, then
  marks the square and why (the piece that must capture pulses, and when another piece
  takes more, the pieces it takes; a second wrong square in the same capture lights its
  next stop). How many pieces a piece that must capture takes shows as pips a child
  counts without reading, but not which: with moves at once, counting down jump by jump;
  with mistakes only as a mistake's hint, from a wrong move until the capture ends,
  counting down jump by jump as with moves (2026-11-12; from 2026-11-09 they hid again
  at the next right jump, so a child who had been shown the count lost it partway;
  earlier on 2026-11-09 the pips showed whatever the setting, which gave the capture
  away before the child looked for it). A capture of many jumps is played jump by jump by the child, never
  finished by the game (2026-11-09). Mistakes is the
  default; moves is on by default only in the first lessons that teach the basic ideas,
  and in the tutorial at the first start.
- In a game, help shows the danger, never the answer, unless asked (2026-11-09). The
  **lookout** (Estonian *Valvur*), a round eye toggle at the end of whose turn's line,
  off until the player turns it on and remembered per player, marks what the player's
  skill would miss: the pieces the other side could take were it its turn, every piece
  of a multi-capture's chain, drained of color and still; while a piece is dragged over
  a square, what that move would leave open; a crowning square, shaded under a dark ghost
  king; and the other side's traps, a sacrifice whose forced capture wins it more. It
  shows less as the skill climbs, the plainest threats first, and nothing at hard
  ([ai](architecture/ai.md#the-lookout)). The **hint** is a tile beside undo move with
  three pips, a game's three hints (each side's three against a friend): the first press
  lights the piece to move with the puzzles' pulsing ring and spends a hint, the second
  shows its square with a light ghost of the piece for nothing more. Neither shows while
  a capture is due, nor in puzzles. A hint alone makes a player lazy, though lighting the
  piece to move helps; the lookout teaches to look.
  Puzzles never show a selected piece's targets, whatever the setting: the point of a
  puzzle is that the child thinks (2026-11-08).
- Lean: no engine, one small Java class over SDL's activity, no allocation in the frame
  loop, no frames drawn while idle.

## MVP scope

| Area | Included |
| --- | --- |
| Rules | Russian draughts 8×8, complete ([rules](architecture/rules.md)) |
| Board | Flat 2D, GPU-drawn; move hints (moves or mistakes only), forced captures pulse, multi-jumps animate; tap or drag to move, a multi-jump by its last square or stop by stop |
| Play | Pass-and-play; vs computer at 3 levels; either with no clock, 5+3, or 10+5 |
| Puzzles | About 30 in 3 tiers, International 10×10 first (2026-11-08): find the capture; multi-jumps and crowning; shots and "the only safe move" |
| Controls | Undo move, start over, back, settings; the lookout and the hint in a game; on home, an X that closes the app |
| Language | English by default, from a string table picked by the system's locale; Estonian as a translation if it stays cheap, finished after the core gameplay (2026-11-07) |
| Platforms | Android APK sideloaded onto the tablet; macOS for development. Every screen fits phones and tablets of any proportions, 9:20 to near square, in both orientations, with taps no smaller on the hand than about 10 mm (2026-11-08: phones fit rather than the app being listed for tablets only; [rendering](architecture/rendering.md#screen-sizes-and-the-safe-area)) |

## After the MVP, in order

1. **International 10×10.** The engine has it from the MVP; this adds the board layout,
   puzzles, and AI tuning. Once it is there it is the default variant: the first card at
   the first start and the one a new game's setup starts on, with Russian 8×8 beside it
   (2026-11-07).
2. **Learning.** Lessons on mini-boards (4×4, 6×6), one rule each, with icons and voice;
   100+ puzzles; endgame drills (2 kings vs 1, Petrov's triangle); child profiles with
   stars; sound.
3. **Looks.** A 3D board from the same game state, and the glass UI from the prototypes
   and design boards. Settings' Board row chooses flat or 3D, the 3D board in the
   season's own material or its wood, stone, or carved board, and every screen with a
   board follows it.
4. **Release.** Play Store under Google's Families Policy: no ads or tracking, a privacy
   policy. English checkers as a rules toggle. The application id is
   `io.github.kaitk.draughts` (2026-11-08); the build signs an app bundle (AAB) for Play
   with an upload key kept outside the repo ([development](development.md#release-builds)).
5. **Chess**, reusing the platform, rendering, UI, puzzle, and lesson layers.
6. **A NoGraphicsAPI version** through goose-ngfx, for desktop and Apple devices.

## Not planned

Online play, accounts, ads, in-app purchases, analytics.
