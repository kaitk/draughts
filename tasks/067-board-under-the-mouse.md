# 067: Light the board under the mouse

Status: todo (before task 064's Steam release)

Task 066 lights the glass tiles under the mouse on a desktop; the board doesn't answer
the pointer until it is pressed. Show what a click would do there, on a desktop only
(`gui::desktop_scale` above 0), flat and 3D: the piece the child may move under the
mouse, and perhaps its targets once one is chosen. Look, fade, and what lights to be
agreed with the user, in the spirit of task 066 (a faint form of an existing state, in
the theme's glow, no motion).

## Acceptance criteria

- [ ] The look agreed and built on the flat and the 3D board, on the Mac, never on
      Android or with `--touch on`.
- [ ] A resting mouse draws nothing, and a move over one square draws nothing new.
- [ ] A test drives the pointer over the board and checks what lights.
- [ ] `docs/architecture/rendering.md` and `docs/decisions/rendering.md` say how and why.
