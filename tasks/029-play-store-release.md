# 029: Release on Google Play

Status: in-progress (the package and the drafts ready, 2026-11-08; the listing's first
screenshots and feature graphic, 2026-11-09; the identity, the Play account, and the
checks on the tablet remain)

Everything between a sideloaded APK and the app on Google Play, under Google's Families
Policy: the app is for children, with no ads, no tracking, no accounts, and no network
(`docs/product.md`, "After the MVP": release). Android first; the App Store is not
planned yet. Things Play requires change yearly: check each against Play's current
documentation when doing this, not this list.

## Done (2026-11-08)

- **Identity:** the application id is `io.github.kaitk.draughts` (chosen 2026-11-08),
  `APP_ID` in `scripts/android.py`, the one place it is set: aapt2's
  `--rename-manifest-package` gives it to the app. The Java code moved to the package of
  the same name, so `adb shell am start -n io.github.kaitk.draughts/.DraughtsActivity`
  works; `scripts/idle_cpu.sh` and `scripts/lifecycle_memory.sh` read the id and the
  activity from `android.py`. `versionCode` 1 and `versionName` 0.1.0 are `VERSION_CODE`
  and `VERSION_NAME` beside it, no longer in the manifest. On the tablet this is a new
  app beside the old `com.kaitk.draughts`, with its own (empty) settings and game:
  uninstall the old one (`adb uninstall com.kaitk.draughts`).
