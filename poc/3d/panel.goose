// The prototype's tuning panel (P): gfx ui sliders over the board for the wood's finish
// and the winter frame's marble, the parameters in the look data (looks::Finish,
// looks::Marble) the app reads too. A tool on the Mac, not the app's UI: it allocates
// while shown (ui's input and drawing), nothing while hidden. The values are baked only
// when they settle: on the slider's release, or after it has been held still a moment.
// "Print" (or V) writes them to stdout as Goose literals, to paste into looks.goose as
// the defaults.
namespace panel;
import std;
import vec;
import gfx;
import ui;

let X:      f32 = 12.0;
let Y:      f32 = 12.0;
let WIDTH:  f32 = 300.0;
let HEIGHT: f32 = 452.0;
let ROW:    f32 = 22.0;
let SETTLE: f64 = 0.35;  // seconds a held slider waits before baking

struct Panel {
    shown:      bool,
    ctx:        ui::Context,
    wood:       i64,
    finish:     looks::Finish,
    marble:     i64,
    stone:      looks::Marble,
    seen_f:     looks::Finish,  // last frame's, to tell when they last changed
    seen_m:     looks::Marble,
    changed_at: f64,
    // Where the varnish slider and the Print button are, in pixels (for --frames).
    varnish_at: ui::Rect,
    print_at:   ui::Rect,
}

// A panel holding g's values, hidden; its ui context is made the first time it shows,
// drawn `scale` pixels to the ui's unit.
fn new(g: render3d::Gpu&) -> Panel {
    var p = Panel { shown: false, ctx: default<ui::Context>(), wood: g.wood, finish: g.finish,
                    marble: g.marble, stone: g.stone, seen_f: g.finish, seen_m: g.stone,
                    changed_at: 0.0, varnish_at: ui::rect(0, 0, 0, 0), print_at: ui::rect(0, 0, 0, 0) };
    return p;
}

// Shows or hides the panel.
fn toggle(p: Panel&, scale: f32) {
    p.shown = !p.shown;
    if p.shown && p.ctx.id == 0 {
        p.ctx = ui::create(14.0, scale);
        guard p.ctx.id != 0 else { abort(str("ui: ", ui::error())); }
    }
}

// Takes g's values again, after a key switched the wood or the marble.
fn sync(p: Panel&, g: render3d::Gpu&) {
    p.wood = g.wood;
    p.finish = g.finish;
    p.marble = g.marble;
    p.stone = g.stone;
}

// A label with its value, and a slider; returns the slider's bounds.
fn slider(c: ui::Context, name: const u8[:], v: f32&, lo: f32, hi: f32) -> ui::Rect {
    let ratios: f32[2] = [0.42, 0.58];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    var text: u8[>..] = [];
    text.append(name);
    text.push(' ');
    num(text, v);
    ui::label(c, text, ui::TEXT_LEFT);
    let r = ui::widget_bounds(c);
    ui::slider_float(c, lo, v, hi, (hi - lo) / 200.0);
    return r;
}

fn variant(c: ui::Context, name: const u8[:], v: i64&, hi: i64) -> bool {
    let ratios: f32[2] = [0.42, 0.58];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    ui::label(c, str(name, " ", v), ui::TEXT_LEFT);
    return ui::slider_int(c, 0, v, hi, 1);
}

fn heading(c: ui::Context, text: const u8[:]) {
    ui::layout_row_dynamic(c, ROW, 1);
    ui::label(c, text, ui::TEXT_LEFT);
}

