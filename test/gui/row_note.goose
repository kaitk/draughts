// A menu row's note keeps gui::NOTE_GAP from its label: drawn whole where both fit, shrunk
// to fit where it would run into the label (a long translation in landscape's 360 dp
// column, Estonian's "Vaata kordust" with "Kaotasid · raske"), and left out where it
// would shrink below NOTE_LEAST, its icon then alone at the row's right.
import std;
import vec;
import gui from "../../src/gui";

// A row 360 wide; prints where the label ends, where the note starts and its glyphs'
// height (whole at the small face's 0.8 of its size), and where the note's icon starts.
fn show(g: gui::Gui&, what: const u8[:], label: const u8[:], note: const u8[:], icon: i64 = gui::NO_ICON) {
    gui::begin(g, gui::Input { at: float2 { -1.0, -1.0 }, .. }, 1.0, 0.0);
    let first = g.quads.len;
    gui::row(g, 1, float4 { 0.0, 0.0, 360.0, 88.0 }, gui::NEXT, label, note, false, true, false, icon);
    var label_end: f32 = 0.0;
    var note_at: f32 = -1.0;
    var note_h: f32 = 0.0;
    var icon_at: f32 = -1.0;
    var n = 0;
    for q in g.quads[first..] {
        if q.look.x == gui::TEXT {
            if n < label.len { label_end = q.rect.x + q.rect.z; }
            else { if note_at < 0.0 { note_at = q.rect.x; } note_h = q.rect.w; }
            n++;
        } else if q.look.x == gui::ICON && q.rect.x > 100.0 { icon_at = q.rect.x; }
    }
    print(what, ": label ends ", label_end, ", note at ", note_at, " ", note_h, " tall, icon at ", icon_at);
}

fn main() {
    var g = gui::Gui {};
    gui::test_faces(g);
    gui::desktop_scale = 0.0;
    show(g, "both fit", "Replay", "Lost");
    show(g, "a little long: the note shrunk", "Kordus", "Kaotasid arvutile raske");
    show(g, "too long: no note", "Vaata kordust", "Kaotasid raske");
    show(g, "too long, with an icon: the icon alone", "Vaata kordust", "Kaotasid raske", gui::COMPUTER);
}
