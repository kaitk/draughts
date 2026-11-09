# 044: A plain background

Status: todo

A background without a photograph, as a choice in settings' Background row beside the
seasons and by the date (the user, 2026-11-09). On the Galaxy A33 a build without the
photographs showed the page color under the 3D board's blur and grading, a dark-to-brown
fade, and the user liked it. Its colors should suit the board it frames: each season's
board (its wood or stone, the flat board's squares) gets a plain gradient picked to match
it, rather than one brown for all.

Also lighter: no photograph decoded or uploaded, and the 3D board's backdrop has no blur
or harmonics to make, so its first switch is shorter.

## Acceptance criteria

- [ ] A Plain tile in the Background row, its thumbnail the gradient, kept in the
      player's file
- [ ] A gradient per season's board, checked beside each board flat and 3D, in a
      prototype first (`prototypes/`)
- [ ] With Plain chosen, no photograph is decoded or held (memory measured)

## Prototype

`prototypes/plain.html` (2026-11-09). The season still picks the board, so plain is an
on/off of its own beside the Background row rather than a sixth tile: a, a Picture row
(photo or plain); b, a two-part switch under the row's name; c, one Plain tile at the
row's end. Two takes on the fade per board (`&grad=`): a, what the 3D backdrop's grade
makes of the page color with no photograph (the A33 build's look), pale low down; b,
darker, the page to a deep tone of the frame with a faint light of the dark square in
the middle. Awaiting the choice of place and fade.
