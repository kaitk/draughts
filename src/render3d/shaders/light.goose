namespace shaders;

// The light every lit surface shares: the sun, the sky and the probes (LIGHT_FN), the
// shadow map's taps, the tonemap (and the tuner's toe), the occlusion's read, and the wind.

// LIT_FRAG's and TABLE_FRAG's shadow in 4 taps or in 16, not 9 (SHADOW_FN): a phone's
// and a desktop's (render3d::set_shadow).
let SHADOW_FEW = "#define SHADOW_FEW 1\n";
let SHADOW_MANY = "#define SHADOW_MANY 1\n";
// The light tuner's shaders (render3d::tuned_frags), after FRAME: each tonemap's toe
// switched by Frame's toe (its --toe, --table-toe, --board-toe, --toe-off). The app's never
// take it: a uniform switch cost the room 0.7 ms a frame on the Mac, and any change to the
// lit shader's text moves a few pixels of the game's picture there.
let TOE_FN = """
    #define TOE_SWITCH 1
    // The toe of the way `way` taking toe.w off (Frame's toe).
    vec3 toe_off(vec3 c, float way) {
        float f = toe.w;
        if (way < 0.5) {
            float y = max(dot(c, vec3(0.2126, 0.7152, 0.0722)), 1e-6);
            return c * ((y < 2.0 * f ? y * y / (4.0 * f) : y - f) / y);
        }
        if (way < 1.5) {
            float x = min(c.r, min(c.g, c.b));
            return c - (x < 2.0 * f ? x - x * x / (4.0 * f) : f);
        }
        return c;
    }
    """;

// The wind in the trees outside (rooms::wind_at), before LIGHT_FN, which reads it for the
// tree's shadow, and in the tree's vertex stages (TREE_FN's tree_moved), so a leaf and its
// fleck in the room move by one vector: the noise, the gust where it reaches, the ruffle
// and the branches' sway. Every shader that takes LIGHT_FN takes this just before it.
let WIND_FN = """
    float window_hash(vec2 p) {
        vec3 p3 = fract(vec3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }
    float window_noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(window_hash(i), window_hash(i + vec2(1.0, 0.0)), u.x),
                   mix(window_hash(i + vec2(0.0, 1.0)), window_hash(i + vec2(1.0, 1.0)), u.x), u.y);
    }

    // The wind at m, a point of the tree's plane (rooms::wind_at, after Zioma's noise of
    // time a layer): x the whole tree's slow sway, -1..1; y the gust, its front crossing
    // the crown along the wall, only in some regions of branches (rooms::gust_regions: a
    // slow noise a branch's reach across, drifting along the wind). With the sines
    // (wind_now.w 1, the tuner's), the gust is their product's peaks, all over the crown.
    vec2 wind_at(vec2 m) {
        if (abs(wind_now.w - 1.0) < 0.5) {
            float front = wind.z * wind.y - m.x * 0.015;
            float sines = (0.5 + 0.5 * sin(front * 0.21)) * (0.6 + 0.4 * sin(front * 0.53 + 2.0));
            return vec2(wind_now.x, smoothstep(0.55, 1.0, sines));
        }
        float g = clamp(wind_now.y + wind_now.z * m.x, 0.0, 1.0);
        if (gust_reach.w > 0.0 && g > 0.0) {
            float n = window_noise(m * (1.0 / 6.0) - vec2(1.0, 0.15) * gust_reach.x);
            g *= smoothstep(gust_reach.z, gust_reach.z + gust_reach.w, n);
        }
        return vec2(wind_now.x, g);
    }

    // Leaves turning in a gust: how far each small patch has turned, 0..1, on a phase of
    // its own, fast. A weight to blend a leaf layer with itself nudged as a whole, so
    // patches flip between two places and nothing is warped.
    float ruffle_at(vec2 m, float gust, float size) {
        float t = wind.z * wind.y;
        float phase = window_noise(m / size) * 6.2832;
        return gust * min(wind.w, 1.0) * (0.5 + 0.5 * sin(t * 7.3 + phase));
    }

    // The branches swaying apart (rooms::WIND_BRANCHES): how far a leaf layer's lookup at
    // m moves in the map, by a slow field a branch's reach across, at most a leaf's width,
    // so neighbouring regions sway a little differently and no shape smears. Two value
    // noises, along and across the wind, each scrolled along it at its own pace, so the
    // field changes its shape as it goes; the farther layers move more and quicker, and
    // quicker still where a gust reaches (its clock run ahead, rooms::gust_clock).
    vec2 branch_sway(vec2 m, float layer, float gusted) {
        vec2 p = m * branches.w + vec2(37.1, 11.7) * layer;
        float c = (branches.x + gusted * gust_reach.y) * (0.3 + 0.06 * layer);
        float along = window_noise(p - vec2(1.0, 0.15) * c);
        float across = window_noise(p.yx + vec2(5.3, 2.9) - vec2(0.4, 0.9) * (1.3 * c));
        float a = (branches.y + gusted * branches.z) * (0.8 + 0.1 * layer);
        return a * vec2(2.0 * along - 1.0, 0.7 * (2.0 * across - 1.0)) / tree.xy;
    }
    """;

