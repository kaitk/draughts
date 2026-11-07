# Product

## Purpose

A draughts (kabe) learning app for children of about 5 to 8: play, puzzles, and later
lessons. It runs first on an Android Galaxy tablet, then on the Play Store for free.
Chess may follow on the same base.

## Principles

- Minimal first: ship the smallest thing children use, and grow from how they use it.
- Usable without reading: icons first, legal moves always shown, big touch targets.
- Lean: no engine, no Java/Kotlin of our own, no allocation in the frame loop, no frames
  drawn while idle.

## MVP scope

| Area | Included |
| --- | --- |
| Rules | Russian draughts 8×8, complete ([rules](architecture/rules.md)) |
| Board | Flat 2D, GPU-drawn; legal moves glow, forced captures pulse, multi-jumps animate; tap to move |
| Play | Pass-and-play; vs computer at 3 levels |
| Puzzles | About 30 in 3 tiers: find the capture; multi-jumps and crowning; shots and "the only safe move" |
| Controls | Undo, hint, restart |
| Language | English, from a string table; the font has Estonian letters |
| Platforms | Android APK sideloaded onto the tablet; macOS for development |

## After the MVP, in order

1. **International 10×10.** The engine has it from the MVP; this adds the board layout,
   puzzles, and AI tuning.
2. **Learning.** Lessons on mini-boards (4×4, 6×6), one rule each, with icons and voice;
   100+ puzzles; endgame drills (2 kings vs 1, Petrov's triangle); two child profiles
   with stars; sound; Estonian.
3. **Looks.** A 3D board from the same game state, and the glass UI from the prototypes
   and design boards.
4. **Release.** Play Store under Google's Families Policy: no ads or tracking, a privacy
   policy. English checkers as a rules toggle. Before the first upload: the final app id
   (`com.kaitk.kabe` is a placeholder in `android/AndroidManifest.xml`), an icon, a release
   signing key kept outside the repo, an app bundle (AAB) if Play requires one over an
   APK, and the target SDK Play asks for then.
5. **Chess**, reusing the platform, rendering, UI, puzzle, and lesson layers.
6. **A NoGraphicsAPI version** through goose-ngfx, for desktop and Apple devices.

## Not planned

Online play, accounts, ads, in-app purchases, analytics.
