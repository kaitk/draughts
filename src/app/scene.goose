// The season's photograph, sharp behind home, and its copies blurred once on the GPU for
// the game and the glass (docs/architecture/rendering.md, "Scene and glass"). With the
// plain background nothing is loaded and the fade (shaders::FADE_FN) is drawn instead.
namespace scene;
import std;
import vec;

// The blurred copy's side. The photograph is cover-cropped by the screen's long side, so
// the blur is a fraction of it: 14 px at 1280 px is a sigma of 5.6 texels here.
let SIZE = 512;

// The sharp photograph's side where the JPEG is decoded; the ASTC image keeps its own.
let SHARP_SIZE = 2048;

// The glass copy's side, and its blur: 24 px at 1280 px is 4.8 texels here, of which the
// 512 px copy already has 2.8.
let GLASS_SIZE = 256;
let GLASS_SIGMA = 3.9;

// Settings' thumbnails in one texture: the four seasons' photographs at the picture's
// 76 × 50 dp shape, under them the four plain fades, then the board pictures.
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

fn release<B>(be: B&, s: Scene&) {
    be.release(s.photo);
    if s.has {
        be.release(s.sharp);
        be.release(s.glass);
    }
    be.release(s.sampler);
}

// Settings' thumbnails (THUMB_W..THUMBS above); a season without a photograph is black.
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
        // One photograph at a time: four at once would take SDL a second 16 MiB block that stays.
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
    // The board pictures (scripts/board_thumbs.py): an atlas of slot-sized cells, a row a season.
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
