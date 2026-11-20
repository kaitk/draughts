# 109: The library as a whole room

Status: in-progress (planned 2026-11-20, under the epic 107; before task 106's modelling)

The concept frames show the library in pieces, and they disagree: `library-home-01`
made the far window smaller and squared the niches, though `style-01` and
`library-autumn-02` have the windows alike in deep niches with rounded tops. Before the
home shot is modelled (task 106), settle the whole room once, so the home shot, the
game's views, and the writing desk (task 108) sit in one room that makes sense: a
library in a real manor, believable and beautiful.

## The way (the user, 2026-11-20)

- Start from `style-01` (all local in `design/manor/`), whose room is mostly right: the
  stove's place in the corner is realistic, and most of what stands there belongs in
  some form.
- Flesh it out: all four walls, the doors (probably three), the windows (probably three
  on the garden side, a little slimmer than now; `garden-facade-01` as a guide, not to
  match exactly), the floor (the ground floor, below), the writing desk in the corner at the left (as in
  `style-01`'s foreground), and more bookcases, open ones, near the table on another
  wall, so it reads as a library.
- Try different layouts with ChatGPT and keep what is most believable and artistically
  beautiful. The reference images must be as realistic in what they hold as `style-01`:
  the number of plants, paintings, books, and other things a lived-in room has, so it
  looks believable, not bare and not crowded.
- What ChatGPT does well and badly: `design/manor/prompts.txt`'s head (few nouns and a
  mood, the image attached, a new chat each time; it redraws rather than edits). It
  places things loosely, so the plan the model follows is written here, from the images
  chosen, not taken from a generated floor plan.

## The room (the user choosing, 2026-11-20)

Five rounds of images (`design/manor/prompts.txt` 19 to 40, the results in
`design/manor/set-aside/` and `build/notes/chatgpt-109/`) showed that the models place
things carelessly: to fit three windows in a frame they stretch the room into a gallery,
they move the stove out of its corner and put doors where no house would, from words or
from a plan alone as much as from `style-01`. So the plan is ours, drawn to scale by
`design/manor/room/plan.py` (`python3 plan.py OUT_DIR`; its PNGs, local, in
`design/manor/room/`), and images are made with `style-01` attached for the look and the
labelled plan for the layout, one prompt at a time.

Only the window wall and the games table are fixed, as the home shot and the game's light
need them; the rest is a concept, to be moved once the room is modelled and seen (the
user, 2026-11-20).

Measured as the script has it: x along the window wall from the stove's end, 0 to 9 m; y
from the hall wall, 0 to 7 m. Facing the stove's end, the windows are on the left, as in
`style-01`.

- The ground floor, the garden side, beside the garden salon, the floor about a metre
  over the lawn; the windows face south-west, the sun 18° up and 20° left of straight out
  (`rooms::AUTUMN`). 9 by 7 m, the ceiling about 4 m.
- Walls: the window wall 0.8 m thick, the hall wall 0.6 m, the end walls 0.5 m. Dark
  oak wainscot, the dark blue-grey wallpaper with muted gold flowers above, herringbone
  oak.
- Windows: three alike, their middles at x 1.5, 4.5 and 7.5; 1.1 by 2.5 m, the sills
  0.8 m up. Niches 1.3 m wide with straight reveals, square to the wall (not splayed),
  topped by a shallow segmental arch (not a half circle), the casement near the outer
  face and rectangular, as `style-01`'s: two leaves, above a transom at two thirds of
  its height small panes 3 across a leaf and 4 up, below it 2 large panes a leaf; the inner shutters fold flat against
  the reveals; lace curtains; white sills on the panelling, with vases, plants and small
  things moved as the shots want.
- The door from the hall: a double door 1.4 m wide in the middle of the hall wall,
  facing the middle window, a low open bookcase on each side (1.3 by 0.4 m).
- The stove: pale green glazed tiles, in the corner of the hall wall and the stove's end
  wall, about 1.15 m square with its front corner cut, fed through the hall wall.
- The stove's end wall: a double door to the garden salon, 1.3 m wide, near the hall side
  (y 1.65 to 2.95), and the glazed bookcase on its window side (y 3.6 to 5.4), as
  `style-01`'s back wall.
- The far end wall: plan 1, the default, a double door to the next room in line with the
  salon's (an enfilade); plan 2, no door, open shelves to the ceiling with a ladder. Our
  views don't tell them apart, so it is left until one does.
- The hall wall's far part: the sofa under a large painting, a sofa table and an
  armchair before it.
- The games table, the first place to play: a round table about 0.8 m across, smaller
  than `style-01`'s, its middle 1.2 m from the window wall opposite the middle window, as
  the game's window light has it (`rooms::AUTUMN`'s `window.x`, 36 units). On a rug of
  about 3 by 2.2 m, the players either side along the wall, the one facing the stove with
  the window at their left and a little behind; the window side free. The game's table is
  1.05 m across (`mesh::TABLE_R`, 16 units); about 12 units when the room is modelled,
  checked on screen.
