# Store listing: English (en-GB, the default)

Play Console → Grow users → Store presence → Main store listing. Play's limits: title 30
characters, short description 80, full description 4000 (Play Console Help
[9859152](https://support.google.com/googleplay/android-developer/answer/9859152), read
2026-11-09). The counts are of the text in each fence, as Python's `len` gives them;
`store/preview/build.py` checks them. The App Store's text is in `app-store.md`.

## Title (8 of 30)

```text
Draughts
```

The same as the launcher's name (`strings/en.txt`), and nothing for the audience: the
text names no age, since the hard level and puzzles are hard for grown-ups too
(2026-11-09). Play's metadata policy bars ranking, price, and promotion in the title
("#1", "best", "free")
([9898842](https://support.google.com/googleplay/android-developer/answer/9898842), read
2026-11-09).

## Short description (79 of 80)

```text
Draughts on a 2D or 3D board: play the computer or a friend, solve 120 puzzles.
```

## Full description (2,444 of 4,000)

```text
A calm draughts game to play and learn: big pieces, a flat 2D or a 3D board, and nothing to distract from the game.

PLAY
• Play the computer at three levels: easy, medium, and hard. It adjusts a little after each game, so it stays a fair match.
• Or play a friend on the same tablet or phone, taking turns (on one device, not online).
• Three kinds of draughts: International on the 10 × 10 board, and Brazilian and Russian on 8 × 8.
• Move by tapping a piece and its square, or by dragging it. Undo a move, or start over.
• Play without a clock, or with 5 or 10 minutes each, plus 3 or 5 seconds a move.

PUZZLES
• 120 puzzles: 74 for International draughts in six themes (Learn, Captures, Crowning, Shots, King shots, and Safe move), and 46 for Russian draughts in four. Brazilian players get the International set.
• Each theme goes from easy to harder, and some puzzles are played with black.
• Learn comes first and shows the rules in action; the other themes open once half of it is solved.
• Up to three stars a puzzle, one fewer for each mistake; a solved puzzle can be played again for all three.

PLAYERS
• Up to four players on one device, each with an animal picture and a name if they want one.
• Each player keeps their own look, move hints, stars, computer level, and saved game.
• Switching player takes two taps from the home screen.

MOVE HINTS
• Hints that help without doing the thinking: by default the game says nothing until a move is wrong, then shows the square and why. Showing every possible move can be turned on for the very first games.
• Capturing is compulsory: the piece that must capture is marked, with a dot for each piece it will take.

THE BOARD
• A flat board, or a 3D one with light and shadow, which you can turn by hand on the home screen.
• Four seasons, each a photograph with its own board: autumn wood, winter stone, spring carved stone, and summer sunset.
• The season follows the date, or stays on the one you choose; or a plain background in the colours of the board.

FOR EVERYONE
• Large buttons and pictures, so even a child who can't read yet finds their way.
• Simple enough for a first game, while the hard level and the hardest puzzles test grown-ups too.
• In English and Estonian, following the device's language.

NOTHING ELSE
• No ads, no in-app purchases, no accounts, and no internet: everything stays on the device.

Draughts runs on phones and tablets, in portrait and landscape.
```

## What the text leans on

Each claim is a fact of the app as built (2026-11-09, `main` at `ab53395`); check again
before an upload:

- Variants, levels, clocks (5 min +3 s, 10 min +5 s), undo, start over: `docs/product.md`,
  `strings/en.txt`. The computer comes first and a friend second, on one device: there is
  no online play.
- "It adjusts after each game": `ai::adapt` (`docs/architecture/ai.md`), per player.
- Puzzles: `src/puzzles/international.txt`, 74 in six themes (Learn 12, Captures 10,
  Crowning 12, Shots 20, King shots 10, Safe move 10), and `src/puzzles/russian.txt`, 46
  in four (Learn 12, Captures 10, Crowning 10, Shots 14), counted 2026-11-09; the app
  shows the set of the player's draughts, Brazilian players International's
  (`puzzles::set_of`). The themes opening at half of
  Learn, and the stars (three at stake, a miss puts one out down to one, the best kept):
  `docs/architecture/puzzles.md`. Shots has two levels so far, the others three, so the
  text says "from easy to harder".
- Players: four at most, six badges, an optional name of up to 12 characters, and what
  each keeps: `docs/architecture/README.md`, "Players", and task 038. Switching is home's
  chip, then a face on the card: two taps.
- Hints and the pips on a piece that must capture: `docs/product.md`, "Principles";
  puzzles never show a piece's targets.
- The 3D board, turned by hand on home, and the four season boards: the README's
  features, task 015.
- No internet: the manifest asks for no permission at all (`aapt2 dump permissions`).
- "The hard level and the hardest puzzles test grown-ups too": the reason the text names
  no age (2026-11-09); the Families forms still give the age groups
  (`play-console.md`).
- "Stays on the one you choose": settings' Theme row (a season, or by date); its switch
  puts the plain background in place of the photograph (task 044).
