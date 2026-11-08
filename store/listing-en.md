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

## Short description (78 of 80)

```text
Draughts to play with a friend or the computer, and puzzles to learn the game.
```

## Full description (1,586 of 4,000)

```text
Draughts for children and their families: a calm board game to play and learn, with big pieces, a clear board, and nothing to distract from the game.

PLAY
• Play a friend on the same tablet or phone, taking turns.
• Play the computer at three levels: easy, medium, and hard. It adjusts a little after each game, so it stays a fair match.
• Three kinds of draughts: International on the 10 × 10 board, and Brazilian and Russian on 8 × 8.
• Move by tapping a piece and its square, or by dragging it.
• Take back a move, or start over.
• Play without a clock, or with 5 or 10 minutes each.

LEARN
• Puzzles in small steps: capture pieces, become a king, stay safe, win the game.
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
• No data collected: the settings and the game in progress stay on the device.

Draughts runs on phones and tablets, in portrait and landscape.
```

## What the text leans on

Each claim is a fact of the app as built (2026-11-08); check again before an upload:

- Variants, levels, clocks, take back, start over: `docs/product.md`, `strings/en.txt`.
- "It adjusts after each game": `ai::adapt` (`docs/architecture/ai.md`).
- Puzzle goals: `goal.*` in `strings/en.txt`. Task 037 is replacing the set; reword
  "Puzzles in small steps" if the new set is grouped by theme.
- Hints: `docs/product.md`, "Principles".
- No internet: the manifest asks for no permission at all (`aapt2 dump permissions`).
- "The one you choose": settings' Background row (a season, or by date).
