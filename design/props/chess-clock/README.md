# The chess clock's references

References for the antique chess clock on the 3D board's table (task 100). The images
and the video are other people's and stay local; only this list is in git.

| File | What it shows | From |
| --- | --- | --- |
| `leipzig-hedewig-01.png` | The one to try (a plainer case is the fallback): a German chess clock of about 1900, two round drum movements in nickel and brass, white dials with Arabic numerals and a small seconds dial at the top, blued spade hands, a cast brass rocker with scrolls over them, on a walnut plinth with a plaque "Schachzentrale H. Hedewig's Nachf., Leipzig C 1" | [chess-collection.de](https://www.chess-collection.de/newpagefea89af1) |
| `haller-german-clock-ca1900.mp4` | The same kind of clock in use, 34 s: the rocker pressed down on one side stops that clock and starts the other; "German Chess Clock, probably made by Thomas Haller, ca. 1900" | the user's download |
| `haller-frame-01.jpg` to `06.jpg` | The video's frames, one each 6 s, 960 px wide | `ffmpeg -vf fps=1/6,scale=960:-1` |
| `dial-seconds-01.png` | The dial to use: generated flat artwork, cream enamel, Art Nouveau Arabic numerals, a small seconds dial at the top, no hands; its painted brass ring is cropped off for the modelled bezel | ChatGPT, 2026-11-20 |
| `dial-plain-01.png`, `dial-roman-01.png` | The same without the seconds dial, and with Roman numerals; set aside | ChatGPT, 2026-11-20 |
| `hands-01.png` | Blued steel spade hands, hour and minute, flat on white | ChatGPT, 2026-11-20 |
| `hand-seconds-01.png` | The seconds hand: generated, blued steel, thin, a counterweight tail | ChatGPT, 2026-11-20 |
| `flag-01.png` | The flag: generated, a brass lever with a red tab; optional | ChatGPT, 2026-11-20 |
| `jaques-congress-01.png` | Set aside: an English Jaques congress timer, two dials in a mahogany case, its plaque an English club's; the German clock suits the Baltic German manor better (the user, 2026-11-20) | [chessantiques.com](https://chessantiques.com/product/vintage-jaques-congress-timer/), which has more pictures |
