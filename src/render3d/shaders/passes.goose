namespace shaders;

// The screen passes: SSAO and GTAO, the glow, the HDR tonemap, the planar mirror, the
// upscale, and the debug views.

// The window's glow (render3d::bloom_pass), no rays: the room's image shrunk to a quarter,
// a 4 × 4 block a pixel from four bilinear taps, only what is brighter than a threshold
// kept, in linear light; blurred across and down (GLOW_BLUR_FRAG); added back over the
// image in linear light (GLOW_ADD_FRAG). Glow: x the threshold (the least channel, sRGB,
// so only near-white glows: the glass, the sky, the backlit lace, not the board's sunlit
// maple), y the knee over it, zw a source texel in uv.
let GLOW_PICK_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform Glow { vec4 glow_pick; };
    void main() {
        vec2 at = floor(gl_FragCoord.xy) * 4.0;
        vec3 c = texture(src, (at + vec2(1.0, 1.0)) * glow_pick.zw).rgb + texture(src, (at + vec2(3.0, 1.0)) * glow_pick.zw).rgb
               + texture(src, (at + vec2(1.0, 3.0)) * glow_pick.zw).rgb + texture(src, (at + vec2(3.0, 3.0)) * glow_pick.zw).rgb;
        c *= 0.25;
        float bright = min(c.r, min(c.g, c.b));
        result = vec4(pow(c, vec3(2.2)) * smoothstep(glow_pick.x, glow_pick.x + glow_pick.y, bright), 1.0);
    }
    """;

// The glow blurred one way: x and y a texel's step in uv, z sigma in texels; w unused; then
// one target pixel in uv.
let GLOW_BLUR_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform GlowBlur { vec4 glow_dir; vec4 glow_px; };
    void main() {
        vec2 uv = gl_FragCoord.xy * glow_px.xy;
        vec3 sum = vec3(0.0);
        float total = 0.0;
        for (int i = -12; i <= 12; i++) {
            float w = exp(-0.5 * float(i * i) / (glow_dir.z * glow_dir.z));
            sum += w * texture(src, uv + float(i) * glow_dir.xy).rgb;
            total += w;
        }
        result = vec4(sum / total, 1.0);
    }
    """;

// The room's ambient occlusion (render3d::ssao_pass): what the screen shows of the room, the
// table and the board drawn at half size into where each pixel is and which way it faces
// (PRE_FRAG); each pixel's share of the sky hidden by what it shows within a reach
// (SSAO_FRAG), blurred over 4 × 4 by distance (SSAO_BLUR_FRAG); read back in ROOM_FRAG and
// TABLE_FRAG's room variant (SSAO_FN) for their indirect light only.

// Where each pixel is from the eye (world units) and how much it hides (w: 1, the lace
// LACE_HIDES, 0 nothing drawn), and its normal toward the eye. With PRE_ROOM the room's
// mesh, whose glass hides nothing.
let PRE_ROOM = "#define PRE_ROOM 1\n";
let PRE_FRAG = """
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    #ifdef PRE_ROOM
    layout(location = 3) in vec2 v_extra;
    #endif
    layout(location = 0) out vec4 pre_place;
    layout(location = 1) out vec4 pre_facing;
    // The lace lets about three quarters through where it hangs flat.
    const float LACE_HIDES = 0.4;
    void main() {
        float hides = 1.0;
    #ifdef PRE_ROOM
        float kind = floor(v_extra.y + 0.001);
        if (kind > 9.5 && kind < 10.5) discard;
        if (kind > 10.5 && kind < 11.5) hides = LACE_HIDES;
    #endif
        vec3 rel = v_world - eye.xyz;
        vec3 n = normalize(v_normal);
        if (dot(n, rel) > 0.0) n = -n;
        pre_place = vec4(rel, hides);
        pre_facing = vec4(n * 0.5 + 0.5, 1.0);
    }
    """;

