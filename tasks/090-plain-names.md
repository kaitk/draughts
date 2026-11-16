# 090: Plain names

Status: todo

Some of the code's most-used names are single figurative English words (`deaf`, `took`,
`settle`, `quiet`) or one word doing several unrelated jobs (`over` means three things).
A programmer reading English as a second language, a Finnish or an Estonian one, has to
read the body to know what such a name means. Task 089's sound names went through this
on 2026-11-16 (`heard` became `sound_event`, three `hear` functions became
`add_sound_events`, `gather_sound_events`, and `play_sounds`); this task does the same
for the rest of `src/`.

The bar: a name says literally what the thing is or does, in plain compound words, and no
name means two different things in the code. Terms of the trade stay (`lerp`, `quad`,
`uv`, `rig` for a camera rig), and so do the app's own feature names (`lookout`, `glass`).

## The review (2026-11-16)

A read-only pass over `src/` (not `src/sound/` or `board/sound_event.goose`), counting
only names with about five uses or more, a namespace, or a field of a core struct. Uses
are grep counts (call sites, or a field's reads and writes); the proposed names are
starting points, to be chosen when each is renamed.

| # | Name (where it is defined) | Uses | What it does | Why it stumbles | Proposed |
|---|---|---|---|---|---|
| 1 | `over`: `Event.over` game.goose:38, `Board.over` board.goose:181, `over: board::Overlay` params and fields (`Frame.over`, shell.goose:84) | ~36 | Three things: any game ended (for the history); the square under the pointer; the pieces drawn over the UI | One short word with three unrelated meanings | `ended_for_history`, `target_under_pointer`, `overlay` |
| 2 | `Game.counted` game.goose:71, `Game.kept` game.goose:110 (and `Board.counted` board.goose:135) | ~14 / ~6 | The game's end was sent to the shell (for the rating; for the history). The board's: the counts shown after a mistake | Neither word says "end reported", and the two are easy to swap | `end_sent_for_rating`, `end_sent_for_history`, `counts_shown_after_mistake` |
| 3 | `Board.quiet` board.goose:134 | 12 | Hides the counts while the computer moves | In draughts a "quiet move" is a non-capture, and `rules` uses it that way | `hide_counts` |
| 4 | `Gui.took` gui.goose:260, `gui::take` gui.goose:758 | 14 + 5 | The press landed on the UI, not the board | "take" and "took" as an idiom for claiming the press | `press_on_ui`, `claim_press` |
| 5 | `Gui.deaf` gui.goose:296, `gui::listen` gui.goose:652 | 9 + 9 | Turns the pointer off or on for the controls declared after it | A body metaphor | `input_off`, `set_input_enabled` |
| 6 | `gui::hold` gui.goose:795, `hold_if` gui.goose:823 | 24 + 6 | The plain button: clicked, and how far it is pressed | Reads as press-and-hold, and a real `hold_tile` exists | `button`, `button_if_on` |
| 7 | `settle`: rig.goose:161, panel.goose:412, replay.goose:217 | 5 / 6 / ~3 | Eases the camera back to rest; fits the 3D view into the layout; sets the board to a move's position | Figurative, and a different job in each place | `ease_to_rest`, `fit_view`, `show_position_at_move` |
| 8 | `rest`: `panel::rest` panel.goose:395 and `Layout.rest`; `render::rest` render.goose:92 | 5+ / 2 | Stores the resting view; releases the 3D targets at the frame's end | One word for two different jobs | `set_rest_view`, `release_targets_unless_shown` |
| 9 | `aim`: panel.goose:462, ending.goose:40 | 3 / 1 | Applies the rig's camera to the layout; starts the win's glow | One word for two different jobs | `apply_camera`, `start_win_glow` |
| 10 | `turned`: view3d.goose:98, shell.goose:1067, replay.goose:281 | ~5 | A view rotated by the camera; whether the board is flipped for black | One word for two different jobs | `with_camera_turn`, `board_flipped` |
| 11 | `shown` / `shows`: shell.goose:1102, clock.goose:64, `Board.shows` board.goose:174, `Game.shown` game.goose:56 | ~25 | The board on screen; the whole seconds to show; a count of positions shown; the seconds last drawn | One word for four different jobs | `board_on_screen`, `whole_seconds`, `position_count`, `clock_seconds_drawn` |
| 12 | `Game.seen` game.goose:55, `Game.still` / `stilled` game.goose:59-60, `Board.still` / `held` board.goose:179-180 | 21 / 10 / 24 | When the clock last counted; when the win's animation stops moving; the pulsing rings drawn without moving | Short past participles that hide what they refer to | `clock_counted_at`, `win_still_from`, `win_still_drawn`, `static_picture`, `rings_frozen` |
| 13 | `Game.asking` / `asks` / `answered` / `trapping` / `judging` game.goose:65-109 | 18 / 8 / 5 / 9 / 12 | The ids and counts of the requests to the computer's worker thread | They don't say they are request ids | `ai_request_id`, `ai_request_count`, `ai_answered`, `trap_request_id`, `judge_request_id` |
| 14 | `judge`: tutorial.goose:180 and puzzle.goose:172, against `ai::judge` judge.goose:151 (and the bool `Game.judge`) | ~6 | Handles the player's move on the board, against grading a move's quality | One word for two different jobs | `handle_player_move`; keep `ai::judge`; `judge_moves` |
| 15 | `gui::face` gui.goose:886, against `Gui.faces` (the fonts) | 6 | Draws a player's animal badge | "face" is the font face everywhere else in `gui` | `player_badge` |
| 16 | `Game.look` / `watched` game.goose:78-80, `Event.looked` game.goose:37 | ~10 | The lookout on or off; its cached threats; it was toggled | `look` is the themes' word too | `lookout_on`, `lookout_cache`, `lookout_toggled` |
| 17 | `board::waiting` board.goose:447, against `gui::waiting` gui.goose:877 | 20 / 1 | The square a piece stops on partway through a capture; the 3D board's loading text | Vague, and the two mean different things | `capture_stop_square`, `loading_text` |
| 18 | `Shell.staged` / `went` / `came` / `left` shell.goose:138, 166-168 | 4 / 10 / 12 / ~5 | Home shows the setup's board; the transition's from and to layouts and views; the setup that was left | Prose words, and "left" is also the side | `showing_setup_board`, `from_layout` / `to_layout`, `from_view` / `to_view`, `setup_left` |
| 19 | `Board.again` board.goose:129, `Board.kept_at` board.goose:132 | 9 / 11 | A press on the selected piece that puts it down on release; when the next stops started pulsing | Can't be guessed | `release_deselects`, `next_stops_pulse_at` |
| 20 | `gui::tap()` gui.goose:469, `stacked()` gui.goose:475, `side()` gui.goose:482 | 138 / 12 / 10 | Sizes: the least tap, a stacked tile's height, the room beside words | They read as verbs or adjectives, not sizes | `tap_size`, `stacked_tile_height`, `word_padding` |
| 21 | `gui::fitting` gui.goose:1208 | 40 | The largest face the text fits in | An adjective alone | `face_that_fits` |
| 22 | `fill`: `gui::fill` gui.goose:774, against `board::fill`, `view3d::fill`, `shell::fill` | 30 / 4 | Draws a rounded rect, against building the frame's pieces | One word for two different jobs | `rounded_rect`; `build_frame_pieces` |
| 23 | `who` namespace, who.goose:19 | 18 | The players' card and sheet | A pronoun as a name | `player_card` |
| 24 | `put`: game.goose:719, shell.goose:893 | ~6 | Draws a piece over the UI | Too general | `overlay_piece` |
| 25 | `panel::Layout.three` panel.goose:122, `gui::bleed` gui.goose:515, `gui::prefer` focus.goose:234 | 19 / 8 / 6 | The board is 3D; a rect stretched to the screen's edges; a control marked as the main one | Clipped, or a trade's jargon (print's bleed) | `is_3d`, `extend_to_screen_edge`, `mark_primary` |

Judged fine in the review: `glass`, `gui::panel`, `rig`, `looks`, `think`, `lookout` (a
feature's name), `notes`, `sheet`, `cut_top` / `cut_left`, `hover`, `moving`, `go_to`,
`board_of`, `ended`, `drawn`, `winner`, `must_capture`, `ghost`, `glow`, `hint_*`,
`by_hand`, `spot_of`, `labelled`, `pick`, `Settings.volume` / `muted` / `variant` /
`level`.

Not counted: `settings::put_in_list` (task 089) calls `game::put`, which row 24 renames.

## How

- The user picks the rows and the names first; then one commit per area (gui, board and
  game, shell, app), the full suite passing between them.
- A rename that touches the docs (`docs/architecture/`, the "from above" page's
  `where` lines) updates them in the same commit.
- A grep for each old name before and after, so none is left in code, tests, or docs.

## Acceptance criteria

- [ ] The rows to rename chosen, with their names
- [ ] Renamed, area by area, the tests passing after each
- [ ] No old name left in `src/`, `test/`, `tools/`, or `docs/`
- [ ] `agents/goose.md` (or `agents/writing.md`) states the naming bar, so new code keeps it
