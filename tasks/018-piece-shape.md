# 018: The pieces' shape and shine, as the 3D reference shows them

Status: done

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

- [x] Pieces in every theme, cropped up close beside the 3D reference and the close-ups,
      show a flat top with a recessed ring and the reference's soft shine
- [x] Checked on the Mac and on the tablet; rendering.md ("Board and pieces", "Light")
      updated to match

## Outcome (2026-11-07)

- **Groove**: `groove()` in the piece shader, radii 0.655 to 0.745, shaded as a concave
  cut (`-dy * sin(2πt)`, smooth to nothing at both edges, so no hard line) with a little
  shade at its floor. Band and face are one color now; the band's tint toward the rim
  color is gone.
- **Outer edge**: the raised `bead()` lit only a thin sliver of the edge and the dark
  line at 96% to 100% hid it. It is now a rounded shoulder from 86% (`shoulder()`): the
  normal turns from up to sideways, lit by a light above the board and toward its top,
  so the upper side carries a soft highlight that peaks halfway round and the lower side
  falls into shade. Dark pieces' highlight is brighter than in `951b546`; no spot on the
  face.
- **Warm shade**: shade mixes toward the color squared (`lit()`), and the light pieces'
  side is the face squared at 92%, which keeps cream warm where black turned it grey.

Compared at 300% to 400% with the autumn and winter close-ups and the 3D reference, in
all four themes at 1920 × 1200 on the Mac and from `adb exec-out screencap` on the
tablet (same layout, same look). The close-ups' rims are wider and rounder than ours,
which is the tyre-like rim set aside before; ours follows the 3D reference.