- **Target SDK:** 36 already. Play requires new apps and updates to target Android 16
  (API 36) from 2026-08-31
  ([developer.android.com/google/play/requirements/target-sdk](https://developer.android.com/google/play/requirements/target-sdk),
  read 2026-11-08). Closed testing: a personal account created after 2023-11-13 needs at
  least 12 testers opted in for the 14 days before applying for production
  ([Play Console Help 14151465](https://support.google.com/googleplay/android-developer/answer/14151465),
  read 2026-11-08).
- **Signing:** an upload key at `~/.config/draughts/upload-key.jks` (PKCS12, alias
  `upload`, RSA 4096, `CN=Draughts`, valid to 2054-03-26, certificate SHA-256
  `C4:F6:7B:CD:…:1D:6F:4B`), its random password in
  `~/.config/draughts/upload-key.properties` (mode 600, the folder 700). Neither is in
  git. `scripts/android.py --release` signs with it, debug builds with the debug key.
  How to back it up is in `docs/development.md`, "The upload key".
- **The bundle:** `scripts/android.py app/draughts.goose --release` builds
  `build/android/draughts/draughts-release.apk` and `draughts-release.aab` beside the
  debug `draughts.apk`. bundletool 1.18.3 (pinned by version and SHA-256, downloaded into
  `build/` if missing) builds the AAB from a base module of aapt2's `--proto-format`
  output, the dex, and the arm64-v8a libraries, with `PAGE_ALIGNMENT_16K`; jarsigner signs
  it, `bundletool validate` passes. The script checks every library's ELF `LOAD`
  segments are aligned to 16 KB, and `zipalign -c -P 16` passes on the release APK and on
  the arm64 split bundletool makes from the AAB for a device like the tablet.
- **The icon:** winter again (`SHIPPED = "winter"`, `icon_background` #06172b); the
  foreground PNGs are byte-identical to winter's before autumn shipped.
- **Drafts** in `store/`: the listing in English and Estonian, the privacy policy page in
  both, and the answers for Data safety, ads, IARC, target audience and the Families
  Policy, and the store settings (`store/README.md`).

The release build, once (2026-11-08, the tree of `e1f9f09`, with the photographs' ASTC
masters present):

| | Bytes |
| --- | --- |
| `draughts-release.apk` | 11,449,560 |
| `draughts-release.aab` | 9,107,572 |
| `libmain.so`, stored, stripped | 9,160,784 (7,485,760 of it the four ASTC photographs) |
| `libSDL3.so`, stored, stripped | 1,931,888 |
| `classes.dex` | 97,116 |

- `apksigner verify --print-certs`: v3 scheme verified, one signer, `CN=Draughts`, the
  upload key's SHA-256. `jarsigner -verify` on the AAB: "jar verified", signer `CN=Draughts`
  with the same SHA-256 (its warnings are those of any self-signed key: no chain, no
  timestamp).
- `aapt2 dump badging`: `io.github.kaitk.draughts`, versionCode 1, versionName 0.1.0,
  targetSdkVersion 36, native-code arm64-v8a, launchable `DraughtsActivity` labelled
  "Draughts"; `aapt2 dump permissions`: none.
- `test/run_tests.py` and `--build`: 40 of 40 each.
- Not yet on a device: the main session checks the release APK on the tablet.

## What remains for the user

- **Identity:** the developer name (`{DEVELOPER}`, likely "Gideonic") and contact email
  (`{CONTACT_EMAIL}`) for Play and the drafts; confirm the privacy policy's URL,
  `https://kaitk.github.io/draughts/privacy`, and publish `store/privacy/index.html` there
  (`store/README.md`). Never the Snowhound name, domain, or email.
- **Back up the upload key** before the first upload: both files in
  `~/.config/draughts/`, as `docs/development.md` says.
- **Decide `allowBackup`:** on now, so Android's own backup may carry a child's progress
  to a new tablet; the Data safety answers count that as not collected
  (`store/play-console.md`). Off removes the question.
- **Play Console:** the developer account (a personal account: identity check, then the
  closed test above), the app's entry, the listing pasted from `store/`, the 512 px icon
  (`~/Downloads/draughts-store/icon/play-512.png`, winter), the 1024 × 500 feature
  graphic, and the screenshots (both below), then the App content forms from
  `store/play-console.md`, and Play App Signing (Google-generated app key) at the first
  upload of `draughts-release.aab`.
- **Read the drafts:** the listing (rewritten for task 037's puzzles and task 038's
  players), the Estonian especially, and the policy, which now names players and their
  optional names.
- **Pick or redo the images:** the feature graphic is a first draft; say whether the
  screenshots' choice of scenes and the made-up player (Mia the fox) will do, and
  whether the Estonian listing gets a full Estonian set.

## The listing's images, first iteration (2026-11-09)

- **Texts:** `store/listing-en.md` and `listing-et.md` describe the 64 puzzles in five
  themes (the library, black to move in some, Learn opening the rest, the stars) and the
  players (four, badge, name, each keeping their look, stars, computer level, and game);
  English 74 and 2,218 characters, Estonian 64 and 2,284. `store/privacy/index.html` and
  `store/play-console.md` said the app had no names to enter; they now say a player's
  optional name stays on the device.
- **Play's rules** (read 2026-11-09, in `store/README.md`): tablet screenshots must be
  16:9 or 9:16, so the tablet's own 16:10 doesn't fit its slots; the tablet set is shot
  at 2560 × 1440, and a 2560 × 1600 set is kept beside it.
- **Screenshots** in `~/Downloads/draughts-store/screenshots/play-0.1/`: `tablet/`
  (2560 × 1440), `phone/` (1080 × 1920 at 548 dp), `tablet-16x10/`, six each: home, a
  game with a capture shown, the puzzle library, a Shots puzzle black to move mid-solve,
  settings with the seasons, and the computer's setup in Estonian. Each checked by eye;
  `shoot.sh` there retakes them (`store/README.md`).
- **Feature graphic:** `feature-graphic-draft.png` there, the autumn photograph, the
  board, and the wordmark in Libertinus Sans, by `feature.sh` (ImageMagick).
- **Seen while shooting:** at 16:9 and 16:10 the library's right column of themes ends
  about 24 dp from the screen's edge while the left starts 128 dp in, so the two columns
  sit off centre; the counts aren't cut. One run of the puzzle shot at 1280x800 came out
  as Learn's page instead of the puzzle and was right when run again; not looked into.
- The old `screenshots/play/` set (2026-11-08, before the puzzles and players) is
  superseded.

## Checks before upload

- The release build on the tablet from a clean install (`adb uninstall
  io.github.kaitk.draughts`, then `adb install draughts-release.apk`), and
  `scripts/idle_cpu.sh` and `scripts/lifecycle_memory.sh` on it; task 011 (SDL's
  accelerometer, the last idle CPU) done.
- Idle CPU, 2026-11-09, the tablet untouched at home: 0.03 s in 60 s (0.05%), 61
  voluntary switches; the PSS at home 134 MB.
- Raise `VERSION_CODE` for every upload after the first.

## Notes

- **The pre-launch report:** Play may run the app on virtual devices, whose software GPU
  (SwiftShader) can lack ASTC; the Android build ships the photographs only as ASTC, so
  there the app shows the page color without a photograph, the expected fallback, not a
  bug (`docs/architecture/rendering.md`). Real devices with Vulkan all have ASTC.
- **The photographs:** the APK embeds only what is in `design/backgrounds/masters/`
  locally; build the release where the `-6x6.astc` files are present, or it ships
  without photographs.
- **Screens:** the listing's screenshots must show the app as it runs on that class of
  device; phones are listed too, as the layouts fit them (task 030, done).

## Acceptance criteria

- [x] Final application id, upload key outside the repo, release AAB built by the script
      (2026-11-08; the key's backup is the user's)
- [x] Task 030 done, so phones and larger tablets are listed
- [ ] Store listing in English and Estonian, with icon, feature graphic, and screenshots
      (texts, screenshots, and a feature graphic drafted 2026-11-09; the developer
      name, the user's review, and the final feature graphic remain)
- [ ] Target audience, content rating, Data safety, and privacy policy filled in (the
      answers and the policy drafted in `store/`)
- [ ] Closed test run as Play requires, then the app published
