// The 3D board's model without graphics (model3d, task 061): the plan a theme is put on
// in, step by step (render3d::theme_step runs each in a frame of its own), for the full
// frame map and a mitred one, so every row of each surface is baked once, in order, its
// mips with its last band; and the photograph's light as harmonics: a grey photograph
// lights evenly (only the first band, the mean, has light: the grey's linear value times
// 0.282 × 4π, 3.54), one lit from above has its light in the y band too, and
// `toward_grey` takes a colored one's light to grey.
import std;
import vec;
import model3d from "../../src/model3d";

let WHAT = ["begin", "pipeline", "plan", "frame", "photo pipelines", "photo"];

fn plan(rows: i64) {
    print("a frame map ", rows, " rows high:");
    var line: u8[>..] = [];
    var plan_to = 0;
    var frame_to = 0;
    for k in model3d::THEME_STEPS {
        let s = model3d::step(k, rows);
        line.clear();
        format(line, "    ", k, " ", WHAT[s.what]);
        if s.what == model3d::PIPELINE || s.what == model3d::PLAN || s.what == model3d::FRAME {
            format(line, " rows ", s.y0, "..", s.y1);
            if s.mips { format(line, ", mips"); }
        }
        if s.what == model3d::PHOTO { format(line, " part ", s.part); }
        print(line);
        // Each band begins where the one before ended.
        if s.what == model3d::PLAN {
            if s.y0 != plan_to { print("    the plan's bands don't meet"); }
            plan_to = s.y1;
        }
        if s.what == model3d::FRAME {
            if s.y0 != frame_to { print("    the frame map's bands don't meet"); }
            frame_to = s.y1;
        }
    }
    print("    the plan to row ", plan_to, " of ", model3d::PLAN_SIZE, ", the frame map to ", frame_to, " of ", rows);
}

// Nine harmonics, two decimals each.
fn show(name: const u8[:], sh: float4[9]) {
    var line: u8[>..] = [];
    format(line, name, ":");
    for c in sh { format(line, " (", floor(c.x * 100.0 + 0.5) / 100.0, " ", floor(c.y * 100.0 + 0.5) / 100.0, " ",
                         floor(c.z * 100.0 + 0.5) / 100.0, ")"); }
    print(line);
}

fn main() {
    plan(model3d::FRAME_MAP);
    plan(model3d::FRAME_MITRED_ROWS);
    let n = 64;
    var px: u8[>..] = [];
    for i in n * n * 4 { px.push(if i % 4 == 3 { 255 } else { 128 }); }
    print("the grey's linear value: ", floor(model3d::linear(128.0 / 255.0) * 1000.0 + 0.5) / 1000.0);
    show("grey", model3d::harmonics(px[..], n, 0.0));
    // Lit above the horizon, dark below.
    for y in n {
        for x in n {
            let v: u8 = if y < n / 2 { 255 } else { 0 };
            for c in 3 { px[(y * n + x) * 4 + c] = v; }
        }
    }
    show("lit from above", model3d::harmonics(px[..], n, 0.0));
    // Orange, then half way to grey.
    for i in n * n {
        px[i * 4] = 230;
        px[i * 4 + 1] = 120;
        px[i * 4 + 2] = 30;
    }
    show("orange", model3d::harmonics(px[..], n, 0.0));
    show("orange half grey", model3d::harmonics(px[..], n, 0.5));
}
