# 046: Release on the App Store

Status: in-progress (0.2.0 (1) uploaded and submitted for review, 2026-11-12)

Draughts on the App Store for iPhone and iPad, in Games → Puzzle at 4+ (not the Kids
category): no ads, no tracking, no accounts, no network, as on Play (task 029). The
listing and App Store Connect's answers are in `store/app-store.md`, the preview in
`store/preview/app-store.html`. Apple's rules change: check each against Apple's pages.
The preparation notes are in git at 314c3b5.

## Done

- The app meets the bundle's rules (2026-11-09): the privacy sentence in settings
  (Guideline 5.1.1(i)), `PrivacyInfo.xcprivacy` written by `scripts/ios.py`, no
  CoreBluetooth (`SDL_HIDAPI OFF`), the icon and launch colour through `actool`, resizable
  iPad windows (no `UIRequiresFullScreen`), and no links out (no `OpenURL`, rating prompt,
  or share sheet; check again before each submission).
- `scripts/ios.py --release --upload` builds, signs, and uploads the `.ipa`
  (`docs/development.md`, "The App Store build").
- No Estonian listing: Estonian is not an App Store localization; its text waits in
  `store/app-store.md`.

## Decided (2026-11-09 to 12)

- Games → Puzzle, 4+, Made for Kids No; the listing speaks to all ages (Guideline
  5.1.4(b)). iPhone and iPad. EU trader status: non-trader.
- The bundle id is `io.github.kaitk.draughts.app` for good (`BUNDLE_ID` in
  `scripts/ios.py`; the plain id was taken by another team). No Apple ID, team id, or
  device id goes into the repo; `DRAUGHTS_IOS_TEAM` picks the signing team.
- Support URL `https://kaitk.github.io/draughts/`, privacy URL
  `https://kaitk.github.io/draughts/privacy/`.

## What is left

- Approval, then release by hand (Pending Developer Release → Release This Version).
- TestFlight on the iPhone 13 mini.
- The iPhone screenshots retaken from today's app (Results, the move list); no new build
  needed.

## Acceptance criteria

- [x] The listing, the answers, the screenshots, and a preview of the page
- [x] The privacy text in the app, the privacy manifest, the icon, and the launch screen
- [x] The iPad layout in a resized window (task 050)
- [ ] A distribution build uploaded and tried through TestFlight on a device
- [ ] Submitted (2026-11-12) and approved, in Games → Puzzle at 4+