// Each half-size pixel's occlusion, after McGuire's Alchemy obscurance: SSAO_TAPS points of
// a spiral round it on the screen, out to the reach's size there; each hides as much as it
// stands over the pixel's plane (the cosine of its angle above it, less a bias that keeps a
// flat surface clear), fading to nothing at the reach. Each pixel of a 4 × 4 block turns
// the spiral its own way, so the blur's 4 × 4 takes all sixteen turns and no noise is left.
// ssao_fwd: xyz the clip's w along the view (row 3 of view_proj), w half-size pixels a
// world unit spans at w 1; ssao_look: x the reach (world units), y the bias, z the
// largest spiral (pixels), w the gain. result: r the light kept (1 all), g the distance from
// the eye (0 nothing drawn).
let SSAO_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D pre_place;
    layout(set = 2, binding = 1) uniform sampler2D pre_facing;
    // The block GTAO_FRAG shares (render3d::SsaoBlock); this reads its first two.
    layout(set = 3, binding = 0) uniform Ssao { vec4 ssao_fwd; vec4 ssao_look; vec4 ssao_ray_x; vec4 ssao_ray_y; vec4 ssao_gtao; };
    const int SSAO_TAPS = 8;
    void main() {
        ivec2 px = ivec2(gl_FragCoord.xy);
        ivec2 size = textureSize(pre_place, 0);
        vec4 c = texelFetch(pre_place, px, 0);
        if (c.w <= 0.0) {
            result = vec4(1.0, 0.0, 0.0, 1.0);
            return;
        }
        float dist = length(c.xyz);
        vec3 n = normalize(texelFetch(pre_facing, px, 0).xyz * 2.0 - 1.0);
        float reach = ssao_look.x;
        float spiral = min(reach * ssao_fwd.w / max(dot(ssao_fwd.xyz, c.xyz), 1e-3), ssao_look.z);
        if (spiral < 1.0) {
            result = vec4(1.0, dist, 0.0, 1.0);
            return;
        }
        int cell = (px.x % 4) + 4 * (px.y % 4);
        float turn = 6.2832 * float(cell) / 16.0;
        float jitter = fract(float(cell) * 0.618034);
        float hidden = 0.0;
        for (int i = 0; i < SSAO_TAPS; i++) {
            float t = (float(i) + jitter) / float(SSAO_TAPS);
            float a = turn + 2.39996 * float(i);
            ivec2 q = px + ivec2(floor(vec2(cos(a), sin(a)) * (t * spiral) + 0.5));
            if (q.x < 0 || q.y < 0 || q.x >= size.x || q.y >= size.y) continue;
            vec4 s = texelFetch(pre_place, q, 0);
            vec3 v = s.xyz - c.xyz;
            float vv = dot(v, v);
            float up = dot(v, n) * inversesqrt(vv + 1e-4);
            hidden += s.w * max(up - ssao_look.y, 0.0) * max(1.0 - vv / (reach * reach), 0.0);
        }
        float kept = clamp(1.0 - ssao_look.w * hidden / float(SSAO_TAPS), 0.0, 1.0);
        result = vec4(kept, dist, 0.0, 1.0);
    }
    """;

// The light tuner's trial (render3d::ssao_gtao, --gtao on): each half-size pixel's occlusion
// by ground-truth ambient occlusion (Jimenez et al. 2016, after Intel's XeGTAO, MIT) in
// place of SSAO_FRAG's: GTAO_SLICES slices through the view at the pixel, turned its own way
// across the 4 × 4 block (SSAO_BLUR_FRAG's sixteen turns, a Bayer order); in each, the
// highest point seen each side within the reach (GTAO_STEPS taps a side, nearer ones
// denser), faded out over the reach's last 61.5% and by how much each hides (PRE_FRAG's w,
// the lace's 0.4); the arc of the cosine-weighted sky between them, by the normal's share in the
// slice. Worked out in world units from the eye (PRE_FRAG's places), the slices' directions
// in the screen's plane (ssao_ray_x, ssao_ray_y, render3d::screen_steps), so no view matrix.
// SSAO_BLUR_FRAG's 4 × 4 blur by distance is its edge-aware denoise, over all sixteen turns,
// with nothing kept from frame to frame. ssao_gtao: x the power the visibility is raised to.
let GTAO_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D pre_place;
    layout(set = 2, binding = 1) uniform sampler2D pre_facing;
    layout(set = 3, binding = 0) uniform Ssao { vec4 ssao_fwd; vec4 ssao_look; vec4 ssao_ray_x; vec4 ssao_ray_y; vec4 ssao_gtao; };
    const int GTAO_SLICES = 3;
    const int GTAO_STEPS = 3;
    const float HALF_PI = 1.5707963;
    const float PI = 3.1415927;
    // acos to about 1e-4 (Lagarde's).
    float fast_acos(float x) {
        float a = abs(x);
        float r = (-0.156583 * a + HALF_PI) * sqrt(1.0 - a);
        return x >= 0.0 ? r : PI - r;
    }
    const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
    void main() {
        ivec2 px = ivec2(gl_FragCoord.xy);
        ivec2 size = textureSize(pre_place, 0);
        vec4 cp = texelFetch(pre_place, px, 0);
        if (cp.w <= 0.0) {
            result = vec4(1.0, 0.0, 0.0, 1.0);
            return;
        }
        vec3 c = cp.xyz;
        float dist = length(c);
        vec3 v = -c / dist;
        vec3 n = normalize(texelFetch(pre_facing, px, 0).xyz * 2.0 - 1.0);
        float reach = ssao_look.x;
        float radius = min(reach * ssao_fwd.w / max(dot(ssao_fwd.xyz, c), 1e-3), ssao_look.z);
        if (radius < 1.0) {
            result = vec4(1.0, dist, 0.0, 1.0);
            return;
        }
        int cell = (px.x % 4) + 4 * (px.y % 4);
        float slice_turn = (BAYER[cell] + 0.5) / 16.0;
        float step_jitter = fract(float(cell) * 0.618034);
        float fade_mul = -1.0 / (0.615 * reach);
        float fade_add = (1.0 - 0.615) / 0.615 + 1.0;
        float least = 1.3 / radius;
        float seen = 0.0;
        for (int sl = 0; sl < GTAO_SLICES; sl++) {
            float phi = (float(sl) + slice_turn) * PI / float(GTAO_SLICES);
            vec2 omega = vec2(cos(phi), sin(phi));
            vec3 dir = normalize(omega.x * ssao_ray_x.xyz + omega.y * ssao_ray_y.xyz);
            vec3 ortho = dir - dot(dir, v) * v;
            vec3 axis = normalize(cross(ortho, v));
            vec3 pn = n - axis * dot(n, axis);
            float pn_len = length(pn);
            float cos_n = clamp(dot(pn, v) / max(pn_len, 1e-4), -1.0, 1.0);
            float nang = (dot(ortho, pn) < 0.0 ? -1.0 : 1.0) * fast_acos(cos_n);
            float low0 = cos(nang + HALF_PI);
            float low1 = cos(nang - HALF_PI);
            float hc0 = low0;
            float hc1 = low1;
            for (int st = 0; st < GTAO_STEPS; st++) {
                float t = (float(st) + step_jitter) / float(GTAO_STEPS);
                t = t * t + least;
                vec2 off = floor(omega * (t * radius) + 0.5);
                for (int side = 0; side < 2; side++) {
                    ivec2 q = px + ivec2(side == 0 ? off : -off);
                    if (q.x < 0 || q.y < 0 || q.x >= size.x || q.y >= size.y) continue;
                    vec4 s = texelFetch(pre_place, q, 0);
                    if (s.w <= 0.0) continue;
                    vec3 d = s.xyz - c;
                    float len = length(d);
                    float hcos = dot(d, v) / max(len, 1e-4);
                    float w = clamp(len * fade_mul + fade_add, 0.0, 1.0) * s.w;
                    if (side == 0) hc0 = max(hc0, mix(low0, hcos, w));
                    else hc1 = max(hc1, mix(low1, hcos, w));
                }
            }
            float h0 = -fast_acos(clamp(hc1, -1.0, 1.0));
            float h1 = fast_acos(clamp(hc0, -1.0, 1.0));
            h0 = nang + clamp(h0 - nang, -HALF_PI, HALF_PI);
            h1 = nang + clamp(h1 - nang, -HALF_PI, HALF_PI);
            float sin_n = sin(nang);
            float arc0 = (cos_n + 2.0 * h0 * sin_n - cos(2.0 * h0 - nang)) * 0.25;
            float arc1 = (cos_n + 2.0 * h1 * sin_n - cos(2.0 * h1 - nang)) * 0.25;
            seen += pn_len * (arc0 + arc1);
        }
        seen = clamp(seen / float(GTAO_SLICES), 0.0, 1.0);
        result = vec4(pow(seen, ssao_gtao.x), dist, 0.0, 1.0);
    }
    """;

