# 024: Review the Estonian translation

Status: todo

Once the MVP's prototypes have their text mostly in (2026-11-07): a Gemini agent (agy;
Gemini 3.8 writes the best Estonian of the models, given the right context) reads
`strings/et.txt` and the prototypes' text, and a Claude session then checks what it
changed against the English and the context before anything is taken.

## Work

- Brief the agent with: `strings/en.txt` and `strings/et.txt` side by side, what the app
  is and who uses it (`docs/product.md`: children of about 5 to 8), where each string shows
  (key names, prototypes), the draughts terms in Estonian use (kabe, tamm, lööma,
  käik), and the limits of each tile's width (rendering.md).
- Take a change only with a reason: wrong, unnatural, or too long for its tile. Keep
  the keys; every language file has every key (`test/strings/`).
- Check the longer labels on the Mac and the tablet in both orientations with `--lang et`.

## Acceptance criteria

- [ ] Every Estonian string read by the agent, its changes reviewed and taken or declined
- [ ] Screens checked in Estonian in both orientations
