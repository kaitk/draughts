// Frame pacing: the screen drawn every frame for 30 seconds, then it quits. With no
// argument it only clears; with a number N a full-screen shader runs N rounds of busy
// work a pixel, a GPU load that doesn't change from frame to frame. Measured on the
// device by the compositor (SurfaceFlinger's timestats), it shows how many frames miss
// the display's refresh at a given load, with no app logic at all.
//
//   scripts/android.py poc/pace.goose --run
//   adb shell am start -S -n io.github.kaitk.draughts.pace/io.github.kaitk.draughts.DraughtsActivity --es args 40

import std;
import vec;
import gfx;
import os;

struct Work { screen: float4 }

fn main() {
    var android_root: u8[>..] = [];
    let on_android = env("ANDROID_ROOT", android_root);
    let window_flags = if on_android { gfx::WINDOW_FULLSCREEN } else { gfx::WINDOW_RESIZABLE };
    guard gfx::open("Draughts pace", 1280, 800, window_flags) else {
        abort(str("gfx: ", gfx::error()));
    }
    defer gfx::close();
    let argv = args();
    // pace [rounds] [uploads]: the shader's busy work a pixel, and how many 16 KB
    // buffers are rewritten each frame before the pass, as the app's pieces and quads are.
    var rounds = 0;
    var uploads = 0;
    for i in 1..argv.len {
        let n, ok = parse_int(argv[i]);
        if ok && i == 1 { rounds = n; }
        if ok && i == 2 { uploads = n; }
    }
    print("pace: ", rounds, " rounds, ", uploads, " uploads");
    var data: u8[16384] = [0; 16384];
    var bufs: gfx::Buffer[..8] = [];
    for i in min(uploads, 8) { bufs.push(gfx::buffer(gfx::BUFFER_STORAGE, data[..])); }
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
        layout(set = 3, binding = 0) uniform Work { vec4 screen; };   // x rounds, y phase
        void main() {
            float a = v_uv.x + screen.y, b = v_uv.y;
            for (int i = 0; i < int(screen.x); i++) {
                a = fract(sin(a * 12.9898 + b) * 43758.5453);
                b = fract(sin(b * 78.233 + a) * 12345.678);
            }
            result = vec4(0.1 + 0.1 * a, 0.1 + 0.2 * screen.y, 0.2 + 0.1 * b, 1.0);
        }
        """);
    let pipeline = gfx::pipeline(vs, fs, gfx::PipelineDesc {});
    var n = 0;
    while gfx::frame() {
        let t = gfx::time();
        if t > 30.0 { break; }
        let k: f32 = (n % 90) / 90.0;
        data[0] = (n % 256) as u8;
        for b in bufs { gfx::update_buffer(b, data[..]); }
        gfx::begin_screen(float4 { 0.0, 0.0, 0.0, 1.0 });
        if rounds > 0 {
            gfx::bind(pipeline);
            gfx::uniforms(gfx::FRAGMENT, 0, Work { screen: float4 { rounds, k, 0.0, 0.0 } });
            gfx::draw(3);
        }
        gfx::end_pass();
        n++;
    }
    print("pace: ", n, " frames, ", rounds, " rounds");
}
