namespace shaders;

// The air: the dust in the sun's beams and the haze.

// Dust in the sunbeam (render3d::Dust), the main menu's scene only: points drifting in the
// sunbeam's own volume over the table, one camera-facing quad each, drawn as instances after
// the scene and added to it. Each point's light is the sun through the shell's windows where
// it is (shell_open's direct light, LIGHT_FN before DUST_VERT), worked out once in the vertex
// shader, so the beam has the pattern's shape and none is drawn where none is lit. Where a
// point is comes from its seed (`motes`, filled once) and the seconds, so nothing is
// uploaded a frame. dust_box: the volume's low corner, w the seconds; dust_span: its size
// along dust_u (the window wall), dust_v (up) and dust_w (into the room along the beam),
// each a world vector; dust_look: y the lens's blur (the disc's radius in pixels at 1000
// high where the distance is twice the focus's), z how bright, w the focus's distance from
// the eye; dust_lens: y the forward scattering's g, w the largest disc's radius in those
// pixels (0 none; the lens's near cap, render3d::Lens). The shell's windows after them, as
// ROOM_HEAD's block has them (render3d::dust_block), with the lace's mask, for LIGHT_FN's
// shell_open, which the dust is compiled with (SHELL_WINDOWS). dust_shape: z the share of
// fibres, w their width across as a share of a point's.
// The points (build/notes/window-view/refs/research-haze-motes.md): every flake is far under
// a pixel, so it is a point of a fixed footprint, a Gaussian dust_point.x pixels wide (sigma)
// at any resolution and distance, carrying the light it really scatters: the sun's
// irradiance × its cross-section × its phase × the pixels a metre squared there, summed over
// the footprint. Sizes log-normal (a median 25 µm flake), fibres 10 µm thick and 0.5-3 mm
// long as lines of that length on the screen, dust_shape.w of a point's width across with
// the same light (sub-pixel, so they don't read as stripes). Flakes glint as they tumble
// (0.1-1 turn a second): a lobe 2-6° round the mirror direction, 5-15 times as bright,
// dust_point.y of it (0 none). They move in world centimetres a second (dust_move: x the
// air's drift along the wall, y the rise over the sun's patch, slower higher up, z the
// swirls' speed, w their size in cm), settling by their size; no step is random a frame.
// dust_point.z: the sun on the room's surfaces over the board's (Room.shell_sun.y ×
// room_exposure), so a point is lit as the wall behind it; w a metre in world units.
// dust_near: x the board's share along dust_w, y how much denser the points are round it
// (0 even). With the lens on, a point becomes the lens's disc with its light spread over it.
let DUST_HEAD = """
    layout(set = 0, binding = 0) uniform sampler2D tree_map;
    layout(set = 0, binding = 1) uniform sampler2D lace_mask;
    layout(std430, set = 0, binding = 2) readonly buffer Motes { vec4 motes[]; };
    layout(set = 1, binding = 1) uniform Dust {
        vec4 dust_box;
        vec4 dust_span;
        vec4 dust_look;
        vec4 dust_lens;
        vec4 axes;
        vec4 tile;
        vec4 shell;
        vec4 shell_mids;
        vec4 shell_niche;
        vec4 shell_glass;
        vec4 shell_sun;
        vec4 window_view;
        vec4 dust_u;
        vec4 dust_v;
        vec4 dust_w;
        vec4 dust_shape;
        vec4 dust_move;
        vec4 dust_point;
        vec4 dust_near;
    };
    """;
