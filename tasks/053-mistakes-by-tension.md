# 053: Mistakes where the position is tense

Status: done

Easy and medium should err where a person does: more where captures are around (a long
multi-capture, a capture away from the piece just moved), less in a quiet position, where
an obvious blunder looks like a machine (the user, 2026-11-09). Prior art, all chess:
Guid and Bratko (2006, 2011) found every strength errs more in complex positions;
Regan and Haworth's model, which `ai/` already uses for choosing, shows the same; Maia
(McIlroy-Young et al., 2020) predicts human blunders from the position, tactics among the
strongest signals.

Today easy's overlooks (`docs/architecture/ai.md`, "How each part plays like a person",
point 2) have a flat chance by skill, fading to none by 15; medium never overlooks.

## Plan

- The overlook chance scaled by the position: low with no capture within the level's
  view, higher where `pace::tense` holds (or a measure from the search).
- A capture is overlooked more the more pieces it takes and the further it starts from
  the piece just moved; a one-piece capture next to it almost never.
- Medium gets a small share: never a one-piece reply, now and then a long multi-capture.
- Seeded and integer as now, so every machine agrees.

## Acceptance criteria

- [x] Overlooks scale with tension and a capture's size and distance, tested headless in
      `test/ai/`
- [x] Self-play numbers before and after: hung pieces per game in quiet and tense
      positions, by level; win rates between skills close to today's, so adapting holds
- [x] `docs/architecture/ai.md` updated with the rule and the numbers

## Outcome

Built as planned (`ai::overlooked`, `ai::notice`; the rule in `docs/architecture/ai.md`,
"How each part plays like a person", point 2). Each of the child's captures after each
of the computer's moves is overlooked by its own seeded chance: by its pieces 25, 160,
300, 450 per thousand at skill 0 for 1, 2, 3, 4+, each fading with the square of the
way to its sure skill (15, 25, 65, 65); times 1 to 2 by its distance from the moved
piece; a tenth of that where no capture was around before the move. Tension is the
root's half of `pace::tense` (must capture, or the other side could): the move's half is
what the capture after it already is.

Numbers (`build/aimatch V A B 400 --hangs`, tables in `docs/architecture/ai.md`): skill
0's hanging moves per 100 games went from 36 quiet and 12 tense to 6 and 32 in Russian,
72 and 22 to 10 and 79 in International, 34 and 15 to 6 and 33 in Brazilian; medium
(40) now hangs 1 to 12 times per 100 games, all but a few in tense positions, to captures of
three pieces or more. Easy at 0 scores about as before against skills 0 and 10 without
overlooks (0.35 as before in Russian, 0.30 to 0.28 International, 0.35 to 0.34 Brazilian
against 10). Fifteen points win 80 to 97% at the bottom of the scale (85 to 99 before)
and 63 to 75% from 25 to 40 (62 to 69 before), so adapting's steps hold.
