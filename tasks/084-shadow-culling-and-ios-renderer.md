# 084: The shadow pass's culling and the iPhone's renderer

Status: in progress

Two follow-ups from task 081. The shadow map's pass was the one 3D pipeline with no cull
mode: try back- and front-face culling there, keeping either only for a measured win on
the Galaxy A33 with an unchanged look. And `auto` picks gfx on iOS only because ngfx's
MSAA frame was 2% slower on the M1 Pro (task 077): time the two on the iPhone 13 mini.

## Acceptance criteria

- [x] Back- and front-face culling in the shadow pass, shots checked on the Mac; the kept
      one's cycles on the A33, the decision recorded (2026-11-13)
- [ ] gfx and ngfx on the iPhone 13 mini: presented frames and the GPU's time a frame,
      two runs each, alternated; a proposal for `auto` on iOS if ngfx wins clearly

## Measured

**Culling in the shadow pass** (2026-11-13). Shots on the Mac, headless with a fixed
clock, at the Pixel's 1080 × 2400 at 540 dp in both orientations and the tablet's
1920 × 1200 both ways, wood and stone, against main; pixels differing by more than 8 of
255 at the tablet's landscape, wood:

| Shadow pass | Depth bias, slope | Pixels | What shows |
| --- | --- | --- | --- |
| Back faces culled | 1.0, 1.5 | 272 | single pixels along the shadows' edges |
| Front faces culled | 1.0, 1.5 | 18,563 | acne bands on the pieces' feet, lit side |
| Front | 0, 0 | 10,969 | the same, thinner |
| Front | −1.0, −1.5 | 11,361 | acne on the pieces' rims |
| Front | −2.0, −4.0 | 23,540 | more on the rims |
| Front | 4.0, 6.0 | 36,319 | the shadows pulled off the pieces (peter-panning) |

The pieces are closed: their undersides lie within a shadow texel of their feet, so
front-face culling compares a foot against a face that close, whatever the bias.

The A33, back faces culled against main, both beside the Play app (`--id-suffix`),
`--bench 300`, autumn's wood, alternated, five runs each, thermal status 0 throughout,
611 MHz in every waited phase but one run's dip to 507:

| Build | Waited with the shadow map P50 | The pass alone | Difference |
| --- | --- | --- | --- |
| Main | 14.96 to 15.57 ms | 13.62 to 14.37 | 1.07 to 1.35 |
| Back faces culled | 14.78 to 14.81 (15.42 in the dip) | 13.63 to 13.67 | 1.13 to 1.15 |

The pass alone, which draws no shadow map, came out at 13.6 or 14.4 ms by run whatever the
build, so compare the runs where it was 13.6 for both: 14.96 to 15.00 ms against 14.78
to 14.81, about 0.1 M cycles a frame, 1%. Small, but in every matched pair; kept.
