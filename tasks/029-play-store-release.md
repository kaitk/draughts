# 029: Release on Google Play

Status: todo

Everything between a sideloaded APK and the app on Google Play, under Google's Families
Policy: the app is for children, with no ads, no tracking, no accounts, and no network
(`docs/product.md`, "After the MVP": release). Android first; the App Store is not
planned yet. Things Play requires change yearly: check each against Play's current
documentation when doing this, not this list.

## Work

- **Identity:** the final application id (`com.kaitk.draughts` is a placeholder in
  `android/AndroidManifest.xml`; it can never change once uploaded), `versionCode` and
  `versionName` raised per upload.
- **Signing:** an upload key kept outside the repo and backed up, with Play App Signing;
  `scripts/android.py` signs with it for release builds and the debug key otherwise.
- **The bundle:** an Android App Bundle (AAB), which Play requires for new apps, built by
  `scripts/android.py` beside the APK (`bundletool`, or `aapt2 --proto-format` and a
  zip in the bundle's layout); arm64-v8a, the 16 KB page alignment Play requires of
  native libraries (the APK already aligns to 16 KB), and the target SDK Play asks for
  then.
- **Screens:** the listing's screenshots must show the app as it runs on that class of
  device; phones are listed too once task 030 fits the layout to them.
- **Play Console:** the developer account (a new personal account must run a closed
  test with at least 12 testers for 14 days before production; check the current
  rule), the app's entry, the store listing in English and Estonian (title, short and
  full description), the icon (task 028), the 1024 × 500 feature graphic, and
  screenshots (`~/Downloads/draughts-store/screenshots/play/`, retaken once puzzles are
  in).
- **Policy forms:** target audience and content (ages 5 and under, 6 to 8), so the
  Families Policy applies; the content rating questionnaire (IARC); the Data safety form
  (no data collected or shared); ads declared as none; a privacy policy at a public URL,
  short since nothing is collected.
- **Checks before upload:** the release build on the tablet from a clean install, and
  `scripts/idle_cpu.sh` and `scripts/lifecycle_memory.sh` on it; task 011 (SDL's
  accelerometer, the last idle CPU) done.

## Acceptance criteria

- [ ] Final application id, upload key outside the repo, release AAB built by the script
- [ ] Task 030 done, so phones and larger tablets are listed
- [ ] Store listing in English and Estonian, with icon, feature graphic, and screenshots
- [ ] Target audience, content rating, Data safety, and privacy policy filled in
- [ ] Closed test run as Play requires, then the app published
