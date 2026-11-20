// The tables the 3D board can stand on, as data: its edge's profile and the bake's
// (shaders::BAKE_FRAG's mode 2, which reads it in a look's light squares' slots): a
// wood's color and roughness, its figure, growth rings, pores and finish, how the top is
// made of planks, and its age. Each a take on the manor concepts' tables (task 093),
// tuned in tools/table_tune.
namespace tables;
import std;
import vec;

// The takes: mahogany made as the board's own frame is, its growth rings, pores and
// fibre, under a glossy varnish, worn; and flame mahogany, book-matched, its figure
// swept into flames and swirls.
let BOARD_WOOD = 0;
let FLAME = 1;
let COUNT = 2;
let NAMES = ["board", "flame"];

// The table each look stands on with settings' Table background: the flame mahogany for
// every look till each board has a table of its own.
fn for_look(look: i64) -> i64 { FLAME }

struct Table {
    wood:  float4,          // sRGB and the polish's roughness on the top
    fig:   float4,          // as looks::Theme.light_fig
    ring:  float4,          // as looks::Theme.light_ring
    model: f32,             // the wood's model (model3d::WOOD_MODELS), as the board's
    // x pores, y open pores, z late-wood furrows (the noise models'; frame_surface's)
    pores: float4,
    // x each plank's own tone, y pores, z the seams' darkness, w relief, as Theme.surface
    surface: float4,
    // x a plank's width (world units, a square is 1), y a seam's half width, z the
    // ribbon figure's contrast, w the ribbon's stripes per unit across the grain
    planks: float4,
    // Its age (BAKE_FRAG's table_over, the finer wear wear_at's): x the old varnish's
    // blotches, y its fine crazing, z scratches, w dents and nicks
    patina: float4,
    // x how much lighter the rim is where hands wore the varnish, y how wide (world units)
    wear: float4,
    // The flame figure (BAKE_FRAG's table_over): x how strong, y its scale (flames a
    // unit), z how far the flames sweep and swirl, w how alike two book-matched leaves
    // are about a seam down the middle (1 a mirror; 0 one piece, no seam)
    flame:  float4,
    finish: looks::Finish,
    // The light on it (shaders::TABLE_FRAG's pool): x its reach round the board (world
    // units), y how dim beyond, z how dark the edge's underside, w how strong the board's
    // reflection in it
    light: float4,
    // Its polish (TABLE_FRAG's coat): x the polish's roughness on the edge (the top's is
    // baked: wood.w, raised where scratched and worn), y how strong it is, z how far it
    // follows the wood's relief, w how broad the key light's highlight in it (a
    // roughness: the key is a window)
    coat: float4,
    // How the polish varies, as old varnish does (TABLE_FRAG): x how much its roughness
    // changes in blotches, y how much its strength (duller where rougher), z the
    // blotches' size (world units), w how much the wear shows in it: the scratches and
    // dents catching the light, the worn rim duller
    polish: float4,
    // Its edge (mesh::table_profile): x the profile (mesh::EDGE_BULLNOSE..), y the top's
    // thickness, z the moulding's size, w how far in the frieze is set
    edge: float4,
}

// Mahogany made as the board's frame is (looks::autumn's frame, the TUNED finish): its
// growth rings, pores and fibre showing, under a glossy varnish, blotched and worn
// lighter at the rim (2026-11-19).
fn board_wood() -> Table {
    return Table {
        wood:    float4 { 0.42, 0.19, 0.11, 0.098 },
        fig:     float4 { 0.2, 0.25, 0.45, 1.0 },
        ring:    float4 { 0.05, 0.3, 0.6, 0.6 },
        model:   2.0,
        pores:   float4 { 1.0, 0.0, 1.2, 0.0 },
        surface: float4 { 0.08, 1.0, 0.4, 1.0 },
        planks:  float4 { 6.0, 0.005, 0.0, 1.6 },
        patina:  float4 { 0.988, 0.105, 0.0, 0.208 },
        wear:    float4 { 0.485, 1.036, 0.0, 0.0 },
        flame:   float4_0,
        finish: looks::Finish { varnish: 0.5, sanding: 0.3, grain: 1.0, rings: 1.0, warmth: 0.15, pickle: 0.0,
                                caulk: 1.0 },
        light: float4 { 8.603, 0.192, 0.53, 1.0 },
        coat:  float4 { 0.203, 0.799, 0.25, 0.35 },
        polish: float4 { 0.3, 0.25, 2.5, 0.6 },
        edge:  float4 { 3.0, 0.9, 0.38, 1.4 },
    };
}

// Flame mahogany, two leaves of one log, little alike: deep red-brown, its figure swept
// into dark flames and golden swirls, the rings and pores faint under it, glossy, worn
// at the rim, a few dents and scratches (tuned 2026-11-19).
fn flame() -> Table {
    return Table {
        wood:    float4 { 0.4, 0.17, 0.09, 0.1 },
        fig:     float4 { 0.2, 0.15, 0.25, 1.0 },
        ring:    float4 { 0.05, 0.3, 0.25, 0.4 },
        model:   2.0,
        pores:   float4 { 0.6, 0.0, 0.4, 0.0 },
        surface: float4 { 0.0, 0.6, 0.6, 0.6 },
        planks:  float4 { 40.0, 0.004, 0.0, 1.6 },
        patina:  float4 { 0.5, 0.05, 0.12, 0.3 },
        wear:    float4 { 0.6, 1.1, 0.0, 0.0 },
        flame:   float4 { 0.8, 0.3, 0.61, 0.15 },
        finish: looks::Finish { varnish: 0.5, sanding: 0.3, grain: 1.0, rings: 1.0, warmth: 0.15, pickle: 0.0,
                                caulk: 1.0 },
        light: float4 { 8.603, 0.192, 0.53, 1.0 },
        coat:  float4 { 0.2, 0.8, 0.25, 0.35 },
        polish: float4 { 0.3, 0.25, 2.5, 0.6 },
        edge:  float4 { 3.0, 0.9, 0.38, 1.4 },
    };
}

fn get(which: i64) -> Table { if which == FLAME { flame() } else { board_wood() } }