// The light's functions LIT_FRAG and TABLE_FRAG share: GGX, its visibility and Fresnel,
// the split sum's fit, the room's harmonics, and the sRGB curve.
let LIGHT_FN = """
    // Filament's GGX, its height-correlated Smith visibility, Schlick's Fresnel.
    float d_ggx(float noh, float a) {
        float a2 = a * a;
        float f = (noh * a2 - noh) * noh + 1.0;
        return a2 / (PI * f * f);
    }

    float v_smith(float nov, float nol, float a) {
        float a2 = a * a;
        float l = nov * sqrt((-nol * a2 + nol) * nol + a2);
        float v = nol * sqrt((-nov * a2 + nov) * nov + a2);
        return 0.5 / (l + v);
    }

    vec3 f_schlick(vec3 f0, float voh) {
        float f = pow(1.0 - voh, 5.0);
        return f0 + (1.0 - f0) * f;
    }

    // Karis's fit of the split-sum's DFG for mobile.
    vec3 env_brdf(vec3 f0, float rough, float nov) {
        vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
        vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
        vec4 r = rough * c0 + c1;
        float a004 = min(r.x * r.x, exp2(-9.28 * nov)) * r.x + r.y;
        vec2 ab = vec2(-1.04, 1.04) * a004 + r.zw;
        return f0 * ab.x + ab.y;
    }

    vec3 sh_eval(vec3 n) {
        vec3 r = sh[0].rgb * 0.282095
               + sh[1].rgb * (0.488603 * n.y) + sh[2].rgb * (0.488603 * n.z)
               + sh[3].rgb * (0.488603 * n.x)
               + sh[4].rgb * (1.092548 * n.x * n.y) + sh[5].rgb * (1.092548 * n.y * n.z)
               + sh[6].rgb * (0.315392 * (3.0 * n.y * n.y - 1.0))
               + sh[7].rgb * (1.092548 * n.x * n.z)
               + sh[8].rgb * (0.546274 * (n.x * n.x - n.z * n.z));
        return max(r, vec3(0.0));
    }

    // How much of the key the tree outside lets through to p (trees.goose): p carried
    // along the key onto the map, which holds the tree as the sun sees it, blurred by the
    // sun's disc at each layer's distance, so its gaps are round flecks. Farther from the
    // window than the board's middle, its mips blur it more. Each layer sways on its own.
    // x the limbs' light, y the leaves', the leaves blurred tree_blur.z mips more (with
    // the noise's leaves inside the crown, its shape alone).
    vec2 tree_light(vec3 p, vec3 l, vec2 nw, vec2 along, float toward) {
        float back = dot(p.xz, nw) / toward;
        vec2 m = vec2(dot(p.xz, along) - dot(l.xz, along) * back, p.y - l.y * back);
        vec2 uv = (m - tree.zw) / tree.xy + 0.5;
        float more = max(back * back - 2.0 * tree_blur.y * back, 0.0);
        float lod = 0.5 * log2(max(more * tree_blur.x * tree_blur.x, 1.0));
        // Each layer shifts as a whole, by its own noises along and across the wind
        // (rooms::wind_at), the gust's share as its front reaches m. Nothing bends a limb.
        float gust = wind_at(m).y;
        float t = wind.z * wind.y;
        // The ruffle: the near and middle leaves blended with themselves nudged a leaf's
        // width, patch by patch; its noise worked out only where it may turn a patch 5% or more
        // (less moved a still shot by at most a level).
        float turn = gust * min(wind.w, 1.0) > 0.05 && wind_now.w < 1.5 ? ruffle_at(m, gust, 1.5) : 0.0;
        vec2 nudge = vec2(cos(t * 5.1), sin(t * 4.3)) * (0.35 / tree.xy);
        float wood = textureLod(tree_map, uv + tree_shift[0].xy + gust * tree_shift[0].zw, lod).a;
        float leafy = lod + tree_blur.z;
        vec2 at_near = uv + tree_shift[1].xy + gust * tree_shift[1].zw;
        vec2 at_mid = uv + tree_shift[2].xy + gust * tree_shift[2].zw;
        vec2 at_far = uv + tree_shift[3].xy + gust * tree_shift[3].zw;
        // The branches: each layer moved by region, never blended with itself.
        if (wind_now.w > 1.5) {
            at_near += branch_sway(m, 0.0, gust);
            at_mid += branch_sway(m, 1.0, gust);
            at_far += branch_sway(m, 2.0, gust);
            turn = 0.0;
        }
        float near = textureLod(tree_map, at_near, leafy).r;
        float middle = textureLod(tree_map, at_mid, leafy).g;
        if (turn > 0.001) {
            near = mix(near, textureLod(tree_map, at_near + nudge, leafy).r, turn);
            middle = mix(middle, textureLod(tree_map, at_mid - nudge.yx, leafy).g, turn);
        }
        float far = textureLod(tree_map, at_far, leafy).b;
        return vec2(wood, near * middle * far);
    }

    // The noise's leaves at p, t along the key from the window's wall: clumps rounder
    // and softer the farther they are, and single leaves within them.
    float noise_leaves(vec3 p, vec3 l, vec2 along, float toward, float t) {
        float tl = t + leaves.z / toward;
        vec3 ql = p + l * tl;
        vec2 lw = vec2(dot(ql.xz, along), ql.y) * leaves.y;
        // The wind: the canopy shifts with the sway, and in a gust warps a little, each
        // clump out of step.
        vec2 wa = wind_at(vec2(dot(ql.xz, along), ql.y));
        float tw = wind.z * wind.y;
        float warp = 0.3 + 0.7 * wa.y;
        lw += wind.x * (vec2(1.0, 0.15) * (wa.x + 1.5 * wa.y)
                        + warp * vec2(sin(tw * 0.9 + lw.y * 0.7), 0.6 * cos(tw * 0.7 + lw.x * 0.5)));
        float n = 0.55 * window_noise(lw) + 0.3 * window_noise(lw * 2.03 + 7.1)
                + 0.15 * window_noise(lw * 4.1 + 3.7);
        float ls = 0.02 + room.z * tl * leaves.y * leaves.w;
        float open_sky = smoothstep(leaves.x - ls, leaves.x + ls, n);
        // The single leaves within: under a clump only their gaps let the sun through,
        // small round flecks; in the open their own small shadows, fainter. They
        // flutter faster than the branches sway.
        if (twigs.x > 0.0) {
            vec2 lf = lw * twigs.x;
            float m = 0.65 * window_noise(lf) + 0.35 * window_noise(lf * 2.13 + 5.3);
            float gaps = smoothstep(twigs.y - twigs.z, twigs.y + twigs.z, m);
            open_sky = mix(gaps, mix(1.0, gaps, twigs.w), open_sky);
        }
        return open_sky;
    }

    #ifdef SHELL_WINDOWS
    // The shell's box windows (room_shell, shell_mesh.goose's casement, metres): how much
    // of the sun the casement at a glass plane lets through at w (along from the window's
    // middle, up from the floor): the blind frame's opening, the transom, the meeting
    // stiles, each sash's stiles and rails, and its bars, each edge `soft` wide. `slope`:
    // how far the sun's line moves along the wall and up a metre deeper into it (0 the
    // members flat at the plane; Frame's panes.w 1, the light tuner's --light physical): each
    // member's band then widened by its depth along it, the frame's 0.1 m, the sashes' 0.045
    // and the bars' 0.036 (room_shell::casement_members), the sashes and bars taken at their
    // middle, 2.5 and 3 mm deeper than the plane.
    float casement(vec2 w, float soft, vec2 slope) {
        const float BAR = 0.024;
        vec2 frame = 0.05 * abs(slope);
        vec2 sash = 0.0225 * abs(slope);
        vec2 bar = 0.018 * abs(slope);
        vec2 ws = w + 0.0025 * slope;
        vec2 wb = w + 0.003 * slope;
        float s = shell_niche.y;
        float h = shell_niche.y + shell_niche.z;
        float zt = s + (h - s) * 2.0 / 3.0;
        float gx = 0.49;
        float x = abs(w.x);
        float xs = abs(ws.x);
        float open = min(gx - x - frame.x, min(w.y - (s + 0.03) - frame.y, (h - 0.06) - w.y - frame.y));
        open = min(open, min(abs(w.y - zt) - 0.045 - frame.y, xs - (0.0175 + 0.05) - sash.x));
        bool upper = ws.y > zt;
        float y0 = upper ? zt + 0.045 : s + 0.03;
        float y1 = upper ? h - 0.06 : zt - 0.045;
        float ax0 = 0.0175 + 0.05;
        float ax1 = gx - 0.055;
        float ay0 = y0 + (upper ? 0.055 : 0.08);
        float ay1 = y1 - 0.055;
        open = min(open, min(ax1 - xs - sash.x, min(ws.y - ay0 - sash.y, ay1 - ws.y - sash.y)));
        float across = upper ? 3.0 : 1.0;
        float up = upper ? 3.0 : 2.0;
        float pitch_x = (ax1 - ax0 + BAR) / across;
        float pitch_y = (ay1 - ay0 + BAR) / up;
        // The bars: each the width BAR, its far edge at a whole pitch from the leaf's edge.
        float u = abs(wb.x) - ax0 + 0.5 * BAR;
        float v = wb.y - ay0 + 0.5 * BAR;
        if (across > 1.5 && u > 0.5 * pitch_x && u < (across - 0.5) * pitch_x)
            open = min(open, abs(u - pitch_x * floor(u / pitch_x + 0.5)) - 0.5 * BAR - bar.x);
        if (v > 0.5 * pitch_y && v < (up - 0.5) * pitch_y)
            open = min(open, abs(v - pitch_y * floor(v / pitch_y + 0.5)) - 0.5 * BAR - bar.y);
        return smoothstep(-soft, soft, open);
    }

    // How much of the casement's glazed opening (the blind frame's, its sashes and bars
    // taken as LACE_GLAZED on average) is at w, its edge `soft` wide: where the sun through
    // the glass can light the lace, so what the lace scatters on starts there, never at the
    // frame or the plaster round it.
    float glazing(vec2 w, float soft) {
        float s = shell_niche.y;
        float h = shell_niche.y + shell_niche.z;
        return smoothstep(-soft, soft, min(0.49 - abs(w.x), min(w.y - (s + 0.03), (h - 0.06) - w.y)));
    }

    // The curtains' lace panels (model3d's curtains.goose): a panel's height, inner edge and
    // outer edge (metres from the window's middle) at its outline's keys, shell.goose's
    // LACE_HUNG_AS_MADE and LACE_OUTER, taken straight between them here; the inner edge
    // hung shell_mids.w further over the opening (room_shell::lace_hang).
    const vec3 LACE_EDGES[6] = vec3[6](vec3(0.05, 0.585, 0.955), vec3(0.5, 0.615, 0.89), vec3(0.95, 0.645, 0.8),
                                       vec3(1.6, 0.58, 0.85), vec3(2.6, 0.45, 0.89), vec3(3.7, 0.35, 0.9));
    vec2 lace_edges(float y) {
        vec2 e = LACE_EDGES[0].yz;
        for (int i = 0; i < 5; i++) {
            if (y > LACE_EDGES[i].x) {
                float t = clamp((y - LACE_EDGES[i].x) / (LACE_EDGES[i + 1].x - LACE_EDGES[i].x), 0.0, 1.0);
                e = mix(LACE_EDGES[i].yz, LACE_EDGES[i + 1].yz, t);
            }
        }
        return e - vec2(shell_mids.w, 0.0);
    }

    // Where uv (world units: across the cloth from its outer edge, up it from the hem) falls
    // in the lace's mask: the field's tile (its first 1024 rows) repeating, on down into
    // the hem's strip (its last 384 rows, 0.21 m) at the cloth's foot, at one scale.
    vec2 lace_place(vec2 uv) {
        float k = (0.375 * tile.z - uv.y) / tile.z;
        float row = k > 0.0 ? 1.0 + min(k, 0.3745) : fract(k);
        return vec2(uv.x / tile.z, row * (1024.0 / 1408.0));
    }

    // How much of the sun the lace in front of a niche lets on at w (metres from the
    // window's middle, up from the floor, at its plane): its thread keeps out all but
    // shell_glass.w where it covers, about a quarter of the sun where the panel hangs at its
    // 2× fullness (0.55 m wide), more where it is gathered narrower toward the tie (as
    // model3d's room_light::lace_lets); its pattern half washed out, since the lace scatters
    // on forward much of what it doesn't let straight through, blurred to the shadow's
    // softness, a little denser on the folds' flanks.
    // A machine lace's net ground stops about a fifth of the sun, its motifs as much as the
    // thread does (1 - shell_glass.w); the pattern shows at LACE_PATTERN_SHOWN of its
    // contrast, the rest scattered on.
    const float LACE_NET_STOPS = 0.2;
    const float LACE_PATTERN_SHOWN = 0.75;
    #ifndef WINDOW_MAP
    // y: with wide over 0, the share of the sun the lace stops on average round w (its
    // outline blurred wide, the pattern's mean), for its light below; else 0.
    vec2 lace_shadow(vec2 w, float soft, float wide) {
        vec2 e = lace_edges(w.y);
        float x = abs(w.x);
        float edge = min(min(x - e.x, e.y - x), min(w.y - 0.07, 3.7 - w.y));
        float scattered = 0.0;
        if (wide > 0.0) {
            float mean_lets = 1.0 - mix(LACE_NET_STOPS, 1.0 - shell_glass.w, 0.5);
            scattered = smoothstep(-wide, wide, edge) * (1.0 - pow(mean_lets, max(0.55 / max(e.y - e.x, 0.05), 1.0)));
        }
        float inside = smoothstep(-soft, soft, edge);
        if (inside < 0.001) return vec2(1.0, scattered);
        float s = clamp((x - e.x) / (e.y - e.x), 0.0, 1.0);
        vec2 uv = vec2((1.0 - s) * 1.2, w.y - 0.07) * shell.w;
        float cover = textureLod(lace_mask, lace_place(uv), log2(max(soft * 1024.0 / 0.56, 1.0))).r;
        cover = mix(0.5, cover, LACE_PATTERN_SHOWN);
        float folds = 0.8 + 0.4 * (0.5 + 0.5 * sin(6.2831853 * 6.0 * s));
        float flat_lets = 1.0 - clamp(mix(LACE_NET_STOPS, 1.0 - shell_glass.w, cover) * folds, 0.0, 0.9);
        return vec2(mix(1.0, pow(flat_lets, max(0.55 / max(e.y - e.x, 0.05), 1.0)), inside), scattered);
    }
    #endif

    // The share of the sun the lace stops that it scatters on forward into a broad cone
    // (thin cloth, as a lit lace glows), and that cone's widening a metre: about 25° across.
    // The casement's glazing lets through about LACE_GLAZED of the sun on average, which the
    // cone's light, blurred past the bars, takes.
    const float LACE_FORWARD = 0.35;
    const float LACE_CONE = 0.22;
    const float LACE_SOFT = 0.006;
    const float LACE_GLAZED = 0.7;

    #ifdef WINDOW_MAP_PLACE
    // The window's light map (render3d::window_map_pass): the shell's pattern baked in the
    // window wall's inner face, where the key's ray from a point crosses it, over the strip
    // that holds the windows and WINDOW_MAP_MARGIN (metres) round their niches. x and y its
    // lower corner (along the wall, up; world units), z and w its size.
    const float WINDOW_MAP_MARGIN = 0.2;
    const vec2 WINDOW_MAP_SIZE = vec2(2048.0, 832.0);   // render3d::WINDOW_MAP_W, WINDOW_MAP_H
    vec4 window_map_place() {
        float lo = shell_mids.x;
        float hi = shell_mids.x;
        for (int i = 1; i < 3; i++) {
            if (float(i) >= shell.x) break;
            lo = min(lo, shell_mids[i]);
            hi = max(hi, shell_mids[i]);
        }
        float side = (shell_niche.x + WINDOW_MAP_MARGIN) * shell.w;
        float y0 = shell.z + (shell_niche.y - WINDOW_MAP_MARGIN) * shell.w;
        float y1 = shell.z + (shell_niche.y + shell_niche.z + shell_niche.w + WINDOW_MAP_MARGIN) * shell.w;
        return vec4(lo - side, y0, hi - lo + 2.0 * side, y1 - y0);
    }
    // How far past the face (world units) the map's lace channels are baked for: a little
    // past where shell_open first takes the lace (its distance from the lace over 0.5).
    float window_map_lace_t(float toward) { return 0.6 + shell_glass.z / toward; }
    #endif

    #ifdef WINDOW_MAP
    // The mip that blurs an edge baked soft_ref soft (smoothstep's half width, metres) on to
    // soft: a level's box with its bilinear tap spreads (2^L texel)²/4, a smoothstep s²/5.
    float window_map_lod(float soft, float soft_ref, float texel) {
        return log2(max(0.894 * sqrt(max(soft * soft - soft_ref * soft_ref, 0.0)) / texel, 1.0));
    }

    // shell_open from the window's light map: the nearest niche's outline as shell_open has
    // it, times the map where the key's ray from p crosses the inner face (behind p within
    // the niche; on the inner glass and past it the outer casement's, traced): its
    // casements' light (g), or past the lace that with the lace's shadow (r) and what the
    // lace scatters on (a, its outline's part; the glazing's traced), each blurred on by a
    // mip to its softness at p; then
    // the tree's light (b, 1 where the map holds none), blurred on as tree_light blurs it,
    // or with WINDOW_MAP_LEAVES while the leaves move (shell_ends.z 0) tree_light itself.
    float shell_open(vec3 p) {
        vec3 l = light_dir.xyz;
        vec2 nw = -axes.zw;
        vec2 along = axes.xy;
        float toward = dot(l.xz, nw);
        if (toward < 0.05) return 0.0;
        float metre = shell.w;
        float widen = shell_sun.x > 0.0 ? shell_sun.x : room.z;
        float d = dot(p.xz, nw);
        float t0 = (shell.y - d) / toward;
        float t = max(t0, 0.0);
        vec3 q = p + l * t;
        float u = dot(q.xz, along);
        float mid = shell_mids.x;
        for (int i = 1; i < 3; i++) {
            if (float(i) >= shell.x) break;
            if (abs(u - shell_mids[i]) < abs(u - mid)) mid = shell_mids[i];
        }
        float half_w = shell_niche.x;
        float rise = shell_niche.w;
        float radius = (half_w * half_w + rise * rise) / (2.0 * rise);
        float arch_mid = shell_niche.y + shell_niche.z + rise - radius;
        vec2 w = vec2(u - mid, q.y - shell.z) / metre;
        float soft = (0.03 + widen * t) / metre;
        float head = arch_mid + sqrt(max(radius * radius - w.x * w.x, 0.0));
        float through = smoothstep(-soft, soft, min(half_w - abs(w.x), min(w.y - shell_niche.y, head - w.y)));
        if (through < 0.001) return 0.0;
        vec3 q0 = p + l * t0;
        vec4 place = window_map_place();
        vec2 uv = vec2((dot(q0.xz, along) - place.x) / place.z, (q0.y - place.y) / place.w);
        vec2 texels = place.zw / (metre * WINDOW_MAP_SIZE);
        float texel = max(texels.x, texels.y);
        // The bars' softness at the inner glass, at p and as baked.
        float glass = shell_glass.x / toward;
        float bars = (0.03 + widen * (t + glass)) / metre;
        float tl = t0 - shell_glass.z / toward;
        float lit;
        if (t0 + glass <= 0.0) {
            // On the inner glass or past it (the sashes' faces): the outer casement's alone,
            // which the map doesn't hold, traced here.
            float tg = t0 + shell_glass.y / toward;
            vec3 g = p + l * tg;
            vec2 wg = vec2(dot(g.xz, along) - mid, g.y - shell.z) / metre;
            lit = tg > 0.0 ? through * casement(wg, (0.03 + widen * tg) / metre, vec2(dot(l.xz, along), l.y) * (panes.w / toward)) : through;
        } else if (tl > 0.5) {
            float tr = window_map_lace_t(toward);
            vec4 m = textureLod(window_map, uv, window_map_lod(bars, (0.03 + widen * (tr + glass)) / metre, texel));
            lit = through * m.r;
            if (window_view.y > 0.0) {
                float tlr = tr - shell_glass.z / toward;
                float wide = (0.03 + widen * tl + (LACE_SOFT + LACE_CONE) * tl) / metre;
                float wide_r = (0.03 + widen * tlr + (LACE_SOFT + LACE_CONE) * tlr) / metre;
                // The glazing the cone sees, traced: blurred apart from the lace's outline,
                // as the map can't blur their product.
                float cone = LACE_CONE * tl / metre;
                float glazed = 1.0;
                for (int k = 0; k < 2; k++) {
                    float tg = t0 + (k == 0 ? shell_glass.x : shell_glass.y) / toward;
                    vec3 g = p + l * tg;
                    vec2 wg = vec2(dot(g.xz, along) - mid, g.y - shell.z) / metre;
                    glazed *= glazing(wg, (0.03 + widen * tg) / metre + cone);
                }
                float lace_wide = textureLod(window_map, uv, window_map_lod(wide, wide_r, texel)).a;
                lit += window_view.y * LACE_FORWARD * LACE_GLAZED * glazed * lace_wide;
            }
        } else {
            lit = through * textureLod(window_map, uv, window_map_lod(bars, (0.03 + widen * glass) / metre, texel)).g;
        }
        lit = min(lit, 1.0);
    #ifdef WINDOW_MAP_LEAVES
        if (shell_ends.z < 0.5) {
            if (tree.x > 0.0 && lit > 0.001) {
                vec2 leaves_lit = tree_light(p, l, nw, along, toward);
                lit *= leaves_lit.x * leaves_lit.y;
            }
            return lit;
        }
    #endif
        // The tree's blur at p past its blur at the face (tree_light's lod: a radius of
        // 2^lod of its map's texels), as the map's.
        float tree_lod = 0.0;
        if (tree.x > 0.0 && t0 > 0.0) {
            float back = d / toward;
            float face = shell.y / toward;
            float tb2 = tree_blur.x * tree_blur.x;
            float r2 = max((back * back - 2.0 * tree_blur.y * back) * tb2, 1.0);
            float r2_face = max((face * face - 2.0 * tree_blur.y * face) * tb2, 1.0);
            float tree_texel = tree.x / (metre * float(textureSize(tree_map, 0).x));
            tree_lod = log2(max(sqrt(max(r2 - r2_face, 0.0)) * tree_texel / texel, 1.0));
        }
        return lit * textureLod(window_map, uv, tree_lod).b;
    }
    #else
    // How much of the key reaches p through the shell's windows, 0 to 1: p traced along the
    // key to the window wall's inner face (the niche's arched outline: or where p is, if it
    // is in the niche), on to the two glass planes with their bars, and back to the lace in
    // front, which lets on the scattered share of what it stops softly round its shadow
    // (window_view.y, 0 none); summed over the windows, then the tree outside.
    float shell_open(vec3 p) {
        vec3 l = light_dir.xyz;
        vec2 nw = -axes.zw;
        vec2 along = axes.xy;
        float toward = dot(l.xz, nw);
        if (toward < 0.05) return 0.0;
        float metre = shell.w;
        // The penumbra's widening with distance: the shell's own, sharper than the game's
        // window takes it.
        float widen = shell_sun.x > 0.0 ? shell_sun.x : room.z;
        float d = dot(p.xz, nw);
        float half_w = shell_niche.x;
        float rise = shell_niche.w;
        float radius = (half_w * half_w + rise * rise) / (2.0 * rise);
        float spring = shell_niche.y + shell_niche.z;
        float arch_mid = spring + rise - radius;
        vec2 slope = vec2(dot(l.xz, along), l.y) * (panes.w / toward);
        float lit = 0.0;
        for (int i = 0; i < 3; i++) {
            if (float(i) >= shell.x) break;
            float mid = shell_mids[i];
            // The niche's outline at the inner face, or at p within the niche.
            float t = max((shell.y - d) / toward, 0.0);
            vec3 q = p + l * t;
            vec2 w = vec2(dot(q.xz, along) - mid, q.y - shell.z) / metre;
            float soft = (0.03 + widen * t) / metre;
            float head = arch_mid + sqrt(max(radius * radius - w.x * w.x, 0.0));
            float through = smoothstep(-soft, soft, min(half_w - abs(w.x), min(w.y - shell_niche.y, head - w.y)));
            if (through < 0.001) continue;
            // The lace in front of the niche, for what is behind it in the room: its shadow a
            // little softer than the bars' (LACE_SOFT a metre, its threads' own scatter), and
            // what it scatters on from a cone LACE_CONE wide, lit only where the glass is.
            float tl = (shell.y - shell_glass.z - d) / toward;
            float cone = window_view.y > 0.0 && tl > 0.5 ? LACE_CONE * tl / metre : 0.0;
            // The two casements, and their glazed opening as the lace's cone sees it.
            float glazed = 1.0;
            for (int k = 0; k < 2; k++) {
                float tg = (shell.y + (k == 0 ? shell_glass.x : shell_glass.y) - d) / toward;
                if (tg <= 0.0) continue;
                vec3 g = p + l * tg;
                vec2 wg = vec2(dot(g.xz, along) - mid, g.y - shell.z) / metre;
                float soft_g = (0.03 + widen * tg) / metre;
                through *= casement(wg, soft_g, slope);
                if (cone > 0.0) glazed *= glazing(wg, soft_g + cone);
            }
            if (tl > 0.5) {
                vec3 c = p + l * tl;
                vec2 wl = vec2(dot(c.xz, along) - mid, c.y - shell.z) / metre;
                float soft_l = (0.03 + widen * tl) / metre + LACE_SOFT * tl / metre;
                vec2 lace = lace_shadow(wl, soft_l, cone > 0.0 ? soft_l + cone : 0.0);
                through = through * lace.x + window_view.y * LACE_FORWARD * LACE_GLAZED * glazed * lace.y;
            }
            lit += through;
        }
        lit = min(lit, 1.0);
        if (tree.x > 0.0 && lit > 0.001) {
            vec2 tr = tree_light(p, l, nw, along, toward);
            lit *= tr.x * tr.y;
        }
        return lit;
    }
    #endif
    #endif

    // How much of the key reaches p through the window (rooms::Room's pattern), 0 to 1: p
    // traced along the key to the window's wall, where the opening, its bars, and the
    // curtain say whether the sun came through, and on to the trees beyond, whose leaves
    // dapple it; each edge softer the farther it is from p. 1 with no pattern. A wall keeps
    // all of the sun out: a highlight takes this.
    float window_open(vec3 p) {
        if (room.y <= 0.0) return 1.0;
    #ifdef SHELL_WINDOWS
        if (shell.x > 0.5) return shell_open(p);
    #endif
        vec3 l = light_dir.xyz;
        vec2 h = normalize(l.xz);
        float a = radians(window.y);
        vec2 nw = vec2(cos(a) * h.x - sin(a) * h.y, sin(a) * h.x + cos(a) * h.y);
        vec2 along = vec2(-nw.y, nw.x);
        float toward = dot(l.xz, nw);
        if (toward < 0.05) return 0.0;
        float t = (window.x - dot(p.xz, nw)) / toward;
        vec3 q = p + l * t;
        // Along the wall from where the board's middle sees the sun, up from the sill.
        vec2 w = vec2(dot(q.xz - l.xz * (window.x / toward), along) - window.w, q.y - window.z);
        float soft = 0.03 + room.z * t;
        vec2 size = opening.xy * panes.xy;
        float inside = min(size.x * 0.5 - abs(w.x), min(w.y, size.y - w.y));
        float lit = smoothstep(-soft, soft, inside);
        // The bars between the panes.
        vec2 f = abs(fract(vec2(w.x / panes.x + opening.x * 0.5, w.y / panes.y) + 0.5) - 0.5) * panes.xy;
        lit *= smoothstep(-soft, soft, min(f.x, f.y) - panes.z * 0.5);
        // The lace curtain drawn in from the opening's far side, its edge in folds.
        if (opening.z > 0.0) {
            float edge = size.x * 0.5 - opening.z + 0.6 * sin(w.y * 0.35) + 0.3 * sin(w.y * 0.9 + 1.3);
            lit *= mix(1.0, opening.w, smoothstep(edge - 2.0 * soft, edge + 2.0 * soft, w.x));
        }
        // The leaves outside: the tree's baked shadow, or clumps of noise, rounder and
        // softer the farther they are.
        if (tree.x > 0.0) {
            vec2 tr = tree_light(p, l, nw, along, toward);
            // With the noise's leaves inside the tree's crown: its limbs, and the dapple
            // where it has leaves; a bare tree's crown has none.
            float crown = clamp((1.0 - tr.y) * tree_blur.w, 0.0, 1.0);
            float leaves_lit = tree_blur.z > 0.0 ? mix(1.0, noise_leaves(p, l, along, toward, t), crown) : tr.y;
            lit *= tr.x * leaves_lit;
        } else if (leaves.x > 0.0) {
            lit *= noise_leaves(p, l, along, toward, t);
        }
        return lit;
    }

    // The key's light through the window as the diffuse takes it: the shade keeps out
    // room.y of it, the rest standing for the light the room throws back (the game's room
    // has no other).
    float window_light(vec3 p) {
        if (room.y <= 0.0) return 1.0;
        return mix(1.0 - room.y, 1.0, window_open(p));
    }

    vec3 to_srgb(vec3 c) {
        c = clamp(c, 0.0, 1.0);
        return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
    }
    """;

