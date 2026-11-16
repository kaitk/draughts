# Sound

The app makes a few quiet sounds: a piece set down, a capture's stops and its taken
pieces, a crowning, a wrong move, a capture due elsewhere, the clock's two warnings, a
puzzle solved, and a game's end. Why these and no others:
[decisions](../decisions/sound.md).

Three parts, one way round:

1. **The board and the game say what happened** (`src/board/sound_event.goose`, namespace
   `sound_event`). No audio here, so it stays testable headless.
2. **The shell gathers it** once a frame, one sound a move (`shell::gather_sound_events`).
3. **The app plays it** through the sound bank (`src/sound/`, namespace `sound`), over
   goose_gfx's mixer (`audio`).

## Sound events

A board keeps `Board.sound_events`, a fixed list of at most eight `sound_event::Event`s
(a kind and a step). The board adds them as its animation gets there, not at the tap, so
a sound lines up with what is seen, whoever moved:

- `board::add_sound_events`, at the top of each update, adds a `STOP` for each of a
  capture's stops the animation has reached (its `step` the stops before it), then the
  last landing: `CROWN`, `TAKE`, or `MOVE` (`sound_event::landing`), or `Board.finale`
  in its place (a puzzle's `SOLVED`). `Board.stops_sounded` counts what is already said.
- A hop landed by hand, or a dropped stop, says its `STOP` at once.
- A wrong move says `WRONG` as the piece slides back; a piece or square chosen while
  another must capture says `MUST`.
- The game adds `DRAWN`, `WON`, or `LOST` (lost only to the computer) as its end begins,
  and the clock's `GOLD` (under a minute) and `RED` (0:20) through `sound_event::chime`:
  once each a side a game (`Game.chimes`), for a person's clock only.

`shell::gather_sound_events`, at the end of `shell::frame`, copies the game's, the
puzzle's, and How to play's events into `Frame.sound_events`, adds a `MOVE` when the
volume was just set (`Settings.play_sample`), clears every board's list (the preview's,
home's, and the replay's too, which play nothing), and keeps one sound a move
(`sound_event::one_per_move`): of the events that end a move, the most important stays
(the end, then a crowning, then the taken pieces, then the piece set down). Stops, wrong
moves, and the clock always stay.

## The bank

`sound::Bank` holds the mixer's sounds in a fixed table. `sound::set_level(bank, level,
muted)` sets the gain, -36 dB to 0 dB along the slider (`sound::gain_of`); the first time
it is above zero it opens the device (`audio::open` at 24 kHz) and makes every sound; at
zero it closes the device and frees them (`sound::close`). Nothing is made, and the
device stays closed, while the volume is zero, so a phone at its default never opens
audio.

The sounds, all mono at 24 kHz, each with its gain against the move baked in, so the
volume is one gain for all:

| Kind | Made from | Length |
| --- | --- | --- |
| `MOVE` | One of six recorded hits at random, never the same twice running; a capture's stop a whole tone up a step (the mixer's pitch) | about 110 ms |
| `TAKE` | One of four recorded hits, the same way | about 100 ms |
| `CROWN` | A kannel's two plucks up a fifth (`pluck`, Karplus-Strong) | 1.6 s |
| `WRONG`, `MUST` | Two low felt knocks (`knock`, modal), the second lower, or higher for `MUST` | 0.2 s |
| `GOLD`, `RED` | A mallet note (`note`), and the same as ri-tai, short then long (`ritai`) | 1.5 s |
| `SOLVED` | Three mallet notes up, low (D4, F sharp, A), 3 dB under the other moments | 2.5 s |
| `WON` | Three mallet notes up (D4, A, D5), 3 dB under the other moments | 2.4 s |
| `LOST` | Two low notes together | 3.0 s |
| `DRAWN` | The kannel's two low strings | 2.4 s |

Every sound's tail is cut once it stays under -54 dBFS (`trim`), with a 10 ms fade.
All 19 come to 1503 KB of the mixer's `f32` and are made in about 30 ms on the Mac.
`sound::play(bank, kind, step)` is one call to `audio::play`; the voices are the
mixer's, so nothing allocates in the frame loop.

### The recorded hits

`tools/sound_hits.py` cuts the kept hits from the two recordings in `design/sounds/`
(local; [decisions](../decisions/sound.md#how-they-sound) says where to get them), brings
them down to 24 kHz, encodes them as IMA ADPCM, and writes `assets/sounds/hits.bin`
(10 KB), which `src/sound/hits.goose` embeds. The file: the move's and the take's hit
counts (u16 each), then each hit's sample count (u32) and its 4-bit codes, two a byte,
the first in the low nibble; each hit starts from predictor 0 and step index 0. The tool
also writes what `test/sound/adpcm` must print, so the decoder is checked against the
encoder.

## The app

`app::play_sounds`, after the frame's settings are saved, calls `sound::set_level` when
the volume or the mute changed and plays `Frame.sound_events`, a `STOP` as a `MOVE` at
its step. At launch a desktop's default volume is set to half
(`settings::default_volume`), and on iOS the ambient audio session is asked for before
audio opens (`src/app/sound.c`, `SDL_AUDIO_CATEGORY`), so the silent switch mutes the app
and the player's music keeps playing.

## The setting

Settings' Sound section, between Look and Game, has one Volume row
(`settings::volume_row`): a speaker tile and a slider (`gui::slider`) whose thumb is a
white piece drawn over the UI (`settings::put_in_list`, which fades it out with the
list's edge). The speaker shows the level by its arcs; a tap mutes and unmutes, keeping
the level, or at zero brings the sound back at half. Dragging the slider redraws the row
but writes nothing; on release the level is written and a move plays at it. While a
slider is held the list doesn't scroll (`Gui.sliding`). Left and Right step it by a
tenth when it has the keys' focus.

The level is the device's: `settings.txt` keeps `volume = N` (a percent) once it was
changed and `sound = off` while muted (`players::write_device`), and a player switch
keeps them.

## Tests

- `test/sound/bank`: every sound made into an offline mixer (`audio::open_offline`),
  played alone, and rendered to its end: heard, finite, as long as its table says; a
  move's and a take's hits each their own, never the same twice running; closed at zero.
- `test/sound/adpcm`: the embedded hits decoded, checked against the tool's checksums.
- `test/board/sound_event`: what the board says for moves, captures by hand and by
  playing, crowning, wrong moves, and a capture due; one sound a move; the clock's
  warnings once a side.
- `test/shell/settings`: the Volume row's speaker, the slider dragged and released, and
  the device's keys in `settings.txt`.