let DUST_VERT = """
    layout(location = 0) out vec2 v_at;
    layout(location = 1) flat out vec4 v_glow;
    layout(location = 2) flat out vec4 v_shape;

    // A unit vector from two numbers 0..1.
    vec3 sphere_dir(vec2 r) {
        float z = 2.0 * r.x - 1.0;
        float a = 6.2832 * r.y;
        float q = sqrt(max(1.0 - z * z, 0.0));
        return vec3(q * cos(a), z, q * sin(a));
    }

    // v turned by angle a about the unit axis k (Rodrigues).
    vec3 turned_about(vec3 v, vec3 k, float a) {
        float c = cos(a);
        return v * c + cross(k, v) * sin(a) + k * dot(k, v) * (1.0 - c);
    }

    // The screen's direction (pixels) of a world vector d at pos, and its length there.
    vec2 on_screen(vec3 pos, vec3 d, vec4 clip) {
        vec4 c2 = view_proj * vec4(pos + d, 1.0);
        return (c2.xy / c2.w - clip.xy / clip.w) * 0.5 * screen.xy;
    }

    // The air's swirls at p (world units) after t seconds, as a displacement: four slow
    // transverse waves, each 5-20 cm long (dust_move.w its middle) and turning over in 2-6
    // s, so motes a few centimetres apart move together and their paths curl; the sum's
    // speed about dust_move.z cm a second. Free of divergence, so the dust neither bunches
    // nor thins.
    const vec3 SWIRL_K[4] = vec3[4](vec3(0.6, 0.0, 0.8), vec3(0.0, 0.6, 0.8), vec3(0.8, 0.6, 0.0), vec3(0.48, -0.6, 0.64));
    const vec3 SWIRL_B[4] = vec3[4](vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.8, 0.0, -0.6));
    const float SWIRL_LONG[4] = float[4](0.55, 0.8, 1.15, 1.6);
    const float SWIRL_TURN[4] = float[4](2.3, 3.4, 4.6, 5.9);
    const float SWIRL_SHARE[4] = float[4](0.45, 0.4, 0.35, 0.3);
    vec3 swirl(vec3 p, float t, float cm) {
        vec3 d = vec3(0.0);
        for (int j = 0; j < 4; j++) {
            float k = 6.2832 / (SWIRL_LONG[j] * dust_move.w * cm);
            float w = 6.2832 / SWIRL_TURN[j];
            float a = SWIRL_SHARE[j] * dust_move.z * cm / w;
            d += SWIRL_B[j] * (a * cos(k * dot(SWIRL_K[j], p) + w * t + 1.7 * float(j)));
        }
        return d;
    }

    void main() {
        const vec2 corners[6] = vec2[6](vec2(-1, -1), vec2(1, -1), vec2(1, 1),
                                        vec2(-1, -1), vec2(1, 1), vec2(-1, 1));
        vec2 c = corners[gl_VertexIndex];
        vec4 s = motes[gl_InstanceIndex % 1024];
        vec4 s2 = motes[(gl_InstanceIndex + 517) % 1024];
        vec4 s3 = motes[(gl_InstanceIndex + 263) % 1024];
        float t = dust_box.w;
        bool fibre = fract(s.w * 53.1 + s.x * 3.7) < dust_shape.z;
        float cm = 0.01 * dust_point.w;
        // A point's size against the median (log-normal, a sigma of 0.55: a third of them
        // past 1.7 times as large or small).
        float grain = exp(0.55 * clamp(sqrt(-2.0 * log(max(s2.x, 1e-4))) * cos(6.2832 * s2.y), -2.5, 2.5));
        // Carried by the air along the wall at 0.5-1.5 times its drift, a little across,
        // risen over the sun's patch and settling by size (a fibre's drag slows it), the
        // height eased so the rise is quicker low down than high.
        float settle = (fibre ? 0.6 : 1.0) * clamp(0.45 * grain * grain, 0.2, 1.5) * cm;
        vec2 dir = normalize(vec2(1.0, 0.8 * (s3.y - 0.5)));
        float drift = dust_move.x * (0.5 + s3.x) * cm;
        vec3 rate = vec3(drift * dir.x, dust_move.y * cm - settle, drift * dir.y) / dust_span.xyz;
        vec3 f = fract(s.xyz + rate * t);
        float h = f.y + 0.35 * f.y * (1.0 - f.y);
        vec3 pos = dust_box.xyz + f.x * dust_u.xyz + h * dust_v.xyz + f.z * dust_w.xyz;
        pos += swirl(pos, t, cm);
        // Faded near the box's faces, so a point wrapping round doesn't pop; none inside
        // the board.
        vec3 e = min(f, 1.0 - f) * 12.0;
        float fade = clamp(min(e.x, min(e.y, e.z)), 0.0, 1.0);
        if (max(abs(pos.x), abs(pos.z)) < INNER + FRAME_W && pos.y < FRAME_TOP + 0.02) fade = 0.0;
        // Denser round the board: each kept where its own number is under the density
        // there, fading in and out as it drifts.
        if (dust_near.y > 0.0) {
            vec2 off = vec2((f.x - 0.5) / 0.32, (f.z - dust_near.x) / 0.38);
            float dense = 0.35 + 0.65 * exp(-dot(off, off)) * (1.0 - 0.45 * f.y);
            fade *= smoothstep(0.0, 0.2, mix(1.0, dense, dust_near.y) - 0.8 * fract(s.w * 91.7));
        }

        // The sun through the window where it is, 0..1; all of it with no pattern.
        float sun = room.y > 0.0 ? clamp((window_light(pos) - 1.0 + room.y) / room.y, 0.0, 1.0) : 1.0;
        vec3 to_eye = eye.xyz - pos;
        float d = length(to_eye);
        vec3 v = to_eye / d;
        float g = dust_lens.y;
        float mu = dot(v, -light_dir.xyz);
        vec4 clip = view_proj * vec4(pos, 1.0);
        float px = screen.y / 1000.0;
        float coc = dust_look.y * px * abs(d - dust_look.w) / max(d, 0.01);
        if (dust_lens.w > 0.0) coc = min(coc, dust_lens.w * px);
        // Unlit, it is not drawn at all.
        if (sun * fade < 0.003) fade = 0.0;

        vec2 ax = vec2(1.0, 0.0);
        // The light it scatters, the sun's irradiance where it is (as the room's surfaces
        // take it) x its cross-section in m^2 x its phase (1/sr: Henyey-Greenstein at g with
        // a fifth even, and a narrow peak a few degrees round the sun's line, the diffraction
        // of a particle many wavelengths across) x the pixels a metre there squared: the sum
        // of its pixels, which the fragment's footprint keeps.
        float hg = (1.0 - g * g) / (12.566 * pow(1.0 + g * g - 2.0 * g * mu, 1.5));
        float angle = acos(clamp(mu, -1.0, 1.0));
        float p = 0.8 * hg + 0.2 / 12.566 + 30.0 * exp(-angle * angle / 0.0027);
        float fibre_long = 0.0005 * pow(6.0, fract(s3.z * 3.1 + s.y));
        float area = fibre ? fibre_long * 1.0e-5 : 3.1416 * pow(12.5e-6 * grain, 2.0);
        vec3 side = normalize(cross(v, vec3(0.0, 1.0, 0.0)) + vec3(1e-4, 0.0, 0.0));
        float per_metre = length(on_screen(pos, side * cm, clip)) * 100.0;
        vec3 glow = light_color.rgb * (light_dir.w * params.x * dust_point.z * sun * dust_look.z * area * p * per_metre * per_metre);
        // A faint tint of its own, a few percent.
        glow *= 1.0 + 0.06 * (s3.xyz - 0.5);
        float sigma = dust_point.x;
        float across = sigma;
        float along = 0.0;
        if (fibre) {
            // Lint: its length across the view at the screen, tumbling slowly, thinner than
            // a point across.
            vec3 spin = sphere_dir(vec2(fract(s.w * 7.31 + s.y * 3.1), fract(s.w * 17.9 + s.z * 5.3)));
            vec3 axis = normalize(turned_about(sphere_dir(s2.zw), spin, t * 0.4 * (0.3 + fract(s3.w * 5.7)) + 6.2832 * s.z));
            vec2 long_px = on_screen(pos, (axis - v * dot(axis, v)) * (fibre_long * 100.0 * cm), clip);
            along = length(long_px);
            ax = along > 1e-4 ? long_px / along : vec2(1.0, 0.0);
            across = sigma * dust_shape.w;
        } else if (dust_point.y > 0.0) {
            // A flake's glint: its face tumbling at 0.1-1 turn a second, flashing as it
            // passes the mirror direction between the sun and the eye; the lobe wider for the
            // quick ones, so each flash lasts a few frames.
            vec3 spin = sphere_dir(vec2(fract(s.w * 7.31 + s.y * 3.1), fract(s.w * 17.9 + s.z * 5.3)));
            float turn = 6.2832 * 0.1 * pow(10.0, fract(s3.z * 7.7 + s.x));
            vec3 face = normalize(turned_about(sphere_dir(s2.zw), spin, t * turn + 6.2832 * s.z));
            vec3 hv = normalize(light_dir.xyz + v);
            float off_mirror = acos(min(abs(dot(face, hv)), 1.0));
            float lobe = clamp(turn * 0.03, 0.035, 0.105);
            glow *= 1.0 + dust_point.y * (5.0 + 10.0 * s3.w) * exp(-off_mirror * off_mirror / (lobe * lobe));
        }
        float reach = 3.0 * sigma + coc;
        vec2 half_px = vec2(0.5 * along + reach, reach);
        v_shape = vec4(sigma, coc, along, across);
        v_glow = vec4(glow * fade, 0.0);
        vec2 outer = half_px + 1.0;
        vec2 side_ax = vec2(-ax.y, ax.x);
        v_at = c * outer;
        vec2 off = ax * (c.x * outer.x) + side_ax * (c.y * outer.y);
        clip.xy += off * 2.0 / screen.xy * clip.w;
        gl_Position = clip.w > 0.1 && fade > 0.0 ? clip : vec4(0.0, 0.0, -2.0, 1.0);
    }
    """;