- The writing desk, the second place to play (task 108): 1.5 by 0.75 m, green leather,
  at a right angle to the window wall in front of the third window, its board in the
  middle of the leather, 1.2 m from the window opposite its middle, as the table's, so
  one room light serves both. Its player sits at the middle of the long side facing the
  stove, the window at their left.
- The chandelier in the middle of the room; a reading armchair and a side table by the
  first window; a tall plant in that corner; paintings in gilt frames on the piers and
  walls.

## Outside: the park the windows see (the user, 2026-11-20)

The first two park images (`library-outside-01`, `-02`) are a grove seen standing on
the lawn, the second with a path that wanders to the house for no reason. The look is to
be thought through with the room, not taken from one picture:

- A manor's park, every one different. Estonian manors' parks had straighter lines and
  better kept trees than now, but the look wanted is the concepts' tall, older, wilder
  trees. Alatskivi (`ref-alatskivi-aerial.png`, local; far too big a house, its park a
  little too kept) shows what fits when tuned: open lawns swept between masses of tall
  mixed trees, solitaires, a few spruces, broad curving gravel paths along the lawns'
  edges, water beyond.
- Trees close to the windows: the shadow on the board needs one within a few metres (the
  tree of task 105, the sun 18° up and 20° left of straight out).
- From the ground floor, about a metre over the lawn: the walk along the house, the lawn,
  the paths where a park would have them.
- Seen from the planned windows (the room above): their sills about 1.8 m over the lawn,
  the eyes of a player at the games table about 2.2 m and of someone standing about
  2.6 m; looking south-west, the sun 18° up and 20° left of straight out; the windows 3 m
  apart, each framed by its straight reveals, 1.3 m wide and about 0.6 m deep, the
  shutters folded flat against them.
- What the windows show (worked out from the plan, 2026-11-20): a player at the games
  table, eyes 0.4 m over the sill and 2 m in from the wall's outer face, sees the lawn
  only from about 11 m out, standing from about 6.5 m; the walk along the house is hidden
  but from the sill. The opening spans about 11° below the horizon to 45° above it, so
  the view is mostly crowns and sky over a thin band of lawn. Between windows 3 m apart a
  tree 15 m out shifts about 11°, one at 50 m about 3°, one at 200 m under 1°: the
  trees up to about 100 m need their own layers, the tree line beyond can be flat.
- Three windows and the home screen's pans see the park from different places, so a
  single 3:2 picture, which can't be wider, shows no parallax. Rather in layers by
  depth: the near tree ours (task 105's, drawn as well as cast), mid trees as cut-outs,
  the far tree line and sky as a wide band (pictures put side by side; the blur hides
  the seams), the sun's glow ours. Each layer's images from ChatGPT once the look is
  chosen; a view out of the whole window wall from inside first, to judge the look.
- What the images showed (round 6, `design/manor/prompts.txt` 41 to 46): the park as
  `library-park-01` (against the sun, the maple close, the oak alone, spruces on the right,
  the lake in the tree line). A single tree comes from ChatGPT as a usable transparent
  cut-out (`library-oak-01`); a whole tree line comes redrawn and cartoony. A panel to the
  side matches in kind, not in place, and its sky differs: panels join with a cut at a
  trunk, the sky drawn by us behind tree lines cut from the panels.
- The layers put together (`design/manor/outside/park.py`): the
  three far panels on a cylinder, their skies cut by a smooth sky fitted to them, joined
  at trunks, over a sky of ours, the oak at 40 m. The panels' seams hide in the crowns;
  `library-far-01`'s haze turns half transparent and still reads as haze. Through the
  plan's windows, from the games table only the middle window shows the park: the side
  windows' straight reveals, 0.8 m deep, hide it, and from the middle of the room they
  show slivers of a few degrees. So the middle window's view, some 30° across, carries
  the game; the band's sides serve the home screen and standing views. The oak dead
  ahead fills the middle window, and lit from the front it stands out of the backlit band.
- Chosen (the user, 2026-11-20): work on from these layers and redo what looks ugly once
  the room renders; haze and depth of field blur the far band and much of its roughness.
  The script's defaults set the tree line at about 110 m and the oak at 70 m, 22° right
  of straight out, so the middle window keeps the lake and the sun's glow; seen through
  the windows the band at 60 m crowded them. To move once rendered.

## Acceptance criteria

- [x] Several layouts tried as ChatGPT images, at least `style-01`'s view and the
      reverse view of the fourth wall, with their prompts in `prompts.txt` (set aside: the
      models can't lay out a room; our plan instead)
- [x] One layout chosen by the user: our plan, `style-01` for the look
- [x] The room's plan written here: walls, windows, doors, stove, bookcases, desk,
      table, rug, sizes in metres, for task 106 to model from
- [x] The park outside thought through and its layers' images made, the user choosing
      (round 6; the backlit oak and the spruce group's cut-out wait for the renders)
- [ ] Task 106's prompts and images (the simplified home shot, the window) brought in
      line with the chosen room
