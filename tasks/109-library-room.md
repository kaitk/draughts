# 109: The library as a whole room

Status: todo (planned 2026-11-20, under the epic 107; before task 106's modelling)

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
  match exactly), the upper floor, the writing desk in the corner at the left (as in
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

## A first plan to try (2026-11-20, not chosen)

Directions as seen in `style-01`: the windows on the left wall.

- The sun stays where the library's light has it (`rooms::AUTUMN`): 18° up, 20° left of
  straight out of the windows.
- The ground floor, the garden side (the user, 2026-11-20: as Baltic manors mostly had
  their main rooms and library), a room beside the garden salon in `garden-facade-01`,
  the floor raised on the house's plinth about a metre over the lawn; it faces
  south-west, the low afternoon sun of the rooms' light (task 104). The trees' trunks and
  lower crowns fill the windows, and the park's gravel path shows.
- The window wall: three windows evenly spaced, each in a deep niche with a rounded top,
  folded shutters, lace curtains, a white sill on the panelling.
- The doors: two double doors in line (an enfilade) through the back wall and the fourth
  wall (behind `style-01`'s camera), and one to the hall.
- The stove in the back right corner, stoked from the hall's side, as was common.
- The glazed bookcase on the back wall; open shelves to the ceiling on the right wall,
  near the table.
- The writing desk in the front left corner by the first window, the light from the left.
- The round table on the rug, a sofa on the window side, chairs, the chandelier.
- About 7 by 9 m, the ceiling about 4 m; the windows about 1.1 m by 2.5 m, the sills about
  0.8 m from the floor.

Open: the open shelves on the right wall or on the fourth wall; the third door in the
right wall between the shelves or in the fourth wall.

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
- Three windows and the home screen's pans see the park from different places, so a
  single 3:2 picture, which can't be wider, shows no parallax. Rather in layers by
  depth: the near tree ours (task 105's, drawn as well as cast), mid trees as cut-outs,
  the far tree line and sky as a wide band (pictures put side by side; the blur hides
  the seams), the sun's glow ours. Each layer's images from ChatGPT once the look is
  chosen; a view out of the whole window wall from inside first, to judge the look.

## Acceptance criteria

- [ ] Several layouts tried as ChatGPT images, at least `style-01`'s view and the
      reverse view of the fourth wall, saved in `design/manor/room/` with their prompts in
      `prompts.txt`
- [ ] One layout chosen by the user, its images as believable in their contents as
      `style-01`
- [ ] The room's plan written here: walls, windows, doors, stove, bookcases, desk,
      table, rug, sizes in metres, for task 106 to model from
- [ ] The park outside thought through and its layers' images made, the user choosing
- [ ] Task 106's prompts and images (the simplified home shot, the window) brought in
      line with the chosen room
