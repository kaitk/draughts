// The game's 3D board (task 015), behind the `--3d` flag with the Board row's 3D chosen
// (settings::raised). A stub until poc/3d's renderer moves here: each drawn frame fills
// the 3D board's scene from the flat board's draw lists (view3d::fill) and works out what
// it would draw again, the board when its inputs changed and the shadow map when the
// pieces stand differently (view3d::changes), while the flat board is still what is drawn,
// in the 3D layout's flat square (draw.goose).
namespace draw3d;
import std;
import vec;

struct Drawer {
    scene:   view3d::Scene = view3d::Scene {},     // this frame's
    drawn:   view3d::Scene = view3d::Scene {},     // the last one drawn
    redraw:  bool          = false,                 // this frame draws the 3D board again,
    shadow:  bool          = false,                 // and the shadow map first
    frames:  i64           = 0,                     // frames that showed the 3D board,
    draws:   i64           = 0,                     // those that would draw it,
    shadows: i64           = 0,                     // and the shadow map
}

// The frame board::fill left in b, on the flat layout l, seen through v.
fn frame(d: Drawer&, b: board::Board&, l: board::Layout, v: view3d::View) {
    view3d::fill(d.scene, b, l, v);
    let c = view3d::changes(d.drawn, d.scene);
    d.redraw = c & view3d::DRAW != 0;
    d.shadow = c & view3d::SHADOW != 0;
    d.frames++;
    if d.redraw {
        d.draws++;
        d.drawn = d.scene;
    }
    if d.shadow { d.shadows++; }
}
