# 017: The native board on the season, as the design boards show it

Status: todo

Bring the app on the tablet to the look the prototypes and the user settled on
(2026-11-07), for all four seasons: the simple flat 2D board on the season's photograph,
blurred, with board and pieces styled like the seasonal design boards. Task 004 drew the
board natively with an older look (a frame, a strong light pool from the top left, grain);
`docs/architecture/rendering.md` (Look) now describes the target. The panel, buttons, and
menus are task 008, not this one.

## References

- The design boards, local and not to be checked in:
  `~/Downloads/kabe_theme_design_boards/` (`kabe_autumn_wood.png`, `kabe_winter_stone.png`,
  `kabe_spring_birch_four_seasons.png`, `kabe_winter_sea_comparison.png`) and
  `~/Downloads/Kabe Winter Stone UI Board.png`. Look at each season's game screen up close
  before writing the shaders.
- The prototype: `prototypes/game.html?season=<season>` (the blurred photo is the default
  there), checked with agent-browser.
- Theme values: `app/theme.goose` and rendering.md's table.

## What the design boards show (study, 2026-11-07)

- **Board**: no frame and no light pool; squares edge to edge with slightly rounded outer
  corners, sitting in the same glass card as the panel. The squares carry a very faint
  surface, never busy: autumn a fine wood grain, winter a faint paper-like mottling,
  spring and summer almost flat. A soft shadow under the board.
- **Pieces**: what the user calls the lighting; soft and diffuse, not the strong spec and
  falloff the native pieces have now. Each piece is a low disc with a rounded rim: the
  top edge of the rim catches light, the bottom edge is a little darker, the face has a
  gentle top-to-bottom gradient and a raised inner ring. A short soft shadow straight
  down to slightly down-right, and a thin visible side. Light pieces cream, dark ones
  deep and slightly glossy with a lighter rim.
- **States**: the selected piece lifted with a glow ring in the theme's glow color;
  targets are small glowing dots; the piece that must capture has a red ring and glow.
- **Background**: the season photograph, softly blurred, behind everything.

## Work

1. **Background**: decode the season's JPEG as rendering.md decided (stb_image in the
   program's own C through its `.build` sidecar, from `embed_file` bytes), draw it
   cover-cropped, and blur it once on the GPU when the season or screen size changes
   (the same blurred copy the glass panels will sample in task 008). All four seasons;
   `--theme` picks one for checking. The images are not in git and are not to be added
   without asking the user: until they agree, the build embeds the local masters from
   `design/backgrounds/masters/` and falls back to the theme's page color when they are
   missing, so a fresh checkout still builds.
2. **Board shader**: drop the frame, bevel, and light pool; plain squares with the
   faint per-theme surface above, rounded corners, the soft shadow under the board.
3. **Piece shader**: the soft rim light, face gradient, raised inner ring, thin side,
   and short soft shadow above, replacing the current spec and falloff. Keep the crown,
   selection, and the red pulse.
4. **Move hints** (`docs/product.md`): mistakes only by default, so no target dots; a
   wrong move flashes a red ring on its square twice and the piece that must capture
   pulses. A dev flag (`--hints moves`) shows the dots. Covered in `test/board/`.
5. **Check**: screenshots on the Mac for every season at 1920×1200 and 1200×1920, put
   next to the design boards; then the tablet over USB (`adb shell svc power stayon usb`
   first, back to `false` after), all four seasons via `--theme`, both orientations.
   Re-run `scripts/idle_cpu.sh` and the memory check from task 004 and record the numbers
   here: the background texture adds graphics memory, which must stay flat.

## Acceptance criteria

- [ ] The blurred season photograph behind the board, all four seasons, on the Mac and
      the tablet; a missing image falls back to the page color
- [ ] The board flat with no frame or light pool, the faint per-theme surface only
- [ ] Pieces with the design boards' soft rim light, face gradient, inner ring, and
      short shadow; crown, selection, and must-capture pulse kept
- [ ] Hints on mistakes only by default, with a red mark for a wrong move; tested
- [ ] Mac screenshots of each season compared with its design board, and differences
      either fixed or noted here
- [ ] Idle CPU and memory measured on the tablet and recorded here; still no frames
      while idle
- [ ] rendering.md updated where the native form differs from what it says
