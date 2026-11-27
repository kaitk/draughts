// goose-ngfx's half of the build that holds both renderers: gfx's handle types on ngfx's
// calls (nx), the window's half, and the 3D board's recorder.
// The entry of the package src/ngfx/, which the roots declare as gpu_ngfx (a package
// can't be named ngfx, goose-ngfx's name); the app's root imports its backend.goose, the
// seam, which brings the app's drawers (app_ngfx.goose).
namespace gpu_ngfx;
import std;
import vec;
import ngfx;
import .nx;
import .host_ngfx;
import .render3d_ngfx;
