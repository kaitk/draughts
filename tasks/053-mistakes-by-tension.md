# 053: Mistakes where the position is tense

Status: todo

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

- [ ] Overlooks scale with tension and a capture's size and distance, tested headless in
      `test/ai/`
- [ ] Self-play numbers before and after: hung pieces per game in quiet and tense
      positions, by level; win rates between skills close to today's, so adapting holds
- [ ] `docs/architecture/ai.md` updated with the rule and the numbers
