// Task 001: the smallest Goose program that shows what the app needs on the tablet. A
// shader-drawn piece follows touch (SDL turns touches into mouse events), and a line of
// TrueType text with Estonian letters is drawn through ui.
//
//   goose poc.goose            in the compiler's process, on the Mac
//   scripts/android.py poc     an APK for the tablet (docs/development.md)

import std;
import vec;
import gfx;
import ui;
import os;

// The fragment shader's uniform block, std140: three vec4s.
struct Piece { center_radius: float4, screen: float4, color: float4 }

fn main() {
    // Full screen on Android hides the status and navigation bars (SDL makes it
    // immersive); the Mac keeps a resizable window. Goose has no platform query, but
    // every Android app process has ANDROID_ROOT in its environment.
    var android_root: u8[>..] = [];
    let on_android = env("ANDROID_ROOT", android_root);
    let window_flags = if on_android { gfx::WINDOW_FULLSCREEN } else { gfx::WINDOW_RESIZABLE };
    guard gfx::open("Kabe POC", 1280, 800, window_flags) else {
        abort(str("gfx: ", gfx::error()));
    }
    defer gfx::close();

    // One triangle that covers the screen; the fragment shader draws the board's
    // background and the piece as signed distances.
    let vs = embed_shader("vert", """
        layout(location = 0) out vec2 v_uv;
        void main() {
            vec2 p = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
            v_uv = p;
            gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
        }
        """);
    let fs = embed_shader("frag", """
        layout(location = 0) in vec2 v_uv;
        layout(location = 0) out vec4 result;
        layout(set = 3, binding = 0) uniform Piece {
            vec4 center_radius;   // xy center in pixels, z radius
            vec4 screen;          // xy screen size in pixels, z time
            vec4 color;
        };
        void main() {
            vec2 px = vec2(v_uv.x, 1.0 - v_uv.y) * screen.xy;
            // A dark checkerboard with a soft vignette.
            vec2 cell = floor(px / (min(screen.x, screen.y) / 8.0));
            float dark = mod(cell.x + cell.y, 2.0);
            vec3 bg = mix(vec3(0.16, 0.19, 0.25), vec3(0.09, 0.11, 0.15), dark);
            bg *= 1.0 - 0.35 * length(v_uv - 0.5);
            // The piece: a disc with a rim, an inner ring and a glow that pulses.
            float d = length(px - center_radius.xy) - center_radius.z;
            float aa = 1.0;
            float body = clamp(0.5 - d / aa, 0.0, 1.0);
            float ring = clamp(0.5 - abs(d + center_radius.z * 0.35) / aa, 0.0, 1.0) * 0.6;
            float glow = exp(-max(d, 0.0) / (center_radius.z * 0.25))
                       * (0.35 + 0.15 * sin(screen.z * 4.0));
            vec3 c = mix(bg + color.rgb * glow, color.rgb * (0.85 + 0.15 * v_uv.y), body);
            c = mix(c, vec3(1.0), ring * body);
            result = vec4(c, 1.0);
        }
        """);
    let pipeline = gfx::pipeline(vs, fs, gfx::PipelineDesc {});

    // Tenor Sans with Latin-1, Latin Extended-A (õäöüšž) and general punctuation (— “”).
    let atlas = ui::create_font_atlas();
    let ranges: u32[6] = [0x20, 0xFF, 0x100, 0x17F, 0x2010, 0x2027];
    let font = ui::add_font_from_memory(atlas, embed_file("../assets/fonts/TenorSans-Regular.ttf"),
                                        48.0, ui::FontConfig {}, ranges);
    guard ui::bake(atlas) else { abort(str("ui: ", ui::error())); }
    let hud = ui::create_context(font);
    var style = ui::style(hud);
    style.window.fixed_background = ui::style_item_hide();
    ui::set_style(hud, style);

    // `-- --frames N` stops after N frames and saves the last one as poc.png.
    var frames = -1;
    let argv = args();
    if argv.len == 3 && argv[1] == "--frames" {
        let n, ok = parse_int(argv[2]);
        if ok { frames = n; }
    }
    var drawn = 0;
    var center = float2 { 640.0, 400.0 };
    while gfx::frame() {
        if gfx::key_pressed("Escape") { break; }
        let size = gfx::screen_size();
        // A quick tap can press and release within one frame, so mouse_down alone
        // misses it; pressed and released catch the tap, down follows a drag.
        if gfx::mouse_pressed(gfx::MOUSE_LEFT) || gfx::mouse_released(gfx::MOUSE_LEFT) ||
           gfx::mouse_down(gfx::MOUSE_LEFT) {
            center = gfx::mouse_pos();
        }
        let radius: f32 = min(size.x, size.y) / 14.0;

        gfx::begin_screen(float4 { 0.0, 0.0, 0.0, 1.0 });
        gfx::bind(pipeline);
        gfx::uniforms(gfx::FRAGMENT, 0, Piece {
            center_radius: float4 { center.x, center.y, radius, 0.0 },
            screen: float4 { size.x, size.y, gfx::time() as f32, 0.0 },
            color: float4 { 0.93, 0.62, 0.30, 1.0 } });
        gfx::draw(3);
        gfx::end_pass();

        // An empty input batch, which also ends the HUD's last frame. Not
        // ui::input_from_gfx: the HUD takes no input, and that turns on text input,
        // which opens Android's on-screen keyboard.
        ui::input_begin(hud);
        ui::input_end(hud);
        if ui::begin(hud, "hud", ui::rect(0, 0, size.x, 160),
                     ui::WINDOW_NO_INPUT | ui::WINDOW_NO_SCROLLBAR) {
            ui::draw_text(hud, ui::rect(40, 40, size.x - 80, 60), "Kabe — õäöüšž ÕÄÖÜŠŽ", font,
                          ui::Color { 0, 0, 0, 0 }, ui::Color { 240, 236, 228, 255 });
            ui::draw_text(hud, ui::rect(40, 100, size.x - 80, 60),
                          str(gfx::driver(), "  ", size.x, "×", size.y), font,
                          ui::Color { 0, 0, 0, 0 }, ui::Color { 160, 170, 190, 255 });
        }
        ui::end(hud);
        ui::render(hud);
        drawn++;
        if drawn == frames { break; }
    }
    if frames > 0 { gfx::screenshot("poc.png"); }
    ui::destroy(hud);
}
