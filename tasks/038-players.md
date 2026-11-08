# 038: Players on one tablet

Status: in progress (take a chosen 2026-11-09 and built; the chip, bare and mirroring
the X, and the badges' look chosen and built, the badges' final silhouettes to come; to
check on the Mac and the tablet)

A family shares one tablet: children of different ages and a parent. Each child wants their
own look (season and board) and their own puzzle stars, and a way to start them again
(2026-11-08). Players are local only: no accounts, no network, no passwords. This is the
"child profiles with stars" in `docs/product.md`'s learning step, and comes after the
MVP, beside task 037's puzzle library, whose stars it keeps per player.

## What a player holds

A player is a picture, an optional name, and everything a child makes their own. The rest
belongs to the tablet.

| Kept | Per player | Per device | Why |
| --- | --- | --- | --- |
| Picture: an animal on its own colour | yes | | A child who can't read yet finds themselves by it. Six animals (fox, hare, bear, owl, frog, hedgehog, forest animals as the photographs are Estonian), each its own colour; one a player has is not offered to another |
| Name, up to 12 characters | yes, optional | | For the parent; nobody needs to read it to pick themselves |
| Look: background (season), kings, board (2D/3D) | yes | | What each child wants their own |
| Move hints | yes | | Moves suits a younger child learning the basics, mistakes an older one |
| A new game's setup: draughts, level, colour, clock | yes | | Each child plays at their own level |
| The computer's skill per level, the games against it | yes | | `ai::adapt` follows the child who plays; shared, it would follow neither |
| Puzzle stars, and so which themes are open | yes | | Each child's own progress |
| The game in progress (`game.bin`) | yes | | Continue means "my game": switching to a sibling must not replace a game against the computer. A pass-and-play game is the player's who started it. A few KB each |
| The first start done (task 026) | yes | | A new player meets "learn the moves or just play"; open question 6 |
| Language | | yes | The parent sets it once; a child who can't read gains nothing from choosing |
| Sound (later) | | yes | The room's volume, not the child's |
| Which player is playing | | yes | The last player stays until switched (takes a and c) |

## The takes

`prototypes/profiles.html?take=a|b|c`, with `&state=home`, `pick`, `add`, `edit`, or
`hold`, `&n=1` to `4` players, and `&lang=et`. Shots of all three at the tablet's and a
phone's size in both orientations were checked with `agent-browser` (1280 × 800, 800 ×
1280, 1040 × 480, 480 × 1040), every tap 88 dp.

- **a, the player beside the name.** Home's king beside the wordmark becomes the
  player's face, 64 dp in an 88 dp tap. A tap opens "who's playing" on a glass card over
  the dimmed home: a face per player with its name under it, the player lit with the glow
  ring, then + while there is room; a face switches and closes the card. Home loses
  nothing: the board stays 620 dp in the tablet's portrait, 380 on a 480 × 1040 phone.
- **b, who's playing first.** Every launch with more than one player opens on the faces,
  200 dp glass tiles on the photograph (132 on a phone), two by two where four don't fit
  a row; a tap goes home, where the face beside the name comes back here as in a. Asks
  every time, so a child never plays on as their sibling, at the cost of a tap on every
  launch, also after Android closed the app in the background.
- **c, faces on home.** A row of 88 dp faces under the wordmark, the player lit as a
  setting's tile is; one tap switches. Tapping the lit face opens its sheet; + adds one.
  The row costs the portrait board: 620 to 516 dp on the tablet, 380 to 276 on a 480 ×
  1040 phone. On a phone in landscape the faces take the wordmark's row, the gear at
  their end, since the column has no room for both.

All three share the player's sheet: back, the face and name (or "New player"), and done;
the six pictures, those taken dimmed; the name, a field 88 dp tall; and when editing,
start again and remove. In a and b the sheet is behind the picker's pencil: the pencil
puts a badge on each face, and a face then opens its sheet, three taps from home, out of
a child's way. In c it is behind the lit face, two taps. On a phone in landscape the
pictures stand at the left, three by two, and the name and the holds at the right.

**Proposed: a.** It costs home's layout nothing in any size, the face says at a glance who
is playing, switching is two taps, and editing is three. Take b if children keep
playing as each other; c if one tap matters more than the portrait board.

## Switching, adding, starting again, removing