// The panel's frame, after gfx::frame(): its input, its window, what was changed.
// Returns whether it should be drawn again: any `input` this frame, or a value changed.
fn frame(p: Panel&, now: f64, input: bool) -> bool {
    let c = p.ctx;
    ui::input_from_gfx(c);
    let flags = ui::WINDOW_BORDER | ui::WINDOW_TITLE | ui::WINDOW_MOVABLE | ui::WINDOW_NO_SCROLLBAR;
    var printed = false;
    let s = ui::scale(c);
    if ui::begin(c, "Tuning (P)", ui::rect(X, Y, WIDTH, HEIGHT), flags) {
        heading(c, "Wood");
        if variant(c, "variant", p.wood, render3d::WOOD_MODELS - 1) { p.finish = looks::finish(p.wood); }
        p.varnish_at = scaled(slider(c, "varnish", p.finish.varnish, 0.0, 1.0), s);
        slider(c, "sanding", p.finish.sanding, 0.0, 1.0);
        slider(c, "grain", p.finish.grain, 0.0, 2.0);
        slider(c, "rings", p.finish.rings, 0.5, 2.0);
        slider(c, "warmth", p.finish.warmth, -1.0, 1.0);
        heading(c, "Marble (winter frame)");
        if variant(c, "variant", p.marble, looks::MARBLES - 1) { p.stone = looks::marble(p.marble); }
        slider(c, "veins", p.stone.veins, 0.0, 2.0);
        slider(c, "waviness", p.stone.wave, 0.0, 2.5);
        slider(c, "polish", p.stone.polish, 0.0, 1.0);
        slider(c, "tint", p.stone.tint, 0.0, 1.0);
        ui::layout_row_dynamic(c, ROW + 4.0, 3);
        p.print_at = scaled(ui::widget_bounds(c), s);
        if ui::button_label(c, "Print") { printed = true; }
        if ui::button_label(c, "Defaults") {
            p.finish = looks::finish(p.wood);
            p.stone = looks::marble(p.marble);
        }
        if ui::button_label(c, "Plain") { p.finish = looks::PLAIN; }
    }
    ui::end(c);
    if printed || gfx::key_pressed("V") { print_values(p); }
    var changed = false;
    if p.finish != p.seen_f || p.stone != p.seen_m {
        p.seen_f = p.finish;
        p.seen_m = p.stone;
        p.changed_at = now;
        changed = true;
    }
    return changed || input;
}

fn scaled(r: ui::Rect, s: f32) -> ui::Rect { ui::rect(r.x * s, r.y * s, r.w * s, r.h * s) }

// Whether the mouse is the panel's this frame (over it, or a drag begun on it).
fn wants_mouse(p: Panel&) -> bool { p.shown && ui::wants_mouse(p.ctx) }

// Bakes the panel's values into g once they settle: the mouse released, or a slider
// held still SETTLE seconds. Returns whether it baked.
fn settle(p: Panel&, g: render3d::Gpu&, now: f64) -> bool {
    let same = p.wood == g.wood && p.finish == g.finish && p.marble == g.marble && p.stone == g.stone;
    guard !same else { return false; }
    guard !gfx::mouse_down(gfx::MOUSE_LEFT) || now - p.changed_at > SETTLE else { return false; }
    let c = clock();
    render3d::tune(g, p.wood, p.finish, p.marble, p.stone);
    print("tuned: wood ", g.wood, ", marble ", g.marble, ", baked in ", (clock() - c) * 1000.0, " ms");
    return true;
}

fn draw(p: Panel&) { ui::render(p.ctx); }

// x with up to three decimals, at least one.
fn num(out: u8[>..]&, x: f32) {
    let v = (abs(x) * 1000.0 + 0.5) as i64;
    if x < 0.0 && v > 0 { out.push('-'); }
    format(out, v / 1000);
    out.push('.');
    let f = v % 1000;
    out.push(('0' + f / 100) as u8);
    if f % 100 != 0 { out.push(('0' + f / 10 % 10) as u8); }
    if f % 10 != 0 { out.push(('0' + f % 10) as u8); }
}

fn num4(out: u8[>..]&, v: float4) {
    out.append("float4 { ");
    num(out, v.x);
    out.append(", ");
    num(out, v.y);
    out.append(", ");
    num(out, v.z);
    out.append(", ");
    num(out, v.w);
    out.append(" }");
}

// The values as Goose literals, for looks::finish and looks::marble.
fn print_values(p: Panel&) {
    let f = p.finish;
    var a: u8[>..] = [];
    format(a, "// wood ", p.wood, "\nlooks::Finish { varnish: ");
    num(a, f.varnish);
    a.append(", sanding: ");
    num(a, f.sanding);
    a.append(", grain: ");
    num(a, f.grain);
    a.append(", rings: ");
    num(a, f.rings);
    a.append(", warmth: ");
    num(a, f.warmth);
    a.append(" }");
    print(a);
    let m = p.stone;
    var b: u8[>..] = [];
    format(b, "// marble ", p.marble, "\nlooks::Marble { base: ");
    num4(b, m.base);
    b.append(", vein: ");
    num4(b, m.vein);
    b.append(",\n                form: ");
    num4(b, m.form);
    b.append(",\n                veins: ");
    num(b, m.veins);
    b.append(", wave: ");
    num(b, m.wave);
    b.append(", polish: ");
    num(b, m.polish);
    b.append(", tint: ");
    num(b, m.tint);
    b.append(" }");
    print(b);
}
