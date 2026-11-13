# Goose findings

Gaps found in Goose, goose_gfx, the SDL it pins, and goose-ngfx, with what we do about
each here and what could go upstream. Newest first. goose-ngfx is the user's, so its gaps
are fixed there when Draughts needs them; the entries name what is still open.

Draughts builds gfx from `kaitk/goose_gfx`'s `main` (the submodule): upstream `main` with
every change Draughts needs merged in. Each change is also a branch of its own on upstream
`main`, offered upstream one at a time (2026-11-12). Pull requests the user opens, not yet
opened (2026-11-11): those branches (task 065 lists them, and which stack on which;
`upstream-series` is all of them) to `aardappel/goose_gfx`; and `kaitk/NoGraphicsAPI`'s
`astc-6x6`, ASTC 6 × 6, `vsync-option`, and `linux-presentation` (2026-11-12) to
`sebbbi/NoGraphicsAPI`. An entry's "Upstream" line says what each proposes.

## Goose: `embed_shader` drops `mediump`, so no shader runs in fp16 (2026-11-13)

Goose's own GLSL compiler (`shaderc.c`, its SPIR-V from cute_spirv) parses `mediump` on a
declaration and drops it: a fragment shader with `mediump vec3` and `mediump float`
locals compiles to SPIR-V with no `RelaxedPrecision` decoration, where glslang
(`glslangValidator -V`) gives the same source twelve. A `precision mediump float;`
statement is an error ("unexpected token at global scope"), and so are
`GL_EXT_shader_explicit_arithmetic_types_float16`'s `float16_t` and `f16vec3`
("expected ';'"). `RelaxedPrecision` is how a Vulkan driver is told a value may be 16-bit,
and needs no device feature; the explicit types would also need `shaderFloat16`, which
SDL_GPU doesn't enable. Mali GPUs run fp16 at twice fp32's rate and in half the registers:
the A33's lit shader is more than half its 3D frame, and held 64 registers on the
tablet's G615 (task 059).

- Here: nothing; task 081's fp16 step waits for it. The Metal and HLSL translations may
  keep `float` (SPIRV-Cross's MSL leaves `RelaxedPrecision` out by default), so the Mac's
  shots can't show fp16's rounding: check it with screenshots on an Android device.
- Upstream: `mediump` (and `lowp`) on a variable, parameter, function result, or
  interface variable decorates it and the operations computed into it `RelaxedPrecision`,
  as glslang does for Vulkan; `precision` statements accepted, setting the default.

## Goose: the Linux release's SDL has no Wayland (2026-11-12)

The `libSDL3.a` in `goose-v2026.4-linux-x64` is built with X11 and offscreen video only:
`SDL_VIDEO_DRIVER=wayland` says "wayland not available". On a Wayland desktop (Bazzite's
GNOME 50) every Goose program runs through XWayland, so a fractional display scale is
upscaled by the compositor rather than drawn at the display's pixels, and the window is
matched to its `.desktop` file by X11's `WM_CLASS` (SDL's app id, `src/app/display.c`)
rather than Wayland's app id.

- Here: `scripts/linux.py` builds the submodule's SDL (3.4.16, the release's version) with
  the Goose package's options and Wayland and X11 both required, in place of the
  release's `libSDL3.a`, in the `draughts-jammy` box (task 076). On GNOME 50 the window is
  Wayland's, libdecor's title bar on it, sharp at 125% and 150%; `SDL_VIDEO_DRIVER=x11`
  still opens it through XWayland. The executable still needs only libc and libm.
- Upstream: build the release's SDL with `SDL_WAYLAND=ON` (and libdecor dynamically
  loaded, as SDL does by default), which needs only the Wayland headers on the build
  machine; SDL loads `libwayland-client` at run time, so X11-only systems still run.

## NoGraphicsAPI: no presenting on Linux (2026-11-12)

NoGraphicsAPI's Vulkan backend presented on Win32 only; elsewhere a `DeviceDesc::window`
was unsupported, so ngfx ran headless on Linux. Two more things stood in the way of a
Wayland window: a Wayland surface's `currentExtent` is undefined (0xFFFFFFFF), which
`recreate_swapchain` refused, and RADV lists 72 formats for a Wayland surface (each format
in each of its color spaces), over the 64 `max_surface_formats` held, which it refused as
well ("Required Vulkan device, memory, or display capabilities are unavailable").
`sebbbi/NoGraphicsAPI` `ffd9f2a`, goose-ngfx v0.5.0.

- Here: `kaitk/NoGraphicsAPI`'s `linux-presentation`: `DeviceDesc::display` and
  `window_system` (`wayland`, the default, or `xlib`) make a Wayland or an Xlib surface;
  `set_drawable_extent` gives a Wayland swapchain the window's size; 256 surface formats.
  The fork's `ngfx` has it, and goose-ngfx's `ngfx::open(window, w, h, flags, display, kind)`
  takes gfx's three (task 076). Draughts' ngfx build presents on Wayland and on XWayland
  on the RX 6800.
- Upstream: `linux-presentation` to `sebbbi/NoGraphicsAPI` as one pull request, Wayland
  first and X11 the fallback.

## Goose: TinyCC's run in memory fails under SELinux (2026-11-12)