- **Switching** writes the leaving player's file and game, reads the other's, and shows
  their game and look at once: the face lights in the frame after the tap and the
  photograph loads in the frame after that, as settings' season tile does
  ([rendering](../docs/architecture/rendering.md#scene-and-glass)); the board changes at
  once, as a setup's does. Who's playing is only on home, so no game or puzzle is cut off.
- **Adding** opens the sheet with the first free animal lit; done adds the player and
  switches to them, with every setting at its default (the season by the date). Four
  players at most, a fixed table: + is gone at four.
- **Start again** clears the player's stars, the computer's skill and games, and their
  saved game; the picture, name, and look stay.
- **Remove** deletes the player's files. The last player can't be removed, only started
  again. Removing the player who is playing makes the first left the player.
- **Both are holds** of 1.5 s, a ring filling round the tile (the glow colour for start
  again, the forced-capture red for remove); let go early and nothing happens. No dialog:
  a dialog needs reading, and a hold is what a child doesn't do in passing and a parent
  does knowingly. Tried in the prototype: a 0.5 s press does nothing, a full hold removes.

## The files

One file per player rather than sections in `settings.txt`:

- `settings.txt` keeps the device: `language`, `player = 2` (the playing player's id),
  later `sound`.
- `player-N.txt`, N the player's id, 1 to 4: `picture = fox`, `name = Mia`, then today's
  keys as they are (`season`, `board`, `hints`, `kings`, `draughts`, `level`, `color`,
  `clock`, `skill_*`, `games`, `stars`). Players show in the order of their ids; a new
  player takes the lowest free id.
- `game-N.bin`, the player's saved game, as `game.bin` is today.

Each file is written whole and atomically as today (`write_file_atomic`), starting again
or removing is deleting files, and `shell/settings.goose`'s `parse` and `write` keep
working on a player's keys. One file with sections would rewrite every player on any
change and need a section parser.

In memory: the playing player's `Settings` as now, and for the others only their picture
and name for the picker, in a fixed table of four read at start. Switching reads one
small file into a fixed buffer, on a tap, never while idle.

**Migration**, at start, when `settings.txt` has no `player` key: its player keys become
`player-1.txt` with `picture = fox` and no name; `game.bin`, if there is one, is renamed
`game-1.bin`; then `settings.txt` is rewritten with `language` and `player = 1`. That
order loses nothing if the app is killed halfway: until `settings.txt` is rewritten, the
next start migrates again from the same keys, and each step repeated does the same. A fresh install starts the
same way, with one player and the first start.

## Native work

- The six pictures as filled icons on the 24-unit grid, as home's tiles' icons are, over
  an SDF disc with a gradient in the animal's colour; the prototype's paths are the
  first draft.
- The name: SDL's text input (`SDL_StartTextInput` brings up Android's keyboard; text
  arrives as UTF-8). The atlas bakes Latin-1 and Latin Extended-A, so Estonian names
  draw. Could wait (open question 2).
- The hold's ring: an SDF rounded-rect outline drawn up to the hold's fraction; frames
  run only while held, then the screen is still.
- Strings: who's playing, new player, picture, name, start again, remove, hold, in
  `strings/en.txt` and `et.txt` (the prototype has "Kes mängib?", "Uus mängija", "Pilt",
  "Nimi", "Alusta otsast", "Eemalda", "Hoia all", for review with the rest).

## Decisions (2026-11-09)

The user's answers to the open questions below:

1. Take a: who's playing on a card over home, the sheet behind its pencil.
2. Names are in the first version: optional, up to 12 characters, through SDL's text
   input (Android's keyboard).
3. The language is the device's.
4. The game in progress is the player's.
5. Start again clears the stars, the computer's skill and games, and the saved game.
6. Every new player gets the first start (task 026, not built yet): only a per-player
   flag for now, `first_start = done` in their file.
7. Four players and six badges; start again and remove are holds of 1.5 s.

Changed while building (2026-11-09):

- **The badges are pieces (chosen 2026-11-09, `badges.html` direction 1).** Each badge
  is home's king as the light pieces are drawn now (and later ivory, stone, the 3D
  board, through the shared `man_top`), the animal in the crown's place and colour,
  simple and bold as the crown is, with at most a faint inner shadow along its upper
  edge: not a deep engraving. The king and its crown stay as they are. Six animals: fox,
  hare, owl, hedgehog, bear, frog. A player's file keeps the badge as a name
  (`picture = fox`); the six colours are gone.
- **The art pipeline.** Each animal is a single-colour silhouette in
  `assets/badges/<animal>.svg`; the final ones come later from the user (generated
  images traced to SVG), and until then the files hold the prototype's hand-drawn
  silhouettes. The app embeds the files when built and `badges/badges.goose` bakes them
  at start into a signed distance texture (96 texels a side per animal), which
  `badge()` in `app/widgets.goose` samples; nothing is evaluated per frame on the CPU.
  Replacing a file and building again is all a swap takes; check it with
  `test/badges` (bless its coarse drawing) and a look on screen. What a file must be:
  a viewBox on the svg element, square best (the longer side spans the badge's square,
  centred, ±0.56 of the piece's radius, the crown's room; keep the shape inside that
  square's inscribed circle, the groove beyond it), and the shape as one or more paths
  filled together even-odd (holes by even-odd or by reversed subpaths), each `d` of
  M L H V C S Q T A Z in either case. Transforms on paths and groups are applied
  (matrix, translate, scale, rotate: potrace's `translate(0,H) scale(0.1,-0.1)` works).
  Fill, stroke, and any other element (circle, rect, use, text) are ignored, so
  convert shapes and strokes to a filled path first. At most 4096 straight pieces after
  flattening (each curve 2 to 32).
- **Possible later, open:** a carved look for both the crown and the badges, the mark
  recessed into the top and lit as the groove is (a darker floor, a lit lower wall and
  a shadowed upper one, from the distance field). First briefed for this task and set
  aside before it was built, for the crown's flat look (2026-11-09).
- **Home keeps its king beside the wordmark**, and the player is a chip of their own,
  first the badge and name in a round glass 88 dp tall, as the X was
  (`badges.html?home=2`).
- **The chip's place, first (chosen 2026-11-09, replaced the same day):** above the
  board's top left corner (left edges level, 16 dp between), the board keeping its top
  128 dp down for it.
- **The chip bare, mirroring the X (the user, 2026-11-09, after seeing it on the
  tablet):** no glass or disc, just the badge (64 dp, centred in the first 88 dp of the
  tap) and the name beside it in the row labels' face (`gui::LABEL`, 30 dp, was the
  20 dp body face), bare as the X and the gear; pressed, the X's press (`gui::bare`:
  white at 10% and a faint ring, a pill over badge and name, 88 dp tall). It sits in the
  X's row: 24 dp from the top and from the left of the board's side of the screen (the
  safe area's left in portrait, the column's right edge in landscape), as the X is
  24 dp from the right and the top; no longer anchored to the board. The board clears
  the badge as it clears the X (in landscape, moving down to 8 dp under the row or
  narrowing; in portrait the centred board's room from the X covers it). A board still
  in the row under the name steps down below it where that costs it no size (the
  tablet with its navigation bar in landscape, whose board sits 113 dp down, and the
  20:9 phone's landscape at 540 dp); a name that would still come within 16 dp of the X
  or of the board leaves the chip round, the badge alone. A twelve-character name (the
  tests' faces, wider than the font) fits at the tablet's sizes, with its navigation bar
  too, the foldable's and 4:3's landscape, and the 20:9 phone at every tested scale and
  inset; it falls back to the badge at the foldable's and 4:3's portrait, a 9:16 phone's
  landscape at 480 dp, and its portrait with the Pixel 7a's insets. `home::player_spot` places
  it; `test/shell/sizes` checks at every size, with no name and twelve characters, that
  it is level with the X, as far from the board's side's left as the X from the right,
  and off the column, the X, and the board.

  The room kept above the board for the first place is given back. Board sizes in dp,
  before (the chip above the board) and after, from `test/shell/sizes` and the shell
  tests:

  | Screen | Before | After |
  | --- | --- | --- |
  | The tablet, landscape (1280 × 800 dp) | 560, top at 128 dp | 560, top at 120 dp |
  | The tablet, portrait | 620 | 620 |
  | The tablet with its navigation bar, landscape | 526, top at 128 dp | 526, top at 113 dp (120 with a name) |
  | Foldable, portrait | 339 | 411 |
  | 4:3, portrait | 407 | 479 |
  | 20:9 phone, landscape, 480 dp | 328 | 336 |
  | 20:9 phone, landscape, 480 dp, the Pixel 7a's insets | 291 | 299 |
  | 20:9 phone, landscape, 540 dp, the Pixel 7a's insets | 346 | 349 |
  | Every other tested size | unchanged | unchanged |
- **Who's playing opens by itself only on a fresh install's first run**, at the sheet of
  its one player, so the child picks a badge and perhaps a name; done or back goes home.
  Later starts never ask. An install from before players becomes player 1 silently.

## What was built

- `shell/players.goose`: the files, the migration, and a player's keys; `shell.goose`
  switches, adds, edits, starts again, and removes (`switch_player`..); the app reads the
  players at start and writes the playing player's file and game.
- `shell/who.goose`: the card and the sheet; `gui::hold_tile` (the hold and its ring),
  `gui::face`, typed characters in `gui::Input`; the shader's ring, faces, and the plus,
  pencil, check, and bin icons; the app turns the keyboard on and off and feeds it in.
- Strings in English and Estonian (`players.*`).
- `badges/badges.goose` and `assets/badges/`: the animals' SVG files read and baked;
  `draw::MAN_BLOCK` shared by the pieces and `badge()`.
- Tests: `test/shell/players` (files, migration killed after each step, add, switch,
  start again, remove), `test/shell/who` (the card and sheet driven by the pointer, the
  holds, typing, back, the first run, the layouts at the tablet's and a phone's sizes in
  both orientations, in both languages: every tap 88 dp, inside the safe area, none
  overlapping); `test/shell/sizes` counts the chip among home's tiles and checks its place.

What to look at on screen, at the tablet's size (`--size 960x600`, `600x960`) and a
phone's (`--dp 480 --size 1066x480`, `--size 450x1000 --dp 480`): home with the chip
(no name, then a name); the card with one and with four players, pencil on; a new
player's sheet; a player's sheet with both holds, one held partway (a long press on the
tablet); the sheet while typing, with Android's keyboard up (does the card clear it in
landscape?); the first run on a fresh install (`adb uninstall`, then install).

Unsure: whether Android's keyboard covers the name field in the tablet's landscape (the
card moves to the top while typing, but SDL's text input area isn't set: gfx has no call
for it); whether a hidden keyboard comes back on a second tap of the field (the app stops
and starts text input again on each tap).

## Open questions

1. Which take: a (proposed), b, or c?
2. Names in the first version, or pictures only, leaving out text input?
3. Language per device (proposed), or per player for a family reading two languages?
4. The game in progress per player (proposed), or one game the family shares?
5. Start again: the stars, the computer's levels, and the game (proposed), or the stars
   only?
6. Does a new player see the first start (task 026), or only the first player?
7. Four players and six animals enough, and these animals?
8. Is a 1.5 s hold enough to keep remove from a child, or does it want more?

## Acceptance criteria

- [x] A take chosen, and its home, picker, and sheet recorded in
      `docs/architecture/rendering.md` ("Controls"); what a player holds and the files in
      `docs/architecture/README.md`; `docs/architecture/puzzles.md`'s stars in the
      player's file
- [x] Up to four players, each with a picture, an optional name, and their own look, move
      hints, setup, computer skill and games, stars, and saved game; the language per
      device
- [x] Switching takes at most two taps from home and shows the player's game, look,
      stars, and level at once; nothing allocates in the frame loop
- [x] Adding takes a picture and an optional name; start again and remove are 1.5 s
      holds that a shorter press doesn't trigger; the last player can't be removed
- [x] An install with today's `settings.txt` and `game.bin` comes up as player 1 with
      nothing lost, also when killed during the migration
- [x] Headless tests: a player's file read and written back, the migration, start again
      and remove, the picker's layout at the tablet's and a phone's size
- [x] Every tap 88 dp; strings in English and Estonian, `test/strings/` passing
- [ ] Checked on the Mac at the tablet's and a phone's sizes in both orientations, then on
      the tablet over USB
- [x] The badges' look chosen and drawn in `badge()`: home's man with the animal in the
      crown's place, from SVG files baked at start (placeholder silhouettes)
- [ ] The final silhouettes from the user in `assets/badges/`
- [x] Where the player shows on home chosen, and `home::player_spot` moved there: bare,
      mirroring the X at the board's side's top left (2026-11-09), checked off the
      column, the X, and the board at every size
