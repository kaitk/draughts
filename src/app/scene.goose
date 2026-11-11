// The season's photograph (docs/architecture/rendering.md, "Scene and glass"): sharp
// behind home, and blurred once on the GPU when the season is picked behind the 2D game.
// The program's C (background.c) makes the sharp texture: the built-in ASTC image where
// the GPU samples it, else the JPEG decoded. A shrinking pass averages it down to a small
// copy, and two passes of a Gaussian, across and then down, blur that into the texture
// the board pass samples behind the game. A season whose image isn't built in has no
// photograph, and the board pass shows the page color. Glass panels sample a copy
// blurred further, made at the same time. With the plain background (task 044) nothing
// is decoded, uploaded, or held: the board pass and the glass draw the fade
// (shaders::FADE_FN in src/render3d/) from the theme's colors. What is drawn is this
// file's; the passes' shaders and GPU calls are the renderer's (scene_gpu.goose).
namespace scene;
import std;
import vec;

// The blurred copy's side. The photograph is cover-cropped to the screen by its long
// side, so the blur is a fraction of that: 14 px at 1280 px (rendering.md) is a sigma
// of 5.6 texels here, at any screen size. Scaled up, a blurred image this size shows
// no texels.
let SIZE = 512;

// The sharp photograph's side where the JPEG is decoded: as it is stored, about a texel
// to a pixel across a 1920 px screen. 16 MB of graphics memory as RGBA8, 1.8 MB as the
// ASTC image (6 × 6 blocks), which keeps the size it is stored at.
let SHARP_SIZE = 2048;

// The glass copy's side, and its blur: the one a 24 px blur is at 1280 px (rendering.md,
// "Scene and glass"), 4.8 texels here, of which the 512 px copy already has 2.8.
let GLASS_SIZE = 256;
let GLASS_SIGMA = 3.9;

// A season's thumbnail in settings: the photograph's middle at the picture's 104 × 64
// shape, about a texel to a pixel at 1.5 pixels per dp; the four stacked in one texture,
// and under them the four plain fades (THUMBS slots in all).
let THUMB_W = 160;
let THUMB_H = 98;
let THUMBS = 8;

struct Scene {
    photo:   gpu::Texture,     // the blurred copy, or a 1×1 stand-in when there is none
    sharp:   gpu::Texture,     // the photograph as it is, or the stand-in
    glass:   gpu::Texture,     // the copy glass samples, blurred further
    sampler: gpu::Sampler,
    has:     bool,             // whether there is a photograph
    plain:   bool,             // the plain background chosen: no photograph, the fade
}

// The photograph of theme `kind` (theme::WOOD..SUNSET), and its blurred copies; with
// `plain`, none.
fn load(kind: i64, plain: bool = false) -> Scene {
    let sampler = scene_gpu::sampler();
    let sharp = if plain { gpu::no_texture() } else { render3d::draughts_photo(kind, SHARP_SIZE) };
    if sharp.id == 0 {
        let none = scene_gpu::black();
        return Scene { photo: none, sharp: none, glass: none, sampler: sampler, has: false, plain: plain };
    }
    let src = scene_gpu::target(SIZE, SIZE);
    let shrink = scene_gpu::shrinker();
    scene_gpu::begin(src, true);
    scene_gpu::shrink(shrink, sampler, sharp, float4 { 0.0, 0.0, 1.0, 1.0 }, float4 { 0.0, 0.0, SIZE, SIZE });
    scene_gpu::end();
    scene_gpu::done(shrink);
    let across = scene_gpu::target(SIZE, SIZE);
    let blurred = scene_gpu::target(SIZE, SIZE);
    let glass_across = scene_gpu::target(GLASS_SIZE, GLASS_SIZE);
    let glass = scene_gpu::target(GLASS_SIZE, GLASS_SIZE);
    let blur = scene_gpu::blurrer();
    let step = 1.0 / SIZE;
    scene_gpu::blur(blur, sampler, src, across, float4 { step, 0.0, 5.6, step });
    scene_gpu::blur(blur, sampler, across, blurred, float4 { 0.0, step, 5.6, step });
    // The glass copy reads the 512 px copy at half its resolution, in its own texels.
    let g = 1.0 / GLASS_SIZE;
    scene_gpu::blur(blur, sampler, blurred, glass_across, float4 { g, 0.0, GLASS_SIGMA, g });
    scene_gpu::blur(blur, sampler, glass_across, glass, float4 { 0.0, g, GLASS_SIGMA, g });
    scene_gpu::done(blur);
    gpu::release(across);
    gpu::release(glass_across);
    gpu::release(src);
    return Scene { photo: blurred, sharp: sharp, glass: glass, sampler: sampler, has: true, plain: false };
}

// Releases the scene's textures, for another season's.
fn release(s: Scene&) {
    gpu::release(s.photo);
    if s.has {
        gpu::release(s.sharp);
        gpu::release(s.glass);
    }
    gpu::release(s.sampler);
}

// The four seasons' thumbnails stacked, by theme, top to bottom, in one texture: each
// photograph's middle at the thumbnail's shape, shrunk on the GPU, one at a time; a
// season without a photograph is black. Under them the four plain fades, by theme, as
// the plain background paints them at the thumbnail's shape. A decoded JPEG (about 125 ms for the four on the
// tablet) is scaled to SIZE on the way, so its texture is small. The app makes this in
// the first frame after the launch's first that draws nothing, rather than when settings
// first open.
fn thumbs() -> gpu::Texture {
    let t = scene_gpu::target(THUMB_W, THUMBS * THUMB_H);
    let sampler = scene_gpu::sampler();
    let shrink = scene_gpu::shrinker();
    let crop: f32 = THUMB_H as f32 / THUMB_W;
    for kind in 4 {
        let photo = render3d::draughts_photo(kind, SIZE);
        // The first pass clears the whole texture; the others keep what is drawn.
        scene_gpu::begin(t, kind == 0);
        if photo.id != 0 {
            scene_gpu::shrink(shrink, sampler, photo, float4 { 0.0, (1.0 - crop) * 0.5, 1.0, crop },
                              float4 { 0.0, kind * THUMB_H, THUMB_W, THUMB_H });
        }
        scene_gpu::end();
        // One photograph at a time: as ASTC (1.8 MB) it sits in SDL's shared 16 MiB
        // block, and four at once took a second block that stayed.
        scene_gpu::let_go(photo);
    }
    scene_gpu::done(shrink);
    let fade = scene_gpu::fader();
    scene_gpu::begin(t, false);
    for kind in 4 {
        let c = theme::get(kind);
        scene_gpu::fade(fade, float4 { 0.0, (4 + kind) * THUMB_H, THUMB_W, THUMB_H }, c.fade_top, c.fade_low, c.fade_light);
    }
    scene_gpu::end();
    scene_gpu::done(fade);
    gpu::release(sampler);
    return t;
}