// The occlusion blurred over the 4 × 4 block round each pixel (the spiral's sixteen turns),
// each texel by how near its distance from the eye is to the middle's, so an edge keeps
// its sides apart. The block runs from -2 to 1, so texel i holds the occlusion at i, not
// i + 0.5 (SSAO_FN reads it so).
let SSAO_BLUR_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D ssao_raw;
    void main() {
        ivec2 px = ivec2(gl_FragCoord.xy);
        ivec2 last = textureSize(ssao_raw, 0) - 1;
        vec2 c = texelFetch(ssao_raw, px, 0).rg;
        if (c.y <= 0.0) {
            result = vec4(1.0, 0.0, 0.0, 1.0);
            return;
        }
        float sum = 0.0;
        float total = 0.0;
        for (int k = 0; k < 16; k++) {
            ivec2 at = clamp(px + ivec2(k % 4 - 2, k / 4 - 2), ivec2(0), last);
            vec2 s = texelFetch(ssao_raw, at, 0).rg;
            float w = max(1.0 - abs(s.y - c.y) / (0.03 * c.y), 0.0);
            sum += w * s.x;
            total += w;
        }
        result = vec4(sum / max(total, 1e-4), c.y, 0.0, 1.0);
    }
    """;

// The light tuner's view of the depth of field's depth (render3d::depth_show_pass) over the
// picture: view.x 1 the distance along the view, from 0.5 m white to 16 m black on a log
// scale, the view out deep blue; 2 the lens's signed disc (render3d::Lens), blue in focus
// to yellow at the far cap behind it and magenta at the near cap before it, green where
// it is under a pixel across. to_w: the depth's d to the distance along the view, b / (d -
// a), and the metres a world unit; lens: the focus (world units), the aperture and the near
// and far caps (shares of the width); view: y the picture's width in pixels.
let DEPTH_SHOW_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D scene_depth;
    layout(set = 3, binding = 0) uniform DepthShow { vec4 to_w; vec4 lens; vec4 view; };
    void main() {
        float d = texelFetch(scene_depth, ivec2(gl_FragCoord.xy), 0).r;
        bool out_there = d >= 1.0;
        float w = out_there ? 1e9 : to_w.y / (d - to_w.x);
        if (view.x < 1.5) {
            float k = clamp(log2(w * to_w.z / 0.5) / 5.0, 0.0, 1.0);
            result = vec4(out_there ? vec3(0.05, 0.08, 0.3) : vec3(1.0 - k), 1.0);
            return;
        }
        float coc = lens.y * (1.0 - lens.x / w);
        float t = coc >= 0.0 ? clamp(coc / max(lens.w, 1e-4), 0.0, 1.0) : clamp(-coc / max(lens.z, 1e-4), 0.0, 1.0);
        vec3 c = mix(vec3(0.1, 0.2, 0.6), coc >= 0.0 ? vec3(1.0, 0.85, 0.1) : vec3(0.9, 0.1, 0.8), t);
        if (abs(coc) * view.y < 0.5) c = vec3(0.2, 0.8, 0.3);
        result = vec4(c, 1.0);
    }
    """;

