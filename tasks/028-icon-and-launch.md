# 028: The app icon and the launch screen

Status: todo (the user is making the images from `~/Downloads/draughts-store/prompts.md`)

The app has no icon and no resources: the APK's manifest has a literal label and the
platform's theme (`android/AndroidManifest.xml`), so the launcher shows Android's
default, and launch shows a blank screen before the first frame. Android first; Apple
where it costs nothing extra now, since the release is Android first (task 029).

The prompts, what each store needs, and the store screenshots are in
`~/Downloads/draughts-store/` (`README.md`, `prompts.md`), outside the repo on purpose.
The user runs the prompts through ChatGPT and picks a take, then asks for the layers and
the monochrome silhouette (the prompts' follow-ups).

## Work

- **Android icon:** an adaptive icon (`mipmap-anydpi-v26`): foreground and background
  layers at 108 dp (432 px at xxxhdpi down to 108 px at mdpi), with what matters inside
  the central 66 dp; a monochrome layer for Android 13's themed icons; legacy mipmaps at
  48 to 192 px for older launchers. The pieces in the foreground, a flat color or the
  plain background layer behind.
- **Launch screen:** Android 12+'s system splash, the icon on
  `windowSplashScreenBackground` set to the icon's background color, held until the app
  draws its first frame. An app theme of our own replaces `Theme.NoTitleBar.Fullscreen`,
  keeping the fullscreen window.
- **The build:** `scripts/android.py` gains a `res/` folder compiled with `aapt2
  compile` and linked with the manifest; the APK's size before and after recorded.
- **Play icon:** 512 × 512, 32-bit PNG, for the listing (task 029).
- **Apple, for later:** one 1024 × 1024 opaque PNG, its dark and tinted variants from the
  same layers, and a launch screen that is a background color only (`UILaunchScreen`).
  Kept with the masters until an iOS build exists.
- **Where the images live:** images don't go in git without the user's OK. The icon's
  PNGs are small and the APK needs them; ask whether they go in `android/res/` or stay
  local and are copied in at build time, as the background masters are.

## Acceptance criteria

- [ ] The launcher shows the icon on the tablet, round and squircle masks both clean,
      and the themed (monochrome) icon when Android's themed icons are on
- [ ] Launch shows the icon on its background color, then the app, with no white or
      black flash between them
- [ ] Recognizable at 48 px
- [ ] The APK's size recorded before and after
- [ ] The 512 × 512 Play icon and the Apple 1024 × 1024 exported from the same master
