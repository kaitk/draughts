// Task 005: drawing only when something changed. A piece moves where the screen is
// tapped and pulses for a second; otherwise nothing is drawn. Every 5 seconds it prints
// how many times frame() returned and how many frames it drew. With
// patches/goose_gfx/0002-draw-on-demand.patch (the Android build), an idle frame()
// presents nothing and waits for an event, so idle shows about 5 frame() calls and no
// draws in 5 seconds; the Mac's built-in gfx still returns at the display's rate.
//
//   goose idle.goose                     on the Mac
//   scripts/android.py poc/idle.goose --run && adb logcat -s goose:*

import std;
import vec;
import gfx;
import os;

struct Piece { center_radius: float4, screen: float4 }

fn main() {
    var android_root: u8[>..] = [];
    let on_android = env("ANDROID_ROOT", android_root);
    let window_flags = if on_android { gfx::WINDOW_FULLSCREEN } else { gfx::WINDOW_RESIZABLE };
    guard gfx::open("Draughts idle", 1280, 800, window_flags) else {
        abort(str("gfx: ", gfx::error()));
    }
    defer gfx::close();

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
            vec4 center_radius;   // xy center in pixels, z radius, w pulse 0..1
            vec4 screen;          // xy screen size in pixels
        };
        void main() {
            vec2 px = vec2(v_uv.x, 1.0 - v_uv.y) * screen.xy;
            vec3 bg = vec3(0.10, 0.13, 0.18) * (1.0 - 0.35 * length(v_uv - 0.5));
            float d = length(px - center_radius.xy) - center_radius.z;
            float body = clamp(0.5 - d, 0.0, 1.0);
            float glow = exp(-max(d, 0.0) / (center_radius.z * 0.3)) * 0.6 * center_radius.w;
            vec3 piece = vec3(0.96, 0.92, 0.84);
            result = vec4(mix(bg + vec3(1.0, 0.83, 0.43) * glow, piece, body), 1.0);
        }
        """);
    let pipeline = gfx::pipeline(vs, fs, gfx::PipelineDesc {});

    var center = float2 { 640.0, 400.0 };
    var last_size = int2 { 0, 0 };
    var dirty = true;
    var pulse_until = 0.0;
    var calls = 0;
    var draws = 0;
    var since = clock();
    while gfx::frame() {
        calls++;
        if gfx::key_pressed("Escape") { break; }
        let size = gfx::screen_size();
        if size.x != last_size.x || size.y != last_size.y {
            last_size = size;
            dirty = true;
        }
        if gfx::mouse_pressed(gfx::MOUSE_LEFT) || gfx::mouse_released(gfx::MOUSE_LEFT) {
            center = gfx::mouse_pos();
            pulse_until = gfx::time() + 1.0;
            dirty = true;
        }
        let pulsing = gfx::time() < pulse_until;
        if dirty || pulsing {
            let pulse: f32 = if pulsing { (pulse_until - gfx::time()) as f32 } else { 0.0 };
            gfx::begin_screen(float4 { 0.0, 0.0, 0.0, 1.0 });
            gfx::bind(pipeline);
            gfx::uniforms(gfx::FRAGMENT, 0, Piece {
                center_radius: float4 { center.x, center.y, min(size.x, size.y) / 14.0, pulse },
                screen: float4 { size.x, size.y, 0.0, 0.0 } });
            gfx::draw(3);
            gfx::end_pass();
            draws++;
            dirty = false;
        }
        let now = clock();
        if now - since >= 5.0 {
            print("idle: ", calls, " frame() calls, ", draws, " draws in 5 s");
            calls = 0;
            draws = 0;
            since = now;
        }
    }
}
