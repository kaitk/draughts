# 07: One-glance captures and International 32

Status: todo

- Russian's library has puzzles where only one capture takes the N the goal names, so the
  goal gives the answer away; 25 are rated 500 or more (18 at 800 and up), International
  and Brazilian one each. Rate them as the easiest band, or drop them, and make `rate`
  see it for new ones.
- International's course puzzle 32 (Captures level 1) is now a single legal move: its
  second double was moved on 2026-11-09 to remove a rival, which removed the choice too.
  Make it a choice again (a second capture that is taken back) without the rival.

## Acceptance criteria

- [ ] No one-glance capture rated at 500 or more; `rate` keeps new ones low
- [ ] International 32 has a real choice and passes `build/puzzles` and the kings check
