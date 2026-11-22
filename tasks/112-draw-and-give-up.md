# 112: Offer a draw and give up

Status: in progress

Testers asked for an "offer draw" option and a way to give up. A kings-only ending runs
its rules' count to the end, 25 moves each in International and up to 60 in Russian
and Brazilian, which drags. Start over already cancels a lost game, but it counts for
nothing, so a loss can be dodged and never reaches the rating.

The chosen takes are folded into `prototypes/game.html` (`?view=kings|no|asked|giveup|lost|drawn`,
`&friend=1`); the page of takes, `game-draw.html`, is in git history (`git log -- prototypes/game-draw.html`).

## Plan

- **The draw tile** shows while both sides have a king, otherwise not at all, with start
  over (in portrait the bar's fourth tile).
  - Against the computer, "Offer draw": the computer answers at once from its last search
    score. It accepts when it isn't winning, backed by a check on the material for the
    kings' endings the score misjudges (two kings against one looks won and is a draw).
    A refusal is a card in the middle, as the end's are, over an undimmed board: the
    handshake crossed out, "No draw", "The computer wants to play on."
    (Estonian "Arvuti tahab edasi mängida.") with the computer's icon in place of "The
    computer" (`refused.note = @ wants to play on.`, a marker each language puts where
    its grammar wants; a small `gui` helper lays the text and `glyph_icon` out on one
    line, and the draw card's `note_break` counts the icon as a word), and Continue
    alone. The tile
    then stays dim for 5 moves before it can be asked again, so tapping until yes
    doesn't work. (The tile answering itself and a line under whose turn were the other
    takes.)
  - In a friend's game, "Draw" ends the game at once with no second player's say. Undo
    takes it back like any other ending. Asking the other player first would be a lot of
    code for a corner case.
- **The computer offers a draw** when its search sees a dead draw with kings on both
  sides: a card in the middle over an undimmed board, as the refusal's, with Draw or Play
  on. It offers once a game: Play on says the player wants to win, so it never asks again
  (the player can still offer).
- **An agreed draw** ends like a rules draw: the draw's card with "Agreed", ½ for the
  rating, the skill unchanged, a line in the history.
- **Giving up** goes through start over, so there's no new tile: from the child's 5th move in
  a game against the computer, start over asks "Give up this game?". Give up counts as a
  loss (history, rating, the skill adapts down) and shows the win's card for the
  computer, "White gave up", with back and play again. Before that, and in a friend's
  game, start over stays free as now. This replaces "a game started over before
  it ends doesn't count" (`docs/architecture/ai.md`, "Skill").

## Acceptance criteria

- [x] The takes chosen in the prototype (2026-11-22): the tile with start over, the
      refusal and the computer's offer as cards in the middle, the crossed handshake,
      the computer's icon in the refusal's line
- [x] The page folded into `game.html` once built
- [x] The decisions recorded in `docs/decisions/ai.md` (giving up, the computer's
      answer) and `docs/decisions/rules.md` (a draw agreed, with no arbiter's count),
      and `docs/architecture/` updated to match
- [x] The computer's answer and its own offer as pure functions over the position and
      score, tested headless on kings' endings it must accept or decline
- [x] The tile, the offer, the give-up card, and the end's cards built, their strings
      in `strings/en.txt` and `strings/et.txt`
- [x] A game given up and a draw agreed counted once in the results and the rating,
      and not again after undo and a second ending
- [ ] Checked on the Mac and the tablet in both orientations

## Built (2026-11-22)

- `src/ai/offer.goose`: `offer::dead_draw`, `accepts_draw` (declines from half a man
  ahead), `offers_draw` (a dead draw, or only kings within a fifth of a man);
  `test/ai/offer.goose` in each draughts. The game keeps `Game.ended_by`, the refusal's
  ply, the offer, and the last score, saved with it (`shell::Saved` version 5, 4 and 3
  read). `test/shell/draw_offer.goose` drives it through the shell: the rating, skill,
  and history count an agreed draw and a give-up once, not again after undo.
- The way out with the draw tile: two over two in landscape (touch and desktop alike, in
  the column's room, so nothing under it moves), the bar's fourth in portrait, an icon
  after back in the compact bar. `test/shell/sizes` lays out the tile, the three middle
  cards, and the given-up card at every size in both languages: all in place.
- `--card refused|offer|give-up|gave-up|agreed` shoots the cards.
- Checked on the Mac (2026-11-22), flat and 3D: the tile at 2560×1600 desktop, 1920×1200
  tablet landscape, 1200×1920 portrait, and narrow windows; every card in English
  landscape and Estonian portrait. Words shrink a face to fit in a few half-width tiles:
  "Alusta uuesti" beside "Paku viiki" in landscape, "Offer draw" in a 1100×700 window,
  "Mängin edasi" on the give-up card in portrait. The compact bar's icon wasn't reached
  on the Mac (the window doesn't go that small).

