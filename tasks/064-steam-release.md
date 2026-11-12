# 064: Release on Steam

Status: todo (low priority, someday; scoped 2026-11-10, not decided)

Draughts on Steam for Windows, macOS, and Linux, free, with full controller support so it
can be Steam Deck Verified. No Steamworks SDK is needed to ship; Steam Cloud's Auto-Cloud
syncs the settings and saved game without it. Rough cost when scoped: two to three weeks
of work, over at least five weeks of calendar for Valve's waits. Valve's rules change;
check each against Steamworks' pages when doing this.

## Valve's waits and fees

- The Steam Direct fee, US$100 per app, paid once (recouped only past US$1,000 of
  revenue, so never for a free game), plus Steamworks' tax, bank, and identity checks.
- At least 30 days from paying the fee to release: pay it first, work while it runs.
- The store page "Coming Soon" for at least two weeks before release.
- Valve's review of the store page and of the build, a few business days each.

## Acceptance criteria

- [ ] `docs/product.md`'s "After the MVP" lists Steam, and `docs/development.md` the
      desktop release builds.
- [ ] The Steamworks account open and the app's fee paid.
- [ ] Store art: the header, small, main, and vertical capsules, the library capsule,
      hero, and logo, at Steam's sizes; at least five 1920 × 1080 screenshots; a trailer
      if it stays cheap. Large images stay local, as Play's do.
- [ ] The store's text from `store/listing-en.md` (and Estonian if Steam offers it) in
      `store/`, with the content survey's answers (no data collected, no ads).
- [ ] Windows: the icon and version info in `draughts.exe`; system requirements name a
      Vulkan GPU, as the app draws through Vulkan.
- [ ] macOS: a `.app` bundle with `Info.plist` and an `.icns` icon, signed with Developer
      ID under the hardened runtime and notarized (the Apple account of task 046).
      Apple silicon only unless Goose ships an x64 macOS release.
- [ ] Linux: a `scripts/linux.py` build that runs in the Steam Runtime (sniper), if Goose
      builds or ships for Linux.
- [ ] Desktop play: the controls a mouse's size (done 2026-11-11, `gui::DESKTOP_DP`) and
      the tile under the mouse lit (task 066); fullscreen by a setting and Alt+Enter (Alt+Enter
      and F11 done 2026-11-12), the window's size remembered,
      a minimum window size, and every screen checked at 1080p, 1440p, and 4K with the
      mouse alone.
- [ ] Controllers: every screen played with a gamepad alone, with a visible focus and
      gamepad glyphs, at the Deck's 1280 × 800 with text readable there (task 072).
- [ ] SteamPipe: one depot per OS and the build scripts in the repo, the upload key or
      login kept out of it; the game installed and played through the Steam client on
      each OS, and on a Deck if one is at hand.
- [ ] Auto-Cloud set to the settings' folder on each OS.
- [ ] Released, and submitted for Deck verification.
