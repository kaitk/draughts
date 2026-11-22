# 112: Offer a draw and give up

Status: todo

Testers asked for an "offer draw" option and a way to give up. A kings-only ending runs
its rules' count to the end, 25 moves each in International and up to 60 in Russian
and Brazilian, which drags. Start over already cancels a lost game, but it counts for
nothing, so a loss can be dodged and never reaches the rating.

The takes are in `prototypes/game-draw.html` (`?view=offer|no|asked|giveup|lost|drawn|friend`,
`&at=left|right` for where the draw tile goes, `&no=card|a|b` for how a refusal shows, `&ask=panel|card`
for where the computer's offer shows).

## Plan

- **The draw tile** shows while both sides have a king, otherwise not at all.
  - Against the computer, "Offer draw": the computer answers at once from its last search
    score. It accepts when it isn't winning, backed by a check on the material for the
    kings' endings the score misjudges (two kings against one looks won and is a draw).
    A refusal is a card in the middle, as the end's are, over an undimmed board: the
    computer's face and a thumbs down, "No draw", "The computer wants to play on."
    (Estonian "Arvuti tahab edasi mängida."), and Continue alone. The tile
    then stays dim until it can be asked again a few moves later, so tapping until yes
    doesn't work. (The tile answering itself and a line under whose turn were the other
    takes.)
  - In a friend's game, "Draw" ends the game at once with no second player's say. Undo
    takes it back like any other ending. Asking the other player first would be a lot of
    code for a corner case.
- **The computer offers a draw** when its search sees a dead draw with kings on both
  sides: an offer of Draw or Play on, in the play panel or as a card over an undimmed
  board. Play on keeps it from offering again for a while.
- **An agreed draw** ends like a rules draw: the draw's card with "Agreed", ½ for the
  rating, the skill unchanged, a line in the history.
- **Giving up** goes through start over, so there's no new tile: once a game against the
  computer is a few moves in, start over asks "Give up this game?". Give up counts as a
  loss (history, rating, the skill adapts down) and shows the win's card for the
  computer, "White gave up", with back and play again. In the first few moves, and in a
  friend's game, start over stays free as now. This replaces "a game started over before
  it ends doesn't count" (`docs/architecture/ai.md`, "Skill").

## Acceptance criteria

- [ ] The takes chosen in the prototype; the page folded into `game.html` once built
- [ ] The decisions recorded in `docs/decisions/ai.md` (giving up, the computer's
      answer) and `docs/decisions/rules.md` (a draw agreed, with no arbiter's count),
      and `docs/architecture/` updated to match
- [ ] The computer's answer and its own offer as pure functions over the position and
      score, tested headless on kings' endings it must accept or decline
- [ ] The tile, the offer, the give-up card, and the end's cards built, their strings
      in `strings/en.txt` and `strings/et.txt`
- [ ] A game given up and a draw agreed counted once in the results and the rating,
      and not again after undo and a second ending
- [ ] Checked on the Mac and the tablet in both orientations
