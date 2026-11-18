# 01: Concept art for the manor room

Status: in-progress

Find the manor and the room before modelling anything. ChatGPT paints the frames from
`design/manor/prompts.txt`; the results stay local in `design/manor/`.

## Rounds

1. **The room alone**, without the app's boards, so the board doesn't become the hero
   and the room doesn't drift toward the UI's palette: the library by its window per
   season, the stair hall, the garden façade, the view out of the window.
2. **The board in the room**: a screenshot of the 3D board at the game's rest angle, with
   ChatGPT painting the room around it while keeping the board, its framing, and the light
   from the left. The autumn and winter close-ups (`agents/design.md`) for colour.
3. **Model sheets** of the chosen room: a floor plan, wall elevations, and close-ups of
   the window niche, the tiled stove, and the wainscoting.

## The direction so far (2026-11-17)

- The room: `style-01.png`, the library drawn from the first style block: two deep
  niches on the left, patterned wallpaper above dark wainscoting, the tiled stove in the
  far right corner. Two board places in it: the round table with flowers and the writing
  desk at the left edge.
- The house: `garden-facade-01.png`, ochre with white trim, a terrace, old trees within
  metres of the windows; stylised outside, but right for the light and shadow inside.
- Where the room is: the upper floor's middle room behind the three windows under the
  pediment, about 9 × 7 m with a ceiling of about 4 m. `style-01` looks along that
  window wall: its two niches are the middle and far windows, the third behind the
  camera. The garden side faces south-west, so the afternoon sun comes in low from the
  left through the trees.
- The second room: `upper-hall-02.png`, the hall at the top of the stairs with glazed
  doors onto the balcony over the columned portico, the table in the sun by the doors.
  The same manor, a little larger: the portico is on the entrance front, which faces
  north-east, so this hall lies back to back with the library and gets low morning
  sun, cooler and crisper than the library's warm afternoon. The concept's light comes
  from the right; in play the camera sits across the table so the doors are on the left.
- The library's home screen: `library-menu-01.png`, the window and the park sharp, the
  sun flaring through the leaves, the board waiting on the round table in the soft
  foreground at the right. Good enough to iterate on; lilacs in October to be swapped
  for the season's flowers.
- The library in play: `library-table-01.png`, the board on the round table under
  dappled sun through the window and the branches, the room soft behind. The light
  pattern across board and table is the one to bake (the README's cookie).
- The library's desk in play: `library-desk-01.png`, a good mahogany desk and props, but
  the desk stands out in the room instead of against the wall by the window, and the
  board is too big for it. To redo.
- The books, for the period: German, in brown half-leather with gilt bands and titles in
  Fraktur on the spines, many in multi-volume sets ("Goethe's Werke", 1–12), worn at the
  edges. `style-01`'s glazed bookcase and window-sill books are closer to it than the
  later frames' loose, generic volumes.
- The upper hall in winter: `hall-winter-01.png` (the hall kept, doors closed, snow);
  `hall-winter-pair-01.png`, a menu frame and a play frame side by side, the one with the
  magic: the snowy doors with the column sharp, the board soft at the side, a warm lamp;
  the stone board close under even snow light. `hall-winter-menu-01.png` and
  `hall-winter-table-01.png` are its two halves made whole, a baseline that lost some
  of it. `hall-winter-table-02.png`, closer in, is the play concept: near the game's
  framing, the board's stone and carved border and the pieces' worn marble legible, the
  doors only a bright edge on the left; `-01` stays for the hall behind. The stone board with a carved border is near the app's stone and carved looks.
- The rooms' surfaces, liked as they are in the concepts:
  - The library (`style-01`, `library-menu-01`): wallpaper with a muted gold-brown floral
    pattern on a dark blue-grey ground, between damask and a Morris paper, above dark
    panelled wainscoting.
  - The upper hall (`upper-hall-02`): walls of pale blue-grey painted plaster, chalky and
    a little uneven (distemper or limewash), white cornice; halls were painted, living
    rooms papered.
  - Classical busts in white plaster or marble on top of the bookcases and cabinets.
  - Generally the rooms' furnishing in these frames: the lace curtains, the glazed
    bookcases, the gilt-framed landscapes, the worn rugs on the floorboards and parquet.
- What failed: long lists of details (ChatGPT draws every noun, each on its own), "the
  same room" across chats, and "nothing else" (a bare room).

## Acceptance criteria

- [x] Round 1: a room direction chosen, saved as `design/manor/<shot>-NN.png`
- [ ] Round 2: the game's camera works with the room
- [ ] The decade fixed, and the style block in the prompts updated to match
- [ ] Round 3: a floor plan and elevations to model from
