namespace shaders;

// The wood baked at startup into textures with mips: the board, the table, the room.

// BAKE_FRAG with the black marble slab (render3d::BAKE_SLAB), the table's alone
// (BAKE_TABLE), or the room's oak alone (BAKE_ROOM); without any the rest of the board's.
let BAKE_SLAB = "#define BAKE_SLAB 1\n";
let BAKE_TABLE = "#define BAKE_TABLE 1\n";
let BAKE_ROOM = "#define BAKE_ROOM 1\n";

// The board's surfaces, baked once per theme into two targets: albedo and roughness
// (sRGB), and the normal's x and z. mode.x 0 bakes the plan of the field and its inlay,
// seen from above; 1 the frame map, its grain along u; 2 the table's top seen from
// above, its wood in the light squares' slots (table_cut); 3 the table's wear (wear_at);
// 4 and 5 the room's oak, the floor's field and the wall's (oak_at, in the slots
// surfaces::Oak names). mode.y: the wood's model
// (--wood): 0 noise drawn out along the grain, 1 growth rings, 2 growth
// rings with pores and a fibre relief, 3 the first with thin lines and pores laid over
// it. size: the target in texels, then in world units. The rest is the theme's
// (looks::Theme): each surface's color and roughness and its figure.
let BAKE_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 out_albedo;
    layout(location = 1) out vec4 out_normal;
    layout(set = 3, binding = 0) uniform Bake {
        vec4 mode;
        vec4 size;
        vec4 light_sq;
        vec4 light_fig;
        vec4 dark_sq;
        vec4 dark_fig;
        vec4 inlay;
        vec4 inlay_fig;
        vec4 frame;
        vec4 frame_fig;
        vec4 surface;    // x: each square's own tone, y: pores, z: seams, w: relief
        vec4 frame_surface;  // the frame's wood: x pores, y relief, z late-wood furrows
        vec4 stone;      // x: veins, y: clouding, z: the roughness following the figure
        // The growth rings (wood::rings), per surface: x a ring's width in world units,
        // y how flat-sawn the pieces are (0 quarter-sawn, 1 flat), z the late wood's
        // darkening, w the pores' density.
        vec4 light_ring;
        vec4 dark_ring;
        vec4 frame_ring;
        vec4 finish;     // the wood's (looks::Finish): varnish, sanding, grain, rings
        vec4 tone;       // x: its warmth, y: pickle, z: caulk; w: samples a side a texel
        vec4 marble;     // looks::Marble: veins, wave, polish, tint; mode.w the variant
        vec4 marble_base;
        vec4 marble_vein;
        vec4 marble_form;
        vec4 seam;       // the frame's caulked seams: x a plank's width, y half width, z dark
        vec4 carve;      // looks::Carving: depth, repeats per side, moss; w 1 carved
        vec4 moss;       // the moss's color (sRGB), w: how patchy
        vec4 carve_more; // looks::Carving: x the motif, y amber, z lichen
        vec4 fill;       // the carving's fill (looks::Theme.fill, sRGB), w: how much
        vec4 lichen;     // the lichen's color (sRGB)
    };
    const float FIELD = 4.0;
    vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }

    float h12(vec2 p) {
        vec3 p3 = fract(vec3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }
    float vnoise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(h12(i), h12(i + vec2(1, 0)), u.x),
                   mix(h12(i + vec2(0, 1)), h12(i + vec2(1, 1)), u.x), u.y);
    }
    float fbm(vec2 p) {
        float s = 0.0;
        float a = 0.5;
        for (int i = 0; i < 5; i++) {
            s += a * vnoise(p);
            p = p * 2.03 + vec2(17.1, 9.2);
            a *= 0.5;
        }
        return s / 0.97;
    }
    // Three octaves, for the figures that don't need five.
    float fbm3(vec2 p) {
        float s = 0.0;
        float a = 0.5;
        for (int i = 0; i < 3; i++) {
            s += a * vnoise(p);
            p = p * 2.03 + vec2(17.1, 9.2);
            a *= 0.5;
        }
        return s / 0.875;
    }

    // Grooves along the grain at y: two contours of a noise drawn out along it,
    // irregularly spaced and ending where it flattens, each a groove of about half_w
    // either side, its distance from the contour by the noise's slope, broken into
    // lengths of about 1 / pieces.
    float furrows(float x, float y, float freq, float half_w, float pieces) {
        vec2 lq = vec2(x * freq + 3.1, y * 0.3);
        float e = 0.002 * freq;
        float slope = abs(vnoise(lq + vec2(e, 0.0)) - vnoise(lq - vec2(e, 0.0))) / 0.004;
        float dist = abs(fract(vnoise(lq) * 2.0) - 0.5) / max(2.0 * slope, 1e-3);
        float w = half_w * (0.75 + 0.5 * vnoise(vec2(x * 4.0, y * 0.9)));
        // Its edges a texel soft at least, so the bake doesn't alias them.
        float texel = size.z / size.x;
        float groove = 1.0 - smoothstep(0.3 * w, w + 0.7 * texel, dist);
        return groove * smoothstep(0.25, 0.45, vnoise(vec2(x * 20.0, y * pieces)));
    }

    struct Wood {
        vec3 albedo;
        float rough;
        float height;
        float cavity;
        #ifdef BAKE_ROOM
        float pore;      // the open pores' share, for the finish to fill
        float fleck;     // the rays' flakes'
        #endif
    };

    float h1(float seed, float k) { return h12(vec2(seed, k)); }

    // Vessels cut along their length: short dark dashes along the grain, scattered in
    // columns across it (the column's rows shifted at random so they never line up),
    // their width tapering to the ends, the edges a texel soft. x across, y along, in
    // world units; dens the share of cells holding one, early 0 to 1 (bigger in the
    // early wood); the cell's hash, for its roughness and depth.
    float vessels(float x, float y, float seed, float dens, float early) {
        const float ACROSS = 0.012;
        const float ALONG = 0.032;
        float texel = size.z / size.x;
        float col = floor(x / ACROSS);
        float yy = y / ALONG + h1(col, seed + 3.3) * 17.0;
        vec2 id = vec2(col, floor(yy));
        if (h12(id + seed * 0.37) >= dens) return 0.0;
        float cx = (col + 0.3 + 0.4 * h12(id + 1.3)) * ACROSS;
        float sy = (yy - id.y - 0.5) / (0.25 + 0.2 * h12(id + 2.1));
        float hw = (0.0012 + 0.0014 * h12(id + 5.7)) * mix(0.75, 1.25, early)
                 * sqrt(max(1.0 - sy * sy, 0.0));
        return 1.0 - smoothstep(-0.5 * texel, 0.6 * texel, abs(x - cx) - hw);
    }

    // Rays seen on a face near the radial plane: thin dark flecks across the grain, a
    // texel or so wide, 0.04 to 0.15 long, far apart, leaning a little. x across, y
    // along; dens scales how many.
    float flecks(float x, float y, float seed, float dens) {
        const float STEP = 0.18;
        const float ACROSS = 0.25;
        float texel = size.z / size.x;
        vec2 id = floor(vec2(x / ACROSS, y / STEP));
        if (h12(id + seed * 0.71 + 3.1) >= 0.5 * dens) return 0.0;
        vec2 c = (id + vec2(0.2, 0.2) + 0.6 * vec2(h12(id + 4.4), h12(id + 6.6)))
               * vec2(ACROSS, STEP);
        float half_len = 0.02 + 0.055 * h12(id + 7.7);
        vec2 d = vec2(x, y) - c;
        float tilt = (h12(id + 8.8) - 0.5) * 0.4;
        float along = d.x;
        float off = abs(d.y - tilt * d.x);
        float taper = max(1.0 - (along / half_len) * (along / half_len), 0.0);
        return taper * (1.0 - smoothstep(0.3 * texel, 1.0 * texel, off));
    }

    #ifdef BAKE_ROOM
    // Oak's rays, sheets of cells running out from the pith, a few centimetres high along
    // the grain. On a face near the radial plane (slant small) they lie
    // almost in the face and show as broad satiny flakes across the grain, the longer the
    // closer the cut, soft-edged, the finish (oak_finish) leaving them a little lighter and
    // glossier, tone on tone; on a face across them (flat-sawn) as short dark lenses along it.
    // slant is the sine of the angle. x across, y along, in world units. x the flakes,
    // y the lenses.
    vec2 oak_rays(float x, float y, float seed, float slant) {
        float texel = size.z / size.x;
        float quarter = 1.0 - smoothstep(0.12, 0.5, slant);
        float flake = 0.0;
        if (quarter > 0.0) {
            const vec2 CELL = vec2(1.1, 1.8);
            vec2 id0 = floor(vec2(x, y) / CELL);
            for (int k = 0; k < 9; k++) {
                vec2 id = id0 + vec2(float(k % 3) - 1.0, float(k / 3) - 1.0);
                if (h12(id + seed * 0.61) > 0.35 * inlay_fig.w) continue;
                vec2 c = (id + vec2(0.2 + 0.6 * h12(id + 1.3), 0.1 + 0.8 * h12(id + 2.7))) * CELL;
                float len = min((0.5 + 1.0 * h12(id + 3.9)) / (0.5 + 3.0 * slant), 1.5);
                float high = 0.15 + 0.4 * h12(id + 5.1);
                vec2 d = vec2(x, y) - c;
                d.y -= (h12(id + 7.7) - 0.5) * 0.4 * d.x;
                d.y += 0.3 * high * (vnoise(vec2(x * 4.0, seed + id.y)) - 0.5);
                float u = d.x / len;
                // Rounded, ragged at the ends, broken into a few flakes: a soft ribbon
                // across the grain, never a stroke.
                float lens = high * sqrt(max(1.0 - u * u, 0.0)) * (0.7 + 0.3 * vnoise(vec2(x * 3.0, id.y + 3.0)));
                float inside = (1.0 - smoothstep(0.2 * lens, lens, abs(d.y))) * smoothstep(texel, 3.0 * texel, lens);
                inside *= smoothstep(0.25, 0.6, vnoise(vec2(x * 2.5, y * 1.5) + id * 3.1));
                flake = max(flake, inside * (0.5 + 0.5 * h12(id + 9.1)));
            }
        }
        float lines = 0.0;
        float across = smoothstep(0.3, 0.8, slant);
        if (across > 0.0) {
            const vec2 TC = vec2(0.1, 0.8);
            vec2 id = floor(vec2(x, y) / TC);
            if (h12(id + seed * 0.43 + 11.0) < 0.2 * inlay_fig.w) {
                vec2 c = (id + vec2(0.3 + 0.4 * h12(id + 1.1), 0.5)) * TC;
                vec2 d = vec2(x, y) - c;
                float u = d.y / (0.08 + 0.25 * h12(id + 2.2));
                float w = 0.012 * max(1.0 - u * u, 0.0);
                lines = (1.0 - smoothstep(0.0, texel, abs(d.x) - w)) * step(abs(u), 1.0) * across;
            }
        }
        return vec2(flake * quarter, lines);
    }
    #endif

    // Growth rings: each piece sawn from a log whose pith runs roughly along its grain,
    // the rings the distance from that axis (Liu et al.'s time volume, the classic
    // solid-texture wood). q.x across the face, q.y along the grain, in world units. The
    // piece's cut is its own: quarter-sawn faces pass near the pith with it far to one
    // side, so the rings show as nearly straight lines; flat-sawn ones lie above it, and
    // the axis leaning out of the face and wandering draws arches where they cut the
    // rings. The rings' radius wobbles, the years are uneven, each year's late wood its
    // own strength: an asymmetric profile, the early wood light, darkening through the
    // year to a sharp edge where the next year's early wood starts. Fibres are fine
    // streaks along the grain, which crosses the ring lines at a slant where the axis
    // leans. The color darkens by Beer's law (base^(1 + a)), so the late wood and the
    // stained pores are deeper and more saturated, as stained wood is. detail adds the
    // pores and a fibre relief into the normal.
    Wood rings(vec2 q, float seed, vec4 base, vec4 k, vec4 ring, bool detail) {
        float rw = ring.x * finish.w;
        float texel = size.z / size.x;
        vec2 o = vec2(h1(seed, 1.7), h1(seed, 9.3)) * 97.0;
        float flatness = clamp(ring.y + (h1(seed, 2.1) - 0.5) * 0.6, 0.0, 1.0);
        float side = h1(seed, 3.7) > 0.5 ? 1.0 : -1.0;
        #ifdef BAKE_ROOM
        // A board as wide as surface.x from a log of its own: a quarter-sawn one with the
        // pith well off its side, a flat-sawn one from 1 to 3 widths over it; the axis
        // leaning about the board's middle, so its arches change along it.
        float d = mix(0.1, 0.8 + 0.6 * surface.x, flatness) * (0.5 + h1(seed, 5.3));
        float c = side * mix(0.5 * surface.x + 1.5 + 4.0 * h1(seed, 6.1), 0.25 * surface.x * (h1(seed, 6.1) - 0.5), flatness);
        float axis = fbm(vec2(q.y * 0.05, 0.5) + o) - 0.5;
        float lean = (h1(seed, 8.8) > 0.5 ? 1.0 : -1.0) * (0.008 + 0.022 * h1(seed, 8.1)) * flatness;
        float dd = max(d + lean * (q.y - 0.5 * size.w) + axis * 0.3 * flatness, 0.3);
        #else
        float d = mix(0.1, 1.6, flatness) * (0.6 + 0.8 * h1(seed, 5.3));
        float c = side * mix(3.0 + 3.0 * h1(seed, 6.1), 0.8 * (h1(seed, 6.1) - 0.5), flatness);
        float axis = fbm(vec2(q.y * 0.12, 0.5) + o) - 0.5;
        float lean = (h1(seed, 8.8) - 0.5) * 0.12 * flatness;
        float dd = max(d + lean * q.y + axis * 0.5 * flatness, 0.02);
        #endif
        float r = length(vec2(q.x - c - axis * 0.8, dd));
        #ifdef BAKE_ROOM
        // Oak's years wander broadly and smoothly: its arches are calm curves, not wiggles.
        r += rw * k.x * 4.0 * (fbm(vec2(q.x * 0.7, q.y * 0.1) + o) - 0.5);
        r += rw * k.x * 0.6 * (vnoise(vec2(q.x * 3.0, q.y * 0.35) + o) - 0.5);
        #else
        r += rw * k.x * 3.0 * (fbm(vec2(q.x * 1.1, q.y * 0.18) + o) - 0.5);
        r += rw * k.x * 0.8 * (vnoise(vec2(q.x * 6.0, q.y * 0.9) + o) - 0.5);
        r += rw * k.x * 0.7 * (vnoise(vec2(q.x * 14.0, q.y * 4.0) + o) - 0.5);
        #endif
        #ifdef BAKE_ROOM
        // A pin knot in one board of three: the rings swept round it, its heart dark.
        float knot = 0.0;
        if (h1(seed, 12.1) < 0.35) {
            vec2 kc = vec2((h1(seed, 12.7) - 0.5) * 0.6 * surface.x, h1(seed, 13.3) * size.w);
            float rk = 0.05 + 0.1 * h1(seed, 13.9);
            float dist = length((q - kc) / vec2(1.0, 2.2));
            r -= rw * 5.0 * exp(-dist * dist / (9.0 * rk * rk));
            knot = 1.0 - smoothstep(0.6 * rk, rk, dist);
        }
        #endif
        float t = r / rw;
        t += 1.2 * (vnoise(vec2(t * 0.3, seed)) - 0.5);
        #ifdef BAKE_ROOM
        // Runs of narrow years and wide ones, as an oak's good and lean decades.
        t += 2.5 * (fbm3(vec2(t * 0.12, seed + 0.5)) - 0.5);
        #endif
        float year = floor(t);
        float ph = t - year;
        #ifdef BAKE_ROOM
        // The ring's edge a texel and a half soft on the face: the years' spacing there is
        // the ring's width over the slope of the distance from the pith (wide on a
        // flat-sawn face), so a cathedral's bands stay crisp and a quarter-sawn face's
        // close lines don't alias.
        float slope = length(vec2(q.x - c - axis * 0.8, abs(lean) * dd)) / max(r, 1e-3);
        float e = clamp(1.5 * texel * slope / rw, 0.03, 0.45);
        #else
        float e = max(0.06, 1.5 * texel / rw);
        #endif
        float late = smoothstep(0.72, 1.0 - e, ph);
        late *= late * (1.0 - smoothstep(1.0 - e, 1.0, ph));
        late *= 0.5 + h1(year + seed * 13.0, 4.4);
        float early = 1.0 - smoothstep(0.0, 0.5, ph);
        // Fibres along the grain, a little wandering.
        float x = q.x + 0.004 * (vnoise(vec2(q.x * 20.0, q.y * 3.0) + o) - 0.5);
        #ifdef BAKE_ROOM
        // No fibre finer than two texels: finer ones alias into streaks.
        float fibre = 0.6 * vnoise(vec2(x * min(55.0, 0.5 / texel), q.y * 0.7) + o)
                    + 0.4 * vnoise(vec2(x * 20.0, q.y * 0.3) + o);
        #else
        float fibre = 0.45 * vnoise(vec2(x * 150.0, q.y * 2.0) + o)
                    + 0.3 * vnoise(vec2(x * 55.0, q.y * 0.7) + o)
                    + 0.25 * vnoise(vec2(x * 380.0, q.y * 30.0) + o);
        #endif
        float broad = fbm(vec2(q.x * 1.2, q.y * 0.25) + o);
        float pore = 0.0;
        #ifdef BAKE_ROOM
        // Ring-porous oak: each year starts with a band of large open pores, short dashes
        // along the grain, wide where a flat-sawn face cuts the year at a slant; a few
        // small ones in the late wood. The rays as oak_rays has them, no pores in a flake.
        float slant = dd / length(vec2(q.x - c - axis * 0.8, dd));   // the sine of the face's angle to the rays
        vec2 rays = oak_rays(x, q.y + o.y, seed, slant);
        float wide = 0.22 + 0.2 * h1(year + seed * 5.0, 3.4);
        float band = smoothstep(0.0, 0.5 * e, ph) * (1.0 - smoothstep(wide - 0.08, wide + 0.08 + e, ph));
        vec2 pq = vec2(x / max(0.03, 1.5 * texel), q.y / 0.5) + o;
        float dash = 0.45 + 0.55 * smoothstep(0.25, 0.7, vnoise(pq));
        pore = ring.w * (band * dash + 0.2 * smoothstep(0.82, 0.96, vnoise(pq * vec2(1.3, 2.0) + 9.0)));
        // Each year's pores as open as its own: some years' bands faint, some heavy.
        pore *= 0.45 + 0.9 * h1(year + seed * 7.0, 2.6);
        pore = max(pore * (1.0 - 0.6 * rays.x), 0.3 * rays.y);
        float a = ring.z * (late - 0.08) + k.z * (fibre - 0.5) * 1.2 + k.y * (broad - 0.5) * 1.5
                + 0.3 * pore + 1.6 * knot;
        Wood w;
        w.albedo = pow(srgb(base.rgb), vec3(1.0 + a));
        w.rough = base.a;
        w.height = 0.15 * late + 0.5 * (fibre - 0.5) - 1.2 * pore + 0.08 * rays.x;
        w.cavity = 1.0 - 0.5 * pore;
        w.pore = pore;
        w.fleck = rays.x;
        return w;
        #else
        if (detail && ring.w > 0.0) {
            // Semi-ring-porous: more and bigger vessels in the early wood.
            pore = vessels(x + o.x, q.y, seed, ring.w * mix(0.6, 1.4, early), early);
            // Rays cut across: sparse thin flecks across the grain, as on the frame.
            pore = max(pore, 0.6 * flecks(x, q.y + o.y, seed, ring.w));
        }
        float a = ring.z * (late - 0.08) + k.z * (fibre - 0.5) * 1.2 + k.y * (broad - 0.5) * 1.5
                + 0.4 * pore;
        Wood w;
        w.albedo = pow(srgb(base.rgb), vec3(1.0 + a));
        w.rough = base.a + 0.06 * (1.0 - late) - 0.04 + 0.25 * pore;
        w.height = 0.15 * late + (detail ? 0.5 : 0.1) * (fibre - 0.5) - 1.2 * pore;
        w.cavity = 1.0 - 0.4 * pore;
        return w;
        #endif
    }

    // A surface with its grain along y, from noise drawn out along the grain, never a
    // regular stripe: a broad soft figure, fine streaks, pores. k: how far the grain
    // wanders, the broad figure's contrast, the fine streaks' contrast, and how far the
    // noise is drawn out along y (1 wood; 0 stone: the same noise round, a clouding with
    // faint veins). base: the color (sRGB) and roughness. f: the pores' strength, the
    // open pores' (dense fine dashes), the fine dark late-wood lines', all following the
    // grain, roughest in them; the late wood as furrows.
    Wood figure(vec2 q, float seed, vec4 base, vec4 k, vec3 f, vec4 ring) {
        float s = k.w;
        if (s > 0.5 && mode.y > 0.5 && mode.y < 2.5) return rings(q, seed, base, k, ring, mode.y > 1.5);
        if (s > 0.5) q.x /= finish.w;
        q += vec2(h12(vec2(seed, 1.7)), h12(vec2(seed, 9.3))) * 97.0;
        float wander = (fbm(q * vec2(0.45, mix(0.45, 0.16, s))) - 0.5) * k.x;
        float x = q.x + wander;
        float broad = fbm(vec2(x * mix(1.3, 2.4, s), q.y * mix(1.3, 0.22, s)));
        float fine = fbm(vec2(x * 26.0, q.y * mix(26.0, 0.7, s)));
        float pores = smoothstep(0.6, 0.9, vnoise(vec2(x * 70.0, q.y * mix(70.0, 1.6, s))));
        // Open pores, dense fine dashes along the grain, and late wood: thin darker lines,
        // both near the screen's pixel at the default view, so the wood reads rough.
        float dash = smoothstep(0.55, 0.8, vnoise(vec2(x * 55.0, q.y * 5.0)))
                   * (0.6 + 0.4 * vnoise(vec2(x * 6.0, q.y * 0.8)));
        // Late wood as furrows, coarser grooves that catch the light, about 0.012 to
        // 0.022 across (2 to 4 pixels at the default view), and finer, shallower ones
        // between them.
        float furrow = (furrows(x, q.y, 16.0, 0.008, 2.5)
                      + 0.6 * furrows(x + 0.37, q.y, 30.0, 0.005, 5.0)) * f.z * s;
        float open = dash * f.y * s;
        pores *= f.x;
        Wood w;
        w.albedo = srgb(base.rgb) * (1.0 + k.y * (broad - 0.5)) * (1.0 + k.z * (fine - 0.5))
                 * (1.0 - 0.12 * pores) * (1.0 - 0.15 * open) * (1.0 - 0.45 * min(furrow, 1.0));
        pores = max(pores, open);
        w.rough = base.a + 0.16 * pores + 0.22 * furrow - 0.08 * (fine - 0.5);
        w.height = (fine - 0.5) * 0.5 - pores * 0.5 - furrow * 2.0;
        w.cavity = 1.0 - 0.15 * open - 0.5 * furrow;
        if (mode.y > 2.5 && s > 0.5) {
            // Laid over the noise: thin straight dark lines, a texel or two across,
            // broken into lengths, and a scatter of pores.
            float texel = size.z / size.x;
            float lines = furrows(x + 0.11, q.y, 40.0, 0.7 * texel, 1.5)
                        + 0.6 * furrows(x + 0.53, q.y, 75.0, 0.5 * texel, 3.0);
            float pore = ring.w > 0.0 ? vessels(x, q.y, seed, 0.6 * ring.w, 0.5) : 0.0;
            float m = min(lines, 1.0);
            w.albedo *= (1.0 - 0.35 * m) * (1.0 - 0.45 * pore);
            w.rough += 0.12 * m + 0.25 * pore;
            w.height -= 0.6 * m + 1.2 * pore;
            w.cavity -= 0.4 * pore;
        }
        if (s < 0.5) {
            // Stone: a soft clouding and a few thin, faint veins, the roughness lowest in
            // the clear stone between them; veins lighter in dark stone, darker in pale.
            // A plain stone's own figure: its seed (looks::Carving.scale, 1 for the first)
            // moves the field, so two stones don't share their veins.
            vec2 qs = q + (carve_more.x > 2.5 ? (carve.y - 1.0) * vec2(17.3, 9.1) : vec2(0.0));
            float cloud = fbm(qs * 0.55 + 4.7);
            float r = abs(fbm(qs * vec2(0.35, 0.5) + vec2(fbm(qs * 0.8) * 1.4, 0.0)) - 0.5);
            float vein = 1.0 - smoothstep(0.0, 0.02, r);
            float pale = dot(base.rgb, vec3(0.33)) > 0.5 ? -1.0 : 1.0;
            w.albedo *= (1.0 + stone.y * (cloud - 0.5) * 2.0) * (1.0 + pale * stone.x * vein);
            w.rough += stone.z * ((cloud - 0.5) * 2.0 + 0.5 * vein);
            if (ring.x > 0.0) {
                // A finer mottling (a stone surface's ring.x, ring.y its features a unit),
                // and paler veins winding through it (ring.z), as jade and serpentine have.
                vec2 mq = q * ring.y;
                float mot = fbm3(mq + vec2(vnoise(mq * 0.7 + 3.3), 0.0) * 1.2 + 21.0);
                float ridge = ring.z > 0.0 ? 1.0 - smoothstep(0.0, 0.07, abs(fbm3(mq * 0.6 + 41.0) - 0.5)) : 0.0;
                w.albedo *= (1.0 + ring.x * (mot - 0.5) * 2.0) * (1.0 + ring.z * ridge);
                w.rough += 0.1 * ring.x * (0.5 - mot);
            }
            if (stone.w > 0.0 && mode.x > 0.5) {
                // Granite on the frame: dark and pale grains a texel or two across.
                float dk = smoothstep(0.6, 0.85, vnoise(q * 120.0));
                float lt = smoothstep(0.68, 0.88, vnoise(q * 95.0 + 31.0));
                w.albedo *= (1.0 - 0.4 * stone.w * dk) * (1.0 + 0.35 * stone.w * lt);
                w.rough += 0.08 * stone.w * (dk - lt);
                w.height += 0.3 * stone.w * (lt - dk);
                // Coarse: the mottling raised a little, the stone's bumpy grain.
                if (ring.x > 0.0) w.height += 2.0 * ring.x * (fbm3(q * ring.y * 1.5 + 61.0) - 0.5);
            }
        }
        return w;
    }

    // The wood's finish (looks::Finish), on wood only: grain scales the figure's
    // contrast round the base color (in the exponent, as Beer's law has it), warmth
    // shifts the color, varnish lowers the roughness and fills the pores a little,
    // sanding makes the relief shallower. Pickling (tone.y, limewash) turns the grain
    // round, paler than the wood where it was darker, and fills the pores and grooves
    // (the cavity) with matte white, level with the surface.
    Wood wood(vec2 q, float seed, vec4 base, vec4 k, vec3 f, vec4 ring) {
        Wood w = figure(q, seed, base, k, f, ring);
        if (k.w < 0.5) return w;
        vec3 b = srgb(base.rgb);
        w.albedo = b * pow(max(w.albedo / b, vec3(1e-3)), vec3(finish.z * (1.0 - 1.6 * tone.y)));
        if (tone.y > 0.0) {
            float fill = tone.y * clamp((1.0 - w.cavity) * 2.5, 0.0, 1.0);
            w.albedo = mix(w.albedo, vec3(0.8, 0.79, 0.75), fill);
            w.rough += 0.12 * fill;
            w.height += 0.8 * fill;
            w.cavity = mix(w.cavity, 1.0, fill);
        }
        w.albedo *= vec3(1.0 + 0.1 * tone.x, 1.0 + 0.02 * tone.x, 1.0 - 0.14 * tone.x);
        w.rough = mix(w.rough, 0.55 * w.rough, finish.x);
        w.cavity = mix(w.cavity, 1.0, 0.3 * finish.x + 0.5 * finish.y);
        w.height *= 1.0 - 0.7 * finish.y;
        return w;
    }

    // Marble, polished, one solid block whose figure runs one way (a stone frame with
    // mode.w > 0). Perlin's turbulent marble without the sine: the veins are
    // contours of a ramp across the flow plus a domain-warped noise (Quilez's warp,
    // noise of the point moved by noise of noise), so they run long and one way,
    // wander, merge and part, never close into rings as contours of noise alone do.
    // Each contour has its own strength and fades in and out along its length; its
    // width is kept even by dividing the distance by the field's slope (fwidth: the
    // bake is a fragment shader), with a soft cloudy halo by the softness. Finer,
    // fainter veins of a second such field, cracks joining them (the edges of warped
    // cells, Worley's), and bundles of thin threads (close contours of a third) by the
    // form. q: x across the frame map's grain, y along it (world x on the block), in
    // world units. Flat: polished stone has no relief. The colors drawn toward the
    // board's steel blue by the tint, their lightness kept.
    vec2 cells(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        float d1 = 8.0;
        float d2 = 8.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 o = vec2(float(x), float(y));
                vec2 c = o + vec2(h12(i + o), h12(i + o + 19.7)) * 0.9 + 0.05 - f;
                float d = dot(c, c);
                if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
            }
        }
        return vec2(sqrt(d1), sqrt(d2));
    }
    vec3 steel(vec3 c, float t) {
        const vec3 STEEL = vec3(0.36, 0.42, 0.48);
        float l = dot(c, vec3(0.3, 0.55, 0.15));
        return mix(c, STEEL * (l / dot(STEEL, vec3(0.3, 0.55, 0.15))), t);
    }
    // A contour of g at each whole number: its strength (some faint, some none) fading
    // along sw, a crisp core `width` across (world units) with a halo by `soft`.
    float vein(float g, float width, float soft, float seed, vec2 sw, float share) {
        float texel = size.z / size.x;
        float level = floor(g + 0.5);
        float dist = abs(g - level) / max(fwidth(g), 1e-5) * texel;
        float strength = smoothstep(1.0 - share, 1.0 - share + 0.35, h12(vec2(level, seed)))
                       * smoothstep(0.3, 0.6, fbm3(vec2(sw.x * 1.2, sw.y * 0.8) + level * 7.1 + seed));
        float w = width * (0.4 + 1.2 * vnoise(sw * vec2(2.0, 3.0) + level + seed));
        float core = 1.0 - smoothstep(w * (1.0 - 0.8 * soft), w + texel, dist);
        float halo = exp(-dist / (0.015 + 0.1 * soft)) * (0.2 + 0.8 * soft);
        return strength * max(core, 0.6 * halo);
    }
    // Coverage of a mineral ribbon averaged across one bake texel.
    float ribbon(float d, float w, float pixel) {
        return clamp((min(d + pixel, w) - max(d - pixel, -w)) / (2.0 * pixel), 0.0, 1.0);
    }
    // One family of seams. Each changes heading at irregular knots. A daughter
    // opens from the same trace, then dies out or rejoins it at the next knot.
    float calcite(vec2 q, float spacing, float width, float pockets, float pixel) {
        float row = floor(q.y / spacing + 0.5);
        float t = q.x / spacing + 13.7 * row;
        float k = floor(t);
        float u = fract(t);
        vec2 knot = vec2(k, row);
        float a = h12(knot);
        float b = h12(knot + vec2(1.0, 0.0));
        float fork = min(u * 2.7, (1.0 - u) * 1.6);
        float grit = fbm3(q * 21.0);
        float jog = (vnoise(vec2(t * 8.0, row)) - 0.5) * 0.08 + (grit - 0.5) * 0.05;
        float d = q.y - spacing * (row + (mix(a, b, u) - 0.5) * 0.57 + jog);
        float milk = smoothstep(0.42, 0.78, fbm3(q * 3.2));
        float w = width * (0.09 + milk * milk * (1.0 + 3.6 * pockets)) * (0.45 + grit);
        float spread = (h12(knot + 4.6) - 0.5) * spacing * 0.53 * fork;
        float daughter = d - spread - fork * (vnoise(q * 14.0) - 0.5) * 0.05;
        float life = smoothstep(0.17, 0.68, vnoise(vec2(t * 1.35, row + 9.3)));
        float core = ribbon(d, w, pixel);
        float twig = ribbon(daughter, width * (0.07 + 0.44 * milk), pixel);
        float cloud = exp(-abs(d + w) / (0.009 + w * 2.6)) * milk * pockets;
        // Dark host rock caught inside a thick seam, in broken slivers along the cut.
        float inclusion = fbm3(vec2(q.x * 37.0, q.y * 108.0));
        float grains = mix(1.0, 0.16 + 0.84 * smoothstep(0.29, 0.68, inclusion),
                           smoothstep(0.003, 0.025, w));
        return life * (max(core * grains, twig * (0.35 + 0.5 * a)) * (0.30 + grit) + cloud * 0.30);
    }

    vec4 black_slab(vec2 p, float pixel) {
        vec2 q = vec2(dot(p, vec2(0.86, 0.51)), dot(p, vec2(-0.51, 0.86)));
        q.y += (fbm3(q * 1.4) - 0.5) * 0.24;
        float v = calcite(q, marble_form.x, marble_form.y, marble_form.w, pixel);
        vec2 crosscut = vec2(q.y + q.x * 0.31, q.x - q.y * 0.31) + 8.2;
        float fine = calcite(crosscut, marble_form.x * 0.68, marble_form.y * 0.47, 0.5, pixel);
        float haze = fbm3(p * 3.7);
        vec3 ground = srgb(marble_base.rgb) * (0.55 + 1.1 * haze);
        return vec4(mix(ground, srgb(marble_vein.rgb), clamp(marble.x * max(v, fine * marble_form.z), 0.0, 1.0)),
                    mix(0.5, 0.06, marble.z) + 0.035 * haze);
    }

    Wood marble_at(vec2 q) {
        float texel = size.z / size.x;
        float veins = marble.x;
        float wave = marble.y;
        float soft = marble_form.y;
        // One way: leaning about 24 degrees off the board's x.
        const float C = 0.913;
        const float S = 0.407;
        vec2 r = vec2(C * q.x + S * q.y, -S * q.x + C * q.y);
        vec2 s = vec2(r.x, r.y * 0.4);
        vec2 w1 = vec2(fbm3(s * 0.5 + vec2(3.1, 7.7)), fbm3(s * 0.5 + vec2(8.4, 1.9))) - 0.5;
        vec2 w2 = vec2(fbm3(s * 0.7 + 2.0 * wave * w1 + vec2(5.5, 2.2)),
                       fbm3(s * 0.7 + 2.0 * wave * w1 + vec2(1.1, 6.6))) - 0.5;
        vec2 sw = s + wave * (1.2 * w1 + 0.5 * w2);
        // The main veins, about 1.3 contours a unit across the flow, half of them shown.
        float g = r.x * 1.3 + wave * 2.2 * (fbm3(sw * 0.5 + 11.3) - 0.5)
                + 0.03 * (vnoise(sw * 5.0) - 0.5);
        float v = vein(g, marble_form.x, soft, 3.7, sw, 0.5);
        // Finer, fainter veins between them, and cracks joining them, in places.
        if (marble_form.z > 0.0) {
            float g2 = r.x * 3.7 + wave * 3.2 * (fbm3(sw * 0.9 + 23.0) - 0.5)
                     + 0.04 * (vnoise(sw * 8.0) - 0.5);
            v = max(v, 0.55 * marble_form.z * vein(g2, 0.4 * marble_form.x, 0.5 * soft, 8.1, sw, 0.6));
            vec2 cp = sw * vec2(1.1, 0.9) + 2.5 * w2;
            vec2 c = cells(cp);
            // The width from the cells' coordinate, which runs on across their edges
            // (fwidth of the edge distance jumps there and broke the cracks into dashes).
            float e = (c.y - c.x) * 0.5;
            float crack = 1.0 - smoothstep(0.4, 1.3, e / max(length(fwidth(cp)), 1e-5));
            crack *= smoothstep(0.55, 0.75, fbm3(sw * 0.9 + 21.0));
            v = max(v, 0.6 * marble_form.z * crack);
        }
        // Bundles of thin wavy threads along the flow.
        float threads = 0.0;
        if (marble_form.w > 0.0) {
            float h = r.x * 14.0 + wave * 9.0 * (fbm3(sw * 0.8 + 31.0) - 0.5) + 3.0 * w2.x
                    + 2.0 * (vnoise(vec2(r.x * 3.0, sw.y * 0.5)) - 0.5);
            float d = abs(h - floor(h + 0.5)) / max(fwidth(h), 1e-5);
            float t = 1.0 - smoothstep(0.3, 1.1, d);
            // In bundles that follow the flow (across it, g), some threads missing.
            float bundle = vnoise(vec2(g * 0.9 + 41.0, sw.y * 0.25));
            t *= smoothstep(0.58, 0.72, bundle) * step(0.3, h12(vec2(floor(h + 0.5), 9.1)))
               * (0.4 + 0.6 * h12(vec2(floor(h + 0.5), 5.3)));
            threads = t * marble_form.w;
        }
        float cloud = fbm(sw * 1.6 + 51.0) - 0.5;
        vec3 base = srgb(steel(marble_base.rgb, marble.w));
        vec3 vein_c = srgb(steel(marble_vein.rgb, marble.w));
        vec3 thread_c = mix(vein_c, vec3(0.8), marble_vein.w);
        base *= 1.0 + marble_base.w * 2.0 * cloud;
        float vv = clamp(v * veins, 0.0, 1.0);
        Wood m;
        m.albedo = mix(base, vein_c, vv);
        m.albedo = mix(m.albedo, thread_c, clamp(threads * veins, 0.0, 1.0));
        m.rough = mix(0.5, 0.06, marble.z) + 0.03 * vv + 0.04 * cloud;
        m.height = 0.0;
        m.cavity = 1.0;
        return m;
    }

    // What wood() is given for a point, and what is laid over its result: the albedo
    // scaled, the height lowered, the roughness toward a seam's.
    struct Cut { vec2 q; float seed; vec4 base; vec4 k; vec3 f; vec4 ring;
                 float shade; float dip; float seam; };

    // The field: light and dark squares, each its own stretch of the surface and its own
    // tone, thin dark seams between them; round them a dark inlay, its grain along each
    // side, a fine dark line where it meets the squares.
    Cut plan(vec2 p) {
        Cut c;
        vec2 a = abs(p);
        float m = max(a.x, a.y);
        c.f = vec3(surface.y, 0.0, 0.0);
        c.seam = 0.0;
        if (m > FIELD) {
            bool along_x = a.y > a.x;
            c.q = along_x ? p.yx : p;
            // The growth rings give each of the four sides its own piece.
            c.seed = along_x ? 71.0 : 83.0;
            if (mode.y > 0.5 && inlay_fig.w > 0.5) c.seed += (along_x ? p.y : p.x) > 0.0 ? 0.0 : 2.0;
            c.base = inlay;
            c.k = inlay_fig;
            c.ring = dark_ring;
            float scribe = 1.0 - smoothstep(0.004, 0.010, m - FIELD);
            c.shade = 1.0 - 0.6 * scribe;
            c.dip = scribe;
            return c;
        }
        // mode.z squares per side (8 or 10), each 8 / mode.z across.
        float n = mode.z;
        vec2 g = (p + FIELD) * (n / (2.0 * FIELD));
        ivec2 sq = clamp(ivec2(floor(g)), ivec2(0), ivec2(int(n) - 1));
        bool dark = ((sq.x + sq.y) & 1) == 1;
        c.q = p;
        c.seed = float(sq.y * int(n) + sq.x) + 1.0;
        c.base = dark ? dark_sq : light_sq;
        c.k = dark ? dark_fig : light_fig;
        c.ring = dark ? dark_ring : light_ring;
        vec2 fr = fract(g);
        float edge = min(min(fr.x, 1.0 - fr.x), min(fr.y, 1.0 - fr.y)) * (2.0 * FIELD / n);
        c.seam = 1.0 - smoothstep(0.002, 0.007, edge);
        c.shade = (1.0 + surface.x * (h12(vec2(c.seed, 4.2)) - 0.5)) * (1.0 - surface.z * c.seam);
        c.dip = c.seam;
        return c;
    }

    // The carved frame (carve.w), its motif carve_more.x: 0 two thin vines in
    // low relief on the frame's top and outer face, interlaced over and under, slender
    // leaves in the eyes between their crossings and a pair at each crossing, a leaf knot
    // (a boss, a ring, four leaves) on each corner's diagonal, a shallow outline cut round
    // them and the stone beyond it left whole; 1 the Baltic folk band cut into the top
    // between two lines, diamonds with a cross in each and between them zigzags and a
    // running meander by turns, a sun wheel (a ring, eight spokes) on each corner's
    // diagonal and a tree of life mid-side on the far and near sides; 2 signs cut into the
    // top, for amber: sun signs and small runic marks by turns, a tree of life mid-side on
    // the far and near sides, a sun on each corner. A height field the bake's normal
    // takes, the cuts a cavity for the occlusion, the moss and the fill (Theme.fill: the
    // leaves' tint, the cut wood's color, the amber). Every edge at least a texel soft, so
    // the mips average it and the frame's Toksvig term widens the roughness where they
    // do. Signed distances in world units: the stems as offset curves, the leaves
    // vesicas, the cut strokes segments, rings and wedges.
    // The map is the mitred frame's (LIT_FRAG): each piece its own band of the map,
    // along it the world's x or z, across the length along the profile (v_uv.y). Two
    // pieces meet on each corner's diagonal, the one at +along and the other at -along
    // in its own band, so the pattern is laid out by |along| near the corners (the cut
    // motifs everywhere, mirrored about each side's middle): the knot or the medallion
    // centred on the diagonal, symmetric, hides the mirror's seam. Along the corners'
    // quarter round the band runs on an arc, at a length along of the band's middle.
    const float PI = 3.14159265;
    const float C_INNER = 4.1;
    const float TOP_AT = 0.0449;     // v_uv.y less the distance out on the frame's top
    const float TOP_MID = 0.256;     // the top band's middle across (v_uv.y)
    const float SIDE_MID = 0.86;     // the outer face's band's
    const float BAND = 0.17;         // the vines' band's half width
    const float STRAND_W = 0.016;    // a vine's half width
    const float SWAY = 0.1;          // how far a vine sways from the band's middle
    const float OUTLINE = 0.011;     // the outline cut round the vines, its width
    const float CUT_W = 0.0135;      // a cut stroke's half width
    const float FOLK_LINE = 0.182;   // the folk band's lines, from its middle
    float vesica(vec2 p, float r, float d) {
        p = abs(p);
        float b = sqrt(r * r - d * d);
        return ((p.y - b) * d > p.x * b) ? length(p - vec2(0.0, b)) : length(p - vec2(-d, 0.0)) - r;
    }
    // A slender leaf from its base `at` along `dir`, `len` long and 0.28 of that wide, its
    // tip bent sideways by `bend` (a share of its length): the Art Nouveau curl.
    float leaf(vec2 p, vec2 at, vec2 dir, float len, float bend) {
        vec2 q = p - at;
        q = vec2(dot(q, vec2(dir.y, -dir.x)), dot(q, dir));
        q.x -= bend * q.y * q.y / len;
        q.y -= 0.5 * len;
        float b = 0.5 * len;
        float h = 0.16 * len;
        float s = b * b / h;
        return vesica(q, 0.5 * (s + h), 0.5 * (s - h));
    }
    // A motif's dome from its signed distance: 0 outside, rounding up to 1 over `round`.
    float dome(float d, float round) {
        float texel = size.z / size.x;
        float m = clamp((-d + 0.5 * texel) / (round + texel), 0.0, 1.0);
        return m * (2.0 - m);
    }
    // The vines' band at x along (signed, by its middle's length), y across from its
    // middle, its corner's arc of radius rc: the motifs' height (0..1), the cut's mask
    // (the outline round them), the leaves' share, how near the motifs (where moss
    // clings).
    vec4 vines(float x, float y, float rc) {
        float texel = size.z / size.x;
        float band = 1.0 - smoothstep(BAND - 0.004, BAND + 0.004 + texel, abs(y));
        if (band <= 0.0) return vec4(0.0);
        float xc = C_INNER + rc * 0.25 * PI;
        float m = max(floor((carve.y - 1.0) * 0.5 + 0.5), 1.0);
        float k = PI * (m + 0.5) / xc;
        // Two vines crossing at each kx = (j + 0.5) pi and at the knot: the j-th
        // crossing's over vine alternates along each.
        float c = cos(k * x);
        float slope = SWAY * k * sin(k * x);
        float norm = inversesqrt(1.0 + slope * slope);
        float d1 = abs(y - SWAY * c) * norm - STRAND_W;
        float d2 = abs(y + SWAY * c) * norm - STRAND_W;
        float j = floor(k * x / PI);
        float xj = (j + 0.5) * PI / k;
        float near = 1.0 - smoothstep(0.02, 0.09, abs(x - xj));
        bool first = mod(j, 2.0) < 0.5;
        float d_over = first ? d1 : d2;
        float d_under = first ? d2 : d1;
        float under = dome(d_under, 0.6 * STRAND_W) * (1.0 - 0.45 * near)
                    * mix(1.0, smoothstep(0.004, 0.011 + texel, d_over), near);
        float h = max(dome(d_over, STRAND_W), under);
        float dm = min(d1, d2);
        // Leaves: one from each vine into each eye, the two turned half round each other
        // (the upper one from right of the middle reaching down and on, the lower from
        // left of it reaching up and back), curling; a pair at each crossing reaching
        // out, leaning one way at even crossings and the other at odd ones.
        float e = floor(k * x / PI + 0.5);
        float xe = e * PI / k;
        float half_eye = 0.5 * PI / k;
        float lf = 1e3;
        for (int s = -1; s <= 1; s += 2) {
            float side = float(s) * (mod(e, 2.0) < 0.5 ? 1.0 : -1.0);   // +1: on the eye's +y
            float xb = xe + side * 0.42 * half_eye;
            float yb = float(s) * SWAY * cos(k * xb);
            vec2 dir = normalize(vec2(-side * 0.88, -side * 0.48));
            lf = min(lf, leaf(vec2(x, y), vec2(xb, yb) - dir * 0.045, dir, 0.28, 0.25));
        }
        float lean = mod(j, 2.0) < 0.5 ? 1.0 : -1.0;
        for (int s = -1; s <= 1; s += 2) {
            vec2 dir = normalize(vec2(0.5 * lean, float(s)));
            lf = min(lf, leaf(vec2(x, y), vec2(xj, 0.0) + dir * 0.025, dir, 0.12, -0.25 * lean * float(s)));
        }
        float stems = dome(dm - 0.003, 0.004);
        h = max(h, 0.85 * dome(lf, 0.02) * (1.0 - stems));
        float leaves = (1.0 - smoothstep(-texel, texel, lf)) * (1.0 - stems);
        dm = min(dm, lf);
        // The knot on the corner's diagonal: the vines pass under a ring, a boss over
        // their crossing, four leaves out from the ring.
        vec2 kp = vec2(abs(x) - xc, y);
        float kr = length(kp);
        if (kr < 0.25) {
            float ring = abs(kr - 0.08) - 0.011;
            h *= smoothstep(0.003, 0.010 + texel, ring);
            leaves *= smoothstep(0.003, 0.010 + texel, ring);
            h = max(h, dome(ring, 0.011));
            float boss = kr - 0.035;
            h = max(h, dome(boss, 0.03));
            float kl = 1e3;
            for (int i = 0; i < 4; i++) {
                float a = radians(i < 2 ? 40.0 : 140.0) * (i % 2 == 0 ? 1.0 : -1.0);
                vec2 dir = vec2(cos(a), sin(a));
                kl = min(kl, leaf(kp, dir * 0.08, dir, 0.1, 0.2 * (i % 2 == 0 ? 1.0 : -1.0)));
            }
            float out_ring = smoothstep(0.0, 0.006, ring);
            h = max(h, 0.9 * dome(kl, 0.02) * out_ring);
            leaves = max(leaves, (1.0 - smoothstep(-texel, texel, kl)) * out_ring);
            dm = min(dm, min(min(ring, boss), kl));
        }
        // The cut: an outline of OUTLINE round the motifs, its outer edge a texel soft.
        float cut = band * (1.0 - smoothstep(OUTLINE, OUTLINE + texel, dm));
        return vec4(h, cut, leaves, band * (1.0 - smoothstep(OUTLINE, 0.045, dm)));
    }

    float seg(vec2 p, vec2 a, vec2 b) {
        vec2 pa = p - a;
        vec2 ba = b - a;
        return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
    }
    // The angle of p off the nearest of n spokes (one along +x), turned by `turn` spokes.
    float spoke(vec2 p, float n, float turn) {
        float k = 2.0 * PI / n;
        float a = atan(p.y, p.x + 1e-7) - turn * k;
        return a - k * floor(a / k + 0.5);
    }
    // A tree of life `s` from its middle to its top, upright along +y: a trunk, three
    // pairs of branches rising out, a twig up from each, two pairs of roots. The
    // distance to its strokes' middles.
    float tree(vec2 p, float s) {
        p /= s;
        vec2 q = vec2(abs(p.x), p.y);
        float d = seg(q, vec2(0.0, -0.75), vec2(0.0, 0.98));
        for (int i = 0; i < 3; i++) {
            float y0 = -0.38 + 0.34 * float(i);
            vec2 tip = vec2(0.95 - 0.2 * float(i), y0 + 0.62);
            d = min(d, seg(q, vec2(0.0, y0), tip));
            vec2 mid = mix(vec2(0.0, y0), tip, 0.5);
            d = min(d, seg(q, mid, mid + vec2(0.02, 0.34)));
            d = min(d, seg(q, tip, tip + vec2(0.16, -0.12)));
        }
        d = min(d, seg(q, vec2(0.0, -0.55), vec2(0.55, -0.95)));
        d = min(d, seg(q, vec2(0.0, -0.75), vec2(0.22, -1.0)));
        return d * s;
    }
    // A sun wheel of radius r: a ring and eight spokes from the hub, widening out.
    float sun_wheel(vec2 p, float r) {
        float l = length(p);
        float ad = spoke(p, 8.0, 0.0);
        float spokes = max(abs(l * sin(ad)) - CUT_W * (0.4 + 1.3 * l / r), l - 0.78 * r);
        return min(abs(l - r) - CUT_W, spokes);
    }
    // Two diamonds one in the other, `r` the outer's half diagonal, a cross in the inner.
    float diamond(vec2 p, float r) {
        vec2 a = abs(p);
        float outer = abs(a.x + a.y - r) * 0.7071 - CUT_W;
        float inner = abs(a.x + a.y - 0.56 * r) * 0.7071 - 0.85 * CUT_W;
        float cross = max(min(a.x, a.y) - 0.8 * CUT_W, max(a.x, a.y) - 0.27 * r);
        return min(min(outer, inner), cross);
    }
    // A zigzag along t (from its start), y across, a its sway, len a wavelength, a small
    // cross in each bay it leaves, above and below by turns.
    float zigzag(float t, float y, float a, float len) {
        float f = fract(t / len);
        float z = a * (4.0 * abs(f - 0.5) - 1.0);
        float norm = inversesqrt(1.0 + 16.0 * a * a / (len * len));
        float d = abs(y - z) * norm - CUT_W;
        vec2 up = abs(vec2((f - 0.5) * len, y - 0.45 * a));
        vec2 dn = abs(vec2((f - floor(f + 0.5)) * len, y + 0.45 * a));
        float c_up = max(min(up.x, up.y) - 0.75 * CUT_W, max(up.x, up.y) - 0.4 * a);
        float c_dn = max(min(dn.x, dn.y) - 0.75 * CUT_W, max(dn.x, dn.y) - 0.4 * a);
        return min(d, min(c_up, c_dn));
    }
    // A running meander along t: a line stepping between ±a, len a step and back.
    float meander(float t, float y, float a, float len) {
        float u = t - len * floor(t / len);
        float d = abs(y - (u < 0.5 * len ? a : -a));
        float yc = clamp(y, -a, a);
        d = min(d, length(vec2(u, y - yc)));
        d = min(d, length(vec2(u - 0.5 * len, y - yc)));
        d = min(d, length(vec2(u - len, y - yc)));
        return d - 0.9 * CUT_W;
    }
    // The folk band at x along (signed, by its middle's length), y across from its middle,
    // on band `side` (0 the near side, 1 the far, 2 and 3 those along z), its corner's arc
    // of radius rc: the cut strokes' signed distance. Diamonds at n steps from the side's
    // middle to the corner's medallion (n from the repeats per side), a tree there on the
    // far and near sides; between them the runs carve_more.w picks (looks::Carving.pattern):
    // 0 zigzags and a meander by turns, 1 zigzags only, 2 the meander only, 3 none. A
    // zigzag starts and ends on the band's middle, a whole number of its periods, so it
    // runs into the diamonds' points as one chain.
    float folk(float x, float y, float rc, float side) {
        float xc = C_INNER + rc * 0.25 * PI;
        float n = max(floor(carve.y * 0.5 + 0.5), 2.0);
        float step_ = xc / n;
        float u = abs(x);
        float j = clamp(floor(u / step_ + 0.5), 0.0, n);
        vec2 e = vec2(u - j * step_, y);
        bool trees = side < 1.5;
        float up = side < 0.5 ? -1.0 : 1.0;
        float d = abs(abs(y) - FOLK_LINE) - 0.8 * CUT_W;
        float m = j > n - 0.5 ? sun_wheel(e, 0.155)
                : (j < 0.5 && trees ? tree(vec2(e.x, e.y * up), 0.165) - CUT_W : diamond(e, 0.15));
        d = min(d, m);
        float g = min(floor(u / step_), n - 1.0);
        float kind = carve_more.w;
        bool zig = kind < 0.5 ? mod(g, 2.0) < 0.5 : kind < 1.5;
        // A zigzag meets a diamond at its point (0.15 out); a meander, a tree, or the
        // corner's wheel keeps a gap.
        float lo = g * step_ + (g < 0.5 && trees ? 0.2 : zig ? 0.15 : 0.175);
        float hi = (g + 1.0) * step_ - (g > n - 1.5 ? 0.2 : zig ? 0.15 : 0.175);
        float span = hi - lo;
        if (span > 0.05 && kind < 2.5) {
            float t = u - lo;
            float len = span / max(floor(span / (zig ? 0.17 : 0.2) + 0.5), 1.0);
            float pat = zig ? zigzag(t + 0.25 * len, y, 0.08, len) : meander(t, y, 0.078, len);
            d = min(d, max(pat, max(lo - u, u - hi)));
        }
        return d;
    }
    // A sun sign of radius r: a disc and eight rays round it, eight shorter between.
    float sun_sign(vec2 p, float r) {
        float l = length(p);
        float disc = l - 0.34 * r;
        float t = clamp((l - 0.48 * r) / (0.52 * r), 0.0, 1.0);
        float ray = max(abs(l * sin(spoke(p, 8.0, 0.0))) - 0.15 * r * (1.0 - t) - 0.25 * CUT_W,
                        max(0.48 * r - l, l - r));
        float t2 = clamp((l - 0.48 * r) / (0.3 * r), 0.0, 1.0);
        float ray2 = max(abs(l * sin(spoke(p, 8.0, 0.5))) - 0.1 * r * (1.0 - t2) - 0.25 * CUT_W,
                         max(0.48 * r - l, l - 0.78 * r));
        return min(disc, min(ray, ray2));
    }
    // A runic mark `s` from its middle to its top, upright along +y, symmetric: kind 0 a
    // stave with a chevron at its top, 1 a diamond on a stave, 2 two chevrons one over the
    // other, 3 a stave crossed by two diagonals. The cut's signed distance.
    float rune(vec2 p, float kind, float s) {
        p /= s;
        vec2 q = vec2(abs(p.x), p.y);
        float d;
        if (kind < 0.5) {
            d = min(seg(q, vec2(0.0, -1.0), vec2(0.0, 1.0)), seg(q, vec2(0.0, 1.0), vec2(0.55, 0.42)));
        } else if (kind < 1.5) {
            d = abs(q.x + abs(p.y) - 0.55) * 0.7071;
            d = min(d, seg(vec2(q.x, abs(p.y)), vec2(0.0, 0.55), vec2(0.0, 1.0)));
        } else if (kind < 2.5) {
            d = min(seg(q, vec2(0.0, 0.85), vec2(0.62, 0.25)), seg(q, vec2(0.0, 0.0), vec2(0.62, -0.6)));
        } else {
            d = min(seg(q, vec2(0.0, -1.0), vec2(0.0, 1.0)), seg(abs(p), vec2(0.0), vec2(0.55, 0.55)));
        }
        return d * s - 0.85 * CUT_W;
    }
    // The signs at x along, y across, on band `side`, its corner's arc of radius rc: suns
    // and runic marks by turns at 2n steps from the side's middle to the corner, a tree
    // of life in the middle of the far and near sides, a sun on the corner.
    float signs(float x, float y, float rc, float side) {
        float xc = C_INNER + rc * 0.25 * PI;
        float n = 2.0 * max(floor(carve.y * 0.25 + 0.5), 1.0);
        const float W = 1.45;   // the signs' strokes wider than the folk band's
        float step_ = xc / n;
        float u = abs(x);
        float j = clamp(floor(u / step_ + 0.5), 0.0, n);
        vec2 e = vec2(u - j * step_, y);
        vec2 eu = vec2(e.x, side < 0.5 ? -e.y : e.y);
        if (j < 0.5 && side < 1.5) return tree(eu, 0.185) - W * CUT_W;
        if (mod(j, 2.0) < 0.5) return sun_sign(e, 0.16);
        return rune(eu, mod(floor(j * 0.5) + side, 4.0), 0.11) - (W - 1.0) * CUT_W;
    }

    // What the carving gives a point of the frame map: its height (world units, 0 the
    // surface), how far it is in the cut ground (0..1), how near a motif's foot (where
    // moss gathers), the fill's share (Theme.fill), and how deep the amber is over the
    // cut there (0..1, its glow).
    struct Carve { float h; float hollow; float foot; float fill; float glow; };
    // A plain stone's weathering (motif 3): a sparse network of hairline cracks, the
    // edges of a warped cell field shown only where a broad noise lets them through, so
    // they run and stop as real ones do. x: the crack (0..1), every edge a texel soft for
    // the mips; y: near it, where moss settles.
    vec2 cracks(vec2 q, float seed) {
        const float CELLS = 1.7;      // cells a world unit (a square is 1)
        vec2 p = q * CELLS + 0.4 * vec2(fbm(q * 2.0 + seed), fbm(q * 2.0 + seed + 5.2));
        vec2 i = floor(p);
        float f1 = 9.0;
        float f2 = 9.0;
        for (int k = 0; k < 9; k++) {
            vec2 id = i + vec2(float(k % 3) - 1.0, float(k / 3) - 1.0);
            vec2 c = id + vec2(h12(id + seed), h12(id + seed + 2.7)) - p;
            float d = dot(c, c);
            if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
        }
        float e = sqrt(f2) - sqrt(f1);
        float texel = CELLS * size.z / size.x;
        float w = 0.008 + 0.012 * vnoise(p * 3.0);
        float show = smoothstep(0.58, 0.68, fbm(q * 0.9 + seed + 9.0));
        float line = 1.0 - smoothstep(w, w + 1.5 * texel, e);
        float near = 1.0 - smoothstep(w, 0.12, e);
        return vec2(line, near) * show;
    }

    // q: x across from the band's start, y along; band: the mitred piece (0 the near
    // side, 1 the far, 2 and 3 the sides along z).
    Carve carving(vec2 q, float band) {
        Carve r = Carve(0.0, 0.0, 0.0, 0.0, 0.0);
        float across = q.x - 0.2;
        float along = q.y - 5.2;
        bool top = across < 0.55;
        float motif = carve_more.x;
        if (motif > 2.5) {
            // 3: no motif, a plain stone weathered: its cracks, moss gathering in and
            // along them, laid out by its seed (carve.y, looks::Carving.scale).
            vec2 c = cracks(q, 7.3 * band + carve.y);
            r.hollow = 0.6 * c.x;
            r.h = -carve.x * c.x;
            r.foot = 0.7 * c.y;
            return r;
        }
        if (!top && motif > 0.5) return r;
        float mid = top ? TOP_MID : SIDE_MID;
        float rc = top ? TOP_MID - TOP_AT : 0.5;
        float rr = top ? max(across - TOP_AT, 0.01) : 0.5;
        float a = abs(along);
        float x = a;
        if (a > C_INNER) x = C_INNER + rc * (0.5 * PI - acos(clamp((a - C_INNER) / rr, 0.0, 1.0)));
        float y = across - mid;
        if (motif < 0.5) {
            vec4 v = vines(sign(along) * x, y, rc);
            r.hollow = v.y * (1.0 - v.x);
            r.h = -carve.x * r.hollow;
            r.foot = max(v.y * (1.0 - smoothstep(0.0, 0.5, v.x)) * smoothstep(0.0, 0.15, v.x + 0.02),
                         0.6 * v.w * (1.0 - v.x));
            r.fill = v.z;
            return r;
        }
        // A rounded groove from the strokes' signed distance, deepest along their middle;
        // the amber filling it to `level` below the surface, level and glossy.
        float d = motif < 1.5 ? folk(x, y, rc, band) : signs(x, y, rc, band);
        float cut = dome(d, motif < 1.5 ? CUT_W : 1.45 * CUT_W);
        float level = 1.0 - carve_more.y;
        r.h = -carve.x * min(cut, level);
        r.hollow = cut;
        r.foot = smoothstep(0.0, 0.3, cut) * (1.0 - smoothstep(0.3, 0.8, cut));
        r.fill = carve_more.y > 0.0 ? smoothstep(level - 0.02, level + 0.1, cut) : smoothstep(0.0, 0.45, cut);
        r.glow = clamp((cut - level) / max(carve_more.y, 1e-3), 0.0, 1.0);
        return r;
    }

    // The frame map: the frame's wood or stone over a square, its grain along u.
    // The growth rings give each band of the map (each mitred piece, LIT_FRAG) its own
    // log and cut, across measured from the band's start.
    Cut frame_map(vec2 p) {
        Cut c;
        c.f = frame_surface.xxz * vec3(0.3, 1.0, 1.0);
        c.q = p.yx;
        c.seed = 7.0;
        if ((mode.y > 0.5 && mode.y < 2.5 && frame_fig.w > 0.5) || carve.w > 0.5) {
            // Each band 1.4 apart, its profile from 0.2 to 1.46 into it: split them in the
            // gap between, so the foot of a piece's face keeps its own band.
            float band = floor((c.q.x - 0.13) / 1.4);
            c.q.x -= band * 1.4;
            c.seed = 7.0 + 5.0 * band;
        }
        c.base = frame;
        c.k = frame_fig;
        c.ring = frame_ring;
        c.shade = 1.0;
        c.dip = 0.0;
        c.seam = 0.0;
        return c;
    }

    // What the frame map lays over its wood: summer's caulked seams, the carving and its
    // moss.
    Wood frame_over(Wood w, Cut c, vec2 p) {
        vec2 q = c.q;
        float seed = c.seed;
        if (seam.x > 0.0 && frame_fig.w > 0.5) {
            // Caulked seams along each mitred piece (LIT_FRAG's bands of 1.4, the top's
            // inner edge 0.2 into its band), a plank's width apart over the top only.
            float across = p.y - floor(p.y / 1.4) * 1.4 - 0.2;
            float k = across / seam.x;
            float d = abs(k - floor(k + 0.5)) * seam.x;
            float texel = size.z / size.x;
            float scribe = (1.0 - smoothstep(seam.y, seam.y + texel, d))
                       * step(0.5 * seam.x, across) * step(across, 0.47) * min(tone.z, 1.0);
            w.albedo = mix(w.albedo, srgb(vec3(0.07, 0.06, 0.055)), clamp(scribe * seam.z * max(tone.z, 1.0), 0.0, 1.0));
            w.rough = mix(w.rough, 0.6, scribe);
            w.height -= 0.6 * scribe;
            w.cavity -= 0.3 * scribe;
        }
        if (carve.w > 0.5) {
            Carve cv = carving(q, floor((seed - 7.0) / 5.0 + 0.5));
            float across = q.x - 0.2;
            // The cut ground a little darker and rougher, moss settling in it in patches,
            // most at the motifs' feet, and along the frame's edges: its inner lip, its
            // rounded edge, the foot of its face.
            float patch = smoothstep(0.4, 0.75, mix(0.5, fbm(q * vec2(4.0, 1.6) + seed), moss.w));
            float edges = max(max(1.0 - smoothstep(0.02, 0.075, across), smoothstep(1.08, 1.24, across)),
                              0.6 * (1.0 - smoothstep(0.0, 0.06, abs(across - 0.5))));
            float edge_moss = edges * smoothstep(0.42, 0.78, fbm(q * vec2(5.0, 1.4) + seed + 3.0));
            float m = clamp(carve.z * ((1.2 * cv.hollow + 1.2 * cv.foot) * patch + edge_moss), 0.0, 1.0);
            float shade = 0.85 + 0.3 * vnoise(q * 40.0);
            // The cut's walls in their own shade where nothing fills them, a little
            // grime round the motifs' feet.
            w.albedo *= (1.0 - 0.45 * cv.hollow * (1.0 - cv.fill)) * (1.0 - 0.1 * cv.foot);
            w.albedo = mix(w.albedo, srgb(moss.rgb) * shade, m);
            w.rough = mix(w.rough + 0.15 * cv.hollow, 0.75, m);
            w.cavity *= 1.0 - 0.3 * cv.hollow - 0.3 * cv.foot;
            if (carve_more.z > 0.0) {
                // Lichen: small round rosettes scattered over the stone, more on the outer
                // face than on the top, out of the cuts, their rims frilled, paler toward
                // the rim; matte and a little raised.
                vec2 cq = q * 4.5 + seed * 3.1;
                vec2 ci = floor(cq);
                float share = 0.4 * carve_more.z * mix(0.5, 1.0, smoothstep(0.4, 0.7, across));
                float lich = 0.0;
                float rim = 0.0;
                for (int k = 0; k < 9; k++) {
                    vec2 id = ci + vec2(float(k % 3) - 1.0, float(k / 3) - 1.0);
                    float h = h12(id + 7.7);
                    if (h < share) {
                        vec2 c = id + 0.2 + 0.6 * vec2(h12(id + 1.9), h12(id + 4.3)) - cq;
                        float r = (0.2 + 0.22 * h12(id + 3.1)) * (0.88 + 0.24 * vnoise(cq * 9.0 + id));
                        float l = length(c);
                        float in_ = 1.0 - smoothstep(r - 0.06, r, l);
                        lich = max(lich, in_);
                        rim = max(rim, in_ * smoothstep(0.4 * r, r, l));
                    }
                }
                lich *= 1.0 - cv.hollow;
                vec3 lc = srgb(lichen.rgb) * (0.75 + 0.2 * vnoise(q * 90.0) + 0.25 * rim);
                w.albedo = mix(w.albedo, lc, 0.85 * lich);
                w.rough = mix(w.rough, 0.85, lich);
                w.height += 0.5 * lich;
            }
            // The fill: the leaves' tint, the cut's lighter wood (its grain kept), or the
            // amber: warm and glossy, level, darker where thin over the cut's walls and
            // brighter where it lies deep (the light it scatters back), catching the light.
            float f = cv.fill * fill.w;
            if (carve_more.y > 0.0) {
                vec3 deep = srgb(mix(fill.rgb, vec3(1.0, 0.9, 0.55), 0.4));
                w.albedo = mix(w.albedo, mix(srgb(fill.rgb) * 0.3, deep * 1.15, pow(cv.glow, 0.6)), f);
                w.rough = mix(w.rough, 0.08, f);
                w.cavity = mix(w.cavity, 1.0, 0.8 * f);
            } else {
                vec3 fig = sqrt(max(w.albedo / srgb(frame.rgb), vec3(0.0)));
                w.albedo = mix(w.albedo, srgb(fill.rgb) * fig, f);
                w.rough = mix(w.rough, w.rough + 0.1, f);
            }
            w.height += cv.h / (0.0015 * max(frame_surface.y, 1e-3));
        }
        return w;
    }

    // What the plan lays over its wood: the inlay's line and the squares' tone and seams
    // (the Cut's), and the carved look's engraved line round the field.
    Wood plan_over(Wood w, Cut c, vec2 p) {
        w.albedo *= c.shade;
        w.rough = mix(w.rough, 0.8, c.seam);
        w.height -= c.dip;
        float m = max(abs(p.x), abs(p.y));
        if (carve.w > 0.5 && carve_more.x < 0.5 && m > FIELD) {
            // The carved look's fine engraved line round the field, down the inlay's
            // middle, a texel soft.
            float texel = size.z / size.x;
            float cut = 1.0 - smoothstep(0.003, 0.006 + texel, abs(m - FIELD - 0.05));
            w.albedo *= 1.0 - 0.35 * cut;
            w.height -= 3.0 * cut;
        }
        return w;
    }

    // The table's top (mode.x 2), round its middle: planks seam.x wide with the grain
    // along y, each its own piece of the wood (the light squares' slots hold the table's:
    // tables::Table) and its own tone.
    Cut table_cut(vec2 p) {
        Cut c;
        float plank = floor(p.x / seam.x + 0.5);
        c.q = vec2(p.x - plank * seam.x, p.y);
        c.seed = 31.0 + 7.0 * plank;
        c.base = light_sq;
        c.k = light_fig;
        c.ring = light_ring;
        c.f = inlay.xyz;
        float edge = abs(abs(c.q.x) - 0.5 * seam.x);
        c.seam = 1.0 - smoothstep(seam.y, seam.y + 0.004, edge);
        c.shade = (1.0 + surface.x * (h12(vec2(c.seed, 4.2)) - 0.5)) * (1.0 - surface.z * c.seam);
        c.dip = 0.3 * c.seam;
        return c;
    }

    // The wear's hashes and noise over a tile that repeats every `per` cells.
    float hw(vec2 c, float per) { return h12(mod(c, per)); }
    float wnoise(vec2 p, float per) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(hw(i, per), hw(i + vec2(1, 0), per), u.x),
                   mix(hw(i + vec2(0, 1), per), hw(i + vec2(1, 1), per), u.x), u.y);
    }
    // cells() over a tile `per` cells across: the nearest two feature points' distances.
    vec2 wcells(vec2 p, float per) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        float d1 = 8.0;
        float d2 = 8.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 o = vec2(float(x), float(y));
                vec2 c = o + vec2(hw(i + o, per), hw(i + o + 19.7, per)) * 0.9 + 0.05 - f;
                float d = dot(c, c);
                if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
            }
        }
        return vec2(sqrt(d1), sqrt(d2));
    }

    // Scratches over the tile: in cells `size` across (`per` of them to the tile), up to
    // two straight scratches each, `keep` of them drawn, of random lengths, angles round
    // `dir`, widths about w and depths: how much of one there is at p.
    float scratches(vec2 p, float size, float per, float keep, float seed, vec2 dir, float w) {
        vec2 i = floor(p / size);
        float best = 0.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 c = i + vec2(float(x), float(y));
                for (int k = 0; k < 2; k++) {
                    vec2 kk = vec2(float(k) * 7.1 + seed);
                    if (hw(c + kk + 0.3, per) > keep) continue;
                    vec2 m = (c + vec2(hw(c + kk + 1.1, per), hw(c + kk + 2.3, per))) * size;
                    float ang = (hw(c + kk + 3.7, per) - 0.5) * 2.4;
                    vec2 d = vec2(cos(ang) * dir.x - sin(ang) * dir.y, sin(ang) * dir.x + cos(ang) * dir.y);
                    float half_len = size * (0.15 + 0.6 * hw(c + kk + 4.9, per));
                    vec2 q = p - m;
                    float t = clamp(dot(q, d), -half_len, half_len);
                    // Thinner and fainter toward its ends, as a dragged grit lifts.
                    float along = max(1.0 - abs(t) / half_len, 0.0);
                    float sw = w * (0.5 + hw(c + kk + 5.3, per)) * (0.5 + 0.5 * sqrt(along));
                    float depth = 0.5 + 0.5 * hw(c + kk + 6.1, per);
                    best = max(best, depth * (1.0 - smoothstep(0.3 * sw, sw, length(q - d * t))));
                }
            }
        }
        return best;
    }

    // The table's wear (mode.x 3) on a tile size.zw across that repeats, which TABLE_FRAG
    // lays twice over the top, turned and scaled the second time so it never shows, and
    // masks by the patches the top's map holds (table_over's cavity): x scratches, y the
    // varnish's crazing, z dents and nicks, as strong as tables::Table.patina says, each
    // half as many as the top has, as the two layers add.
    vec4 wear_at(vec2 p) {
        float tile = size.z;
        float texel = size.z / size.x;
        float sw = max(texel * 1.5, 0.01);
        float s1 = scratches(p, 1.0, tile, 0.37, 1.0, vec2(0.0, 1.0), sw);
        float s2 = scratches(p, 0.5, 2.0 * tile, 0.3, 5.0, vec2(1.0, 0.0), sw);
        // Hairlines, which the top's map was too coarse for.
        float s3 = scratches(p, 0.4, 2.5 * tile, 0.12, 9.0, vec2(0.0, 1.0), 0.5 * sw);
        float scratch = max(max(s1, 0.6 * s2), 0.35 * s3) * dark_sq.z;
        vec2 wq = p * 2.0;
        vec2 warp = vec2(wnoise(wq, 2.0 * tile) + 0.5 * wnoise(wq * 2.0, 4.0 * tile),
                         wnoise(wq + 7.0, 2.0 * tile) + 0.5 * wnoise(wq * 2.0 + 7.0, 4.0 * tile));
        vec2 cl = wcells(p * 7.0 + warp * 0.4, 7.0 * tile);
        float craze = (1.0 - smoothstep(0.0, max(0.05, 8.4 * texel), cl.y - cl.x)) * dark_sq.y;
        vec2 dg = p * 2.5;
        vec2 dc = wcells(dg, 2.5 * tile);
        // A soft bowl, its size and depth its own.
        float r = 0.04 + 0.07 * hw(floor(dg) + 3.3, 2.5 * tile);
        float bowl = max(1.0 - dc.x * dc.x / (r * r), 0.0);
        float dent = bowl * bowl * (0.4 + 0.6 * hw(floor(dg) + 8.9, 2.5 * tile))
                   * step(0.91, hw(floor(dg), 2.5 * tile)) * dark_sq.w;
        return vec4(scratch, craze, dent, 0.0);
    }

    // What the table lays over its wood (dark_sq: tables::Table.patina, dark_fig its wear):
    // its age under a thick varnish. The varnish's blotches, darker and lighter by turns;
    // the rim worn lighter where hands rest. Its finer wear, the crazing, scratches, and
    // dents, is wear_at's, on a tile of its own: here only the patches where the top was
    // used (scratched, dented) and where it was left alone (crazed), in the cavity's
    // channel. The roughness baked is the polish's, which TABLE_FRAG takes on the top.
    Wood table_over(Wood w, Cut c, vec2 p) {
        float blot = fbm(p * 0.35 + 3.1) - 0.5;
        float fine = fbm(p * 1.7 + 8.3) - 0.5;
        w.albedo *= (1.0 + dark_sq.x * (1.6 * blot + 0.6 * fine)) * c.shade;
        // Flame mahogany (dark_ring: tables::Table.flame): the figure swept into flames and
        // swirls, the point warped twice by noise (Quilez's warp) across a flow along the
        // grain; dark where the bands run, golden between, darkened by Beer's law as stain
        // gathers. Book-matched (w over 0), two leaves mirrored about a seam down the
        // middle, as alike as w: the broad flow shared, the finer warp, the bands and the
        // streaks each leaf's own the more as w falls (two cuts of one log, not a mirror).
        if (dark_ring.x > 0.0) {
            bool matched = dark_ring.w > 0.0;
            vec2 f = (matched ? vec2(abs(p.x), p.y) : p) * dark_ring.y;
            vec2 own = (matched && p.x < 0.0 ? 1.0 - dark_ring.w : 0.0) * vec2(13.7, 5.3);
            vec2 w1 = vec2(fbm(f * 0.35 + 1.7 + 0.3 * own), fbm(f * 0.35 + 9.2 + 0.3 * own));
            vec2 w2 = vec2(fbm(f * 0.7 + w1 * 2.0 + 4.1 + own), fbm(f * 0.7 + w1 * 2.0 + 7.3 + own));
            float flow = f.x + dark_ring.z * 2.0 * (w2.x - 0.5) + 0.6 * dark_ring.z * (w1.y - 0.5) * f.y * 0.2;
            float band = fbm(vec2(flow * 1.6, f.y * 0.18 + 1.5 * w2.y) + own);
            float streak = vnoise(vec2(flow * 22.0, f.y * 1.4) + own) - 0.5;
            float a = 2.4 * (band - 0.5) + 0.5 * streak;
            // The light bands lighten half as far as the dark ones darken: golden, not pale.
            a = a > 0.0 ? a : 0.5 * a;
            w.albedo = pow(max(w.albedo, vec3(1e-4)), vec3(1.0 + dark_ring.x * a));
            w.height += 0.3 * streak * dark_ring.x;
        }
        float r = length(p);
        float rim = smoothstep(0.5 * size.z - dark_fig.y, 0.5 * size.z - 0.05, r)
                  * (0.5 + fbm(p * 1.3 + 31.0)) * dark_fig.x;
        w.albedo *= 1.0 + 0.8 * rim;
        w.rough = light_sq.a * (1.0 + 0.6 * blot) + 0.25 * rim;
        w.cavity = fbm(p * 0.4 + 11.0);
        return w;
    }

    #ifdef BAKE_ROOM
    // The finish on the room's oak, laid as a joiner and a century laid it: the oak's own
    // color (w, rings' with the pores and rays), a stain (dark_sq) that goes deepest into
    // the open pores, dark wax (dark_fig) packed into them, an amber shellac or wax
    // (inlay) over everything, then age (inlay_fig): the light's ambering, uneven,
    // blotches, and grime in the pores and low fibres. The roughness is the wax's
    // (light_sq.a), rougher in the pores, smoother on the rays' flakes.
    Wood oak_finish(Wood w, vec2 p, float seed) {
        vec3 c = w.albedo;
        c *= pow(srgb(dark_sq.rgb), vec3(dark_sq.a * (1.0 + 0.6 * w.pore)));
        c = mix(c, srgb(dark_fig.rgb), dark_fig.a * w.pore);
        c *= pow(srgb(inlay.rgb), vec3(inlay.a));
        float blot = fbm(p * vec2(0.08, 0.03) + seed) - 0.5;
        float fine = fbm(p * vec2(0.9, 0.25) + seed * 1.3) - 0.5;
        c *= pow(vec3(0.97, 0.88, 0.7), vec3(inlay_fig.x * (1.0 + blot)));
        c *= 1.0 + inlay_fig.y * (1.4 * blot + 0.6 * fine);
        c *= 1.0 - inlay_fig.z * clamp((1.0 - w.cavity) * 2.0, 0.0, 1.0);
        // The rays' flakes: their cells take less stain and shine, a shade lighter and
        // greyer than the wood round them, the rest in their gloss.
        float y = dot(c, vec3(0.2126, 0.7152, 0.0722));
        c = mix(c, mix(c, vec3(y), 0.15) * 1.15, w.fleck);
        // Its tint (surfaces::Oak.tint, in the frame's slot): lighter by x, greyer or more
        // coloured by y about its luminance.
        y = dot(c, vec3(0.2126, 0.7152, 0.0722));
        w.albedo = max(mix(vec3(y), c, frame.y), vec3(0.0)) * frame.x;
        w.rough = light_sq.a + 0.2 * w.pore - 0.05 * w.fleck + 0.08 * fine + 0.05 * blot;
        return w;
    }

    // The room's oak (model3d::surfaces): boards side by side across x, each surface.x wide
    // and from a tree of its own, a little lighter or darker (surface.z), quarter-sawn
    // (on the floor a share surface.y of them, on the wall every other) or flat-sawn,
    // their grain along y. p from the field's corner.
    Wood oak_at(vec2 p) {
        float i = floor(p.x / surface.x);
        float seed = 17.0 + i * 7.31 + mode.x * 31.7;
        bool quarter = mode.x < 4.5 ? h1(seed, 0.77) < surface.y : mod(i, 2.0) < 0.5;
        vec4 ring = light_ring;
        ring.y = quarter ? 0.0 : 1.0;
        vec2 q = vec2(p.x - (i + 0.5) * surface.x, p.y);
        Wood w = rings(q, seed, light_sq, light_fig, ring, true);
        float tone = (h1(seed, 4.2) - 0.5) * 2.0 * surface.z;
        w.albedo *= vec3(1.0 + tone, 1.0 + 0.85 * tone, 1.0 + 0.6 * tone);
        return oak_finish(w, p, seed);
    }
    #endif

    // One call of wood() for every surface: each call site compiles in full, and a phone
    // makes the pipeline slowly.
    Wood at(vec2 p) {
        #ifdef BAKE_ROOM
        return oak_at(p + 0.5 * size.zw);
        #else
        #ifdef BAKE_TABLE
        Cut c = table_cut(p);
        Wood w = wood(c.q, c.seed, c.base, c.k, c.f, c.ring);
        return table_over(w, c, p);
        #else
        Cut c = mode.x < 0.5 ? plan(p) : frame_map(p);
        Wood w = wood(c.q, c.seed, c.base, c.k, c.f, c.ring);
        return mode.x < 0.5 ? plan_over(w, c, p) : frame_over(w, c, p);
        #endif
        #endif
    }

    // size is the full bake's (model3d::BAKE_SIDE); a phone's half-size target takes
    // tone.w 2 samples a side a texel at the full bake's texels, averaged as its first mip
    // would be, so the wood's fine detail (its furrows and pores a texel or two across)
    // looks as it does on a larger screen instead of twice as coarse.
    void main() {
        vec2 texel = size.zw / size.xy;
        vec2 origin = mode.x < 0.5 || mode.x > 1.5 ? 0.5 * size.zw : vec2(0.0);
        int n = int(tone.w + 0.5);
        vec2 p = (floor(gl_FragCoord.xy) * float(n) + 0.5 * float(n)) * texel - origin;
        #ifdef BAKE_TABLE
        if (mode.x > 2.5) {
            // The table's wear: x scratches, y crazing, z dents into the first target; the
            // scratches' normal (x, z) and the dents' into the second, apart, as TABLE_FRAG
            // masks them apart.
            float relief = 0.0015 * surface.w;
            vec4 sum = vec4(0.0);
            vec4 bump = vec4(0.0);
            vec4 here = vec4(0.0);
            vec4 dx = vec4(0.0);
            for (int k = 0; k < 3 * n * n; k++) {
                int j = k % 3;
                int s = k / 3;
                vec2 q = (floor(gl_FragCoord.xy) * float(n) + vec2(float(s % n), float(s / n)) + 0.5) * texel - origin;
                vec2 o = j == 1 ? vec2(texel.x, 0.0) : (j == 2 ? vec2(0.0, texel.y) : vec2(0.0));
                vec4 t = wear_at(q + o);
                if (j == 0) here = t;
                else if (j == 1) dx = t;
                else {
                    // Scratches 1.5 deep, dents 3, in the bake's relief units: shallower
                    // than the top's map had them, as they are 4 times as steep here.
                    vec2 gs = -1.5 * (vec2(dx.x, t.x) - here.x) / texel;
                    vec2 gd = -3.0 * (vec2(dx.z, t.z) - here.z) / texel;
                    vec3 ns = normalize(vec3(-gs.x * relief, 1.0, -gs.y * relief));
                    vec3 nd = normalize(vec3(-gd.x * relief, 1.0, -gd.y * relief));
                    bump += vec4(ns.xz, nd.xz);
                    sum += vec4(here.xyz, 1.0);
                }
            }
            float share = 1.0 / float(n * n);
            out_albedo = sum * share;
            out_normal = bump * share * 0.5 + 0.5;
            return;
        }
        #endif
        #ifdef BAKE_SLAB
        if (mode.x < 1.5 && mode.w >= 5.0 && mode.w < 9.0) {
            bool frame_cut = mode.x > 0.5;
            vec2 sq = floor((p + FIELD) * (mode.z / (2.0 * FIELD)));
            if (frame_cut || (max(abs(p.x), abs(p.y)) < FIELD && mod(sq.x + sq.y, 2.0) > 0.5)) {
                vec2 q = p.yx;
                float shade = 1.0;
                if (!frame_cut) {
                    Cut c = plan(p);
                    float angle = 6.283 * h12(sq);
                    vec2 axis = vec2(cos(angle), sin(angle));
                    q = vec2(dot(p, axis), dot(p, vec2(-axis.y, axis.x))) + c.seed * 2.3;
                    shade = c.shade;
                }
                out_albedo = black_slab(q, 0.55 * float(n) * max(texel.x, texel.y));
                out_albedo.rgb *= shade;
                out_normal = vec4(0.5, 0.5, 1.0, 1.0);
                return;
            }
        }
        #endif
        #ifndef BAKE_TABLE
        #ifndef BAKE_ROOM
        if (mode.x > 0.5 && mode.x < 1.5 && mode.w > 0.5 && frame_fig.w < 0.5 && carve.w < 0.5) {
            // A marble frame, flat: once a texel, no relief to take the normal from.
            Wood m = marble_at(p.yx);
            out_albedo = vec4(m.albedo, m.rough);
            out_normal = vec4(0.5, 0.5, 1.0, 1.0);
            return;
        }
        #endif
        #endif
        // Each sample and its neighbours along x and y, for the normal, in a loop the
        // compiler can't unroll (its count comes from the block): unrolled, the whole
        // wood compiles three times over.
        float relief = 0.0015 * (mode.x < 0.5 || mode.x > 1.5 ? surface.w : frame_surface.y);
        Wood w;
        vec2 hn = vec2(0.0);
        vec4 albedo = vec4(0.0);
        vec3 normal = vec3(0.0);
        float cavity = 0.0;
        int taps = mode.x > 9.0 ? 4 : 3;
        for (int k = 0; k < taps * n * n; k++) {
            int j = k % taps;
            int s = k / taps;
            vec2 q = (floor(gl_FragCoord.xy) * float(n) + vec2(float(s % n), float(s / n)) + 0.5) * texel - origin;
            vec2 o = j == 1 ? vec2(texel.x, 0.0) : (j == 2 ? vec2(0.0, texel.y) : vec2(0.0));
            Wood t = at(q + o);
            if (j == 0) w = t;
            else if (j == 1) hn.x = t.height;
            else hn.y = t.height;
            if (j == 2) {
                vec2 grad = (hn - w.height) / texel;
                normal += normalize(vec3(-grad.x * relief, 1.0, -grad.y * relief));
                albedo += vec4(w.albedo, w.rough);
                cavity += w.cavity;
            }
        }
        float share = 1.0 / float(n * n);
        out_albedo = albedo * share;
        // The normal's x and z, the cavity's occlusion, the normal's y: what the samples
        // and the mips average shortens the normal, which widens the roughness where they
        // blur.
        vec3 m = normal * share;
        out_normal = vec4(m.x * 0.5 + 0.5, m.z * 0.5 + 0.5, cavity * share, m.y);
    }
    """;
