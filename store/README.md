# Google Play materials

What goes into Play Console for Draughts, drafted so it can be pasted in. Images (the
512 px icon, the feature graphic, screenshots) stay local in `~/Downloads/draughts-store/`.

| File | What it is |
| --- | --- |
| `listing-en.md` | The store listing in English: title, short and full description |
| `listing-et.md` | The same in Estonian, with notes on the wording |
| `privacy/index.html` | The privacy policy, English and Estonian on one standalone page |
| `play-console.md` | The App content answers: Data safety, ads, content rating (IARC), target audience and the Families Policy, the other declarations, and the store settings |

## Placeholders

Replace these everywhere in this folder before anything is published:

| Placeholder | Value |
| --- | --- |
| `{DEVELOPER}` | The developer name on Play, a personal games identity; open |
| `{CONTACT_EMAIL}` | The contact address Play shows on the listing; open |
| `{PRIVACY_URL}` | `https://kaitk.github.io/draughts/privacy` (to confirm) |

```sh
grep -rn '{DEVELOPER}\|{CONTACT_EMAIL}\|{PRIVACY_URL}' store/   # what is left to fill in
```

## Publishing the privacy policy

Play needs it at a public URL that isn't a PDF and that names the app. `privacy/index.html`
needs nothing else: no scripts, no fonts, no images. On GitHub Pages for the repo
`kaitk/draughts`, it shows at `https://kaitk.github.io/draughts/privacy/` when the site is
built from a branch or folder holding `privacy/index.html` (Pages for a private repo needs
a paid plan; a public repo of its own, holding only the page, works on any plan). Check the
URL opens logged out before giving it to Play.

## The app's identity

The application id is `io.github.kaitk.draughts` (2026-11-08), set as `APP_ID` in
`scripts/android.py`, and the version as `VERSION_CODE` and `VERSION_NAME` there.
`docs/development.md`, "Release builds", says how the AAB is built and signed.
