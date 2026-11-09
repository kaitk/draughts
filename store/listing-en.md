# Store listing: English (en-GB, the default)

Play Console → Grow users → Store presence → Main store listing. Play's limits: title 30
characters, short description 80, full description 4000. The counts are of the text in
each fence, as Python's `len` gives them.

## Title (17 of 30)

```text
Draughts for kids
```

The launcher's name stays "Draughts" (`strings/en.txt`). Alternatives: "Draughts: play and
learn" (24), "Draughts" (8).

## Short description (74 of 80)

```text
Play draughts with a friend or the computer, and learn it with 74 puzzles.
```

## Full description (2,218 of 4,000)

```text
Draughts for children and their families: a calm board game to play and learn, with big pieces, a clear board, and nothing to distract from the game.

PLAY
• Play a friend on the same tablet or phone, taking turns.
• Play the computer at three levels: easy, medium, and hard. It adjusts a little after each game, so it stays a fair match.
• Three kinds of draughts: International on the 10 × 10 board, and Brazilian and Russian on 8 × 8.
• Move by tapping a piece and its square, or by dragging it.
• Take back a move, or start over.
• Play without a clock, or with 5 or 10 minutes each.

PUZZLES
• 74 puzzles on the 10 × 10 board, in six themes: Learn, Captures, Crowning, Shots, King shots, and Safe move.
• Each theme goes from easy to harder, and some puzzles are played with black.
• Learn comes first and shows the rules in action; the other themes open once half of it is solved.
• Up to three stars a puzzle, one fewer for each mistake; a solved puzzle can be played again for all three.

PLAYERS
• Up to four players on one tablet, each with an animal badge and a name if they want one.
• Each player keeps their own look, move hints, stars, computer level, and saved game, so one child's game or stars never replace another's.
• Switching player takes two taps from the home screen.

LEARN AS YOU PLAY
• Move hints that help without doing the thinking: by default the game says nothing until a move is wrong, then shows the square and why. Showing every possible move can be turned on for the very first games.
• Capturing is compulsory, and the piece that must capture is marked.

MADE FOR CHILDREN
• Made for children from about 5, and the grown-ups who play with them.
• Large buttons and pictures, so a child who can't read yet can find their way.
• The background follows the season: a photograph of winter, spring, summer, or autumn, or the one you choose.
• In English and Estonian, following the device's language.

NOTHING ELSE
• No ads.
• No in-app purchases.
• No accounts or sign-in.
• No internet: the app works offline and never connects to the network.
• No data collected: the players, their settings, and their games stay on the device.

Draughts runs on phones and tablets, in portrait and landscape.
```

## What the text leans on

Each claim is a fact of the app as built (2026-11-09); check again before an upload:

- Variants, levels, clocks, take back, start over: `docs/product.md`, `strings/en.txt`.
- "It adjusts after each game": `ai::adapt` (`docs/architecture/ai.md`), per player.
- Puzzles: `src/puzzles/international.txt`, 74 in the six themes, 18 of the 62 outside Learn
  black to move; the themes opening at half of Learn, and the stars (three at stake, a
  miss puts one out down to one, the best kept): `docs/architecture/puzzles.md`. Shots
  has two levels so far, the others three, so the text says "from easy to harder".
- Players: four at most, six badges, an optional name of up to 12 characters, and what
  each keeps: `docs/architecture/README.md`, "Players", and task 038. Switching is home's
  chip, then a face on the card: two taps.
- Hints: `docs/product.md`, "Principles"; puzzles never show a piece's targets.
- No internet: the manifest asks for no permission at all (`aapt2 dump permissions`).
- "The one you choose": settings' Theme row (a season, or by date); its switch can put a
  plain background in place of the photograph, which the text leaves out.
