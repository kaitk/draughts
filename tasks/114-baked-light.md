# 114: The manor's light baked and shipped

Status: todo (the last optimization, once the sun and the look are settled; the user,
2026-11-23)

The room and the sun are static in play, so the light that today is worked out each frame or
at room-on could be baked once, offline, and shipped: the indirect light (bounces and sky)
with its colour bleeding, and the occlusion down to small props (books, mouldings, sills,
contacts). The sun's direct light, the tree's moving flecks, the pieces, the reflections and
the highlights stay worked out at run time.

Not now: baking freezes the sun's angles and the room's light, which the user still tunes.
Do it after that tuning ends, as the final optimization of the manor scene (task 110).

It would replace: the SSAO (about 1.2-2.3 ms at 4K, and its grain and shimmer), the probes'
and corners' map's lookups in the floor and the other surfaces, and the floor-lightmap idea
(`build/notes/plans/claude-floor-capture.txt`, option C).

Rough sizes (2026-11-23, guessed, not measured): about 300 m² of surface; the indirect light
at 1-2 cm a texel, directional (three times the data) so the normal maps still respond, and
fine one-channel occlusion at about 5 mm where it shows: about 5-20 MB a sun position
compressed, 50-150 MB uncompressed. One bake for each sun the game ships (the seasons).

Formats: aim at every Android tablet and phone, not our test devices.
- Mobile (Android, iOS, iPadOS) and the Mac: ASTC's LDR profile with a scale (one per map,
  or RGBM), not the HDR profile, which many Adreno GPUs lack.
- Windows and Linux: BC6H or BC7, which their GPUs decode and ASTC they don't.

## Acceptance criteria

- [ ] An offline baker (ray-traced, its samples enough that no grain shows) for the
      library's shell and props, with a unique layout for each procedural surface (or per
      vertex where a small prop's mesh is fine enough)
- [ ] The bakes shipped as ASTC (mobile and Mac) and BC6H or BC7 (Windows and Linux), read
      by both renderers, the app's download size against today's measured
- [ ] SSAO removed; the probes and corners' map replaced where the bake covers them
- [ ] The look against today's judged by the user, frame times and memory measured on the
      Mac and the A33 (task 110's way)
