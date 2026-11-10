// gui::stack, a column or row of children laid out in one pass: sized children with gaps
// from the stack's start; a growing one taking what they leave, two sharing it by weight;
// nothing growing, the children at the start, middle, or end; too tall, the children
// running on past the end and a growing one getting nothing; across, the whole width or
// a child's own, at the left, middle, or right; and a row.
import std;
import vec;
import gui from "../../src/gui";

fn show(name: const u8[:], items: const gui::Item[:], area: float4, dir: i64 = gui::DOWN, justify: i64 = gui::LEFT) {
    var out: float4[4] = [float4 { 0.0, 0.0, 0.0, 0.0 }; 4];
    gui::stack(area, items, out, dir, justify);
    print(name, ":");
    for i in items.len { print("  ", out[i].x, " ", out[i].y, " ", out[i].z, " ", out[i].w); }
}

fn main() {
    let area = float4 { 10.0, 20.0, 200.0, 300.0 };
    show("sized, with gaps", [gui::Item { size: 50.0, .. }, gui::Item { size: 30.0, gap: 10.0, .. },
                              gui::Item { size: 20.0, gap: 5.0, .. }], area);
    show("one grows", [gui::Item { size: 50.0, .. }, gui::Item { grow: 1.0, gap: 10.0, .. },
                       gui::Item { size: 40.0, gap: 10.0, .. }], area);
    show("two grow, 1 and 3, one with a size of its own",
         [gui::Item { grow: 1.0, .. }, gui::Item { size: 20.0, grow: 3.0, gap: 20.0, .. }], area);
    let two = [gui::Item { size: 100.0, .. }, gui::Item { size: 60.0, gap: 40.0, .. }];
    show("none grows, at the start", two, area);
    show("in the middle", two, area, gui::DOWN, gui::CENTER);
    show("at the end", two, area, gui::DOWN, gui::RIGHT);
    show("too tall: run on, nothing to grow",
         [gui::Item { size: 250.0, .. }, gui::Item { grow: 1.0, gap: 20.0, .. }, gui::Item { size: 100.0, gap: 20.0, .. }],
         area, gui::DOWN, gui::CENTER);
    show("across: whole, left, middle, right",
         [gui::Item { size: 10.0, .. }, gui::Item { size: 10.0, across: 50.0, .. },
          gui::Item { size: 10.0, across: 50.0, align: gui::CENTER, .. },
          gui::Item { size: 10.0, across: 50.0, align: gui::RIGHT, .. }], area);
    show("a row, the middle growing, the last centered down it",
         [gui::Item { size: 60.0, .. }, gui::Item { grow: 1.0, gap: 8.0, .. },
          gui::Item { size: 60.0, gap: 8.0, across: 100.0, align: gui::CENTER, .. }], area, gui::ALONG);
}
