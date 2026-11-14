# Store listing: Estonian (et)

Play Console → Grow users → Store presence → Main store listing → Manage translations →
Estonian, entered by hand (not Google's machine translation). The same limits and counts
as `listing-en.md`. The wording follows `strings/et.txt` and task 024: kabe, tamm,
lööma, käik; a side in the plural (valged, mustad). The App Store has no Estonian
listing (`app-store.md`), so this text is Play's alone.

## Title (4 of 30)

```text
Kabe
```

The same as the launcher's name (`strings/et.txt`), as the English is "Draughts".

## Short description (74 of 80)

```text
Kabe 2D- või 3D-laual: mängi arvuti või sõbraga, lahenda päeva ülesandeid.
```

## Full description (3,361 of 4,000)

```text
Rahulik kabemäng mängimiseks ja õppimiseks: suured nupud, lame 2D- või ruumiline 3D-laud ja mitte midagi, mis tähelepanu mängult kõrvale juhiks.

ÕPI
• Kabe on uus? „Kuidas mängida“ õpetab seda lühikeste sammudega laual, iga kabeliigi jaoks, ja juhatab edasi ülesannete või esimese partii juurde.

MÄNGI
• Mängi arvutiga kolmel tasemel: kerge, keskmine ja raske. Pärast iga partiid kohaneb arvuti veidi, et mäng jääks tasavägiseks.
• Või mängi sõbraga samas tahvelarvutis või telefonis, kordamööda käies (ühes seadmes, mitte võrgus); laud pöörab käija poole või jääb paigale.
• Kolm kabeliiki: rahvusvaheline kabe 10 × 10 laual ning Brasiilia ja vene kabe 8 × 8 laual.
• Käi nuppu ja siis ruutu puudutades või lohista nupp kohale. Võta käik tagasi või alusta uuesti.
• Mängi kellata või ajakontrolliga: kummalgi 5 või 10 minutit, lisaks 3 või 5 sekundit käigule.

SINU MÄNGUD
• Tulemustes on sinu varasemad partiid ja reiting arvuti vastu.
• Vaata neid käik-käigult üle, iga käik hinnatud parimast veani, ja mängi mis tahes käigust edasi, et proovida teist teed.

ÜLESANDED
• Tänased ülesanded: kui Õpi on lahendatud, iga päev mõni ülesanne sinu tasemel (vaikimisi 4; seadetes 3, 5 või 10): soojendus, kaks sinu tasemel ja üks veidi raskem. Need tulevad enam kui 7000 ülesande seast rahvusvahelises, vene ja Brasiilia kabes, nende hulgas lõksud, mis karistavad hooletut käiku, ja ükski ei kordu.
• Ülesannete reiting igale mängijale ja kabeliigile: alguses liigub see kiiresti, hiljem rahuneb.
• Kursus: 166 ülesannet, 74 rahvusvahelises kabes kuues teemas (Õpi, Löömine, Tammiks, Kombinatsioonid, Tammi löögid ja Ohutu käik) ning 46 nii vene kui ka Brasiilia kabes neljas teemas.
• Iga teema läheb kergest raskemaks ja mõnes ülesandes mängid mustadega.
• Esimesena tuleb Õpi, mis näitab reegleid mängu käigus; teised teemad avanevad, kui sellest on pool lahendatud.
• Iga ülesande eest kuni kolm tähte, iga vea eest üks vähem; lahendatud ülesannet saab kõigi kolme tähe nimel uuesti proovida.

MÄNGIJAD
• Ühes seadmes kuni neli mängijat, igaühel oma loomapilt ja soovi korral nimi.
• Igal mängijal on oma välimus, vihjed, tähed, arvuti tase ja pooleliolev mäng.
• Mängijat saab avalehel vahetada kahe puudutusega.

VIHJED
• Vihjed, mis aitavad, kuid ei mõtle mängija eest: vaikimisi ei näita mäng midagi enne, kui käik on vale; siis näitab see ruutu ja põhjust. Esimesteks mängudeks saab sisse lülitada ka kõigi võimalike käikude näitamise.
• Löömine on kohustuslik: nupp, mis peab lööma, on märgitud täpiga iga löödava nupu kohta.

KABELAUD
• Lame laud või ruumiline 3D-laud valguse ja pehmete varjudega, mida saab käega pöörata.
• Neli aastaaega, igaühel oma pilt ja laud: puidust, kivist või nikerdatud.
• Aastaaeg vahetub kuupäeva järgi või jääb selleks, mille ise valid; või ühevärviline taust laua toonides, ilma pildita.

KÕIGILE
• Suured pildid ja ikoonid, et ka laps, kes veel lugeda ei oska, saaks ise hakkama.
• Piisavalt lihtne esimeseks partiiks, kuid raske tase ja raskeimad ülesanded panevad proovile ka täiskasvanu.
• Eesti ja inglise keeles, vastavalt seadme keelele.

MITTE MIDAGI LIIGSET
• Reklaamide, rakendusesiseste ostude ja kontodeta ning internetita: kõik jääb seadmesse.

Kabe töötab telefonis ja tahvelarvutis, nii püst- kui ka rõhtpaigutuses.

Kabe on avatud lähtekoodiga, MIT või Apache 2.0 litsentsi all: github.com/kaitk/draughts
```

## Wording notes

- "Nupp" is both a draughts piece and a button, so the text says "nupud" only of pieces
  and "ikoonid" of the controls.
- The themes are named as the library names them (`theme.*` in `strings/et.txt`): Õpi,
  Löömine, Tammiks, Kombinatsioonid, Tammi löögid, Ohutu käik. The section on hints is
  "Õpi mängides" (learn while playing), apart from the theme Õpi.
- "Mõnes ülesandes mängid mustadega": a side in the plural, as `color.black` (Mustad).
- "Loomapilt" (animal picture) for the badge, after `players.picture` (Pilt); "mängija"
  as in `players.new` (Uus mängija).
- "Ruumiline" for the 3D board, as settings' Board row (`board.raised`), with "3D" beside
  it as there; "lame" for the flat one (`board.flat`).
- "Igal mängijal on oma välimus": settings' tab is Välimus (`settings.look`), so it
  stays, though "välimus" is first a person's looks.
- The headings: "Vihjed" (`settings.hints`), "Kabelaud", "Kõigile" (for everyone), and
  "Mitte midagi liigset" ("nothing superfluous") for what the app leaves out.
- "Tasavägine" (evenly matched) for "a fair match"; "partii" for a game played, so "mäng"
  isn't said twice; "ajakontroll" for the clock; "pooleliolev mäng" for the saved game.
- The short description says "lahenda 166 ülesannet": "õpi see 166 ülesandega selgeks"
  read as learning the rules, which takes minutes, and "see" for "kabet" was clumsy.
- Revised 2026-11-09 with a Gemini review (`agents/writing.md`): taken were "partii",
  "mängu käigus" for "in action", "kui sellest on pool
  lahendatud", the stars "kõigi kolme tähe nimel" (not "võita"), "mängija eest" (not
  "lapse eest"), the pips as "märgitud täpiga iga löödava nupu kohta", and the seasons as
  adjectives (sügisene puit, …). Not taken: "kergemast raskemaks" for "kergest raskemaks" (both are used; the user
  decides), "lauavaade" for "välimus" (the app's tab is
  Välimus), and dropping "3D" beside "ruumiline" (the app's Board row shows both). The
  user reads the new lines before an upload.
- Added 2026-11-14 for 0.8.0: "Õpi", "Sinu mängud", and the daily puzzles as
  "Tänased ülesanded" (`daily.today`), "Soojendus" and "Veidi raskem" as the app names
  them, "Kuidas mängida" (`how.title`), the materials "puidust, kivist või nikerdatud"
  (`material.*`). The user reads these lines before an upload.