let DUST_FRAG = """
    layout(location = 0) in vec2 v_at;
    layout(location = 1) flat in vec4 v_glow;
    layout(location = 2) flat in vec4 v_shape;
    layout(location = 0) out vec4 result;
    void main() {
        // A point's footprint, its sum over the pixels 1: a Gaussian sigma v_shape.x pixels
        // round a line v_shape.z long (0 a flake), v_shape.w across it; with the lens's disc
        // v_shape.y round, that disc's even light, its edge as soft as the point.
        float sigma = v_shape.x;
        float r_lens = v_shape.y;
        float line = v_shape.z;
        float lens2 = 0.25 * r_lens * r_lens;
        float wide = sigma * sigma + lens2;
        float thin = v_shape.w * v_shape.w + lens2;
        float dx = max(abs(v_at.x) - 0.5 * line, 0.0);
        float spot = exp(-0.5 * (dx * dx / wide + v_at.y * v_at.y / thin)) / (6.2832 * sqrt(wide * thin) + 2.5066 * sqrt(thin) * line);
        float r = length(vec2(dx, v_at.y));
        float disc = (1.0 - smoothstep(r_lens - sigma, r_lens + sigma, r)) / (3.1416 * r_lens * r_lens + 2.0 * r_lens * line + 1e-4);
        float k = mix(spot, disc, smoothstep(1.5 * sigma, 4.0 * sigma, r_lens));
    #ifdef HDR_OUT
        result = vec4(v_glow.rgb * k, 1.0);
    #else
        result = vec4(pow(v_glow.rgb * k, vec3(1.0 / 2.2)), 1.0);
    #endif
    }
    """;
