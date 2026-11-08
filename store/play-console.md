# Play Console answers

The answers for Play Console's App content forms (Policy and programs → App content), and
the store settings. Drafted 2026-11-08 from the app as built, players added 2026-11-09; the forms' questions change,
so read each one as it stands and answer from the facts in "What the answers rest on".

## What the answers rest on

- **No permissions.** `aapt2 dump permissions build/android/draughts/draughts-release.apk`
  lists none: no `INTERNET`, no `AD_ID`, no location, camera, microphone, or storage.
- **No network.** Without `INTERNET` the app cannot open a socket; nothing in it tries.
- **No third-party SDKs** that collect anything: the app is Goose, SDL3, goose_gfx, and
  Nuklear, all compiled in, none of which talks to a server.
- **On the device only:** `settings.txt`, and each player's `player-N.txt` and
  `game-N.bin`, in the app's internal storage. A player's file holds the optional name a
  child or parent types (up to 12 characters) and the badge; like the rest it never
  leaves the device, which is why Data safety counts it as not collected (Play counts
  data as collected only when it is sent off the device).
- **Android's backup:** `android:allowBackup="true"`, so Android's own Auto Backup may
  copy those files to the user's Google account if the user turned backup on. The
  answers below count that as not collected, since the developer never receives it;
  confirm it against Play's Data safety help when filling the form in. Setting `allowBackup="false"` would remove the question at
  the cost of a child's progress surviving a new tablet (open).

## Data safety

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not asked once the answer above is No |
| Do you provide a way for users to request that their data is deleted? | Not asked; uninstalling or clearing the app's data deletes everything |
| Independent security review | No |
| Account creation | The app has no accounts |

What the listing then shows: "No data shared with third parties" and "No data
collected".

## Ads

| Question | Answer |
| --- | --- |
| Does your app contain ads? | **No** |
| Advertising ID: does your app use advertising ID? | **No** (no `AD_ID` permission; target SDK 36) |

## Content rating (IARC questionnaire)

Email for the certificate: `{CONTACT_EMAIL}`. Category: **Game** (not "Reference, news, or
educational": the app is played, and its puzzles are part of the game).

| Topic | Answer |
| --- | --- |
| Violence (cartoon, fantasy, realistic, blood, gore) | No |
| Fear, horror | No |
| Sexuality, nudity | No |
| Language (profanity, crude humour) | No |
| Controlled substances (drugs, alcohol, tobacco) | No |
| Gambling, simulated gambling, loot boxes | No |
| Users can interact or exchange content (chat, user-generated content) | No: pass-and-play is two people at one device |
| Shares the user's location with other users | No |
| Digital purchases, in-app purchases | No |
| Unrestricted internet access (a browser, search) | No |
| Is the app a web browser or search engine? | No |

Expected: the lowest rating everywhere (PEGI 3, ESRB Everyone, USK 0, IARC 3+).

## Target audience and content

| Question | Answer |
| --- | --- |
| Target age groups | **5 and under**, **6–8**. Not 9–12 or older: older children and adults may enjoy it, but adding them changes nothing here, and a game for 5 to 8 is what it is made for |
| Could your store listing unintentionally appeal to children? | Not asked: children are the target |
| Does the app appeal to children? | Yes |

Choosing an age group under 13 puts the app under the **Families Policy**. What it asks,
and where the app stands:

- **Privacy policy** at a public URL, linked in the listing and reachable from the app's
  store page: `store/privacy/index.html`, published at `{PRIVACY_URL}`.
- **Ads:** none, so the Families Self-Certified Ads SDK rule doesn't apply.
- **No collection of personal or device identifiers** from children, no `AD_ID`, no
  location: met, as above.
- **Content appropriate for children**, the listing included: met; the listing makes no
  claims of being "educational" or "approved" beyond what the app does.
- **Target API level** current: 36.
- **Sign-in:** none.
- **Augmented reality, camera, microphone:** none.
- **Teacher Approved:** Play's teachers review apps for children by their own choice; it
  can't be applied for. Nothing to do.

## Other App content declarations

| Form | Answer |
| --- | --- |
| Privacy policy | `{PRIVACY_URL}` |
| App access | All functionality is available without special access (no login) |
| Government app | No |
| Financial features | None |
| Health apps | Not a health app |
| News app | No |
| Data deletion (accounts) | Not applicable: no accounts |
| Photo and video permissions, full-screen intent, foreground services, exact alarms | Not used |

## Store settings

| Setting | Value |
| --- | --- |
| App or game | Game |
| Category | Board |
| Tags | Up to five of Play's list; pick Board, Casual, Offline, Single player, Family, if offered |
| Contact email | `{CONTACT_EMAIL}` (required, shown on the listing) |
| Website | `https://kaitk.github.io/draughts/` (optional; to confirm) |
| Phone | None |
| Price | Free (a free app can never become paid) |
| Countries | All, or Estonia and the EU first; the user decides |
| Developer name | `{DEVELOPER}` (the Play developer account's name) |
