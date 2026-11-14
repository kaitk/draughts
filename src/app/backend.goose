// The one seam between the app and its renderer, in the builds with gfx alone (this file,
// which src/app/draughts.goose imports): with() runs its block on gfx's backend (gpu::Gfx),
// and open() opens gfx's window. The build that holds goose-ngfx too has its own
// backend.goose (src/ngfx/), which chooses one at start. render.goose and host.goose call
// only these two; the drawers below them take the backend as a parameter, so each is
// compiled once per backend and calls it directly.
namespace backend;
import std;
import vec;

var gfx_backend: gpu::Gfx;

// The block, given the backend.
fn with<F>() { F(&gfx_backend) }

fn open(title: const u8[:], width: i64, height: i64, flags: i64, no_vsync: bool) {
    host_gpu::open(title, width, height, flags, no_vsync);
}