// The haze in the sunbeam (render3d::haze_pass, Haze). The sun is one direction and the
// window's glass flat, so every point of the room maps along the sun onto the outer glass's
// plane, and how much sun reaches it is what passes there: the panes (render3d::haze_panes),
// the lace and the tree outside all as seen in that plane. HAZE_CROSS_FRAG draws that
// cross-section of the beam each frame into a small atlas, a slot each window: x the panes'
// coverage of the texel exactly (each a product set, so its share of a box is the columns'
// share times the rows'), times the lace and the tree; y the same blurred by haze_blur_most.
// HAZE_FRAG then takes each pixel's view from the eye to what the pre-pass drew there
// (pre_place) onto that plane, where it is a straight segment, and averages the atlas over
// haze_look.z jittered taps along its part in each window's slot: the beam's lit length on
// the view. Each tap's blur is the sun's disc's widening of the bars' shadows at its depth
// from the glass, times haze_look.w (1 as the disc does it, more a softer beam), and times
// 1 + haze_pixel.z more looking toward the sun, where the stripes converge on it; a mix of
// x and y by it. Then sigma × the phase (Henyey-Greenstein at g, haze_look.y of it even)
// × the sun as the room's surfaces take it (haze_light), the room's linear light a pixel.
// haze_plane: x the outer glass's depth along the wall's normal, y and z how far along u
// and up the sun moves a unit of that depth, w the windows; haze_pixel: xy a pixel of the
// target in uv; haze_box0..2 the windows' panes' boxes in the plane.
let HAZE_BLOCK = """
    layout(set = 3, binding = 1) uniform Haze {
        vec4 axes;
        vec4 tile;
        vec4 shell;
        vec4 shell_mids;
        vec4 shell_niche;
        vec4 shell_glass;
        vec4 shell_sun;
        vec4 window_view;
        vec4 haze_light;
        vec4 haze_look;
        vec4 haze_plane;
        vec4 haze_ranges;
        vec4 haze_pixel;
        vec4 haze_box0;
        vec4 haze_box1;
        vec4 haze_box2;
    };
    // The atlas's slot's size in texels; the depth from the glass (metres) whose blur its y
    // holds, the deepest the beam reaches across the room.
    const vec2 HAZE_SLOT = vec2(192.0, 384.0);
    const float HAZE_DEEPEST = 5.0;
    float haze_widen() { return shell_sun.x > 0.0 ? shell_sun.x : room.z; }
    // The stripes' blur (world units, a half width) at depth from the glass, times soft.
    float haze_blur(float depth, float soft) { return 0.5 * soft * (0.03 + haze_widen() * max(depth, 0.0)); }
    float haze_blur_most() { return haze_blur(HAZE_DEEPEST * shell.w, haze_look.w * (1.0 + haze_pixel.z)); }
    // Window w's slot: its panes' box grown by the blur and a few texels.
    vec4 haze_slot(int w) {
        vec4 b = w == 0 ? haze_box0 : (w == 1 ? haze_box1 : haze_box2);
        float m = haze_blur_most() + 0.02 * shell.w;
        return b + vec4(-m, -m, m, m);
    }
    """;
