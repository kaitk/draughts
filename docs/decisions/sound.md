# Sound decisions

The decisions behind the app's sounds, dated, with their reasons. How they work now:
[Architecture: Sound](../architecture/sound.md). Task 089 made them.

## Whether, and which

- A few quiet sounds (2026-11-16). The app was silent, chosen for children on touch
  devices; testers found it odd, most of all on a desktop. The rule: a sound tells you
  something happened on the board that you might not have seen. It doesn't reward you,
  and it doesn't echo your own tap. A real board sounds like pieces set down and taken
  off, and nothing else.
- Sounds: a piece set down (yours, the computer's, a friend's), a capture's stops each a
  whole tone above the last, the taken pieces, a crowning, a wrong move, a capture due
  elsewhere, the clock turning gold and red, a puzzle solved, and a game won, lost, or
  drawn (2026-11-16).
- Rejected (2026-11-16): a tick as a piece is picked up (the sound of your own tap); UI
  clicks on buttons, tiles, and scrolling (the plainest bling, and a phone makes its own
  where the user wants them); sounds for the hint and the lookout (help would feel like
  a reward); stars and dots of their own; a tick every second on the clock (it makes a
  player anxious, not careful); music and seasonal ambience (the photographs set the
  mood, and loops grate); voice (lessons may want it, a decision of its own); a buzzer
  for a wrong move.
- One sound a move (2026-11-16): a move's most important event plays in place of the
  others: the game's end, else a crowning, else the taken pieces, else the piece set
  down. The capture's stops before its last keep their rising knocks, and the clock's
  sounds, a wrong move, and a capture due are events of their own. Rejected: the knock
  under the crowning or the end, which doubled them.
- The taken pieces once a capture (2026-11-16). Rejected: a sound per jumped piece, which
  made a long capture too busy; the climbing stops already count it.
- A loss is a plain, warm close, never a sad one (2026-11-16): a four-year-old losing to
  Medium should hear an ending, not a judgment.
- The clock's two sounds for a person's clock only, once each a side a game (2026-11-16):
  never the computer's, and an increment that lifts the time back over a line doesn't
  arm it again. Red is the gold note as ri-tai (short, long), in place of three notes in
  a row. Nothing at the flag: the end's sound says it.
- From the board's and the game's own events, never from input (2026-11-16), so a sound
  lines up with what is seen, whoever moved. Puzzles, How to play, and the settings'
  preview play as a game does.

## How they sound

- Muted, short, and under one another (2026-11-16): the energy under about 1.5 kHz, a
  move about 0.1 s, and every moment mixed well under the move, so the sound heard most
  is the loudest. The notes are on D major's pentatonic scale, so any two that overlap
  sound fine.
- The move and the taken pieces are recordings (2026-11-16): MattyCauldron's "Chess
  Pieces" (Freesound 765866, CC0) for a move and JJTaynos's "Chess Pieces Move (Close)"
  (733927, CC0) for the taken pieces. No credit is owed. Kept by ear: the move's hits 1,
  2, 3, 9, 10, and 11 (the more muted ones) and the take's 2, 4, 5, and 6 (the four least
  like a move), as `tools/sound_hits.py` numbers them. The originals stay local in
  `design/sounds/`; download them from the Freesound pages (a free account) to rebuild.
  Rejected: synthesized knocks, the first of which sounded like an 80s karate game, and
  about 30 other Freesound candidates (chess, crokinole, Scrabble tiles, go stones,
  slides; Stone's alabaster move and a piece's bounce).
- The rest is synthesized (2026-11-16): the crowning a kannel's two plucks up a fifth
  (Karplus-Strong; Estonia's instrument), a wrong move two low felt knocks, a capture due
  the same knocks with the second pitched up, and the clock, the win, and the loss mallet
  notes; a draw the kannel's two low strings. A solved puzzle is three mallet notes up an
  octave low, D4, F sharp, and A (2026-11-16), checked on the Pixel's speaker. Rejected:
  the same notes an octave up (D5), which grated on the Mac, the brightest sound of the
  set and the nearest to a reward's ding; and the kannel's two low plucks, too close to
  the crowning, which a puzzle often plays just before. A solved puzzle and a won game
  are 3 dB under the other moments (2026-11-16): at the moments' level they were a little
  loud on the Mac and the Pixel. Rejected: a marimba
  crowning and a first win that were too much, and the prototype's other takes
  (flute, ocarina, kalimba, tongue drum, temple blocks, music box, a small orchestra,
  a blackbird).
- The sound prototypes removed once the app had the sounds (2026-11-16):
  `prototypes/sound.html` (every candidate playable in a game against a random computer),
  `sound-set.html` (the set and the moments' takes), `sound-codec.html` (the hits as PCM
  and ADPCM), their synthesis `sound.js`, and `tools/sound_samples.py`, which fetched the
  Freesound candidates and cut the originals. Commit 06d8987 is the last that has them.

## Storing and making them

- The hits as IMA ADPCM, 4 bits a sample, mono at 24 kHz (2026-11-16): no difference
  was heard from the original or from 16-bit PCM on headphones, and the ten kept hits
  are 10 KB in git (`assets/sounds/hits.bin`). The decoder is about 20 lines. Rejected:
  Ogg Vorbis and Opus, whose decoders (stb_vorbis about 5,000 lines of C) outweigh the
  audio many times; QOA, worth it only with more recordings; 16-bit PCM, four times the
  size for nothing heard; parameters resynthesized from the recordings, which risks the
  synthetic sound again.
- Everything at 24 kHz, tails cut once inaudible, and made only while the volume is
  above zero (2026-11-16); the device is opened only then and closed at zero, so a phone
  at its default never opens audio, takes no audio focus, and spends no battery on it.
  Measured: 19 sounds, 1503 KB in the mixer (the task's guess was 0.5 to 1 MB; the
  mallet notes' long tails are most of it), made in about 30 ms on the Mac at -O2.
  Rejected: making them at launch, which a phone at its default would pay for nothing.

## The setting

- Off by default on Android and iOS, half on macOS, Windows, and Linux (2026-11-16): a
  tablet is often played in a room with others; a desktop felt broken silent.
- The level belongs to the device, not the player (2026-11-16), kept in `settings.txt`
  beside the language: the speakers are the device's.
- A Sound section between Look and Game with one Volume row (2026-11-16): a speaker tile
  that mutes and unmutes, keeping the level, and a slider whose thumb is a white piece,
  its 88 dp strip the touch area, a move playing on release at the new level. Rejected:
  four tiles (off, and a speaker with one, two, or three arcs), which needed no words
  but gave only three levels.
- The level a gain from -36 dB to 0 dB (2026-11-16), so the slider changes evenly to the
  ear; a linear gain put all the change in its first fifth.
- On iOS the ambient audio session (2026-11-16): the silent switch mutes the app, and the
  player's own music keeps playing under it. On Android the sounds are media, which the
  volume keys govern.