// The key light's shadow map filtered (map_shadow_at), which LIT_FRAG and TABLE_FRAG
// share: after their heads, which bind shadow_map. SHADOW_FEW or SHADOW_MANY first picks
// the taps.
let SHADOW_FN = """
    // The key light's shadow at q, a point already off its surface: a 5 × 5 texel box
    // with bilinear edges in 9 hardware-compared taps, their places and weights from where
    // the point falls in its texel (Castaño's filter, as The Witness has it). On a phone (SHADOW_FEW first) a 3 × 3 box in 4 taps, its edges stepped where
    // larger pieces would show them. On a desktop (SHADOW_MANY) a 7 × 7 box in 16 taps, softer.
    float map_shadow_at(vec3 q) {
        vec4 s = light_view_proj * vec4(q, 1.0);
        // Past the map, beside the board on its table: lit by the map.
        if (abs(s.x) > 1.0 || abs(s.y) > 1.0) return 1.0;
        vec2 size = vec2(textureSize(shadow_map, 0));
        vec2 uv = vec2(s.x * 0.5 + 0.5, 0.5 - s.y * 0.5) * size;
        float z = s.z - 0.0005;
        vec2 base = floor(uv + 0.5);
        vec2 f = uv + 0.5 - base;
        base = (base - 0.5) / size;
    #ifdef SHADOW_FEW
        vec2 w0 = 3.0 - 2.0 * f;
        vec2 w1 = 1.0 + 2.0 * f;
        vec2 o0 = ((2.0 - f) / w0 - 1.0) / size;
        vec2 o1 = (f / w1 + 1.0) / size;
        float sum = w0.x * w0.y * texture(shadow_map, vec3(base + vec2(o0.x, o0.y), z))
                  + w1.x * w0.y * texture(shadow_map, vec3(base + vec2(o1.x, o0.y), z))
                  + w0.x * w1.y * texture(shadow_map, vec3(base + vec2(o0.x, o1.y), z))
                  + w1.x * w1.y * texture(shadow_map, vec3(base + vec2(o1.x, o1.y), z));
        return sum * (1.0 / 16.0);
    #else
    #ifdef SHADOW_MANY
        // A desktop's: a 7 × 7 box in 16 taps.
        vec4 w0 = vec4(5.0 * f.x - 6.0, 11.0 * f.x - 28.0, -(11.0 * f.x + 17.0), -(5.0 * f.x + 1.0));
        vec4 u = vec4((4.0 * f.x - 5.0) / w0.x - 3.0, (4.0 * f.x - 16.0) / w0.y - 1.0,
                      -(7.0 * f.x + 5.0) / w0.z + 1.0, -f.x / w0.w + 3.0) / size.x;
        vec4 w1 = vec4(5.0 * f.y - 6.0, 11.0 * f.y - 28.0, -(11.0 * f.y + 17.0), -(5.0 * f.y + 1.0));
        vec4 v = vec4((4.0 * f.y - 5.0) / w1.x - 3.0, (4.0 * f.y - 16.0) / w1.y - 1.0,
                      -(7.0 * f.y + 5.0) / w1.z + 1.0, -f.y / w1.w + 3.0) / size.y;
        float sum = 0.0;
        for (int j = 0; j < 4; j++) {
            for (int i = 0; i < 4; i++) {
                sum += w0[i] * w1[j] * texture(shadow_map, vec3(base + vec2(u[i], v[j]), z));
            }
        }
        return sum * (1.0 / 2704.0);
    #else
        vec3 w0 = vec3(4.0 - 3.0 * f.x, 7.0, 1.0 + 3.0 * f.x);
        vec3 u = vec3((3.0 - 2.0 * f.x) / w0.x - 2.0, (3.0 + f.x) / 7.0, f.x / w0.z + 2.0) / size.x;
        vec3 w1 = vec3(4.0 - 3.0 * f.y, 7.0, 1.0 + 3.0 * f.y);
        vec3 v = vec3((3.0 - 2.0 * f.y) / w1.x - 2.0, (3.0 + f.y) / 7.0, f.y / w1.z + 2.0) / size.y;
        float sum = 0.0;
        for (int j = 0; j < 3; j++) {
            for (int i = 0; i < 3; i++) {
                sum += w0[i] * w1[j] * texture(shadow_map, vec3(base + vec2(u[i], v[j]), z));
            }
        }
        return sum * (1.0 / 144.0);
    #endif
    #endif
    }
    """;