// HAZE_CROSS_FRAG's inputs, before LIGHT_FN (its lace_shadow and tree_light).
let HAZE_CROSS_HEAD = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D tree_map;
    layout(set = 2, binding = 1) uniform sampler2D lace_mask;
    layout(std430, set = 2, binding = 2) readonly buffer BeamPanes { vec4 beam_panes[]; };
    """;
let HAZE_CROSS_FRAG = """
    // The share of x0..x1 (r) that the intervals lo..hi cover.
    float covered(vec2 r, float lo, float hi) { return max(min(r.y, hi) - max(r.x, lo), 0.0); }

    // The share of the box q ± h the panes of the windows' range first..last cover: each product
    // set's columns' share of its width times its rows' of its height.
    float panes_cover(vec2 q, vec2 h, int first, int last) {
        float sum = 0.0;
        int i = first;
        for (int k = 0; k < 8 && i < last; k++) {
            vec4 b = beam_panes[i];
            int nx = int(beam_panes[i + 1].x);
            int ny = int(beam_panes[i + 1].y);
            if (q.x + h.x > b.x && q.x - h.x < b.z && q.y + h.y > b.y && q.y - h.y < b.w) {
                float cx = 0.0;
                for (int j = 0; j < nx; j++) cx += covered(beam_panes[i + 2 + j].xy, q.x - h.x, q.x + h.x);
                float cy = 0.0;
                for (int j = 0; j < ny; j++) cy += covered(beam_panes[i + 2 + nx + j].xy, q.y - h.y, q.y + h.y);
                sum += cx * cy;
            }
            i += 2 + nx + ny;
        }
        return sum / (4.0 * h.x * h.y);
    }

    // What the lace in front of window w lets through at the outer glass's point p, its pattern
    // blurred as at `far` (world units) past it, and the tree outside.
    float lace_tree(vec3 p, int w, float far) {
        vec3 l = light_dir.xyz;
        vec2 nw = -axes.zw;
        vec2 along = axes.xy;
        float toward = dot(l.xz, nw);
        float m = 1.0;
        float tl = (shell.y - shell_glass.z - dot(p.xz, nw)) / toward;
        vec3 c = p + l * tl;
        float mid = w == 0 ? shell_mids.x : (w == 1 ? shell_mids.y : shell_mids.z);
        vec2 wl = vec2(dot(c.xz, along) - mid, c.y - shell.z) / shell.w;
        float soft_l = (0.03 + haze_widen() * far) / shell.w + LACE_SOFT * far / shell.w;
        m *= lace_shadow(wl, soft_l, 0.0).x;
        if (tree.x > 0.0) {
            vec2 tr = tree_light(p, l, nw, along, toward);
            m *= tr.x * tr.y;
        }
        return m;
    }

    void main() {
        vec2 f = gl_FragCoord.xy / (HAZE_SLOT * vec2(3.0, 1.0));
        int w = int(f.x * 3.0);
        result = vec4(0.0, 0.0, 0.0, 1.0);
        if (float(w) >= haze_plane.w) return;
        vec4 s = haze_slot(w);
        vec2 at = vec2(fract(f.x * 3.0), f.y);
        vec2 q = mix(s.xy, s.zw, at);
        vec2 texel = (s.zw - s.xy) / HAZE_SLOT;
        int first = w == 0 ? 3 : int(haze_ranges[w - 1]);
        int last = int(haze_ranges[w]);
        float sharp = panes_cover(q, 0.5 * texel, first, last);
        float blurred = panes_cover(q, 0.5 * texel + haze_blur_most(), first, last);
        if (sharp + blurred <= 0.0) return;
        vec3 p = vec3(0.0, q.y, 0.0);
        p.xz = axes.xy * q.x - axes.zw * haze_plane.x;
        float far = HAZE_DEEPEST * shell.w;
        result = vec4(sharp * lace_tree(p, w, 0.2 * far), blurred * lace_tree(p, w, far), 0.0, 1.0);
    }
    """;
let HAZE_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D cross_map;
    layout(set = 2, binding = 1) uniform sampler2D pre_place;

    // The part (0..1) of the segment a + s d inside the box r (x0, y0, x1, y1), inv 1 / d: its
    // first and last s.
    vec2 box_span(vec4 r, vec2 a, vec2 inv) {
        vec4 t = (r - a.xyxy) * inv.xyxy;
        vec2 lo = min(t.xy, t.zw);
        vec2 hi = max(t.xy, t.zw);
        return vec2(max(max(lo.x, lo.y), 0.0), min(min(hi.x, hi.y), 1.0));
    }

    // Where p is carried along the sun onto the outer glass's plane.
    vec2 on_glass(vec3 p, vec2 nw, vec2 along) {
        float back = haze_plane.x - dot(p.xz, nw);
        return vec2(dot(p.xz, along) + haze_plane.y * back, p.y + haze_plane.z * back);
    }

    void main() {
        vec4 at = textureLod(pre_place, gl_FragCoord.xy * haze_pixel.xy, 0.0);
        vec3 l = light_dir.xyz;
        vec2 nw = -axes.zw;
        vec2 along = axes.xy;
        float toward = dot(l.xz, nw);
        result = vec4(0.0, 0.0, 0.0, 1.0);
        if (at.w <= 0.0 || toward < 0.05) return;
        vec3 p0 = eye.xyz;
        vec3 p1 = eye.xyz + at.xyz;
        vec2 a = on_glass(p0, nw, along);
        vec2 d = on_glass(p1, nw, along) - a;
        vec2 inv = 1.0 / vec2(d.x >= 0.0 ? max(d.x, 1e-6) : min(d.x, -1e-6), d.y >= 0.0 ? max(d.y, 1e-6) : min(d.y, -1e-6));
        float depth0 = (haze_plane.x - dot(p0.xz, nw)) / toward;
        float depth1 = (haze_plane.x - dot(p1.xz, nw)) / toward;
        float mu = dot(normalize(at.xyz), l);
        float soft = haze_look.w * (1.0 + haze_pixel.z * smoothstep(0.5, 1.0, mu));
        float most = haze_blur_most();
        // A tap's place along the span, jittered pixel by pixel (interleaved gradient noise).
        float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
        int taps = max(int(haze_look.z), 1);
        float lit = 0.0;
        for (int w = 0; w < 3; w++) {
            if (float(w) >= haze_plane.w) break;
            vec4 s = haze_slot(w);
            vec2 sb = box_span(s, a, inv);
            if (sb.y <= sb.x) continue;
            float step = (sb.y - sb.x) / float(taps);
            // A tap stands for its step: blurred at least as far as half of it reaches.
            float reach = 0.5 * step * length(d);
            float sum = 0.0;
            for (int k = 0; k < taps; k++) {
                float t = sb.x + (float(k) + jitter) * step;
                vec2 uv = (a + d * t - s.xy) / (s.zw - s.xy);
                vec2 c = textureLod(cross_map, vec2((float(w) + uv.x) / 3.0, uv.y), 0.0).xy;
                float blur = max(haze_blur(mix(depth0, depth1, t), soft), reach);
                sum += mix(c.x, c.y, clamp(blur / most, 0.0, 1.0));
            }
            lit += sum * step;
        }
        if (lit <= 0.0) return;
        float g = haze_look.x;
        float hg = (1.0 - g * g) / (12.566 * pow(max(1.0 + g * g - 2.0 * g * mu, 1e-4), 1.5));
        float phase = (1.0 - haze_look.y) * hg + haze_look.y / 12.566;
        float metres = lit * length(at.xyz) / shell.w;
        result = vec4(haze_light.rgb * (haze_light.w * phase * metres), 1.0);
    }
    """;
// The haze's light at half size (HAZE_FRAG) added bilinear over the picture.
let HAZE_ADD_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D haze_image;
    layout(set = 3, binding = 0) uniform HazeAdd { vec4 haze_add; };
    void main() { result = vec4(texture(haze_image, gl_FragCoord.xy * haze_add.xy).rgb, 1.0); }
    """;
