// The sound bank rendered headless (docs/architecture/sound.md): every sound built into
// an offline mixer, played alone, and rendered until it ends. Each must be heard (its peak
// over -40 dBFS at full volume), finite, and over within its length, and the moves and the
// moments within what the design gives them: a move about 0.1 s, a moment under 3.5 s, its tail cut once it is quiet.
import std;
import math;
import audio;
import sound from "../../src/sound";

let NAMES = ["move", "take", "crown", "wrong", "must", "gold", "red", "solved", "won", "lost", "drawn", "crown (computer)"];
let MOST = [0.15, 0.15, 3.5, 0.5, 0.5, 3.5, 3.5, 3.5, 3.5, 3.5, 3.5, 0.5];

fn main() {
    var bk = sound::Bank {};
    if !sound::set_level(bk, 1.0, false, true) {
        print("no mixer: ", audio::error());
        exit(1);
    }
    print("sounds ", bk.count, ": ", bk.moves, " moves, ", bk.takes, " takes");
    var bytes = 0;
    for i in bk.count { bytes += 4 * bk.frames[i]; }
    print("in the mixer ", (bytes + 512) / 1024, " KB");
    var buf: f32[512] = [0.0; 512];
    var bad = 0;
    for kind in sound::KINDS {
        let v = sound::play(bk, kind);
        var frames = 0;
        var top: f32 = 0.0;
        var finite = true;
        while audio::playing(v) && frames < 10 * sound::RATE {
            audio::render(buf[..]);
            for x in buf {
                top = max(top, abs(x));
                if !is_finite(x) { finite = false; }
            }
            frames += buf.len / 2;
        }
        let len = sound::length(bk, kind);
        let seconds = len as f64 / sound::RATE;
        let heard = top > 0.01;
        let ok = heard && finite && frames <= len + buf.len / 2 && seconds <= MOST[kind];
        if !ok { bad++; }
        print(NAMES[kind], ": ", if ok { "ok" } else { "WRONG" }, ", ", (1000 * len + sound::RATE / 2) / sound::RATE, " ms", if heard { "" } else { ", silent" },
              if finite { "" } else { ", not finite" }, if seconds <= MOST[kind] { "" } else { ", too long" });
    }
    // A capture's stops: a move a step up each, shorter as it is played faster.
    let v = sound::play(bk, sound::MOVE, 4);
    print("a stop four steps up plays: ", audio::playing(v));
    // A move and a take each pick their own hits, never the same twice running.
    var own = true;
    var again = false;
    var last = [-1, -1];
    for k in 40 {
        let kind = if k % 2 == 0 { sound::MOVE } else { sound::TAKE };
        let i = sound::sound_of(bk, kind);
        if kind == sound::MOVE && (i < 0 || i >= bk.moves) { own = false; }
        if kind == sound::TAKE && (i < bk.moves || i >= bk.moves + bk.takes) { own = false; }
        if i == last[k % 2] { again = true; }
        last[k % 2] = i;
    }
    print("a move's hits and a take's their own: ", own, ", one twice running: ", again);
    sound::set_level(bk, 0.0, false, true);
    print("at zero: open ", bk.open, ", sounds ", bk.count);
    if bad > 0 { exit(1); }
}
