// The season's photograph (docs/architecture/rendering.md, "Scene and glass"), drawn
// through goose-ngfx (task 065; src/app/scene.goose is gfx's, whose comments say what
// each step is for): the sharp texture from the program's C (photo.c), shrunk to SIZE,
// blurred across and down into the copy behind the game, and further into the copy the
// glass samples. The shaders are src/ngfx/shaders/, built ahead (scripts/ngfx.py).
namespace scene;
import std;
import vec;
import ngfx;

let SIZE = 512;
let SHARP_SIZE = 2048;
let GLASS_SIZE = 256;
let GLASS_SIGMA = 3.9;
let THUMB_W = 160;
let THUMB_H = 98;
let THUMBS = 8;

// Theme `kind`'s photograph as a texture's id, or 0 without one (photo.c).
extern fn draughts_photo_ngfx(kind: i64, decoded: i64) -> u32;
fn photo(kind: i64, decoded: i64) -> ngfx::Texture { ngfx::Texture { draughts_photo_ngfx(kind, decoded) } }

struct ShrinkRoot { src: u32, smp: u32, pad0: u32, pad1: u32, from: float4, to: float4 }
struct BlurRoot { src: u32, smp: u32, pad0: u32, pad1: u32, dir: float4 }
struct FadeRoot { to: float4, top: float4, low: float4, light: float4 }

// The pipelines the scene's passes take, made once.
struct Pipelines { shrink: ngfx::Pipeline, blur: ngfx::Pipeline, fade: ngfx::Pipeline }
var pipelines = Pipelines { ngfx::Pipeline { 0 }, ngfx::Pipeline { 0 }, ngfx::Pipeline { 0 } };

fn made() -> Pipelines {
    if pipelines.shrink.id == 0 {
        pipelines.shrink = ngfx::pipeline(embed_file("shaders/shrink.blob"));
        pipelines.blur = ngfx::pipeline(embed_file("shaders/blur.blob"));
        pipelines.fade = ngfx::pipeline(embed_file("shaders/fade.blob"));
    }
    return pipelines;
}

struct Scene {
    photo:   ngfx::Texture,     // the blurred copy, or a 1×1 stand-in when there is none
    sharp:   ngfx::Texture,     // the photograph as it is, or the stand-in
    glass:   ngfx::Texture,     // the copy glass samples, blurred further
    sampler: ngfx::Sampler,
    has:     bool,
    plain:   bool,
}

// What a pass into a texture wrote, made visible to the passes after it that sample it.
fn written() { ngfx::barrier(ngfx::TARGET_WRITE, ngfx::FRAGMENT_READ); }

fn load(kind: i64, plain: bool = false) -> Scene {
    let p = made();
    let sampler = ngfx::sampler(ngfx::LINEAR, ngfx::CLAMP);
    let sharp = if plain { ngfx::Texture { 0 } } else { photo(kind, SHARP_SIZE) };
    if sharp.id == 0 {
        let none = ngfx::texture2d(1, 1);
        var black: u8[4] = [0; 4];
        ngfx::update_texture(none, black);
        return Scene { photo: none, sharp: none, glass: none, sampler: sampler, has: false, plain: plain };
    }
    let src = ngfx::render_target(SIZE, SIZE, ngfx::RGBA8);
    ngfx::begin_pass(src, ngfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 1.0 });
    draw_shrink(p.shrink, sampler, sharp, float4 { 0.0, 0.0, 1.0, 1.0 }, float4 { 0.0, 0.0, SIZE, SIZE });
    ngfx::end_pass();
    written();
    let across = ngfx::render_target(SIZE, SIZE, ngfx::RGBA8);
    let blurred = ngfx::render_target(SIZE, SIZE, ngfx::RGBA8);
    let glass_across = ngfx::render_target(GLASS_SIZE, GLASS_SIZE, ngfx::RGBA8);
    let glass = ngfx::render_target(GLASS_SIZE, GLASS_SIZE, ngfx::RGBA8);
    let step = 1.0 / SIZE;
    pass(p.blur, sampler, src, across, float4 { step, 0.0, 5.6, step });
    pass(p.blur, sampler, across, blurred, float4 { 0.0, step, 5.6, step });
    let g = 1.0 / GLASS_SIZE;
    pass(p.blur, sampler, blurred, glass_across, float4 { g, 0.0, GLASS_SIGMA, g });
    pass(p.blur, sampler, glass_across, glass, float4 { 0.0, g, GLASS_SIGMA, g });
    ngfx::release(across);
    ngfx::release(glass_across);
    ngfx::release(src);
    return Scene { photo: blurred, sharp: sharp, glass: glass, sampler: sampler, has: true, plain: false };
}

fn draw_shrink(shrink: ngfx::Pipeline, sampler: ngfx::Sampler, src: ngfx::Texture, from: float4, to: float4) {
    ngfx::viewport(to.x, to.y, to.z, to.w);
    ngfx::bind(shrink);
    ngfx::draw(ngfx::root(ShrinkRoot { src: ngfx::index(src), smp: ngfx::index(sampler), pad0: 0, pad1: 0,
                                       from: from, to: to }), 3);
}

fn pass(blur: ngfx::Pipeline, sampler: ngfx::Sampler, src: ngfx::Texture, dst: ngfx::Texture, dir: float4) {
    ngfx::begin_pass(dst, ngfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 1.0 });
    ngfx::bind(blur);
    ngfx::draw(ngfx::root(BlurRoot { src: ngfx::index(src), smp: ngfx::index(sampler), pad0: 0, pad1: 0, dir: dir }), 3);
    ngfx::end_pass();
    written();
}

fn release(s: Scene&) {
    ngfx::release(s.photo);
    if s.has {
        ngfx::release(s.sharp);
        ngfx::release(s.glass);
    }
    ngfx::release(s.sampler);
}

// The four seasons' thumbnails stacked, and under them the four plain fades.
fn thumbs() -> ngfx::Texture {
    let p = made();
    let t = ngfx::render_target(THUMB_W, THUMBS * THUMB_H, ngfx::RGBA8);
    let sampler = ngfx::sampler(ngfx::LINEAR, ngfx::CLAMP);
    let crop: f32 = THUMB_H as f32 / THUMB_W;
    for kind in 4 {
        let ph = photo(kind, SIZE);
        var desc = ngfx::PassDesc { clear_color: kind == 0, .. };
        desc.color[0] = t;
        ngfx::begin_pass(desc);
        if ph.id != 0 {
            draw_shrink(p.shrink, sampler, ph, float4 { 0.0, (1.0 - crop) * 0.5, 1.0, crop },
                        float4 { 0.0, kind * THUMB_H, THUMB_W, THUMB_H });
        }
        ngfx::end_pass();
        // The next pass draws into the same texture.
        ngfx::barrier(ngfx::TARGET_WRITE, ngfx::TARGET_WRITE);
        if ph.id != 0 { ngfx::release(ph); }
    }
    var desc = ngfx::PassDesc { clear_color: false, .. };
    desc.color[0] = t;
    ngfx::begin_pass(desc);
    ngfx::bind(p.fade);
    for kind in 4 {
        let c = theme::get(kind);
        let to = float4 { 0.0, (4 + kind) * THUMB_H, THUMB_W, THUMB_H };
        ngfx::viewport(to.x, to.y, to.z, to.w);
        ngfx::draw(ngfx::root(FadeRoot { to: to, top: c.fade_top, low: c.fade_low, light: c.fade_light }), 3);
    }
    ngfx::end_pass();
    written();
    ngfx::release(sampler);
    return t;
}
