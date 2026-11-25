// The 3D board's shaders, GLSL 450 that embed_shader compiles with the program. One
// forward pass draws everything lit: the board and the pieces share one fragment shader
// (GGX after Filament, wrap diffuse, Filament's specular antialiasing, 9 weighted
// hardware-compared shadow taps over 5 × 5 texels on a tablet, 16 over 7 × 7 on iOS and a
// desktop, 4 over 3 × 3 on a phone, analytic occlusion, an ambient of nine spherical
// harmonics taken from the photograph, a mild tonemap). The wood is baked once at
// startup by the bake shader into textures with mips.
//
// The board's measures are repeated here from mesh.goose, as embed_shader takes only a
// literal: test/model3d/geometry checks each against the mesh's.
namespace shaders;

// The pieces, one file a kind of thing drawn, all in this namespace (task 118).
import .shaders.frame;
import .shaders.light;
import .shaders.board;
import .shaders.table;
import .shaders.room;
import .shaders.outside;
import .shaders.tree;
import .shaders.air;
import .shaders.passes;
import .shaders.bake;