// The HDR target made the picture (render3d::tone_pass): the tonemaps' shoulder and grade,
// sRGB, and a dither of under half a level against the 8-bit target's bands. Before the
// shoulder, the glow and the sun's glare in the eye (render3d::SunLook's veil, off as made):
// a veil round the sun falling as 1 / (1 + (θ / θ0)²), white to amber, scaled by the share
// of the sun open: the glow's smallest level at the sun (glow_wide), which holds the sun's
// light blurred over some 5°, so it counts every leaf and bar in front of it.
let HDR_TONE_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D scene_light;
    layout(set = 2, binding = 1) uniform sampler2D glow_light;
    layout(set = 2, binding = 2) uniform sampler2D glow_wide;
    // tone_glow: x the glow's strength (render3d::glow_pass; 0 none), yz a pixel in the
    // glow's uv, w the light tuner's probe (over 0 the light itself times it, under 0 the
    // sun's open share times minus it, both as grey levels); tone_sun: the sun on the picture
    // (pixels), the pixels a degree, w what turns glow_wide's light there into the share
    // open (0 all open); tone_veil: render3d::SunLook's veil; tone_disc: x the disc's radius
    // (pixels), y what turns the picture's light on the disc into its share open (0 none),
    // z the camera's curve, w its exposure (camera_curve); tone_white: the grade's white
    // balance (gains on the light), w its saturation; tone_look: the grade's slope, offset and
    // power on AgX's curve (render3d::Grade).
    layout(set = 3, binding = 0) uniform HdrTone { vec4 tone_glow; vec4 tone_sun; vec4 tone_veil; vec4 tone_disc;
                                                   vec4 tone_white; vec4 tone_look; };
    // The disc's own pixels, five of them, so a bar thinner than the glow's level still hides it.
    float disc_open() {
        if (tone_disc.y <= 0.0) return 1.0;
        ivec2 top = ivec2(1.0 / tone_glow.yz) - 1;
        float h = 0.5 * tone_disc.x, s = 0.0;
        vec2 o[5] = vec2[5](vec2(0.0), vec2(h, 0.0), vec2(-h, 0.0), vec2(0.0, h), vec2(0.0, -h));
        for (int i = 0; i < 5; i++) {
            vec3 c = texelFetch(scene_light, clamp(ivec2(tone_sun.xy + o[i]), ivec2(0), top), 0).rgb;
            s += clamp(max(c.r, max(c.g, c.b)) * tone_disc.y, 0.0, 1.0);
        }
        return s * 0.2;
    }
    float sun_open() {
        float d = disc_open();
        if (tone_sun.w <= 0.0) return d;
        vec3 w = texture(glow_wide, tone_sun.xy * tone_glow.yz).rgb;
        return min(d, clamp(max(w.r, max(w.g, w.b)) * tone_sun.w, 0.0, 1.0));
    }
    vec3 sun_glare(vec2 px, float open) {
        vec2 d = px - tone_sun.xy;
        float ang = length(d) / max(tone_sun.z, 1e-3);
        float t = ang / max(tone_veil.y, 1e-3);
        float veil = tone_veil.x * open / (1.0 + t * t) * (1.0 - smoothstep(0.5 * tone_veil.z, tone_veil.z, ang));
        return veil * pow(vec3(1.0, 0.82, 0.6), vec3(tone_veil.w * min(ang / 10.0, 2.0)));
    }
    vec3 shoulder(vec3 c) {
        float peak = max(c.r, max(c.g, c.b));
        const float start = 0.76;
        if (peak < start) return c;
        const float d = 1.0 - start;
        float np = 1.0 - d * d / (peak + d - start);
        c *= np / peak;
        float g = 1.0 - 1.0 / (0.15 * (peak - np) + 1.0);
        return mix(c, vec3(np), g);
    }
    // AgX, a short fit of Blender's AgX view: Rec.709 into AgX's inset Rec.2020, log2 over
    // 0.18's -10 to +6.5 stops, a polynomial fitted to Blender's curve on grey, the grade's
    // look as Blender's AgX looks take it ((v * slope + offset) ^ power, then the saturation
    // round its luminance), the display's 2.4 power, AgX's outset back into Rec.709 (task 122,
    // build/review122/s5/agx.py).
    vec3 agx(vec3 c) {
        c = c.r * vec3(0.5448147, 0.1404170, 0.0888104) + c.g * vec3(0.3737874, 0.7541376, 0.1788717)
          + c.b * vec3(0.0813979, 0.1054455, 0.7323179);
        vec3 t = clamp((log2(max(c, vec3(1e-10))) + 12.47393) * (1.0 / 16.5), 0.0, 1.0);
        vec3 v = -0.008484016 + t * (0.8965809 + t * (-15.11457 + t * (131.6423 + t * (-557.5602 + t * (1276.883
               + t * (-1578.567 + t * (990.8947 + t * -248.0705)))))));
        v = pow(max(v * tone_look.x + tone_look.y, vec3(0.0)), vec3(tone_look.z));
        float l = dot(v, vec3(0.2126, 0.7152, 0.0722));
        v = pow(max(l + tone_white.w * (v - l), vec3(0.0)), vec3(2.4));
        return v.r * vec3(1.9648874, -0.2993134, -0.1643526) + v.g * vec3(-0.8559884, 1.3263980, -0.2381840)
             + v.b * vec3(-0.1088990, -0.0270846, 1.4025366);
    }
    // The camera's curve, the one place a surface's light becomes the picture's: AgX at the
    // camera's exposure and white balance where tone_disc.z says 3 (render3d::camera_toe);
    // else the toe it says (0 on the luminance, 1 on the least channel, 2 none, each surface
    // having taken its own as it wrote the target), the shoulder and the grade.
    vec3 camera_curve(vec3 c) {
        if (tone_disc.z > 2.5) return agx(c * tone_disc.w * tone_white.rgb);
        if (tone_disc.z < 0.5) {
            float y = max(dot(c, vec3(0.2126, 0.7152, 0.0722)), 1e-6);
            c *= (y < 0.04 ? 12.5 * y * y : y - 0.02) / y;
        } else if (tone_disc.z < 1.5) {
            float least = min(c.r, min(c.g, c.b));
            c -= least < 0.04 ? least - 12.5 * least * least : 0.02;
        }
        return shoulder(c) * vec3(1.02, 1.0, 0.97);
    }
    vec3 encode(vec3 c) {
        c = clamp(c, 0.0, 1.0);
        return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
    }
    void main() {
        vec3 c = max(texelFetch(scene_light, ivec2(gl_FragCoord.xy), 0).rgb, vec3(0.0));
        if (tone_glow.w != 0.0) {
            result = vec4(encode(tone_glow.w > 0.0 ? c * tone_glow.w : vec3(-tone_glow.w * sun_open())), 1.0);
            return;
        }
        if (tone_glow.x > 0.0) c += tone_glow.x * max(texture(glow_light, gl_FragCoord.xy * tone_glow.yz).rgb, vec3(0.0));
        if (tone_veil.x > 0.0) c += sun_glare(gl_FragCoord.xy, sun_open());
        c = camera_curve(c);
        float n = fract(sin(dot(floor(gl_FragCoord.xy), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
        result = vec4(encode(c) + n / 255.0, 1.0);
    }
    """;

// The scenic views' glow (render3d::glow_pass), in the HDR target's linear light before the
// tonemap, so the sun's disc and the sky bleed over the leaves, the bars and the frame in
// front of them: the light over a threshold (a soft knee) picked into a quarter of the
// picture by a tent over 8 × 8 pixels round each texel's 4 × 4 block (sixteen bilinear taps,
// each two pixels' weights 1 3 5 7 7 5 3 1 a row), each tap's light over the threshold
// before they are averaged: the texels overlap, so a thin strip of sun moving across their
// rows fades from one to the next instead of pulsing (2026-11-23); then halved level by level
// (GLOW_DOWN_FRAG, Bjorge's dual filter: five taps) and widened back up (GLOW_UP_FRAG, eight
// taps), each level blended over the one above it by the reach, so the levels' shares sum to
// one; HDR_TONE_FRAG adds the top level times the strength. glow_step: xy a source texel in
// uv, zw a target pixel in uv; glow_look: x the threshold, y the knee, z the brightest a
// channel is taken at (against a single pixel's spark), w the reach (each coarser level's
// share).
let GLOW_FIRST = "#define GLOW_FIRST 1\n";
let GLOW_DOWN_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform GlowStep { vec4 glow_step; vec4 glow_look; };
    vec3 tap(vec2 uv) { return min(max(texture(src, uv).rgb, vec3(0.0)), vec3(glow_look.z)); }
    #ifdef GLOW_FIRST
    vec3 pick(vec2 uv) {
        vec3 c = tap(uv);
        float bright = max(c.r, max(c.g, c.b));
        float knee = max(glow_look.y, 1e-4);
        float soft = clamp(bright - glow_look.x + knee, 0.0, 2.0 * knee);
        soft = soft * soft / (4.0 * knee);
        return c * (max(soft, bright - glow_look.x) / max(bright, 1e-4));
    }
    #endif
    void main() {
        vec2 uv = gl_FragCoord.xy * glow_step.zw;
        vec2 h = glow_step.xy;
    #ifdef GLOW_FIRST
        float at[4] = float[4](-2.75, -0.9166667, 0.9166667, 2.75);
        float w[4] = float[4](0.125, 0.375, 0.375, 0.125);
        vec3 c = vec3(0.0);
        for (int j = 0; j < 4; j++) {
            for (int i = 0; i < 4; i++) c += (w[i] * w[j]) * pick(uv + vec2(at[i], at[j]) * h);
        }
    #else
        vec3 c = (4.0 * tap(uv) + tap(uv - h) + tap(uv + h) + tap(uv + vec2(h.x, -h.y)) + tap(uv - vec2(h.x, -h.y))) * 0.125;
    #endif
        result = vec4(c, 1.0);
    }
    """;
let GLOW_UP_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform GlowStep { vec4 glow_step; vec4 glow_look; };
    void main() {
        vec2 uv = gl_FragCoord.xy * glow_step.zw;
        vec2 h = glow_step.xy;
        vec3 c = texture(src, uv + vec2(-2.0 * h.x, 0.0)).rgb + texture(src, uv + vec2(2.0 * h.x, 0.0)).rgb
               + texture(src, uv + vec2(0.0, -2.0 * h.y)).rgb + texture(src, uv + vec2(0.0, 2.0 * h.y)).rgb
               + 2.0 * (texture(src, uv + vec2(-h.x, h.y)).rgb + texture(src, uv + h).rgb
                        + texture(src, uv + vec2(h.x, -h.y)).rgb + texture(src, uv - h).rgb);
        result = vec4(c / 12.0, glow_look.w);
    }
    """;

// The mirror's picture made the room's light again, with how far each texel stands from the
// floor along the reflection: the pass drew the room, the table and the view out as their
// light before the tonemap (mirror_light), exposed, so the room's exposure's inverse
// (planar_tone.x) takes it back. The depth places the point: planar_back
// is the inverse of the pass's view_proj (columns), planar_eye the eye and, w, the floor's
// y; the point's height over the floor and the eye's give its distance from where the
// reflection leaves the floor, at most planar_tone.y. Where the pass drew nothing of the room
// (past the floor's far edge), the nearest texel below that it did, so the mips and the
// floor's wide blurs never take in black.
let PLANAR_RESOLVE_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D planar_color;
    layout(set = 2, binding = 1) uniform sampler2D planar_depth;
    layout(set = 3, binding = 0) uniform PlanarResolve { vec4 planar_back[4]; vec4 planar_eye; vec4 planar_tone; };
    const int PLANAR_REACH = 8;
    // A texel's light made safe for the mips: a NaN, an infinity or a negative channel from
    // anything drawn into the mirror would spread through them into black blotches on the
    // floor; the brightest (the sun's disc) held to MIRROR_PEAK's luminance, its hue kept.
    vec3 kept_light(vec3 c) {
        float y = dot(c, vec3(0.2126, 0.7152, 0.0722));
        if (!(y >= 0.0 && y <= 1e4)) return vec3(0.0);
        c = clamp(c, vec3(0.0), vec3(1e4));
        return y > 16.0 ? c * (16.0 / y) : c;
    }
    void main() {
        ivec2 px = ivec2(gl_FragCoord.xy);
        ivec2 size = textureSize(planar_color, 0);
        // Over the floor's far edge the mirror draws nothing of the room (the view out
        // drawn first shows there): take the wall's foot a few texels down, so the floor's
        // reflection at the wall never reaches past it into the sky; farther up, the
        // nearest texel below that was drawn, found in doubling steps.
        float depth = texelFetch(planar_depth, px, 0).r;
        for (int k = 1; k <= PLANAR_REACH && depth >= 1.0; k++) {
            ivec2 at = ivec2(px.x, min(px.y + k, size.y - 1));
            float d = texelFetch(planar_depth, at, 0).r;
            if (d < 1.0) {
                px = at;
                depth = d;
            }
        }
        for (int k = 2 * PLANAR_REACH; k <= 1024 && depth >= 1.0; k *= 2) {
            ivec2 at = ivec2(px.x, min(px.y + k, size.y - 1));
            float d = texelFetch(planar_depth, at, 0).r;
            if (d < 1.0) {
                px = at;
                depth = d;
            }
        }
        vec2 uv = (vec2(px) + 0.5) / vec2(size);
        // A 3 × 3 tent over what the pass drew: the half size has no antialiasing, and its
        // steps along a nearly level edge (a threshold's, a moulding's) crawl as the eye moves.
        vec3 c = vec3(0.0);
        float total = 0.0;
        for (int k = 0; k < 9; k++) {
            ivec2 at = clamp(px + ivec2(k % 3 - 1, k / 3 - 1), ivec2(0), size - 1);
            if (texelFetch(planar_depth, at, 0).r >= 1.0) continue;
            float w = (k % 3 == 1 ? 2.0 : 1.0) * (k / 3 == 1 ? 2.0 : 1.0);
            c += w * kept_light(texelFetch(planar_color, at, 0).rgb);
            total += w;
        }
        c /= max(total, 1e-4);
        vec4 h = planar_back[0] * (2.0 * uv.x - 1.0) + planar_back[1] * (1.0 - 2.0 * uv.y)
               + planar_back[2] * depth + planar_back[3];
        vec3 q = h.xyz / h.w;
        float floor_y = planar_eye.w;
        float high = max(q.y - floor_y, 0.0);
        vec3 under = vec3(q.x, 2.0 * floor_y - q.y, q.z);
        float t = length(under - planar_eye.xyz) * high / max(high + planar_eye.y - floor_y, 1e-3);
        t = t >= 0.0 ? min(t, planar_tone.y) : 0.0;
        result = depth < 1.0 ? vec4(c * planar_tone.x, t) : vec4(0.0);
    }
    """;

// The mirror's next mip from the one above (planar_mip.x), each texel a 4 × 4 tent [1 3 3 1]
// of the level above in four bilinear reads, not a 2 × 2 box: a box's mips are tied to their
// texels, so a window's bar over the floor slid by the eye fell into one texel or across two
// and its reflection pulsed as it moved; a tent's change much less with where the bar falls.
let PLANAR_MIP_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D planar_map;
    layout(set = 3, binding = 0) uniform PlanarMip { vec4 planar_mip; };
    void main() {
        float lod = planar_mip.x;
        vec2 texel = 1.0 / vec2(textureSize(planar_map, int(lod)));
        vec2 uv = gl_FragCoord.xy * 2.0 * texel;
        vec2 d = 0.75 * texel;
        result = 0.25 * (textureLod(planar_map, uv + vec2(-d.x, -d.y), lod) + textureLod(planar_map, uv + vec2(d.x, -d.y), lod)
                       + textureLod(planar_map, uv + vec2(-d.x, d.y), lod) + textureLod(planar_map, uv + vec2(d.x, d.y), lod));
    }
    """;

// The tuner's view of the floor's mirror over the whole picture: planar_show x the room's
// exposure, y 1 its light, 2 its distances (white planar_show.z away); planar_px.xy a pixel
// in uv.
let PLANAR_SHOW_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D planar_map;
    layout(set = 3, binding = 0) uniform PlanarShow { vec4 planar_show; vec4 planar_px; };
    vec3 encode(vec3 c) {
        c = clamp(c, 0.0, 1.0);
        return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
    }
    void main() {
        vec4 m = textureLod(planar_map, gl_FragCoord.xy * planar_px.xy, 0.0);
        vec3 c = planar_show.y > 1.5 ? vec3(sqrt(clamp(m.a / planar_show.z, 0.0, 1.0)))
                                     : encode(tonemap(m.rgb * planar_show.x) * vec3(1.02, 1.0, 0.97));
        result = vec4(c, 1.0);
    }
    """;

// The image with its glow added in linear light, into the target: x the glow's strength, yz
// a target pixel in the glow's uv.
let GLOW_ADD_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 2, binding = 1) uniform sampler2D glow;
    layout(set = 3, binding = 0) uniform GlowAdd { vec4 glow_add; };
    vec3 decode(vec3 c) {
        return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
    }
    vec3 encode(vec3 c) {
        c = clamp(c, 0.0, 1.0);
        return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
    }
    void main() {
        vec4 c = texelFetch(src, ivec2(gl_FragCoord.xy), 0);
        vec3 g = texture(glow, gl_FragCoord.xy * glow_add.yz).rgb;
        result = vec4(encode(decode(c.rgb) + g * glow_add.x), c.a);
    }
    """;

// The 3D scene drawn under the screen's size scaled up to it (render3d::upscale_pass):
// upscale.xy a screen pixel in the scene's texels, zw a scene texel in uv. Bilinear, or with
// UPSCALE_CUBIC Catmull-Rom from five bilinear taps: each side's two middle weights, both
// positive, taken by one tap between their texels, and the four corners' small weights
// left out (Jimenez's; the nine taps' look within a level, 0.30 ms against 0.44 at
// 3024 × 1890 on an M1 Pro).
let UPSCALE_CUBIC = "#define UPSCALE_CUBIC 1\n";
let UPSCALE_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform Upscale { vec4 upscale; };
    void main() {
        vec2 at = gl_FragCoord.xy * upscale.xy;
    #ifdef UPSCALE_CUBIC
        vec2 mid = floor(at - 0.5) + 0.5;
        vec2 f = at - mid;
        vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
        vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
        vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
        vec2 w3 = f * f * (-0.5 + 0.5 * f);
        vec2 w12 = w1 + w2;
        vec2 a = (mid - 1.0) * upscale.zw;
        vec2 b = (mid + w2 / w12) * upscale.zw;
        vec2 c = (mid + 2.0) * upscale.zw;
        vec4 sum = texture(src, vec2(b.x, a.y)) * (w12.x * w0.y) + texture(src, vec2(a.x, b.y)) * (w0.x * w12.y)
                 + texture(src, vec2(b.x, b.y)) * (w12.x * w12.y) + texture(src, vec2(c.x, b.y)) * (w3.x * w12.y)
                 + texture(src, vec2(b.x, c.y)) * (w12.x * w3.y);
        float kept = w12.x * w0.y + w0.x * w12.y + w12.x * w12.y + w3.x * w12.y + w12.x * w3.y;
        result = clamp(sum / kept, 0.0, 1.0);
    #else
        result = texture(src, at * upscale.zw);
    #endif
    }
    """;

// The backdrop: the blurred photograph cover-cropped by the screen's long side, graded
// to sit as the 3D reference's background does: lighter, a little more saturated, its
// bright patches lifted into warm bokeh, and lifted toward the theme's tint low down,
// where the reference has a surface under the board, darkened toward the edges. With the
// plain background (draw.y over 0) the fade instead, dimmed to draw.y as the flat game
// dims what is behind it.
let BACKDROP_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D photo;
    // x: how opaque; y: the plain fade's brightness, 0 for the photograph; its colors.
    layout(set = 3, binding = 1) uniform Backdrop { vec4 draw; vec4 fade_top; vec4 fade_low; vec4 fade_light; };
    void main() {
        vec2 s = screen.xy;
        if (draw.y > 0.0) {
            vec3 f = plain_fade(gl_FragCoord.xy, s, fade_top.rgb, fade_low.rgb, fade_light.rgb);
            result = vec4(draw.y * f, draw.x);
            return;
        }
        vec2 uv = (gl_FragCoord.xy - 0.5 * s) / max(s.x, s.y) + 0.5;
        vec3 c = srgb(texture(photo, uv).rgb) * grade.x;
        float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
        c = max(mix(vec3(luma), c, grade.y), vec3(0.0));
        c *= 1.0 + grade.z * smoothstep(0.08, 0.5, luma);
        float low = smoothstep(0.45, 1.0, gl_FragCoord.y / s.y);
        c = c / (1.0 + 0.15 * c * c);
        // A soft vignette (tint.w), so the lit board stands out from the scene round it,
        // under the lift low down.
        vec2 q = gl_FragCoord.xy / s - 0.5;
        c *= 1.0 - tint.w * smoothstep(0.1, 0.55, dot(q, q));
        c = mix(c, tint.rgb, low * grade.w);
        result = vec4(pow(c, vec3(1.0 / 2.2)), draw.x);
    }
    """;

// The photograph shrunk to a small copy, and blurred: the 3D board's backdrop and
// src/app/scene.goose's behind the 2D game, which draws with these two texts as they are
// (docs/architecture/rendering.md, "Scene and glass").
//
// SHRINK_FRAG averages a part of the source into a part of the target. Each target pixel
// takes taps spread evenly across its footprint, about two source texels apart, each a
// bilinear average of four texels: shrinking 4×, 2 × 2 taps on the texels' corners are an
// exact box of 4 × 4 texels.
let SHRINK_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    // The source's part in uv (origin, size), the target's in pixels (origin, size).
    layout(set = 3, binding = 0) uniform Shrink { vec4 from; vec4 to; };
    void main() {
        vec2 pixel = from.zw / to.zw;
        vec2 uv = from.xy + (gl_FragCoord.xy - to.xy) * pixel;
        ivec2 n = max(ivec2(ceil(pixel * vec2(textureSize(src, 0)) * 0.5)), ivec2(1));
        vec3 sum = vec3(0.0);
        for (int y = 0; y < n.y; y++) {
            for (int x = 0; x < n.x; x++) {
                sum += texture(src, uv + ((vec2(x, y) + 0.5) / vec2(n) - 0.5) * pixel).rgb;
            }
        }
        result = vec4(sum / float(n.x * n.y), 1.0);
    }
    """;

let BLUR_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    // One texel's step in the source, sigma in source texels, one target pixel in uv.
    layout(set = 3, binding = 0) uniform Blur { vec4 dir; };
    void main() {
        vec2 uv = gl_FragCoord.xy * dir.w;
        vec3 sum = vec3(0.0);
        float total = 0.0;
        for (int i = -17; i <= 17; i++) {
            float w = exp(-0.5 * float(i * i) / (dir.z * dir.z));
            sum += w * texture(src, uv + float(i) * dir.xy).rgb;
            total += w;
        }
        result = vec4(sum / total, 1.0);
    }
    """;

// A texture drawn over the whole target as it is: the 3D board's image kept from the
// last frame that drew it, under the UI.
let COPY_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    void main() { result = vec4(texelFetch(src, ivec2(gl_FragCoord.xy), 0).rgb, 1.0); }
    """;

// The kept backdrop (render3d::keep_backdrop: BACKDROP_FRAG at full opacity, the
// screen's size) laid texel for texel at opacity draw.x: a fetch a pixel rather than the
// backdrop's grade, vignette, and fade.
let KEPT_FRAG = """
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D kept;
    layout(set = 3, binding = 0) uniform Kept { vec4 draw; };
    void main() { result = vec4(texelFetch(kept, ivec2(gl_FragCoord.xy), 0).rgb, draw.x); }
    """;

// The kept image (premultiplied, clear where no board is) drawn over what is there: its
// rect `from` (pixels of the image) into the rect `to` (pixels of the target), at
// opacity screen.z; the same rect texel for texel at rest, moved and scaled in a
// transition. screen.w greys it (a new theme being prepared over it, draw3d's grey):
// at 1 its saturation GREY_SAT of its own and its brightness GREY_BRIGHT.
let SHOW_VS = "#define SHOW_SET 1\n";
let SHOW_FS = "#define SHOW_SET 3\n";
let SHOW_BLOCK = """
    layout(set = SHOW_SET, binding = 0) uniform Show { vec4 from_rect; vec4 to_rect; vec4 screen; };
    """;
let SHOW_VERT = """
    layout(location = 0) out vec2 v_uv;
    void main() {
        const vec2 corners[6] = vec2[6](vec2(0, 0), vec2(1, 0), vec2(1, 1), vec2(0, 0), vec2(1, 1), vec2(0, 1));
        vec2 c = corners[gl_VertexIndex];
        vec2 px = to_rect.xy + c * to_rect.zw;
        v_uv = (from_rect.xy + c * from_rect.zw) / screen.xy;
        gl_Position = vec4(px.x / screen.x * 2.0 - 1.0, 1.0 - px.y / screen.y * 2.0, 0.0, 1.0);
    }
    """;
let SHOW_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    const float GREY_SAT = 0.15;
    const float GREY_BRIGHT = 0.8;
    void main() {
        vec4 c = texture(src, v_uv);
        float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
        c.rgb = mix(c.rgb, vec3(luma), screen.w * (1.0 - GREY_SAT)) * (1.0 - screen.w * (1.0 - GREY_BRIGHT));
        result = c * screen.z;
    }
    """;

// The room's reflection (render3d::refl_map, task 131): a direction's place in an octahedral
// map (y up: the upper half folded flat in the middle, the lower half's four corners out
// over the edges) and back. ROOM_FRAG keeps its own copy of octa_uv.
let OCTA_FN = """
    vec2 octa_uv(vec3 d) {
        d /= abs(d.x) + abs(d.y) + abs(d.z);
        vec2 e = d.y >= 0.0 ? d.xz : (1.0 - abs(d.zx)) * vec2(d.x >= 0.0 ? 1.0 : -1.0, d.z >= 0.0 ? 1.0 : -1.0);
        return e * 0.5 + 0.5;
    }
    vec3 octa_dir(vec2 uv) {
        vec2 e = uv * 2.0 - 1.0;
        vec3 d = vec3(e.x, 1.0 - abs(e.x) - abs(e.y), e.y);
        if (d.y < 0.0) d.xz = (1.0 - abs(d.zx)) * vec2(d.x >= 0.0 ? 1.0 : -1.0, d.z >= 0.0 ? 1.0 : -1.0);
        return normalize(d);
    }
    """;

// One of the six views of the room into the octahedral map: each texel whose direction the
// view frames takes its light there (the light out of the mirror's pass, made safe as
// PLANAR_RESOLVE_FRAG's, back in the room's units); the rest are left. refl_face: the view's
// view_proj (columns), refl_at: the probe (world) and 1 / the exposure, refl_size: the map's
// size.
let REFL_PACK_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D face;
    layout(set = 3, binding = 0) uniform ReflPack { vec4 refl_face[4]; vec4 refl_at; vec4 refl_size; };
    void main() {
        vec3 d = octa_dir(gl_FragCoord.xy / refl_size.xy);
        mat4 m = mat4(refl_face[0], refl_face[1], refl_face[2], refl_face[3]);
        vec4 c = m * vec4(refl_at.xyz + d, 1.0);
        if (c.w <= 0.0) discard;
        vec2 uv = vec2(0.5, -0.5) * c.xy / c.w + 0.5;
        if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) discard;
        vec3 l = textureLod(face, uv, 0.0).rgb;
        float y = dot(l, vec3(0.2126, 0.7152, 0.0722));
        if (!(y >= 0.0 && y <= 1e4)) l = vec3(0.0);
        l = clamp(l, vec3(0.0), vec3(1e4));
        result = vec4(l * refl_at.w, 1.0);
    }
    """;

// A level of the room's reflection for one roughness: the GGX lobe (α refl_level.y, the
// normal and the eye along the texel's direction, as Karis's split sum takes them) over the
// map's mips, each sample from the mip whose texel is as wide as its share of the lobe
// (filtered importance sampling, Křivánek and Colbert). refl_level: x the level drawn, y its
// α, z the map's size at its first level, w the samples.
let REFL_FILTER_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform ReflFilter { vec4 refl_level; };
    const float PI = 3.14159265;
    void main() {
        vec2 size = vec2(textureSize(src, 0)) / exp2(refl_level.x);
        vec2 uv = gl_FragCoord.xy / size;
        float a = refl_level.y;
        if (a <= 0.0) {
            result = vec4(textureLod(src, uv, 0.0).rgb, 1.0);
            return;
        }
        vec3 n = octa_dir(uv);
        vec3 up = abs(n.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        vec3 tx = normalize(cross(up, n));
        vec3 ty = cross(n, tx);
        int count = int(refl_level.w);
        float texel = 4.0 * PI / (refl_level.z * refl_level.z);
        float a2 = a * a;
        vec3 sum = vec3(0.0);
        float weight = 0.0;
        for (int i = 0; i < count; i++) {
            // Hammersley's points.
            uint b = uint(i);
            b = (b << 16u) | (b >> 16u);
            b = ((b & 0x55555555u) << 1u) | ((b & 0xAAAAAAAAu) >> 1u);
            b = ((b & 0x33333333u) << 2u) | ((b & 0xCCCCCCCCu) >> 2u);
            b = ((b & 0x0F0F0F0Fu) << 4u) | ((b & 0xF0F0F0F0u) >> 4u);
            b = ((b & 0x00FF00FFu) << 8u) | ((b & 0xFF00FF00u) >> 8u);
            vec2 xi = vec2(float(i) / float(count), float(b) * 2.3283064365386963e-10);
            float phi = 2.0 * PI * xi.x;
            float cos_t = sqrt((1.0 - xi.y) / (1.0 + (a2 - 1.0) * xi.y));
            float sin_t = sqrt(1.0 - cos_t * cos_t);
            vec3 h = tx * (sin_t * cos(phi)) + ty * (sin_t * sin(phi)) + n * cos_t;
            vec3 l = 2.0 * dot(n, h) * h - n;
            float nl = dot(n, l);
            if (nl <= 0.0) continue;
            float k = (cos_t * cos_t) * (a2 - 1.0) + 1.0;
            float pdf = a2 / (PI * k * k) / 4.0;
            float omega = 1.0 / (float(count) * pdf);
            float lod = max(0.5 * log2(omega / texel), 0.0);
            sum += textureLod(src, octa_uv(l), lod).rgb * nl;
            weight += nl;
        }
        result = vec4(sum / max(weight, 1e-4), 1.0);
    }
    """;