`goose run` (and `test/run_tests.py`'s default) compiles into memory with libtcc, whose
`mprotect` to make the code executable SELinux refuses on Fedora's and Bazzite's
enforcing default ("tcc: error: mprotect failed (did you mean to configure
--with-selinux?)"), inside a distrobox too. Every test fails; built natively
(`test/run_tests.py --build`) all 89 pass.

- Here: `--build` on Fedora-based machines.
- Upstream: libtcc built `--with-selinux` (`CONFIG_SELINUX`), which maps the code twice
  from a temporary file, once writable and once executable, instead of `mprotect`.

## goose_gfx and ngfx: NO_VSYNC capped full screen on Windows (2026-11-12)

gfx's `NO_VSYNC` asks SDL_GPU for mailbox before immediate. Full screen on the RTX 4090
(NVIDIA 617.42, Vulkan), mailbox is held to the display's refresh: the 3D bench presented
165 fps with `--no-vsync`, 747 with immediate. ngfx's `NO_VSYNC` did nothing on Vulkan:
NoGraphicsAPI fixes FIFO (`swapchain_present_mode`), and ngfx only turns a Metal layer's
display sync off. goose_gfx `v1` and `main`, goose-ngfx v0.5.0, NoGraphicsAPI `a6e78ed`.

- Here: `kaitk/goose_gfx`'s `no-vsync-immediate`, in its `main`, asks for immediate
  first, then mailbox. In goose-ngfx, NoGraphicsAPI's `DeviceDesc` gains `vsync`
  (immediate, else mailbox, else FIFO when false), and `ngfx::open`'s `NO_VSYNC` sets it
  (task 074).
- Upstream: `no-vsync-immediate`, on upstream `main`, also in `upstream-series` and the
  fork's `ngfx`; `DeviceDesc::vsync` to `sebbbi/NoGraphicsAPI` from
  `kaitk/NoGraphicsAPI`.

## goose_gfx: no gamepad (2026-11-11)

The release's goose_gfx (`v1`, which Goose v2026.4 carries) reads the keyboard, the mouse,
and touch, but no gamepad. Upstream `main` has gamepads since `d623f66`: it starts SDL's
gamepad subsystem, opens pads into four slots, and has `gamepad_down`, `pressed`, `axis`
and the rest. The fork's `main` brings them (2026-11-12), but the release's `gfx.goose`
doesn't declare them.

- Here: `host::keys` declares gfx's gamepad functions itself (`src/app/keys.goose`), with
  weak stand-ins in `src/app/gfx_fork.c` for a plain `goose build`, and takes the first
  pad connected. gfx keeps a press let go between two frames as its edge. The stick as
  the D-pad, past half way and let go under a third, stays in `keys.goose`. Until
  2026-11-12 the program's own C (`src/app/pad.c`, since deleted) opened the pad through
  SDL, alongside gfx.
- At rest with a gamepad open: SDL's event wait reads the gamepads every 1 ms while one is
  open (SDL_events.c's `EVENT_POLL_INTERVAL_NS`, the default for games), and on the Mac its
  HIDAPI thread takes a PS5 pad's reports as they stream: the idle app used 1.0 s of CPU in
  20 s (5% of a core; none without the pad). The fork's gfx turns
  `SDL_HINT_AUTO_UPDATE_JOYSTICKS` off and reads the pads itself in `frame()`, and in its
  idle wait every 16 ms while focused, ending the wait only on a press or a stick moved a
  quarter of its way (`gamepad-wake`): 0.4 to 0.6% of a core on
  Windows with a PS5 pad (0.56% with `gamepad-wake`, 2026-11-12). The program opens gfx
  with `SYSTEM_GAMEPADS` (`gamepad-wake`): HIDAPI off on Apple's systems and Android, so
  the system reads the pad and wakes the wait. On Apple's systems gfx sets each pad's
  GameController `valueChangedHandler`, which ends the wait when a button changes or a
  stick leaves or comes back to the middle (pad.c's handler measured 0.01 s in 20 s on the
  Mac); on Android, Android's input events reach SDL from its Java side as they happen, and
  end the wait. The Mac's, the tablet's and iOS's numbers with gfx's handler are to
  measure.
- Upstream: `gamepad-wake`, one branch on `ios-run-loop-wait` (which needs
  `draw-on-demand`'s idle wait first): gfx reading the pads in `frame()` and its idle wait
  instead of SDL every millisecond, and `SYSTEM_GAMEPADS`, opt-in as it trades the HID
  drivers' features for a free rest.
  Whether to also add `gamepad_*` to the release's `gfx.goose` is the next release's.

## Goose: no way to write `goose.h` for a build of one's own (2026-11-11)

A package's C that takes a `u8[>..]&` includes `goose.h` (`gs_rref`, `gs_bld_append`),
which the compiler writes only beside the native parts it builds itself. `goose -o`
with `--emit-runtime` gives a program's C and the runtime's for a build of one's own (the
iOS and Android builds here), but no `goose.h`, and `--header` writes a C host's header
without `gs_bld_append`. goose-ngfx's C needs it on iOS. Goose v2026.4.

- Here: `scripts/ios.py`'s `goose_h` takes the `goose.h` the compiler wrote for
  goose-ngfx's Mac build under `~/.goose/build/pkg/local/`, so the ngfx tree's blob
  compiler (`scripts/ngfx.py`) has to have run first.
- Upstream: `goose --emit-header goose.h`, beside `--emit-runtime`.

## goose_gfx: no window without its GPU device (2026-11-11)

`gfx::open` makes an SDL_GPU device and claims the window for it, and `frame()` presents
through it, so another renderer can't draw into gfx's window and keep gfx's input,
events, time, and draw-on-demand wait. goose-ngfx copied gfx's platform half over an SDL
of its own instead, which puts two SDLs in one process and keeps the two renderers out
of one executable. goose_gfx `v1`, Goose v2026.4.

- Here: `kaitk/goose_gfx`'s `window-only` adds the flag `WINDOW_ONLY` (64): the
  window and no device; `gs_gfx_native_window()` (a `CAMetalLayer` from an SDL Metal
  view on Apple's systems, the `HWND` on Windows, the `ANativeWindow` on Android, none
  headless); on Linux, `window-only-linux` stacked on it, the `wl_surface` on Wayland or
  the X11 window's number, with `gs_gfx_native_display()` its `wl_display` or `Display*`
  and `gs_gfx_native_kind()` which (`NATIVE_WAYLAND` 1, `NATIVE_X11` 2), whichever video
  driver SDL chose; `gs_gfx_presented(shown)`, which the renderer calls each frame so a frame
  that showed nothing makes the next `frame()` wait; and `gs_gfx_needs_present()`, set
  when the window is exposed, shown, or resized. `screen_size()` is the window's size in
  pixels; the calls that need the device are misuses in this mode. The Goose side is the
  program's own externs, as for 0004.
- Upstream: the flag and the three calls in `gfx.goose`. It is also how a program would
  choose its renderer at run time: gfx opens the window first, and then either another
  renderer or gfx's own device draws into it (the device claiming the window later).

## ngfx: no MSAA, since NoGraphicsAPI has none (2026-11-11; fixed in the fork 2026-11-12)

NoGraphicsAPI's textures take no sample count and it has no resolve, so ngfx has neither
(`docs/api.md` in goose-ngfx lists MSAA among what is gone). The 3D board's forward pass
is drawn with 4× MSAA on gfx and resolved without a store (patch 0005). goose-ngfx
v0.3.0, NoGraphicsAPI `0400414`.

- Here: the ngfx build draws the 3D pass at 1x and antialiases it after with SMAA 1x
  (`third_party/smaa/`) or 2 × 2 supersampling by `--aa`; SMAA by default, closest
  to the MSAA for half supersampling's cost (task 065 has the comparison).
- Upstream: MSAA in NoGraphicsAPI (a sample count in `TextureDesc`, and a resolve, on
  Metal 4 and Vulkan), then in ngfx's `TextureDesc` and `PassDesc`: a branch of its own
  in the user's fork, `kaitk/NoGraphicsAPI`, to offer upstream (goose-ngfx `docs/design.md`).
- Done in the fork (2026-11-12): the branch `msaa` on upstream `main` (`TextureDesc` and
  the PSOs' `sample_count`, `TextureUsage::transient`, `ColorAttachment::resolve_view`, a
  test), merged into `ngfx`; goose-ngfx's `TextureDesc.samples`, `TRANSIENT`, and
  `PassDesc.resolve`. The ngfx build draws MSAA by default now
  ([decisions](decisions/rendering.md)); SMAA stays a choice. Upstream: the `msaa` pull
  request, once tested on Vulkan (task 077).

## ngfx: `generate_mips` takes no sRGB texture (2026-11-11)

ngfx's `generate_mips` is a compute pass that writes each level through a storage view,
and neither Vulkan nor Metal allows an sRGB format as storage, so an `RGBA8_SRGB` texture
gets no mips from it. The 3D board's baked surfaces are sRGB with mips, which SDL_GPU's
mip blits average in linear light. goose-ngfx v0.3.0.

- Here: `src/ngfx/shaders/mip.slang` draws each level as a pass into it, the average of
  the 2 × 2 texels under it in the level above, read with `Load`, so the sRGB target
  averages in linear light as the blits do (`render3d::mip_chain` in
  `src/ngfx/render3d/render3d_gpu.goose`).
- Upstream, in goose-ngfx (its `docs/design.md`, "Open"): a UNORM texture with a mutable
  format, an sRGB view to sample and a UNORM storage view, with the conversion in the
  compute shader; or `generate_mips` drawing levels as passes for formats that can't be
  storage, as this does.

## Goose: `pad` and `block` are keywords everywhere (2026-11-11)

`pad` (a struct's padding bytes) and `block` (`block { }`, an expression) are reserved
throughout, though each means something only in one place: `pad` in a struct body,
`block` before a `{`. Both are common names in graphics code, a root struct's padding
field and a shader's uniform block, and both came up porting the renderer to goose-ngfx.
The error names the word, though `block` adds a second, confusing one:

```goose
fn main() { let block = 1; print(block); }
// error: expected identifier in variable declaration, found 'block'
// error: expected '{' in block expression, found ')'
```

Goose v2026.4 (`6c1fbc7`); both are in `reference.md`'s keyword list, so this is by the
spec, a request rather than a bug.

- Here: other names (`pad0` and `pad1` in the ngfx build's roots), and `agents/goose.md`
  lists both.
- Upstream: make them contextual, as `inline` and `checkfree` are (a keyword only before
  `fn`): `pad` only as a struct body's field, `block` only before `{`.

## Goose: `embed_shader`'s GLSL lacks two conversions, and its Metal translation an inout swizzle (2026-11-11)

Compiling SMAA's reference shader (`third_party/smaa/SMAA.hlsl`, its GLSL 3 path) for
the gfx build on v2026.4, cute_spirv refuses `float(b)` of a `bool` ("cannot convert
'bool' to 'float'") and `bvec2(v)` of a `vec2`, both GLSL 4.50; it also has no
`textureLodOffset` or `textureGather`. A swizzle passed as an `inout` argument
(`f(v.xy)` against `void f(inout vec2 x)`) compiles, but the MSL it makes fails when
the pipeline is made on the Mac ("non-const lvalue reference ... cannot bind to a
temporary"):

```glsl
void f(inout vec2 x) { x += 1.0; }
void main() { vec4 v = vec4(0.0); f(v.xy); result = v; }   // fails at gfx::pipeline on Metal
```

- Here: `tools/smaa_glsl.py` writes `src/render3d/smaa.glsl` from the unchanged
  SMAA.hlsl with those six spots rewritten (a ternary, `greaterThanEqual`, the swizzles
  through locals), and `src/render3d/smaa.goose` maps SMAA's sampling macros onto
  `textureLod` with the offset added to the coordinate (task 071).
- Upstream: `float(bool)`, `bvecN(vecN)`, `textureLodOffset`, and `textureGather` in
  cute_spirv; an inout swizzle copied in and out through a temporary in the MSL.

## Goose: an `export fn` called back from C inside an `extern` call overwrites the caller's data stack (2026-11-10)

A Goose function that calls an `extern fn`, whose C calls an `export fn` of the same
program, loses what its own resizables hold: the exported function's resizables are
pushed over them. Found on v2026.4, reduced to:

```goose
extern fn decode() -> bool;                      // C: calls take_pixels(...), returns 1
export fn take_pixels(px: const u8[:]) {
    var tmp: u8[>..] = [];
    for i in 10 { tmp.push((i + 100) as u8); }
}
fn main() {
    var keep: u8[>..] = [];
    keep.push(7);
    decode();
    print(keep[0]);                              // prints 100, not 7
}
```

The export's wrapper seems to start from the data stacks' base rather than their tops.

- Here: no callbacks into Goose. The season's photograph is handed from its decoder
  (`src/app/background.c`) to the renderer's own C (`src/app/photo.c`), which uploads
  it, so the embedded bytes still reach the GPU with no copy (task 061).
- Upstream: a re-entrant export continues from the stacks' tops where a Goose call is
  under way on the thread, or the spec says that an export may not be called while one
  is.

## SDL: `SDL_WaitEventTimeout` polls every millisecond on iOS (2026-11-10)

UIKit's video driver has no `WaitEventTimeout` and no `SendWakeupEvent`, so
`SDL_WaitEventTimeoutNS` falls back to polling: `SDL_PumpEvents`, which runs the run loop
for 2 µs (`UIKit_PumpEvents`), and a 1 ms sleep (`EVENT_POLL_INTERVAL_NS`), a thousand
times a second. With patch 0002's idle wait the iPhone 13 mini's app at rest used 16% of
a core, 8.8% on the main thread and about 2.4% on each of three others, though its loop
passed once a second and drew nothing (task 057). SDL 3.4.16 (`fa2c02b`).

- Here: `kaitk/goose_gfx`'s `ios-run-loop-wait`. On iOS the idle wait
  pumps once and, with no event queued, runs the main run loop itself
  (`CFRunLoopRunInMode(kCFRunLoopDefaultMode, timeout, true)`), which sleeps until a
  source fires (a touch, the system) or the timeout. An event pushed from another thread,
  such as an SDL timer's (`src/app/wake.c`), reaches an event watch that signals a run
  loop source of gfx's own and wakes the main run loop; a signalled source stays pending
  until handled, so a push just before the wait isn't lost. At rest 0.08% of a core in a game
  on either board, and the other threads near nothing too.
- Upstream: in SDL, for the user only (see the swapchain entry): a UIKit
  `WaitEventTimeout` that runs the run loop for the timeout, and a `SendWakeupEvent`
  that signals a source and wakes it, as Cocoa's does with an `NSEvent`. Until then, the
  same in goose_gfx's idle wait if it goes upstream with 0002.

## SDL: a size change while in the background leaves the window black on return (2026-11-09)

Turned in the background (another app open, the screen rotated there), the app came back
black and spun at a core and a half, on the Galaxy A33 and the Pixel 7a, flat board or
3D. Android destroys the app's surface when it leaves; the size change then marks SDL's
swapchain for recreating, and on return the first acquire recreates it before anything
has found the surface lost. `VULKAN_INTERNAL_CreateSwapchain` queries the old surface,
gets `VK_ERROR_SURFACE_LOST_KHR` from `vkGetPhysicalDeviceSurfaceCapabilitiesKHR`, and
fails, without asking for a new surface; every acquire after it fails the same way, and
gfx keeps trying each frame (`0002`). A resume with no size change works, because there
the acquire itself gets `SURFACE_LOST` and recreates both. SDL 3.4.16 (`fa2c02b`).

- Here: `patches/SDL/0004-recreate-a-lost-surface-on-resize.patch`: when the swapchain's
  surface query fails and the surface reports lost, `CreateSwapchain` marks the surface
  and swapchain for recreating and returns `TRY_AGAIN` (no image this frame), as the
  acquire does on `SURFACE_LOST`. On the A33 the frame after the return gets no image,
  the next presents at the new size, and the app is idle after: turned either way, home
  and the game, flat and 3D.
- Upstream: for the user only, as with the other SDL entries.

## SDL: a non-square texture's last mip is blitted at zero size, which loses the device on a Mali-G68 (2026-11-09)

`VULKAN_GenerateMipmaps` blits each level from the one above at `width >> level` by
`height >> level`, never less than 1. The full chain runs to the longer side's 1 pixel, so
a texture wider than tall ends in levels of height 0: the 3D board's mitred frame map,
2048 × 1152 with 12 mips, ends in a 1 × 0 blit (the validation layer:
`VUID-vkCmdBlitImage-dstOffsets-12519`, a zero-extent region). The Pixel 7a's Mali-G710 and
the tablet's G615 skip it; the Galaxy A33's Mali-G68 (driver on Android 16) faults, and
the device is lost in the 3D board's first bake at launch. Nothing waited for a fence
after it while the board stood still, so the board showed and the app looked fine; the
first frames drawn back to back (any transition, a piece moving) failed their swapchain
acquire with `VK_ERROR_DEVICE_LOST`, and the app froze, spinning (the next entry).
SDL 3.4.16 (`fa2c02b`).

- Found on the A33 with the Khronos validation layer (the Android release's
  `libVkLayer_khronos_validation.so` added to a test APK's `lib/arm64-v8a/`, gfx's debug
  mode on), and a log of each `gfx::flush`'s wait: the first, in the bake, already
  returned the loss.
- Here: `render3d::baked` asks for the chain down to the shorter side's 1 pixel (11 mips
  for the frame map, ending 2 × 1), so no level is empty. Nothing samples that far down;
  the Mac's shots are byte for byte the same.
- Upstream: for the user only, as with the other SDL entries: `SDL_max(1, ... >> level)`
  for both offsets' x and y (and depth for 3D) in `VULKAN_GenerateMipmaps`.

## goose_gfx: a lost device makes `frame()` spin, submitting work that never runs (2026-11-09)

Once the GPU device is lost every fence wait and submit fails at once. With draw on
demand (`0002`) a frame whose present fails while it drew tries again next frame without
waiting, so a program drawing each frame ran about 12,000 frames a second on the Galaxy
A33, each submitting work; the Mali driver's per-submit records filled the native heap
(550 MB) until malloc failed, while the screen stayed frozen. goose_gfx `6cfa3de`.

- Here: `kaitk/goose_gfx`'s `end-on-device-lost`: `gfx_sdl_fail`, which every
  failed SDL call goes through, notes an error naming `DEVICE_LOST`, prints it once, and
  sets quit; `frame()` then returns false before presenting or submitting anything, as
  for a closed window. The app's loop ends, it writes the game, and SDL finishes the
  activity: the app closes, and the next start restores the game. On the A33 with the
  loss brought back the app ended 1 s after it, idle. Recreating the device was left out.
- Upstream: the same in goose_gfx, or a `gfx::lost()` a program can check to rebuild its
  resources on a new device.

## goose_gfx and SDL: no pipeline cache, and pipelines made only on first use (2026-11-09)

goose_gfx makes a pipeline's SDL_GPU pipeline when it is first bound in a pass, one per set
of target formats, and SDL_GPU's Vulkan backend calls `vkCreateGraphicsPipelines` with
`VK_NULL_HANDLE` for its cache: there is no `VkPipelineCache`, nothing kept on disk, and
no call to make a pipeline ahead of a pass. So each launch pays every compile again on the
frame that first draws with it: on the Pixel 7a the 3D board's bake pipeline is most of
its 0.71 s cold bake (0.15 s warm), and its pass's pipelines most of its 0.31 s first frame
(task 015). goose_gfx's tables aren't thread-safe either, so a Goose worker can't make
them. goose_gfx `6cfa3de`, SDL as goose_gfx pins it, Goose v2026.4.

- Here: when the 3D board is needed the app makes it ready a step a frame, each pipeline
  bound alone in a pass on 4 × 4 targets of its formats (`render3d::warm`), a still mark in
  the board's place meanwhile (`draw3d::prepare`, task 042). The bake's pipeline is one
  compile and stays one step: about 0.55 s on the Pixel 7a.
- Upstream, for goose_gfx: `gfx::prepare(pipeline, formats...)` to make one ahead of a
  pass. For SDL (the user decides): a pipeline cache in SDL_GPU (a `VkPipelineCache`
  saved and loaded with its data blob, Metal's binary archives), which would take the
  compiles off every launch after the first.

## SDL: SDL_GPU refuses the iOS simulator's Metal device (2026-11-09)

`METAL_CreateDevice` on iOS requires `[device supportsFamily:MTLGPUFamilyApple3]`, and
the simulator's device answers no for it (and for `MTLGPUFamilyMac2`), so
`SDL_CreateGPUDevice` fails with "Device does not meet the hardware requirements for
SDL_GPU Metal" and nothing can be tried in the simulator. Its device draws on the Mac's
GPU, and with the check passed it draws `poc/poc.goose` and the app as the Mac does.
SDL 3.4.16 (goose_gfx `6cfa3de`'s pin), Xcode 26.4, the iOS 18.3 simulator.

- Here: `patches/SDL/0005-metal-on-the-ios-simulator.patch` accepts the device under
  `TARGET_OS_SIMULATOR`, which only the simulator's build compiles; a device build is
  unchanged.
- Upstream (a note for the user, who decides): the same under `TARGET_OS_SIMULATOR`, or a
  property to skip the check, as `SDL_PROP_GPU_DEVICE_CREATE_METAL_ALLOW_MACFAMILY1_BOOLEAN`
  does for old Macs.

## SDL: a rotation on iOS stretches the picture (2026-11-09)

When an iPhone turns, UIKit animates the root view's bounds from the old size to the new
alongside its rotation. SDL's view is that root view and its layer a `CAMetalLayer`,
whose `contentsGravity` is the default `kCAGravityResize`: the program draws once at the
new size (`layoutSubviews` sets the drawable size and SDL sends the resize), and that
frame is scaled to every size the animation passes through, so the board is squeezed to
a column and widens back. Filmed in the simulator (`simctl io recordVideo`, the turn asked
by `requestGeometryUpdateWithPreferences` from a throwaway file). SDL 3.4.16.

- Here: `patches/SDL/0006-metal-contents-unstretched-while-rotating.patch` sets the
  layer's gravity to `kCAGravityCenter` in `viewWillTransitionToSize` and back to resize
  in the transition's completion: the frame turns whole at its own size, as UIKit apps
  turn, with black corners showing meanwhile. Outside a transition nothing changes.
- Upstream (a note for the user, who decides): the same in SDL's UIKit view controller,
  or `kCAGravityCenter` for good on the Metal view, whose drawable always matches its
  bounds outside an animation.

## goose_gfx: no compressed texture formats (2026-11-08)

gfx's formats are uncompressed only: `gfx_texture_format` maps none of SDL_GPU's BC or
ASTC formats, `update_texture` counts bytes as texels × `SDL_GPUTextureFormatTexelBlockSize`
(a block's bytes, wrong for a block of 4 × 4 or 6 × 6 texels), it uploads with
`pixels_per_row` set to the region's width (Vulkan wants a row length that is a
multiple of the block's width: 2048 isn't one of 6), and there is no way to ask whether
the GPU samples a format before making a texture of it (`create_texture` fails, the
cause in `error()`). A 2048² photograph is 16 MiB as RGBA8 against 1.8 MiB as ASTC 6 × 6,
which the tablet's Mali, phones, and Apple silicon sample. goose_gfx `6cfa3de`,
Goose v2026.4.

- Here: `kaitk/goose_gfx`'s `compressed-textures` adds the formats `BC1`, `BC3`,
  `BC7`, `ASTC_4x4`, `ASTC_5x5`, `ASTC_6x6`, `ASTC_8x8` (21 to 27, UNORM; sampled only,
  no mips generated, not read back), counts bytes in whole blocks
  (`SDL_CalculateGPUTextureFormatSize`), uploads tightly packed (`pixels_per_row` 0,
  which every backend takes as tight and in whole blocks), and adds
  `gs_gfx_format_supported(format, usage)` (`SDL_GPUTextureSupportsFormat`). Vulkan
  needs no device feature for it: with `textureCompressionASTC_LDR` not enabled, the
  spec still lets a device report and use single formats through
  `vkGetPhysicalDeviceFormatProperties`, which is what SDL checks. The Goose side
  compiles against the built-in `gfx.goose`, which lacks both, so the program's C calls
  gfx's C API itself (`src/app/background.c`), with a weak stand-in for
  `gs_gfx_format_supported` that answers no where gfx lacks the patch: a plain `goose
  build` links the release's prebuilt `libgoose_gfx.a` and decodes the JPEG, as an Intel
  Mac or a BC-only GPU would. `scripts/mac.py` links a `libgoose_gfx.a` built from the
  patched sources into a copy of the release, which gives the Mac the ASTC path
  (2026-11-10).
- Upstream: the formats and `format_supported` in `gfx.goose` and the header, the byte
  count and upload in blocks, and `texel_size` (Goose side) returning a block's bytes
  for a block format, or a `format_bytes(format, w, h)`. Perhaps loading a `.astc` or
  `.ktx2` from bytes.

## goose_gfx: `ui`'s font atlas is RGBA32 only, its height a power of two (2026-11-08)

`gs_ui_bake_font_atlas` always asks Nuklear for `NK_FONT_ATLAS_RGBA32` (white, the
coverage in alpha) and keeps a copy, which `atlas_pixels` copies out again; Nuklear rounds
the height up to a power of two. A program that uploads the image itself, as Draughts
does, gets four bytes a texel where one would do and up to twice the rows the glyphs use:
on the tablet 1024 × 2048 RGBA, 8 MiB, for 1846 rows of coverage, and three such buffers
(Nuklear's, `ui`'s copy, the program's) while baking.

- Here, no patch (the Mac's `goose` has its own `ui` built in): the app moves the alpha to
  the front of the buffer `atlas_pixels` returned, in place, and uploads only the rows
  the glyphs reach as an R8 texture, its v remapped from whole rows (`src/app/text.goose`).
- Upstream: a format choice on `bake` (`NK_FONT_ATLAS_ALPHA8`, which Nuklear has) and the
  used height beside `atlas_size`; `ui`'s own renderer would then need a coverage-only
  texture path.

## SDL: SDL_GPU's Vulkan allocator rounds large resources up to 64 MiB blocks (2026-11-08)

`VULKAN_INTERNAL_BindResourceMemory` puts a resource up to 2 MiB
(`SMALL_ALLOCATION_THRESHOLD`) in shared 16 MiB blocks, and gives a larger one a new
`VkDeviceMemory` rounded up to a multiple of 64 MiB (`LARGE_ALLOCATION_INCREMENT`), whose
free space later large resources share. A block is given back only once it is empty. On a
GPU with one memory type, as Mali's, a 2D app's few large resources take a whole block:
on the tablet (1920 × 1200) the screen, the photograph, and the text atlas are 34 MiB in a
64 MiB block, and the largest tablet's (2880 × 1920: screen 21 MiB, atlas 32) would need
two. SDL 3.4.16 (`fa2c02b`).

- Here: `patches/SDL/0003-large-allocations-at-their-size.patch` gives a resource over
  2 MiB its own `VkDeviceMemory` of exactly its memory requirements' size, as SDL already
  does for transfer buffers (`dedicated`), and keeps such allocations, transfer buffers'
  too, out of the free list, so nothing else is placed in one and it goes back to the
  driver at a submit soon after its resource is released. Small resources keep the
  shared 16 MiB blocks. SDL has no `VK_KHR_dedicated_allocation` plumbing, so the patch
  doesn't add `VkMemoryDedicatedAllocateInfo`. On the tablet GL mtrack after an animation
  went from 94.4 to 63.6 MB and stays there through rotations and season changes (PSS
  about 31 MB lower everywhere); frame times of moves and season changes unchanged. Large allocations happen only at load, on a season
  change, and on a resize. Rounding to 4 or 8 MiB instead was weighed and rejected
  (`docs/architecture/rendering.md`, GPU memory).
- Upstream: for the user only, as with the other SDL entries. Upstream's rounding suits
  a discrete GPU with many large resources; a threshold over which allocations are
  dedicated (as VMA does for resources over half a block) would serve both.

## goose_gfx: an MSAA pass stores its samples and depth, and cycles them (2026-11-09)

`begin_pass` gives a color target with a resolve texture `RESOLVE_AND_STORE`, every depth
and stencil target `STORE`, and cycles whatever it clears. On a tiler (Mali) the tile
memory holds the samples, so storing them writes them all out: a 4x target at 1920 x 1200
is about 74 MB of samples and depth to memory every drawn frame. Arm's Mali best practice
for MSAA is a transient multisampled target, `DONT_CARE` stores, and the resolve in the
same pass, at about 1-2% of the cost of rendering without it. Cycling a clear can also keep
a second copy of the 4x target for good. goose_gfx `6cfa3de`, Goose v2026.4.

- Here: `kaitk/goose_gfx`'s `msaa-resolve-without-store`, inside `begin_pass`
  only, so Goose code compiles against the release's `gfx.goose` unchanged. A color target
  with a resolve texture stores `RESOLVE` (samples discarded); a depth target of more than
  one sample stores `DONT_CARE` for depth and stencil (SDL asserts that a multisampled
  texture has no SAMPLER usage, so nothing can read it later; gfx's own check says the
  same); neither is cycled on clear. Single-sampled depth keeps `STORE`, for shadow maps.
  A program that loads a multisampled depth in a later pass (`clear_depth` off) now gets
  undefined contents. Not yet measured on the tablet.
- Upstream: the same defaults in goose_gfx, or fields in `PassDesc` for the store ops and
  `cycle`.
- Note for the user (SDL, your call): at the pinned commit SDL resolves in the pass, but its
  Vulkan backend never uses transient or lazily allocated memory for a target, and adds
  transfer usage to every texture, so the 4x target still costs its real bytes; the patch
  saves the bandwidth, not the memory.

## goose_gfx: the screen always has a depth target, and is cycled every frame (2026-11-08)

`gfx_create_screen` makes a window-sized depth target (D32F where supported) beside the
RGBA8 screen, whether or not the program ever asks for `screen_depth()`, and remakes both
on every resize. `begin_pass` sets `cycle` on every color target it clears, the screen
included; since the last frame's blit nearly always still reads the screen when the next
frame clears it, SDL_GPU's Vulkan backend keeps a second (or third) window-sized copy
for good. On the tablet (Mali-G615, one memory type) SDL puts any resource over 2 MiB in
a block rounded up to 64 MiB; the screen, its depth, and their copies and remakes after
the first rotation needed a second such block: graphics 156.6 MB fresh, 207.5 MB after
a rotation. goose_gfx `6cfa3de`, Goose v2026.4.

- Here: `kaitk/goose_gfx`'s `screen-without-depth` makes the screen's
  depth target the first time `screen_depth()` is called (so `begin_screen` still works;
  the POC uses it), and from then on with each resize; and clears the screen without
  cycling. Not cycling is safe: SDL's barrier orders the clear after the last frame's
  blit on the GPU, and the CPU never waits. The app begins its pass with
  `gfx::begin_pass(gfx::screen(), gfx::Texture { 0 }, clear)`. Graphics after an
  animation and a rotation: 207.5 → 138.9 MB, PSS 265 → 196 MB; frame times of a move at
  90 Hz unchanged.
- Upstream: both in goose_gfx. Make the screen's depth lazily as here, or take a flag
  in `gfx::open`; and don't cycle the screen in `begin_pass` (a program-made target that
  is cleared each frame may still gain from cycling). A `cycle` field in `PassDesc`
  would let a program choose.

## goose_gfx: no safe area and no display scale (2026-11-08)

A phone's camera cutout and gesture bar take part of the window, and its density says
how large a pixel is; goose_gfx exposes neither, so a program can't keep its taps out
of the cutout or size them in millimetres. SDL has both: `SDL_GetWindowSafeArea` (on
Android from the window's insets: cutout, system bars and gestures) and
`SDL_GetWindowDisplayScale` (Android's density / 160, 2.625 on the Pixel 7a; on a Mac's
Retina screen 2.0, the pixel density 2 times a content scale of 1.0; a Mac window's safe
area is all of it). goose_gfx `6cfa3de`, Goose v2026.4.

- Here: no patch. A gfx patch can't add a function the program calls: the program's Goose
  is compiled against the release's own `pkg/gfx/gfx.goose` on both platforms, and a
  desktop run uses the gfx built into the goose binary (`agents/goose.md`). So the
  program's own C (`src/app/display.c`) finds the window with `SDL_GetWindows` once and reads
  both each frame, through `dlsym` on the Mac as `src/app/locale.c` does. A safe-area change
  wakes the loop with SDL's `SDL_EVENT_WINDOW_SAFE_AREA_CHANGED`, and the program, seeing
  new insets, draws again.
- Upstream: `gfx::safe_area() -> float4` (the insets in pixels: left, top, right,
  bottom, from `SDL_GetWindowSafeArea` scaled by the pixel density) and
  `gfx::display_scale() -> f32` (`SDL_GetWindowDisplayScale`), declared in
  `src/gfx/gfx_api.h` and `gfx.goose` as the other window queries are; and a safe-area
  change counted as a resize where `frame()` reports one. Small.

## SDL: the Android safe area includes the system gestures' strips (2026-11-08)

`SDLSurface.onApplyWindowInsets` makes the safe area from `systemBars | systemGestures |
mandatorySystemGestures | tappableElement | displayCutout`. With gesture navigation,
`systemGestures` holds the back gesture's strips down both sides, which Android's docs
say still pass taps to the window, so a portrait phone's safe area loses tens of dp of
its width for no tap's sake. With the bars hidden, `mandatorySystemGestures` still holds
the strip at the top a swipe pulls them down from, where taps reach the window too (on
the Pixel 7a 150 px in portrait, 32 more than its camera, and 74 px in landscape). On a
Samsung tablet (the Galaxy Tab A11+) that strip is reported as `tappableElement` too
(45 px), so it stays out of the safe area through that type as well. SDL 3.4.16
(`fa2c02b`).

- Here: `patches/SDL/0002-safe-area-without-system-gestures.patch` leaves
  `systemGestures` out, and takes `tappableElement` and `mandatorySystemGestures` only
  at the sides and the bottom: `max(systemBars | displayCutout, (tap.left, 0, tap.right,
  max(tap.bottom, gestures.bottom)))`. A status bar while shown counts through
  `systemBars`. `scripts/android.py` compiles SDL's Java from the patched copy, as it
  does its C. Checked on the Pixel 7a (0, 118, 0, 84 px in portrait, 118, 0, 0, 84 and
  0, 0, 118, 84 in landscape; a tap in the old top strip reaches the app, a swipe there
  still shows the bars) and on the Galaxy Tab A11+ (0, 0, 0, 72, nothing held at the top).
- Upstream: for the user only, as with the other SDL entries. Possibly a hint choosing
  which insets make the safe area.

## SDL: launch flashes black between Android's splash and the first frame (2026-11-08)

Android 12+ removes its splash at the activity window's first draw. SDLActivity's
window is a `SurfaceView`, whose hole shows what is behind it, black or the launcher,
until SDL presents its first frame, so the theme's `windowBackground` never shows there.
On the tablet the splash fades onto 150 to 260 ms of black before the app. SDLActivity
has no hook for "first frame presented", and the colour behind a `SurfaceView`
(`setResizeBackgroundColor`) is not public API. SDL 3.4.16 (`fa2c02b`).

- Here: `DraughtsActivity` covers the window with a view of the theme's navy and, on
  Android 12+, holds the splash with `getSplashScreen().setOnExitAnimationListener`. The
  program reports its first presented frame over JNI (`src/app/launch.c`, through
  `SDL_GetAndroidActivity`), and the activity removes both then. The theme also sets
  `windowDrawsSystemBarBackgrounds` with a navy `navigationBarColor`, or the navigation
  bar's area shows the launcher's taskbar during the hand-over. On the tablet the icon on
  navy now goes straight to the first frame.
- Upstream: for the user only, as with the other SDL entries. SDL could offer the hold
  itself, keeping the splash until the first `SDL_GPU` or EGL present.

## goose_gfx: `load_texture` reads only PNG and BMP, and only from a file (2026-11-07)

`gs_gfx_load_texture` picks `SDL_LoadBMP` for `.bmp` and `SDL_LoadPNG` for anything
else, from a path. There is no JPEG, and no way to load from bytes already in memory,
such as an `embed_file`. A photograph-like background is about 5 MB as PNG and 0.5 to
0.7 MB as JPEG. goose_gfx `6cfa3de`, Goose v2026.4.

- Here: no patch. The program decodes its JPEGs with stb_image in its own C (a
  `c_sources` entry in its sidecar) and uploads the pixels through gfx's C API, which
  works with the built-in gfx on the Mac too; where the GPU samples ASTC it uploads a
  compressed copy instead (above, and
  [rendering](architecture/rendering.md#scene-and-glass)).
- Upstream: possibly `load_texture_from_memory(bytes, flags)` and JPEG through
  stb_image, which goose_gfx's Nuklear demos already carry. Small and optional.

## SDL: the Java side keeps the accelerometer on at 50 Hz (2026-11-07)

`SDLSurface.handleResume` (and `SDLActivity` at start) registers the accelerometer at
`SENSOR_DELAY_GAME` (20 ms) whenever the app is resumed, whether or not the program opens a
sensor or joystick. SDL uses it for an accelerometer joystick and to notice display
rotation. With the idle board drawing nothing, it is what remains: on the tablet the Java
main thread woke 52 times a second for 1.1 to 1.3 s of CPU a minute, the program's thread
0.02 s, plus the sensor's power. SDL 3.4.16 (`fa2c02b`).

- Here (2026-11-08): no patch. SDL's Java has a hook: `DraughtsActivity` overrides
  `createSDLSurface` to return a subclass of `SDLSurface` whose `enableSensor` ignores
  `TYPE_ACCELEROMETER`, which covers both the start and every resume. Nothing in the app
  needs it: the program opens only video (and audio), no joystick, so the accelerometer
  joystick never exists; and the screen turns because Android rotates the activity
  (SDL requests `FULL_USER`) and the surface's new size reaches the program as a resize.
  What is lost is SDL's display orientation (`SDL_GetCurrentDisplayOrientation`,
  `SDL_EVENT_DISPLAY_ORIENTATION`), which then stays at the launch's; neither gfx nor the
  app reads it. On the tablet our process has no sensor connection while resumed
  (`dumpsys sensorservice`), the main thread does no work at idle, and the whole process
  takes 0.05 to 0.06 s a minute; portrait, landscape, and the flipped landscape still lay
  out right.
- Upstream: for the user only, as with the other SDL entries. Register the accelerometer
  only while a sensor or the accelerometer joystick is open, and learn the rotation from a
  `DisplayManager.DisplayListener` instead.

## SDL: `SDL_WaitEventTimeout` busy-waits on Android (2026-11-07)

On Android every pass of the wait loop in `SDL_WaitEventTimeoutNS` calls
`SDL_PumpEventsInternal(true)`, which takes the poll sentinel out of the queue and pushes
a new one. Pushing any event calls `SDL_SendWakeupEvent`, which on Android queues a
lifecycle WAKE event, and that WAKE ends `Android_PumpEvents(delay)` at once. So the loop
never blocks: on the tablet a 1 s wait used a whole core (1814 s of CPU in 30 minutes,
no voluntary context switches). SDL 3.4.16 (`fa2c02b`).

- Here: patch 0002 sets `SDL_HINT_POLL_SENTINEL` to `"0"` on Android before video init.
  With no sentinel nothing is pushed while waiting, and the wait blocks until an event or
  the timeout: one wakeup a second, 0.41 s of CPU in 30 minutes idle. gfx's
  `SDL_PollEvent` loop drains the queue the same way without the sentinel.
- Upstream: for the user only, under SDL's rule on AI-written reports (see the swapchain
  entry). The likely fix is in SDL: don't push a sentinel inside the wait loop, or don't
  send a wakeup for the sentinel. Check first whether a newer SDL fixes it.

## goose_gfx: `frame()` presents every frame, so an idle program redraws at the display rate (2026-11-07)

`gs_gfx_frame` presents the screen and polls events on every call, whether or not
anything was drawn since the last one. A program that draws only on change still
acquires a swapchain image and blits the screen each frame, and without the present's
vsync wait its loop would spin. There is no way to wait for an event instead. goose_gfx
`6cfa3de`, Goose v2026.4.

- Here: `kaitk/goose_gfx`'s `draw-on-demand`. `frame()` presents only when
  something used the GPU since the last call or the window needs the screen again, and
  after a frame that drew nothing it waits for an event (up to 1 s) before reading
  events. On the tablet an idle program went from a present at every 90 Hz refresh to 5
  `frame()` returns and no presents in 5 seconds, and a tap still wakes it at once
  ([rendering](architecture/rendering.md#frames-and-battery)). The first version lost
  the picture on resume: the first present after Android recreates the surface gets no
  image, so the patch keeps trying for up to 8 frames. The wait also needs the next
  entry's workaround, or it spins on Android, and on iOS its own (the iOS entry above).
  Every build takes the fork's gfx since 2026-11-10 (`scripts/mac.py`, as
  `windows.py`): the Mac at rest went from 8.2% of a core, presenting at 120 Hz, to
  0.03%.
- Upstream: the same in `gs_gfx_frame`, but opt-in, since a program that polls input
  without drawing would otherwise block for up to a second: for example
  `gfx::set_wait_when_idle(true)`, or a window flag for `gfx::open`. A frame that drew
  nothing could skip the present by default, which only saves work.

## SDL: SDL_GPU's Vulkan backend leaks a swapchain on every Android resume (2026-11-07)

When Android brings the app back, SDL_GPU recreates the Vulkan surface
(`needsSurfaceRecreate` in `VULKAN_INTERNAL_AcquireSwapchainTexture`). It destroys the old
surface but not the old swapchain: `VULKAN_INTERNAL_RecreateSwapchain` frees only its
images' views, and `VULKAN_INTERNAL_CreateSwapchain` passes no `oldSwapchain` when the
surface is new, so nothing destroys it. On the tablet each home → resume leaked 28.4 MB
of graphics memory, three 1920×1200 images. Rotation doesn't recreate the surface and
didn't leak. SDL 3.4.16 (`fa2c02b`, goose_gfx's pin).

- Here: `patches/SDL/0001-destroy-swapchain-on-surface-recreate.patch` waits for the device
  and destroys the old swapchain before the old surface. `scripts/android.py` builds SDL
  from a patched copy. After it, 20 cycles hold graphics memory at 112 to 114 MB
  (task 001).
- Upstream: SDL's `CLAUDE.md` asks that no AI-generated code or text go into SDL bug
  reports or pull requests. So the report is the user's own, in their own words, if they
  send one. Check first whether a newer SDL already fixes it.

## Goose: no way to ask which platform the program runs on (2026-11-07)

The program needs to know it's on Android to open full screen (SDL then hides the system
bars) while keeping a resizable window on the Mac.

- Here: the program's C answers, from the compiler's own macros (`draughts_platform` in
  `src/app/launch.c`: `__ANDROID__`, and `TARGET_OS_IPHONE` for iOS, 2026-11-09). The
  POCs still read `env("ANDROID_ROOT", ...)`, true in every Android app process.
- Upstream: possibly an `os` function naming the platform, if more than one program needs it.

## goose_gfx: SDL_GPU requires `shaderClipDistance`, which Mali GPUs lack (2026-11-07)

`gs_gfx_open` calls `SDL_CreateGPUDevice`, which asks for SDL_GPU's default Vulkan features.
`shaderClipDistance` is among them, and the Galaxy Tab A11+'s Mali-G615 doesn't support it,
so `gfx::open` fails with "No supported SDL_GPU backend found!". Goose's GLSL never writes
`gl_ClipDistance`.

- Here: `kaitk/goose_gfx`'s `no-clip-distance` creates the device with properties and the
  feature off.
- Upstream: the same change in goose_gfx, on every platform. Nothing in goose_gfx's API
  can use clip distances, so it costs nothing elsewhere.

## goose_gfx: `ui::input_from_gfx` opens the on-screen keyboard on Android (2026-11-07)

It turns on SDL text input every frame, for text fields. On Android that shows the
keyboard, even for a HUD with no fields.

- Here: a HUD calls `ui::input_begin` and `ui::input_end` with no input instead.
- Upstream: start text input only while a text field has focus (`ui::wants_keyboard`).

## goose_gfx: SDL is static, but SDL's Android Java loads `libSDL3.so` (2026-11-07)

goose_gfx's CMake forces a static SDL. SDLActivity loads `SDL3` and then `main` by name,
so a static SDL needs a Java subclass that overrides `getLibraries()`.

- Here: `android/CMakeLists.txt` builds SDL shared and compiles goose_gfx's sources itself.
- Upstream: possibly an Android path in goose_gfx's CMake, once more than one project
  builds for Android.

## Goose: stdout and stderr go nowhere on Android (2026-11-07)

`print`, `abort`, and runtime errors write to stdout and stderr, which Android discards.

- Here: `android/stdio_to_logcat.c` forwards both to logcat with the tag `goose`.
- Upstream: nothing needed; this is the usual Android shim.
