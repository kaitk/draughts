# checkers

A small draughts learning app for young kids: play, puzzles, and lessons. It runs
first on an Android Galaxy tablet, later on the Play Store for free.

Written in [Goose](https://github.com/aardappel/goose), compiled to C, drawn with SDL3's
GPU API through Vulkan. No engine, no allocation in the frame loop, and no frames while
idle.

- [docs/product.md](docs/product.md): scope, MVP, and what follows
- [docs/architecture/](docs/architecture/README.md): decisions and why
- [tasks/](tasks/README.md): one file per task
- [prototypes/](prototypes/README.md): HTML UI prototypes

Status: Goose runs on the tablet through Vulkan, and the rules engine (`rules/`) plays
Russian, International, and English draughts, checked against published perft counts.
Setup, running, and testing are in [docs/development.md](docs/development.md).
