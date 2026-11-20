// The wind in the trees (rooms::wind_at) over ten minutes of the library's mild default:
// gusts now and then, a few seconds each; the limbs moving far less than the leaves; the
// leaf layers out of step (their shifts' correlation well under 1); nothing past its reach.
import std;
import vec;
import math;
import model3d from "../../src/model3d";

fn main() {
    let r = rooms::get(rooms::LIBRARY);
    let span: f32 = 1.0;
    let steps = 6000;
    var gusty = 0;
    var gusts = 0;
    var was_gusty = false;
    var most:   f32[4] = [0.0, 0.0, 0.0, 0.0];
    var sum_nm: f64    = 0.0;
    var sum_nn: f64    = 0.0;
    var sum_mm: f64    = 0.0;
    var mean_n: f64    = 0.0;
    var mean_m: f64    = 0.0;
    for i in steps {
        let w = rooms::wind_at(r, (i as f32) * 0.1, span);
        let g = w.now.y;
        if g < 0.0 || g > 1.0 { print("a gust out of 0..1"); }
        let is_gusty = g > 0.2;
        if is_gusty { gusty += 1; }
        if is_gusty && !was_gusty { gusts += 1; }
        was_gusty = is_gusty;
        for k in 4 {
            let s = w.shift[k];
            let x = s.x + g * s.z;
            let y = s.y + g * s.w;
            most[k] = max(most[k], sqrt(x * x + y * y));
        }
        let n = (w.shift[1].x + g * w.shift[1].z) as f64;
        let m = (w.shift[2].x + g * w.shift[2].z) as f64;
        mean_n += n;
        mean_m += m;
        sum_nm += n * m;
        sum_nn += n * n;
        sum_mm += m * m;
    }
    let k = steps as f64;
    mean_n /= k;
    mean_m /= k;
    let cov = sum_nm / k - mean_n * mean_m;
    let corr = cov / sqrt((sum_nn / k - mean_n * mean_n) * (sum_mm / k - mean_m * mean_m));
    print("gusts: ", gusts, " in ten minutes, gusty ", gusty * 100 / steps, "% of the time");
    print("limbs reach ", floor(most[0] * 1000.0 + 0.5) as i64, " thousandths of a unit, the near leaves ",
          floor(most[1] * 1000.0 + 0.5) as i64);
    print("the limbs under a fifth of the leaves: ", most[0] < most[1] * 0.2);
    print("near and middle leaves out of step: ", corr < 0.9);
}
