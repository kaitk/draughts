# 029: Release on Google Play

Status: in-progress (on Play from 2026-11-10; the closed test running since its review
passed, seen 2026-11-12)

The app on Google Play under the Families Policy: for all ages, no ads, no tracking, no
accounts, no network (`docs/product.md`). Play's rules change yearly: check each against
its current help, not this file. The App Store is task 046.

## Done

- The release build: `scripts/android.py --release` signs the APK
  and the AAB with the upload key (`docs/development.md`, "The upload key"), 16 KB-aligned,
  `bundletool validate` passing. 0.1.0 (2026-11-08): APK 11.4 MB, AAB 9.1 MB, no
  permissions, target SDK 36.
- The app's entry on Play (2026-11-10 and 11): every App content form as
  `store/play-console.md` has them, every age group, Teacher Approved, the listing in
  English and Estonian with the 0.3 screenshots, category Board.
- 0.1.0 to internal testers 2026-11-11; 0.1.1 (code 2, easy starts at 8) to the Alpha
  track's closed test with 15 testers, its review passed; "12 testers opted in" ticked.

## What is left

- The closed test's 14 days with 12 testers opted in, then apply for production. Play
  doesn't mail testers: send them the opt-in link from the Testers tab.
- Production countries: all proposed (free, offline, collects nothing); the user wants at
  least the main English-speaking ones.
- Move the A33 from its sideloaded debug build to Play's (a `run-as` backup and
  `bmgr backupnow`, a restore at install).
- Raise `VERSION_CODE` for every upload; build releases where the `-6x6.astc` masters are
  present, or the photographs are missing.
- Play's pre-launch report may run on SwiftShader without ASTC: the page color with no
  photograph there is the expected fallback (`docs/architecture/rendering.md`).

## Acceptance criteria

- [x] Final application id, upload key outside the repo, release AAB built by the script
- [x] Task 030 done, so phones and larger tablets are listed
- [x] Store listing in English and Estonian, with icon, feature graphic, and screenshots
- [x] Target audience, content rating, Data safety, and privacy policy filled in
- [ ] Closed test run as Play requires, then the app published
