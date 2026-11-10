# 060: Shared blocks for a second board game

Status: todo

Not soon. Chess may follow Draughts ([product](../docs/product.md)), with the same UI,
look, and renderers (flat and 3D) on the same platforms. Steam is planned later: the Mac
build native, the Windows build on Windows and through Proton on Linux and the Deck. Two
apps shouldn't each write and maintain the rendering, UI, and platform code.

**The shape (2026-11-10): composable blocks, not a framework.** Each app keeps its own
`main` and frame loop. The blocks are functions over flat structs that the app calls:
data in, data out, as the packages are now. Nothing hides the loop, owns the window, or
calls back into the game. Where a block must run game code (a game's legal moves, its
piece kinds), it uses Goose's compile-time generics and overloads, which are
monomorphized and cost nothing at run time. Stored callbacks don't exist in Goose, and
none are needed.

**The scope is two-player board games on a square grid.** Chess, and almost for free
Go (stones are discs) and Reversi. It is not a general game engine: no scene graph,
arbitrary meshes and materials, asset pipeline, audio, or physics.

## What carries over and what doesn't

The blocks would be:

- `gui`
- the UI drawer (`widgets`)
- the photographs and their blurs (`scene`)
- the font atlas (`text`)
- themes
- `strings`' loader
- the badge baker
- players and saved files
- clocks
- `pace`
- the worker's ask/answer protocol (`think`)
- `view3d` and `rig`
- `render3d`'s board, lighting, shadow, multisampling, and photo ambient
- the platform C files and build scripts
- the host and render seams of the code review's stage 4

What stays per game:

- the rules
- the computer player's evaluation and move generation (the sliced search, levels,
  and skill carry over)
- puzzles and their format
- how a move is entered: draughts captures stop by stop; chess castles (two pieces
  move), captures en passant (the taken piece is off the target square), and promotes
  (a choice)
- the pieces' shapes

## Steps

1. The code review's refactors first (2026-11-10): split screens from data, the panel's
   regions and `gui::stack`, the host and render seams. They are the same work.
2. Before chess, make only the generalizations that also serve Draughts, with no frame
   cost:
   - `board::hit` and `center` work in columns and rows, and the game maps those to its
     own square ids. Today they take `rules` bits, with play on dark squares only.
   - `board::Piece` gets a piece-kind index in place of its crown and stack flags.
   - `render3d` gets a mesh table indexed by kind, and draws instanced per kind.
   - The panel's taken-pieces tray takes pieces by kind.
3. Start chess in its own repo with these packages copied in. Pieces in 2D come from SVGs
   through the badge baker's distance-field atlas, beside the analytic disc Draughts
   keeps. In 3D, five pieces are lathe profiles with a few additions; the knight is a
   sculpted mesh embedded in the binary.
4. Once both games use the copies, move what both use unchanged into a shared repo of
   blocks, and pin both apps to it. What differs stays in each game. Designing the blocks
   before a second user exists would generalize the wrong things.

## Acceptance criteria

- [ ] Step 2's generalizations in Draughts, its tests' expected output unchanged, and its
      2D and 3D frame times no worse on the A33
- [ ] A chess app on the same platforms, its rendering, UI, and platform code taken from
      the shared blocks, not copied
- [ ] Neither app's frame loop hidden behind the blocks: each `main` reads like the frame
      described in `docs/architecture/README.md`
- [ ] A change to a shared block (the UI drawer, say) made once and building in both apps
