# Store listing: Estonian (et)

Play Console → Grow users → Store presence → Main store listing → Manage translations →
Estonian, entered by hand (not Google's machine translation). The same limits and counts
as `listing-en.md`. The wording follows `strings/et.txt` and task 024: kabe, tamm,
lööma, käik; a side in the plural (valged, mustad). The App Store has no Estonian
listing (`app-store.md`), so this text is Play's alone.

## Title (12 of 30)

```text
Kabe lastele
```

The launcher's name stays "Kabe" (`strings/et.txt`). Alternatives: "Kabe: mängi ja õpi"
(18), "Kabe" (4).

## Short description (65 of 80)

```text
Mängi kabet sõbra või arvutiga ja õpi see 120 ülesandega selgeks.
```

## Full description (2,648 of 4,000)

```text
Kabe lastele ja peredele: rahulik lauamäng mängimiseks ja õppimiseks. Suured nupud, selge laud ja mitte midagi, mis tähelepanu mängult kõrvale juhiks.

MÄNGI
• Mängi sõbraga samas tahvelarvutis või telefonis, kordamööda käies.
• Mängi arvutiga kolmel tasemel: kerge, keskmine ja raske. Pärast iga mängu kohaneb arvuti veidi, et mäng jääks tasavägiseks.
• Kolm kabeliiki: rahvusvaheline kabe 10 × 10 laual ning Brasiilia ja vene kabe 8 × 8 laual.
• Käi nuppu ja siis ruutu puudutades või lohista nupp kohale.
• Võta käik tagasi või alusta uuesti.
• Mängi kellata või kellaga, kummalgi 5 või 10 minutit.

ÜLESANDED
• 120 ülesannet: 74 rahvusvahelises kabes 10 × 10 laual kuues teemas (Õpi, Löömine, Tammiks, Kombinatsioonid, Tammi löögid ja Ohutu käik) ning 46 vene kabes 8 × 8 laual.
• Iga teema läheb kergest raskemaks ja mõnes ülesandes mängid mustadega.
• Esimesena tuleb Õpi, mis näitab reegleid mängus; teised teemad avanevad, kui pooled selle ülesannetest on lahendatud.
• Iga ülesande eest kuni kolm tähte, iga vea eest üks vähem; lahendatud ülesannet saab uuesti mängida, et võita kõik kolm.

MÄNGIJAD
• Ühes tahvelarvutis kuni neli mängijat, igaühel oma loomapilt ja soovi korral nimi.
• Igal mängijal on oma välimus, vihjed, tähed, arvuti tase ja salvestatud mäng, nii et ühe lapse mäng või tähed ei asenda kunagi teise omi.
• Mängijat saab avalehelt vahetada kahe puudutusega.

ÕPI MÄNGIDES
• Vihjed, mis aitavad, kuid ei mõtle lapse eest: vaikimisi ei näita mäng midagi enne, kui käik on vale; siis näitab see ruutu ja põhjust. Esimesteks mängudeks saab sisse lülitada ka kõigi võimalike käikude näitamise.
• Löömine on kohustuslik: nupp, mis peab lööma, on märgitud ja sellel on täpp iga nupu kohta, mille see lööb.

ILUS KABELAUD
• Lame laud või ruumiline 3D-laud valguse ja varjudega, mida saab avalehel käega pöörata.
• Neli aastaaega, igaühel oma foto ja laud: sügisel puit, talvel kivi, kevadel nikerdatud kivi ja suvel päikeseloojang.
• Aastaaeg vahetub kuupäeva järgi või jääb selleks, mille ise valid.
• Või ühevärviline taust laua toonides, ilma fotota.

LASTELE TEHTUD
• Mõeldud lastele alates umbes viiendast eluaastast ja täiskasvanutele, kes nendega mängivad.
• Suured pildid ja ikoonid, et ka laps, kes veel lugeda ei oska, saaks ise hakkama.
• Eesti ja inglise keeles, vastavalt seadme keelele.

MITTE MIDAGI LIIGSET
• Reklaamideta.
• Rakendusesiseste ostudeta.
• Kontode ja sisselogimiseta.
• Internetita: rakendus töötab võrguühenduseta ega loo kunagi ühendust internetiga.
• Andmeid ei koguta: mängijad, nende seaded ja mängud jäävad seadmesse.

Kabe töötab telefonis ja tahvelarvutis, nii püst- kui ka rõhtpaigutuses.
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
- "Ilus kabelaud" ("a fine board") heads the look, where English has "A board to enjoy";
  "Mitte midagi liigset" ("nothing superfluous") heads what the app leaves out.
- "Tasavägine" (evenly matched) for "a fair match".
- The new lines (the 120 puzzles, the pips, the board and seasons) are unreviewed; run
  them through `agents/writing.md`'s translation review before an upload.
