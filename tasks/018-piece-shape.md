# 018: The pieces' shape and shine, as the 3D reference shows them

Status: todo

The 2D pieces (`app/draw.goose`, the piece fragment shader) should read like the 3D
reference (`agents/design.md`: `ChatGPT Image Nov 7, 2026, 08_19_31 PM.png`, and the
autumn and winter close-ups) seen from above. As of commit `951b546` they don't yet
(2026-11-07):

- **Shape**: the top is almost flat, with a **recessed** ring, a groove cut into it at
  about 70% of the radius. The shader draws that ring as a raised ridge: it uses the
  same `bead()` as the rounded outer edge, lit on its upper side. A groove is concave,
  so its light is the other way round: on the top half of the ring the wall facing down
  (nearer the center) is lit and the far wall is in shade. Flip the sign for the groove,
  keep it narrow, and keep the band and the face at one height and one color.
- **Shine**: `951b546` made the pieces too matte; the commit before (`bc42d05`, wide
  rim, gloss) was a little too shiny. Aim between: a soft highlight on the rounded outer
  edge's upper side, clearer on dark pieces than now, with no glossy spot on the face.

## Acceptance criteria

- [ ] Pieces in every theme, cropped up close beside the 3D reference and the close-ups,
      show a flat top with a recessed ring and the reference's soft shine
- [ ] Checked on the Mac and on the tablet; rendering.md ("Board and pieces", "Light")
      updated to match
