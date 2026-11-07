# UI prototypes

Static HTML prototypes for comparing designs before building them in Goose. Open each file
directly in a browser (`file://`): no server and no build step. CDN dependencies need
internet access. Keep shared files beside the HTML so relative links work.

Check a prototype with the `agent-browser` CLI at tablet sizes: 1280×800 landscape and
800×1280 portrait. When handing one off, include its full absolute `file:///` URL.

Prototypes only use what the native renderer can draw cheaply: rounded rects, SDF
circles, gradients, one pre-blurred background for glass (see
[rendering](../docs/architecture/rendering.md#look)), and baked text. No live
`backdrop-filter` blur. Once a design is chosen, its values (colors, radii, opacities,
sizes) go into `docs/architecture/rendering.md`.