// The room's tonemap, which the room (ROOM_FRAG) and the view out of its windows
// (OUTSIDE_FRAG) share, so the window and the room sit on one curve: the board's curve,
// its toe taken on the luminance and scaled into every channel: taking the least channel
// off, as the board does, turns the room's dim oak orange.
let TONE_FN = """
    vec3 tonemap(vec3 c) {
    #ifdef TOE_SWITCH
        c = toe_off(c, toe.x);
    #else
        float y = max(dot(c, vec3(0.2126, 0.7152, 0.0722)), 1e-6);
        c *= (y < 0.04 ? 12.5 * y * y : y - 0.02) / y;
    #endif
        float peak = max(c.r, max(c.g, c.b));
        const float start = 0.76;
        if (peak < start) return c;
        const float d = 1.0 - start;
        float np = 1.0 - d * d / (peak + d - start);
        c *= np / peak;
        float g = 1.0 - 1.0 / (0.15 * (peak - np) + 1.0);
        return mix(c, vec3(np), g);
    }
    // The floor's mirror keeps the light as it is, before the tonemap (exposed, linear), so
    // the sky through the glass stays as far over the backlit lace as it is; only the sun's
    // disc and its halo are held to MIRROR_PEAK, which the floor's blur spreads anyway.
    const float MIRROR_PEAK = 16.0;
    vec3 mirror_light(vec3 c) {
        float peak = max(c.r, max(c.g, c.b));
        return peak > MIRROR_PEAK ? c * (MIRROR_PEAK / peak) : c;
    }
    #ifdef HDR_OUT
    // The scenic views' HDR target takes the light with tonemap's toe alone taken off; the
    // shoulder and the grade are HDR_TONE_FRAG's. None where Frame's toe.x says 2 (the
    // camera's curve takes it).
    vec3 room_toe(vec3 c) {
        if (toe.x > 1.5) return c;
        float y = max(dot(c, vec3(0.2126, 0.7152, 0.0722)), 1e-6);
        return c * ((y < 0.04 ? 12.5 * y * y : y - 0.02) / y);
    }
    #endif
    """;

