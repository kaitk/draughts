// The one seam between the app and its renderer in the gfx-only build: with() runs its
// block on gfx's backend. The build holding goose-ngfx too has its own backend.goose
// (src/ngfx/), which chooses one at start. The drawers take the backend as a parameter,
// so each is compiled once per backend and calls it directly.
namespace backend;
import std;
import vec;

var gfx_backend: gpu::Gfx;

fn with<F>() { F(&gfx_backend) }

fn open(title: const u8[:], width: i64, height: i64, flags: i64, no_vsync: bool) {
    host_gpu::open(title, width, height, flags, no_vsync);
}
