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
// file's; the passes' shaders and GPU calls are the backend's, `be.scene` (scene_gpu.goose
// on gfx; gpu.goose).
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

// A season's thumbnail in settings: the photograph's middle at the picture's 76 × 50 dp
// shape, about a texel to a pixel at 2.1 pixels per dp (the densest screen's); the four
// stacked in one texture, under them the four plain fades, and under those the board
// pictures, BOARD_PICTURES a season by theme (THUMBS slots in all).
let THUMB_W = 160;
let THUMB_H = 105;
let SEASON_SLOTS = 8;
let BOARD_PICTURES = 4;
let THUMBS = SEASON_SLOTS + 4 * BOARD_PICTURES;

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
fn load<B>(be: B&, kind: i64, plain: bool = false) -> Scene {
    let sampler = be.scene.sampler();
    let sharp = if plain { gpu::no_texture() } else { be.r3d.photo(kind, SHARP_SIZE) };
    if sharp.id == 0 {
        let none = be.scene.black();
        return Scene { photo: none, sharp: none, glass: none, sampler: sampler, has: false, plain: plain };
    }
    let src = be.target(SIZE, SIZE);
    let shrink = be.scene.shrinker();
    be.scene.begin(src, true);
    be.scene.shrink(shrink, sampler, sharp, float4 { 0.0, 0.0, 1.0, 1.0 }, float4 { 0.0, 0.0, SIZE, SIZE });
    be.scene.end();
    be.scene.done(shrink);
    let across = be.target(SIZE, SIZE);
    let blurred = be.target(SIZE, SIZE);
    let glass_across = be.target(GLASS_SIZE, GLASS_SIZE);
    let glass = be.target(GLASS_SIZE, GLASS_SIZE);
    let blur = be.scene.blurrer();
    let step = 1.0 / SIZE;
    be.scene.blur(blur, sampler, src, across, float4 { step, 0.0, 5.6, step });
    be.scene.blur(blur, sampler, across, blurred, float4 { 0.0, step, 5.6, step });
    // The glass copy reads the 512 px copy at half its resolution, in its own texels.
    let g = 1.0 / GLASS_SIZE;
    be.scene.blur(blur, sampler, blurred, glass_across, float4 { g, 0.0, GLASS_SIGMA, g });
    be.scene.blur(blur, sampler, glass_across, glass, float4 { 0.0, g, GLASS_SIGMA, g });
    be.scene.done(blur);
    be.release(across);
    be.release(glass_across);
    be.release(src);
    return Scene { photo: blurred, sharp: sharp, glass: glass, sampler: sampler, has: true, plain: false };
}

// Releases the scene's textures, for another season's.
fn release<B>(be: B&, s: Scene&) {
    be.release(s.photo);
    if s.has {
        be.release(s.sharp);
        be.release(s.glass);
    }
    be.release(s.sampler);
}

// The four seasons' thumbnails stacked, by theme, top to bottom, in one texture: each
// photograph's middle at the thumbnail's shape, shrunk on the GPU, one at a time; a
// season without a photograph is black. Under them the four plain fades, by theme, as
// the plain background paints them at the thumbnail's shape, and the board pictures. A decoded JPEG (about 125 ms for the four on the
// tablet) is scaled to SIZE on the way, so its texture is small. The app makes this in
// the first frame after the launch's first that draws nothing, rather than when settings
// first open.
fn thumbs<B>(be: B&) -> gpu::Texture {
    let t = be.target(THUMB_W, THUMBS * THUMB_H);
    let sampler = be.scene.sampler();
    let shrink = be.scene.shrinker();
    let crop: f32 = THUMB_H as f32 / THUMB_W;
    for kind in 4 {
        let photo = be.r3d.photo(kind, SIZE);
        // The first pass clears the whole texture; the others keep what is drawn.
        be.scene.begin(t, kind == 0);
        if photo.id != 0 {
            be.scene.shrink(shrink, sampler, photo, float4 { 0.0, (1.0 - crop) * 0.5, 1.0, crop },
                              float4 { 0.0, kind * THUMB_H, THUMB_W, THUMB_H });
        }
        be.scene.end();
        // One photograph at a time: as ASTC (1.8 MB) it sits in SDL's shared 16 MiB
        // block, and four at once took a second block that stayed.
        be.scene.let_go(photo);
    }
    be.scene.done(shrink);
    let fade = be.scene.fader();
    be.scene.begin(t, false);
    for kind in 4 {
        let c = theme::get(kind);
        be.scene.fade(fade, float4 { 0.0, (4 + kind) * THUMB_H, THUMB_W, THUMB_H }, c.fade_top, c.fade_low, c.fade_light);
    }
    be.scene.end();
    be.scene.done(fade);
    // The board pictures (design/boards/, scripts/board_thumbs.py): an atlas of cells the
    // slots' size, a row a season by theme, each copied into its slot as it is.
    let boards = be.r3d.photo(BOARDS, SIZE);
    if boards.id != 0 {
        let copy = be.scene.shrinker();
        be.scene.begin(t, false);
        let cell: f32 = 1.0 / BOARD_PICTURES;
        for k in 4 * BOARD_PICTURES {
            let row = k / BOARD_PICTURES;
            let col = k % BOARD_PICTURES;
            be.scene.shrink(copy, sampler, boards, float4 { col * cell, row * cell, cell, cell },
                              float4 { 0.0, (SEASON_SLOTS + k) * THUMB_H, THUMB_W, THUMB_H });
        }
        be.scene.end();
        be.scene.done(copy);
    }
    be.scene.let_go(boards);
    be.release(sampler);
    return t;
}

// The board pictures' atlas among the built-in images (background.c's BOARDS).
let BOARDS = 4;