// The room's occlusion at this pixel, from the half-size map (ssao_map, the block's ssao: x
// how strong, 0 none; y the tuner's views, 1 the occlusion alone, 2 all the indirect light
// keeps; zw the map's texels a pixel): its four texels round the pixel, each by its bilinear
// weight over how far its distance from the eye is from p's, so an edge takes its own side;
// 1 where none is within 5%, as behind the lace. ssao_kept: the light kept at the strength.
// With NO_SSAO (the phone's tier, and the floor's mirror, which draws no map of its own)
// both 1, the map not read.
let SSAO_FN = """
    #ifdef NO_SSAO
    float ssao_at(vec3 p) { return 1.0; }
    float ssao_kept(float raw) { return 1.0; }
    #else
    float ssao_at(vec3 p) {
        if (ssao.x <= 0.0) return 1.0;
        vec2 at = gl_FragCoord.xy * ssao.zw;
        vec2 f = at - floor(at);
        ivec2 i0 = ivec2(floor(at));
        ivec2 last = textureSize(ssao_map, 0) - 1;
        float d = length(p - eye.xyz);
        float sum = 0.0;
        float total = 0.0;
        float nearest = 1.0;
        for (int k = 0; k < 4; k++) {
            ivec2 o = ivec2(k % 2, k / 2);
            vec2 s = texelFetch(ssao_map, clamp(i0 + o, ivec2(0), last), 0).rg;
            float gap = abs(s.y - d) / d;
            nearest = min(nearest, gap);
            float w = ((o.x == 1 ? f.x : 1.0 - f.x) * (o.y == 1 ? f.y : 1.0 - f.y) + 1e-3) / (0.002 + gap);
            sum += w * s.x;
            total += w;
        }
        return nearest > 0.05 ? 1.0 : sum / total;
    }
    float ssao_kept(float raw) { return clamp(1.0 - ssao.x * (1.0 - raw), 0.0, 1.0); }
    #endif
    """;

// Without the screen's maps (SSAO_FN's ssao_map and the contact shadows' pre_place): the
// phone's tier, which draws neither (render3d::ssao_allowed).
let NO_SSAO = "#define NO_SSAO 1\n";
